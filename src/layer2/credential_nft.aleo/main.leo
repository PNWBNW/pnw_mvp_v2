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
        minted_height: u32.private,

        // Ownership
        owner: address.private,
        _nonce: group.public
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

    function anchor_credential_once(credential_id: [u8; 32]) {
        let existing: u32 = Mapping::get_or_use(credential_anchor_height, credential_id, 0u32);
        assert(existing == 0u32);

        let h: u32 = block.height;
        Mapping::set(credential_anchor_height, credential_id, h);
        Mapping::set(credential_status, credential_id, STATUS_ACTIVE);
        Mapping::set(credential_revoked_height, credential_id, 0u32);
    }

    function anchor_scope_if_first(scope_hash: [u8; 32]) {
        let existing: u32 = Mapping::get_or_use(scope_anchor_height, scope_hash, 0u32);
        if existing == 0u32 {
            let h: u32 = block.height;
            Mapping::set(scope_anchor_height, scope_hash, h);
        }
    }

    // ---------------------------------------------------------
    // Mint credential NFT
    // ---------------------------------------------------------
    transition mint_credential_nft(
        credential_id: [u8; 32],
        subject_hash: [u8; 32],
        issuer_hash: [u8; 32],
        scope_hash: [u8; 32],
        doc_hash: [u8; 32],
        root: [u8; 32],
        schema_v: u16,
        policy_v: u16
    ) -> CredentialNFT {

        assert(schema_v != 0u16);
        assert(policy_v != 0u16);

        anchor_credential_once(credential_id);
        anchor_scope_if_first(scope_hash);

        let h: u32 = block.height;

        let nft: CredentialNFT = CredentialNFT {
            credential_id: credential_id.private,

            subject_hash: subject_hash.private,
            issuer_hash: issuer_hash.private,
            scope_hash: scope_hash.private,

            doc_hash: doc_hash.private,
            root: root.private,

            schema_v: schema_v.private,
            policy_v: policy_v.private,
            minted_height: h.private,

            owner: caller.private,
            _nonce: group::rand().public
        };

        return nft;
    }

    // ---------------------------------------------------------
    // Revoke credential NFT (owner-only)
    // ---------------------------------------------------------
    transition revoke_credential_nft(nft: CredentialNFT) {
        assert(nft.owner == caller.private);

        let id: [u8; 32] = nft.credential_id;
        let s: u8 = Mapping::get_or_use(credential_status, id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        consume nft;

        let h: u32 = block.height;
        Mapping::set(credential_status, id, STATUS_REVOKED);
        Mapping::set(credential_revoked_height, id, h);
    }

    // ---------------------------------------------------------
    // Public verification utilities
    // ---------------------------------------------------------
    transition assert_credential_exists(credential_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(credential_anchor_height, credential_id, 0u32);
        assert(h != 0u32);
    }

    transition get_credential_anchor_height(credential_id: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(credential_anchor_height, credential_id, 0u32);
        return h;
    }

    transition get_credential_status(credential_id: [u8; 32]) -> u8 {
        let s: u8 = Mapping::get_or_use(credential_status, credential_id, 0u8);
        assert_status_valid(s);
        return s;
    }

    transition get_credential_revoked_height(credential_id: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(credential_revoked_height, credential_id, 0u32);
        return h;
    }

    transition assert_scope_anchored(scope_hash: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(scope_anchor_height, scope_hash, 0u32);
        assert(h != 0u32);
    }

    transition get_scope_anchor_height(scope_hash: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(scope_anchor_height, scope_hash, 0u32);
        return h;
    }
}
