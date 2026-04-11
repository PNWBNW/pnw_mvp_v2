// ---------------------------------------------------------
// Layer 2 — Credential NFTs v2 (dual-record edition)
// ---------------------------------------------------------
//
// Purpose:
// - Mint revocable credential NFTs that bind a worker to a scope +
//   document commitment issued by an employer.
// - Keep credential content private while anchoring public status,
//   height, and issuer identity on-chain for verifiable audit.
//
// What changed vs v1 (`credential_nft.aleo`):
// - Each mint emits TWO records from a single transition:
//     * an employer-owned authoritative `CredentialNFT`
//     * a worker-owned `CredentialNFT` with identical fields
//   The worker's wallet scan picks up their copy automatically,
//   giving them in-wallet visibility into credentials issued to them.
// - The record now carries `issuer_addr` and `worker_addr` explicitly
//   so the portal can render employer and worker identities without
//   cross-referencing any other record.
// - A new public mapping `credential_issuer` records the authoritative
//   issuer address keyed by `credential_id`, enabling the employer to
//   revoke via public mapping flip without needing to consume either
//   record copy.
// - Revoke is split into three paths:
//     * `revoke_by_issuer` — employer flips public status; no record
//       consumption; affects both wallet copies when they read the
//       public status mapping.
//     * `revoke_by_owner` — record holder consumes their own record
//       AND flips public status (used by the employer when they want
//       to both revoke and prune their wallet in one call).
//     * `burn_view` — worker deletes their own copy without affecting
//       public status (declining or hiding a credential that still
//       exists in the employer's records).
// - Declared `@admin` so we can iterate during the buildathon window.
//   Move to `@noupgrade` post-mainnet.

// ---------------------------------------------------------
// Helper assertions (declared outside the program block so they
// are non-entry utility fns and can be called from final blocks)
// ---------------------------------------------------------
fn assert_cred_status_valid(s: u8) {
    assert(s == 0u8 || s == 1u8 || s == 2u8);
}

