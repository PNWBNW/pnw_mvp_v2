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

    function assert_status_valid(s: u8) {
        assert(s == 0u8 || s == STATUS_ACTIVE || s == STATUS_REVOKED);
    }

    record CredentialNFT {
        credential_id: [u8; 32].private,

        // Identity/scope bindings (commitment-only)
        subject_hash: [u8; 32].private,
        issuer_hash: [u8; 32].private,
        scope_hash: [u8; 32].private,

        // Document commitments
        doc_hash: [u8; 32].private,
        root: [u8; 32].private,

        schema_v: u16.private,
        policy_v: u16.private,

        // Metadata (sentinel; actual height in credential_anchor_height mapping)
        minted_height: u32.private,

        // Ownership
        owner: address.private,
    }

    // ---------------------------------------------------------
    // Public anchor/status mappings
    // ---------------------------------------------------------
    mapping credential_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    mapping credential_status:
        key as [u8; 32].public,
        value as u8.public;

    mapping credential_revoked_height:
        key as [u8; 32].public,
        value as u32.public;

    mapping scope_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

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
            owner: caller,
        };

        return (nft, finalize_mint_credential_nft(credential_id, scope_hash));
    }

    async function finalize_mint_credential_nft(credential_id: [u8; 32], scope_hash: [u8; 32]) {
        // anchor_credential_once (inlined)
        let existing: u32 = Mapping::get_or_use(credential_anchor_height, credential_id, 0u32);
        assert(existing == 0u32);

        Mapping::set(credential_anchor_height, credential_id, block.height);
        Mapping::set(credential_status, credential_id, STATUS_ACTIVE);
        Mapping::set(credential_revoked_height, credential_id, 0u32);

        // anchor_scope_if_first (inlined)
        let scope_existing: u32 = Mapping::get_or_use(scope_anchor_height, scope_hash, 0u32);
        if scope_existing == 0u32 {
            Mapping::set(scope_anchor_height, scope_hash, block.height);
        }
    }

    // ---------------------------------------------------------
    // Revoke credential NFT (owner-only)
    // ---------------------------------------------------------
    async transition revoke_credential_nft(nft: CredentialNFT) -> Future {
        // Bug #4 fix: caller (not caller.private)
        assert(nft.owner == caller);

        let id: [u8; 32] = nft.credential_id;
        // Bug #4c fix: no "consume nft;" — record is implicitly consumed as transition input
        return finalize_revoke_credential_nft(id);
    }

    async function finalize_revoke_credential_nft(id: [u8; 32]) {
        let s: u8 = Mapping::get_or_use(credential_status, id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);
        Mapping::set(credential_status, id, STATUS_REVOKED);
        Mapping::set(credential_revoked_height, id, block.height);
    }

    // ---------------------------------------------------------
    // Public verification utilities
    // Mapping reads are only valid in async function (finalize).
    // These transitions assert conditions on-chain; use the REST API
    // to query actual mapping values off-chain.
    // ---------------------------------------------------------
    async transition assert_credential_exists(credential_id: [u8; 32]) -> Future {
        return finalize_assert_credential_exists(credential_id);
    }

    async function finalize_assert_credential_exists(credential_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(credential_anchor_height, credential_id, 0u32);
        assert(h != 0u32);
    }

    async transition get_credential_anchor_height(credential_id: [u8; 32]) -> Future {
        return finalize_get_credential_anchor_height(credential_id);
    }

    async function finalize_get_credential_anchor_height(credential_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(credential_anchor_height, credential_id, 0u32);
        assert(h != 0u32);
    }

    async transition get_credential_status(credential_id: [u8; 32]) -> Future {
        return finalize_get_credential_status(credential_id);
    }

    async function finalize_get_credential_status(credential_id: [u8; 32]) {
        let s: u8 = Mapping::get_or_use(credential_status, credential_id, 0u8);
        assert_status_valid(s);
    }

    async transition get_credential_revoked_height(credential_id: [u8; 32]) -> Future {
        return finalize_get_credential_revoked_height(credential_id);
    }

    async function finalize_get_credential_revoked_height(credential_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(credential_anchor_height, credential_id, 0u32);
        assert(h != 0u32);
    }

    async transition assert_scope_anchored(scope_hash: [u8; 32]) -> Future {
        return finalize_assert_scope_anchored(scope_hash);
    }

    async function finalize_assert_scope_anchored(scope_hash: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(scope_anchor_height, scope_hash, 0u32);
        assert(h != 0u32);
    }

    async transition get_scope_anchor_height(scope_hash: [u8; 32]) -> Future {
        return finalize_get_scope_anchor_height(scope_hash);
    }

    async function finalize_get_scope_anchor_height(scope_hash: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(scope_anchor_height, scope_hash, 0u32);
        assert(h != 0u32);
    }
}
