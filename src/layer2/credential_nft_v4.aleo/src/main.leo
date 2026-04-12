// ---------------------------------------------------------
// Layer 2 — Credential NFTs v3 (hard on-chain authorization)
// ---------------------------------------------------------
//
// Purpose:
// - Mint revocable credential NFTs that bind a worker to a scope +
//   document commitment issued by an employer.
// - ENFORCE at the contract level that the caller is the employer
//   who signed an active agreement with the target worker.
//
// What changed vs v2 (`credential_nft_v2.aleo`):
// v2 had no authorization check on mint — anyone could call
// `mint_credential_nft` with any target worker address, producing
// a visually legitimate credential whose only tell was the
// `issuer_addr` field. v3 closes that gap.
//
// Authorization model for v3 mint:
//
//   1) `pnw_name_registry_v2::assert_is_owner(employer_name_hash,
//      self.caller)` — proves the caller is the current registered
//      owner of the employer's `.pnw` name. This binds the wallet
//      to the employer role.
//
//   2) `pnw_name_registry_v2::assert_is_owner(worker_name_hash,
//      worker_addr)` — proves the target `worker_addr` is the
//      current owner of the worker's `.pnw` name. This prevents a
//      rogue employer from misdirecting a credential to a wallet
//      that isn't the real worker.
//
//   3) `employer_agreement_v4::assert_employer_authorized(
//          agreement_id, parties_key, employer_name_hash,
//          worker_name_hash)`
//      — reproduces the private parties commitment from inputs and
//      asserts it matches the value stored in v4's public mapping
//      for this agreement. Only the three parties who hold the
//      FinalAgreement record ever see the private `parties_key`,
//      so knowing it is proof of being one of the parties. The
//      employer-specific check in (1) then pins the caller to the
//      employer role. Also asserts the agreement is currently in
//      ACTIVE state (not paused/terminated/superseded).
//
// Combined, these three checks make it impossible for an
// unauthorized actor to mint a credential for a worker they have
// no active agreement with. They would need to both steal the
// employer's `.pnw` name AND extract the `parties_key` from the
// employer's private FinalAgreement record, which requires the
// employer's private Aleo view key.
//
// Everything else (dual-record mint structure, split revoke paths,
// public status/anchor/issuer mappings, palette-code-in-root[0]
// convention) is preserved from v2.
//
// Declared `@admin` so we can iterate. Move to `@noupgrade` at
// mainnet.

import employer_agreement_v4.aleo;
import pnw_name_registry_v2.aleo;
import employer_license_registry.aleo;

// ---------------------------------------------------------
// Helper assertions (declared outside the program block so they
// are non-entry utility fns and can be called from final blocks)
// ---------------------------------------------------------
fn assert_cred_status_valid(s: u8) {
    assert(s == 0u8 || s == 1u8 || s == 2u8);
}

program credential_nft_v4.aleo {

    const STATUS_ACTIVE: u8 = 1u8;
    const STATUS_REVOKED: u8 = 2u8;

    // ---------------------------------------------------------
    // Record
    // ---------------------------------------------------------
    // All fields private. Dual emission: one copy owned by the
    // employer (authoritative), one copy owned by the worker
    // (visible to them on wallet scan). Both copies share the
    // same credential_id.
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
    // Mint — authorized by three cross-program assertions
    // ---------------------------------------------------------
    fn mint_credential_nft(
        // Authorization inputs
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field,

        // Credential target
        worker_addr: address,

        // Credential content
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

        // (0) Employer license is still valid (not revoked by AUTHORITY).
        //     Mirrors the check in create_job_offer / pause / terminate
        //     in employer_agreement_v4. Without this, a revoked employer
        //     could still mint credentials via an existing active agreement.
        let f_lic: Final = employer_license_registry.aleo::assert_verified(employer_addr);

        // (1) Caller owns the employer's .pnw name
        let f_name_emp: Final = pnw_name_registry_v2.aleo::assert_is_owner(
            employer_name_hash,
            employer_addr
        );

        // (2) worker_addr is the current owner of the worker's .pnw name
        let f_name_wkr: Final = pnw_name_registry_v2.aleo::assert_is_owner(
            worker_name_hash,
            worker_addr
        );

        // (3) Caller has an active agreement with this worker, proven
        //     by knowing the private parties_key (checked via commitment)
        //     and by the agreement being in ACTIVE state.
        let f_agreement: Final = employer_agreement_v4.aleo::assert_employer_authorized(
            agreement_id,
            parties_key,
            employer_name_hash,
            worker_name_hash
        );

        // Build both CredentialNFT records
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
            f_lic.run();
            f_name_emp.run();
            f_name_wkr.run();
            f_agreement.run();

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

    // Admin = deploy wallet. Must match the `program_owner` at deploy
    // time or the constructor assertion fails and the deploy is rejected.
    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx")
    constructor() {}
}
