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
    mapping auth_anchor_height: [u8; 32] => u32;
    mapping auth_status: [u8; 32] => u8;
    mapping auth_expires_epoch: [u8; 32] => u32;
    mapping auth_revoked_height: [u8; 32] => u32;
    mapping attestation_anchor_height: [u8; 32] => u32;
    mapping attestation_auth_id: [u8; 32] => [u8; 32];

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
            owner: self.caller,
        };

        return (nft, finalize_mint_authorization_nft(f, auth_id, expires_epoch));
    }

    async function finalize_mint_authorization_nft(f: Future, auth_id: [u8; 32], expires_epoch: u32) {
        f.await();

        // anchor_auth_once (inlined)
        let existing: u32 = auth_anchor_height.get_or_use(auth_id, 0u32);
        assert(existing == 0u32);

        auth_anchor_height.set(auth_id, block.height);
        auth_status.set(auth_id, STATUS_ACTIVE);
        auth_expires_epoch.set(auth_id, expires_epoch);
        auth_revoked_height.set(auth_id, 0u32);
    }

    // ---------------------------------------------------------
    // Revoke authorization NFT (owner-only)
    // ---------------------------------------------------------
    async transition revoke_authorization_nft(nft: AuditAuthorizationNFT) -> Future {
        assert(nft.owner == self.caller);

        let id: [u8; 32] = nft.auth_id;
        return finalize_revoke_authorization_nft(id);
    }

    async function finalize_revoke_authorization_nft(id: [u8; 32]) {
        let s: u8 = auth_status.get_or_use(id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);
        auth_status.set(id, STATUS_REVOKED);
        auth_revoked_height.set(id, block.height);
    }

    // ---------------------------------------------------------
    // Mark authorization expired (permissionless maintenance)
    // ---------------------------------------------------------
    async transition mark_authorization_expired(auth_id: [u8; 32], current_epoch: u32) -> Future {
        return finalize_mark_authorization_expired(auth_id, current_epoch);
    }

    async function finalize_mark_authorization_expired(auth_id: [u8; 32], current_epoch: u32) {
        let s: u8 = auth_status.get_or_use(auth_id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        let exp: u32 = auth_expires_epoch.get_or_use(auth_id, 0u32);
        assert(exp != 0u32);
        assert(current_epoch > exp);

        auth_status.set(auth_id, STATUS_EXPIRED);
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
        let s: u8 = auth_status.get_or_use(auth_id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        let exp: u32 = auth_expires_epoch.get_or_use(auth_id, 0u32);
        assert(exp != 0u32);
        assert(current_epoch <= exp);

        let existing: u32 = attestation_anchor_height.get_or_use(attestation_hash, 0u32);
        assert(existing == 0u32);
        attestation_anchor_height.set(attestation_hash, block.height);
        attestation_auth_id.set(attestation_hash, auth_id);
    }

    // ---------------------------------------------------------
    // Public verification utilities (async; read via REST API off-chain)
    // ---------------------------------------------------------
    async transition assert_authorization_exists(auth_id: [u8; 32]) -> Future {
        return finalize_assert_authorization_exists(auth_id);
    }

    async function finalize_assert_authorization_exists(auth_id: [u8; 32]) {
        let h: u32 = auth_anchor_height.get_or_use(auth_id, 0u32);
        assert(h != 0u32);
    }

    async transition assert_authorization_active(auth_id: [u8; 32], current_epoch: u32) -> Future {
        return finalize_assert_authorization_active(auth_id, current_epoch);
    }

    async function finalize_assert_authorization_active(auth_id: [u8; 32], current_epoch: u32) {
        let s: u8 = auth_status.get_or_use(auth_id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        let exp: u32 = auth_expires_epoch.get_or_use(auth_id, 0u32);
        assert(exp != 0u32);
        assert(current_epoch <= exp);
    }

    async transition assert_attestation_anchored(attestation_hash: [u8; 32]) -> Future {
        return finalize_assert_attestation_anchored(attestation_hash);
    }

    async function finalize_assert_attestation_anchored(attestation_hash: [u8; 32]) {
        let h: u32 = attestation_anchor_height.get_or_use(attestation_hash, 0u32);
        assert(h != 0u32);
    }
}
