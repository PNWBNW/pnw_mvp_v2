import payroll_audit_log.aleo;

program audit_nft.aleo {

    // ---------------------------------------------------------
    // Layer 2 (On-chain) - Audit Authorization NFTs
    // ---------------------------------------------------------
    //
    // Purpose:
    // - Mint revocable audit authorization NFTs.
    // - Enforce expiry semantics for authorization usage.
    // - Anchor audit attestation commitments linked to active authorization NFTs.

    const STATUS_ACTIVE: u8 = 1u8;
    const STATUS_REVOKED: u8 = 2u8;
    const STATUS_EXPIRED: u8 = 3u8;

    function assert_status_valid(s: u8) {
        assert(s == 0u8 || s == STATUS_ACTIVE || s == STATUS_REVOKED || s == STATUS_EXPIRED);
    }

    record AuditAuthorizationNFT {
        auth_id: [u8; 32].private,

        // Commitments
        scope_hash: [u8; 32].private,
        authorization_event_hash: [u8; 32].private,
        policy_hash: [u8; 32].private,

        // Expiry semantics (epoch-style value chosen by portal policy)
        issued_epoch: u32.private,
        expires_epoch: u32.private,

        schema_v: u16.private,
        policy_v: u16.private,
        issued_height: u32.private,

        owner: address.private,
        _nonce: group.public
    }

    // ---------------------------------------------------------
    // Public verification state
    // ---------------------------------------------------------
    mapping auth_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    mapping auth_status:
        key as [u8; 32].public,
        value as u8.public;

    mapping auth_expires_epoch:
        key as [u8; 32].public,
        value as u32.public;

    mapping auth_revoked_height:
        key as [u8; 32].public,
        value as u32.public;

    mapping attestation_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    mapping attestation_auth_id:
        key as [u8; 32].public,
        value as [u8; 32].public;

    function anchor_auth_once(auth_id: [u8; 32], expires_epoch: u32) {
        let existing: u32 = Mapping::get_or_use(auth_anchor_height, auth_id, 0u32);
        assert(existing == 0u32);

        let h: u32 = block.height;
        Mapping::set(auth_anchor_height, auth_id, h);
        Mapping::set(auth_status, auth_id, STATUS_ACTIVE);
        Mapping::set(auth_expires_epoch, auth_id, expires_epoch);
        Mapping::set(auth_revoked_height, auth_id, 0u32);
    }

    function assert_auth_active_and_not_expired(auth_id: [u8; 32], current_epoch: u32) {
        let s: u8 = Mapping::get_or_use(auth_status, auth_id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        let exp: u32 = Mapping::get_or_use(auth_expires_epoch, auth_id, 0u32);
        assert(exp != 0u32);
        assert(current_epoch <= exp);
    }

    function anchor_attestation_once(auth_id: [u8; 32], attestation_hash: [u8; 32]) {
        let existing: u32 = Mapping::get_or_use(attestation_anchor_height, attestation_hash, 0u32);
        assert(existing == 0u32);

        let h: u32 = block.height;
        Mapping::set(attestation_anchor_height, attestation_hash, h);
        Mapping::set(attestation_auth_id, attestation_hash, auth_id);
    }

    // ---------------------------------------------------------
    // Mint authorization NFT
    // ---------------------------------------------------------
    transition mint_authorization_nft(
        auth_id: [u8; 32],
        scope_hash: [u8; 32],
        authorization_event_hash: [u8; 32],
        policy_hash: [u8; 32],
        issued_epoch: u32,
        expires_epoch: u32,
        schema_v: u16,
        policy_v: u16
    ) -> AuditAuthorizationNFT {

        // The authorization event must already be anchored in Layer 1 audit log.
        payroll_audit_log.aleo/assert_event_anchored(authorization_event_hash);

        assert(issued_epoch != 0u32);
        assert(expires_epoch >= issued_epoch);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);

        anchor_auth_once(auth_id, expires_epoch);

        let h: u32 = block.height;

        let nft: AuditAuthorizationNFT = AuditAuthorizationNFT {
            auth_id: auth_id.private,

            scope_hash: scope_hash.private,
            authorization_event_hash: authorization_event_hash.private,
            policy_hash: policy_hash.private,

            issued_epoch: issued_epoch.private,
            expires_epoch: expires_epoch.private,

            schema_v: schema_v.private,
            policy_v: policy_v.private,
            issued_height: h.private,

            owner: caller.private,
            _nonce: group::rand().public
        };

        return nft;
    }

    // ---------------------------------------------------------
    // Revoke authorization NFT (owner-only)
    // ---------------------------------------------------------
    transition revoke_authorization_nft(nft: AuditAuthorizationNFT) {
        assert(nft.owner == caller.private);

        let id: [u8; 32] = nft.auth_id;
        let s: u8 = Mapping::get_or_use(auth_status, id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        consume nft;

        let h: u32 = block.height;
        Mapping::set(auth_status, id, STATUS_REVOKED);
        Mapping::set(auth_revoked_height, id, h);
    }

    // ---------------------------------------------------------
    // Mark authorization expired (permissionless maintenance)
    // ---------------------------------------------------------
    transition mark_authorization_expired(auth_id: [u8; 32], current_epoch: u32) {
        let s: u8 = Mapping::get_or_use(auth_status, auth_id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        let exp: u32 = Mapping::get_or_use(auth_expires_epoch, auth_id, 0u32);
        assert(exp != 0u32);
        assert(current_epoch > exp);

        Mapping::set(auth_status, auth_id, STATUS_EXPIRED);
    }

    // ---------------------------------------------------------
    // Anchor audit attestation bound to an active authorization
    // ---------------------------------------------------------
    transition anchor_audit_attestation(
        auth_id: [u8; 32],
        attestation_hash: [u8; 32],
        current_epoch: u32
    ) {
        assert_auth_active_and_not_expired(auth_id, current_epoch);
        anchor_attestation_once(auth_id, attestation_hash);
    }

    // ---------------------------------------------------------
    // Public verification utilities
    // ---------------------------------------------------------
    transition assert_authorization_exists(auth_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(auth_anchor_height, auth_id, 0u32);
        assert(h != 0u32);
    }

    transition assert_authorization_active(auth_id: [u8; 32], current_epoch: u32) {
        assert_auth_active_and_not_expired(auth_id, current_epoch);
    }

    transition get_authorization_anchor_height(auth_id: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(auth_anchor_height, auth_id, 0u32);
        return h;
    }

    transition get_authorization_status(auth_id: [u8; 32]) -> u8 {
        let s: u8 = Mapping::get_or_use(auth_status, auth_id, 0u8);
        assert_status_valid(s);
        return s;
    }

    transition get_authorization_expiry(auth_id: [u8; 32]) -> u32 {
        let exp: u32 = Mapping::get_or_use(auth_expires_epoch, auth_id, 0u32);
        return exp;
    }

    transition get_authorization_revoked_height(auth_id: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(auth_revoked_height, auth_id, 0u32);
        return h;
    }

    transition assert_attestation_anchored(attestation_hash: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(attestation_anchor_height, attestation_hash, 0u32);
        assert(h != 0u32);
    }

    transition get_attestation_anchor_height(attestation_hash: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(attestation_anchor_height, attestation_hash, 0u32);
        return h;
    }

    transition get_attestation_authorization(attestation_hash: [u8; 32]) -> [u8; 32] {
        let auth_id: [u8; 32] = Mapping::get_or_use(attestation_auth_id, attestation_hash, [0u8; 32]);
        return auth_id;
    }
}