program credential_nft_v2.aleo {

    const STATUS_ACTIVE: u8 = 1u8;
    const STATUS_REVOKED: u8 = 2u8;

    // ---------------------------------------------------------
    // Record
    // ---------------------------------------------------------
    // All fields private. The owner field determines which wallet
    // can decrypt and scan this record. Two records with the same
    // credential_id but different owners can co-exist on-chain.
    record CredentialNFT {
        credential_id: [u8; 32],

        // Identity / scope commitments
        subject_hash: [u8; 32],   // BLAKE3 hash of worker name
        issuer_hash: [u8; 32],    // BLAKE3 hash of employer name
        scope_hash: [u8; 32],

        // Document commitments
        doc_hash: [u8; 32],
        root: [u8; 32],

        schema_v: u16,
        policy_v: u16,

        // Metadata sentinel — real height lives in credential_anchor_height
        minted_height: u32,

        // Parties (private, stored in both copies)
        issuer_addr: address,
        worker_addr: address,

        // Ownership — determines which wallet decrypts this copy.
        // Employer copy sets owner = issuer_addr.
        // Worker copy sets owner = worker_addr.
        owner: address,
    }

    // ---------------------------------------------------------
    // Public mappings
    // ---------------------------------------------------------
    mapping credential_anchor_height: [u8; 32] => u32;
    mapping credential_status: [u8; 32] => u8;
    mapping credential_revoked_height: [u8; 32] => u32;
    mapping credential_issuer: [u8; 32] => address;
    mapping scope_anchor_height: [u8; 32] => u32;

    // ---------------------------------------------------------
    // Mint — emits two CredentialNFT records (employer + worker)
    // ---------------------------------------------------------
    fn mint_credential_nft(
        worker_addr: address,
        credential_id: [u8; 32],
        subject_hash: [u8; 32],
        issuer_hash: [u8; 32],
        scope_hash: [u8; 32],
        doc_hash: [u8; 32],
        root: [u8; 32],
        schema_v: u16,
        policy_v: u16
    ) -> (CredentialNFT, CredentialNFT, Final) {
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);

        let employer_addr: address = self.caller;

        // Authoritative copy — lives in the employer's wallet
        let employer_copy: CredentialNFT = CredentialNFT {
            credential_id: credential_id,
            subject_hash: subject_hash,
            issuer_hash: issuer_hash,
            scope_hash: scope_hash,
            doc_hash: doc_hash,
            root: root,
            schema_v: schema_v,
            policy_v: policy_v,
            minted_height: 0u32,
            issuer_addr: employer_addr,
            worker_addr: worker_addr,
            owner: employer_addr,
        };

        // Worker copy — identical fields except ownership
        let worker_copy: CredentialNFT = CredentialNFT {
            credential_id: credential_id,
            subject_hash: subject_hash,
            issuer_hash: issuer_hash,
            scope_hash: scope_hash,
            doc_hash: doc_hash,
            root: root,
            schema_v: schema_v,
            policy_v: policy_v,
            minted_height: 0u32,
            issuer_addr: employer_addr,
            worker_addr: worker_addr,
            owner: worker_addr,
        };

        return (employer_copy, worker_copy, final {
            // First-write-wins anchor — reject if credential_id already exists
            let existing: u32 = credential_anchor_height.get_or_use(credential_id, 0u32);
            assert(existing == 0u32);

            credential_anchor_height.set(credential_id, block.height);
            credential_status.set(credential_id, STATUS_ACTIVE);
            credential_revoked_height.set(credential_id, 0u32);
            credential_issuer.set(credential_id, employer_addr);

            let scope_existing: u32 = scope_anchor_height.get_or_use(scope_hash, 0u32);
            if scope_existing == 0u32 {
                scope_anchor_height.set(scope_hash, block.height);
            }
        });
    }

    // ---------------------------------------------------------
    // Revoke (issuer, public) — flips public status without
    // consuming any record copy. Both the employer's and the
    // worker's wallets will render this credential as revoked
    // once they read the public status mapping.
    // ---------------------------------------------------------
    fn revoke_by_issuer(
        credential_id: [u8; 32]
    ) -> Final {
        let caller: address = self.caller;
        return final {
            // Must be the issuer of record
            let issuer: address = credential_issuer.get(credential_id);
            assert(caller == issuer);

            let s: u8 = credential_status.get_or_use(credential_id, 0u8);
            assert_cred_status_valid(s);
            assert(s == STATUS_ACTIVE);

            credential_status.set(credential_id, STATUS_REVOKED);
            credential_revoked_height.set(credential_id, block.height);
        };
    }

    // ---------------------------------------------------------
    // Revoke (owner, private) — consumes the record AND flips
    // public status. Useful when the employer wants to both
    // revoke the credential and prune the record from their
    // wallet in one call.
    // ---------------------------------------------------------
    fn revoke_by_owner(nft: CredentialNFT) -> Final {
        assert(nft.owner == self.caller);

        let id: [u8; 32] = nft.credential_id;
        return final {
            let s: u8 = credential_status.get_or_use(id, 0u8);
            assert_cred_status_valid(s);
            assert(s == STATUS_ACTIVE);
            credential_status.set(id, STATUS_REVOKED);
            credential_revoked_height.set(id, block.height);
        };
    }

    // ---------------------------------------------------------
    // Burn view — worker-side convenience. Deletes the worker's
    // copy of a credential from their wallet WITHOUT affecting
    // public status. The employer's authoritative copy remains
    // valid. Useful if a worker wants to decline or hide a
    // credential from their gallery without disputing it.
    // ---------------------------------------------------------
    fn burn_view(nft: CredentialNFT) -> Final {
        assert(nft.owner == self.caller);
        return final {};
    }

    // ---------------------------------------------------------
    // Public verification utilities
    // ---------------------------------------------------------
    fn assert_credential_exists(credential_id: [u8; 32]) -> Final {
        return final {
            let h: u32 = credential_anchor_height.get_or_use(credential_id, 0u32);
            assert(h != 0u32);
        };
    }

    fn assert_scope_anchored(scope_hash: [u8; 32]) -> Final {
        return final {
            let h: u32 = scope_anchor_height.get_or_use(scope_hash, 0u32);
            assert(h != 0u32);
        };
    }

    @admin(address = "aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd")
    constructor() {}
}
