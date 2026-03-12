program credential_nft.aleo {

    // ---------------------------------------------------------
    // Layer 2 (On-chain) - Credential NFTs (Commitment-only)
    // ---------------------------------------------------------
    //
    // Purpose:
    // - Mint revocable credential NFTs that anchor scope + document commitments.
    // - Keep credential content private while preserving public verifiability.
    //
    // Privacy model:
    // - Credential record fields are private.
    // - Public state tracks existence, status, and anchor heights only.

    const STATUS_ACTIVE: u8 = 1u8;
    const STATUS_REVOKED: u8 = 2u8;

    inline function assert_status_valid(s: u8) {
        assert(s == 0u8 || s == STATUS_ACTIVE || s == STATUS_REVOKED);
    }

    record CredentialNFT {
        credential_id: [u8; 32],

        // Identity/scope bindings (commitment-only)
        subject_hash: [u8; 32],
        issuer_hash: [u8; 32],
        scope_hash: [u8; 32],

        // Document commitments
        doc_hash: [u8; 32],
        root: [u8; 32],

        schema_v: u16,
        policy_v: u16,

        // Metadata (sentinel; actual height in credential_anchor_height mapping)
        minted_height: u32,

        // Ownership
        owner: address,
    }

    // ---------------------------------------------------------
    // Public anchor/status mappings
    // ---------------------------------------------------------
    mapping credential_anchor_height: [u8; 32] => u32;
    mapping credential_status: [u8; 32] => u8;
    mapping credential_revoked_height: [u8; 32] => u32;
    mapping scope_anchor_height: [u8; 32] => u32;

    // ---------------------------------------------------------
    // Mint credential NFT
    // ---------------------------------------------------------
    async transition mint_credential_nft(
        credential_id: [u8; 32],
        subject_hash: [u8; 32],
        issuer_hash: [u8; 32],
        scope_hash: [u8; 32],
        doc_hash: [u8; 32],
        root: [u8; 32],
        schema_v: u16,
        policy_v: u16
    ) -> (CredentialNFT, Future) {
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);

        let nft: CredentialNFT = CredentialNFT {
            credential_id: credential_id,
            subject_hash: subject_hash,
            issuer_hash: issuer_hash,
            scope_hash: scope_hash,
            doc_hash: doc_hash,
            root: root,
            schema_v: schema_v,
            policy_v: policy_v,
            minted_height: 0u32,
            owner: self.caller,
        };

        return (nft, finalize_mint_credential_nft(credential_id, scope_hash));
    }

    async function finalize_mint_credential_nft(credential_id: [u8; 32], scope_hash: [u8; 32]) {
        let existing: u32 = credential_anchor_height.get_or_use(credential_id, 0u32);
        assert(existing == 0u32);

        credential_anchor_height.set(credential_id, block.height);
        credential_status.set(credential_id, STATUS_ACTIVE);
        credential_revoked_height.set(credential_id, 0u32);

        let scope_existing: u32 = scope_anchor_height.get_or_use(scope_hash, 0u32);
        if scope_existing == 0u32 {
            scope_anchor_height.set(scope_hash, block.height);
        }
    }

    // ---------------------------------------------------------
    // Revoke credential NFT (owner-only)
    // ---------------------------------------------------------
    async transition revoke_credential_nft(nft: CredentialNFT) -> Future {
        assert(nft.owner == self.caller);

        let id: [u8; 32] = nft.credential_id;
        return finalize_revoke_credential_nft(id);
    }

    async function finalize_revoke_credential_nft(id: [u8; 32]) {
        let s: u8 = credential_status.get_or_use(id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);
        credential_status.set(id, STATUS_REVOKED);
        credential_revoked_height.set(id, block.height);
    }

    // ---------------------------------------------------------
    // Public verification utilities (async; read via REST API off-chain)
    // ---------------------------------------------------------
    async transition assert_credential_exists(credential_id: [u8; 32]) -> Future {
        return finalize_assert_cred_exists(credential_id);
    }

    async function finalize_assert_cred_exists(credential_id: [u8; 32]) {
        let h: u32 = credential_anchor_height.get_or_use(credential_id, 0u32);
        assert(h != 0u32);
    }

    async transition assert_scope_anchored(scope_hash: [u8; 32]) -> Future {
        return finalize_assert_scope_anchored(scope_hash);
    }

    async function finalize_assert_scope_anchored(scope_hash: [u8; 32]) {
        let h: u32 = scope_anchor_height.get_or_use(scope_hash, 0u32);
        assert(h != 0u32);
    }
}
