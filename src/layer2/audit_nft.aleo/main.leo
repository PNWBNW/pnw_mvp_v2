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

        // Metadata (sentinel; actual height in auth_anchor_height mapping)
        issued_height: u32.private,

        owner: address.private,
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

    // ---------------------------------------------------------
    // Mint authorization NFT
    // ---------------------------------------------------------
    async transition mint_authorization_nft(
        auth_id: [u8; 32],
        scope_hash: [u8; 32],
        authorization_event_hash: [u8; 32],
        policy_hash: [u8; 32],
        issued_epoch: u32,
        expires_epoch: u32,
        schema_v: u16,
        policy_v: u16
    ) -> (AuditAuthorizationNFT, Future) {
        assert(issued_epoch != 0u32);
        assert(expires_epoch >= issued_epoch);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);

        // The authorization event must already be anchored in Layer 1 audit log.
        let f: Future = payroll_audit_log.aleo/assert_event_anchored(authorization_event_hash);

        let nft: AuditAuthorizationNFT = AuditAuthorizationNFT {
            auth_id: auth_id,
            scope_hash: scope_hash,
            authorization_event_hash: authorization_event_hash,
            policy_hash: policy_hash,
            issued_epoch: issued_epoch,
            expires_epoch: expires_epoch,
            schema_v: schema_v,
            policy_v: policy_v,
            issued_height: 0u32,
            owner: caller,
        };

        return (nft, finalize_mint_authorization_nft(f, auth_id, expires_epoch));
    }

    async function finalize_mint_authorization_nft(f: Future, auth_id: [u8; 32], expires_epoch: u32) {
        f.await();

        // anchor_auth_once (inlined)
        let existing: u32 = Mapping::get_or_use(auth_anchor_height, auth_id, 0u32);
        assert(existing == 0u32);

        Mapping::set(auth_anchor_height, auth_id, block.height);
        Mapping::set(auth_status, auth_id, STATUS_ACTIVE);
        Mapping::set(auth_expires_epoch, auth_id, expires_epoch);
        Mapping::set(auth_revoked_height, auth_id, 0u32);
    }

    // ---------------------------------------------------------
    // Revoke authorization NFT (owner-only)
    // ---------------------------------------------------------
    async transition revoke_authorization_nft(nft: AuditAuthorizationNFT) -> Future {
        // Bug #4 fix: caller (not caller.private)
        assert(nft.owner == caller);

        let id: [u8; 32] = nft.auth_id;
        // Bug #4c fix: no "consume nft;" — record is implicitly consumed as transition input
        return finalize_revoke_authorization_nft(id);
    }

    async function finalize_revoke_authorization_nft(id: [u8; 32]) {
        let s: u8 = Mapping::get_or_use(auth_status, id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);
        Mapping::set(auth_status, id, STATUS_REVOKED);
        Mapping::set(auth_revoked_height, id, block.height);
    }

    // ---------------------------------------------------------
    // Mark authorization expired (permissionless maintenance)
    // ---------------------------------------------------------
    async transition mark_authorization_expired(auth_id: [u8; 32], current_epoch: u32) -> Future {
        return finalize_mark_authorization_expired(auth_id, current_epoch);
    }

    async function finalize_mark_authorization_expired(auth_id: [u8; 32], current_epoch: u32) {
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
    async transition anchor_audit_attestation(
        auth_id: [u8; 32],
        attestation_hash: [u8; 32],
        current_epoch: u32
    ) -> Future {
        return finalize_anchor_audit_attestation(auth_id, attestation_hash, current_epoch);
    }

    async function finalize_anchor_audit_attestation(
        auth_id: [u8; 32],
        attestation_hash: [u8; 32],
        current_epoch: u32
    ) {
        // assert_auth_active_and_not_expired (inlined)
        let s: u8 = Mapping::get_or_use(auth_status, auth_id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        let exp: u32 = Mapping::get_or_use(auth_expires_epoch, auth_id, 0u32);
        assert(exp != 0u32);
        assert(current_epoch <= exp);

        // anchor_attestation_once (inlined)
        let existing: u32 = Mapping::get_or_use(attestation_anchor_height, attestation_hash, 0u32);
        assert(existing == 0u32);
        Mapping::set(attestation_anchor_height, attestation_hash, block.height);
        Mapping::set(attestation_auth_id, attestation_hash, auth_id);
    }

    // ---------------------------------------------------------
    // Public verification utilities
    // Mapping reads are only valid in async function (finalize).
    // These transitions assert conditions on-chain; use the REST API
    // to query actual mapping values off-chain.
    // ---------------------------------------------------------
    async transition assert_authorization_exists(auth_id: [u8; 32]) -> Future {
        return finalize_assert_authorization_exists(auth_id);
    }

    async function finalize_assert_authorization_exists(auth_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(auth_anchor_height, auth_id, 0u32);
        assert(h != 0u32);
    }

    async transition assert_authorization_active(auth_id: [u8; 32], current_epoch: u32) -> Future {
        return finalize_assert_authorization_active(auth_id, current_epoch);
    }

    async function finalize_assert_authorization_active(auth_id: [u8; 32], current_epoch: u32) {
        let s: u8 = Mapping::get_or_use(auth_status, auth_id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        let exp: u32 = Mapping::get_or_use(auth_expires_epoch, auth_id, 0u32);
        assert(exp != 0u32);
        assert(current_epoch <= exp);
    }

    async transition get_authorization_anchor_height(auth_id: [u8; 32]) -> Future {
        return finalize_get_authorization_anchor_height(auth_id);
    }

    async function finalize_get_authorization_anchor_height(auth_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(auth_anchor_height, auth_id, 0u32);
        assert(h != 0u32);
    }

    async transition get_authorization_status(auth_id: [u8; 32]) -> Future {
        return finalize_get_authorization_status(auth_id);
    }

    async function finalize_get_authorization_status(auth_id: [u8; 32]) {
        let s: u8 = Mapping::get_or_use(auth_status, auth_id, 0u8);
        assert_status_valid(s);
    }

    async transition get_authorization_expiry(auth_id: [u8; 32]) -> Future {
        return finalize_get_authorization_expiry(auth_id);
    }

    async function finalize_get_authorization_expiry(auth_id: [u8; 32]) {
        let exp: u32 = Mapping::get_or_use(auth_expires_epoch, auth_id, 0u32);
        assert(exp != 0u32);
    }

    async transition get_authorization_revoked_height(auth_id: [u8; 32]) -> Future {
        return finalize_get_authorization_revoked_height(auth_id);
    }

    async function finalize_get_authorization_revoked_height(auth_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(auth_anchor_height, auth_id, 0u32);
        assert(h != 0u32);
    }

    async transition assert_attestation_anchored(attestation_hash: [u8; 32]) -> Future {
        return finalize_assert_attestation_anchored(attestation_hash);
    }

    async function finalize_assert_attestation_anchored(attestation_hash: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(attestation_anchor_height, attestation_hash, 0u32);
        assert(h != 0u32);
    }

    async transition get_attestation_anchor_height(attestation_hash: [u8; 32]) -> Future {
        return finalize_get_attestation_anchor_height(attestation_hash);
    }

    async function finalize_get_attestation_anchor_height(attestation_hash: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(attestation_anchor_height, attestation_hash, 0u32);
        assert(h != 0u32);
    }

    async transition get_attestation_authorization(attestation_hash: [u8; 32]) -> Future {
        return finalize_get_attestation_authorization(attestation_hash);
    }

    async function finalize_get_attestation_authorization(attestation_hash: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(attestation_anchor_height, attestation_hash, 0u32);
        assert(h != 0u32);
    }
}
