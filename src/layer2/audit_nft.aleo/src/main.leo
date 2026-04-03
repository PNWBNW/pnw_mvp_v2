import payroll_audit_log.aleo;

// ---------------------------------------------------------
// Status validation helper
// ---------------------------------------------------------
fn assert_audit_status_valid(s: u8) {
    assert(s == 0u8 || s == 1u8 || s == 2u8 || s == 3u8);
}

program audit_nft.aleo {

    // ---------------------------------------------------------
    // Layer 2 (On-chain) - Audit Authorization NFTs
    // ---------------------------------------------------------
    //
    // Purpose:
    // - Mint revocable audit authorization NFTs with dual-consent evidence.
    // - Enforce scope-bound, time-limited access authorization.
    // - Anchor audit attestation commitments linked to active authorization NFTs.
    //
    // Authorization Model (Option A — dual consent, portal-anchored):
    //   1. Auditor submits AuditScopeRequest specifying exactly what data categories,
    //      time period, and access duration they are requesting.
    //   2. Employer hashes their consent over (scope_hash + access_duration + expires_epoch)
    //      and anchors employer_consent_hash in Layer 1.
    //   3. Worker does the same, anchoring worker_consent_hash in Layer 1.
    //   4. Portal derives authorization_event_hash = BLAKE3(employer || worker || request_id)
    //      and anchors it in Layer 1.
    //   5. mint_authorization_nft verifies all three hashes are anchored before minting.
    //   6. The resulting NFT is owned by the auditor and privately encodes the full
    //      consent evidence. The auditor can only access data matching scope_hash.
    //
    // OPTION_B UPGRADE PATH (on-chain sequential signing):
    //   Replace portal-anchored consent hashes with consumed consent NFTs:
    //
    //   record EmployerConsentNFT {
    //       request_id: [u8; 32],
    //       scope_hash: [u8; 32],
    //       auditor_addr_hash: [u8; 32],  // BLAKE3 of auditor address
    //       expires_epoch: u32,
    //       access_duration_epochs: u32,
    //       employer_id_hash: [u8; 32],
    //       owner: address,               // employer address
    //   }
    //
    //   record WorkerConsentNFT {
    //       request_id: [u8; 32],
    //       scope_hash: [u8; 32],
    //       auditor_addr_hash: [u8; 32],
    //       expires_epoch: u32,
    //       access_duration_epochs: u32,
    //       worker_id_hash: [u8; 32],
    //       employer_consent_hash: [u8; 32],  // binds to employer's signed consent
    //       owner: address,                   // worker address
    //   }
    //
    //   mint_authorization_nft would consume both NFTs and derive the
    //   authorization_event_hash from their contents — no portal trust required.
    //   This upgrade requires no changes to data structures or mapping layout below.

    const STATUS_ACTIVE: u8 = 1u8;
    const STATUS_REVOKED: u8 = 2u8;
    const STATUS_EXPIRED: u8 = 3u8;

    // ---------------------------------------------------------
    // AuditAuthorizationNFT
    // ---------------------------------------------------------
    record AuditAuthorizationNFT {
        auth_id: [u8; 32],

        // Off-chain correlation (matches the portal AuditScopeRequest.request_id)
        request_id: [u8; 32],

        // Scope commitment — auditor reveals pre-image to portal to receive data
        scope_hash: [u8; 32],

        // Dual-consent evidence (Option A: portal-anchored; Option B: consumed NFTs)
        employer_consent_hash: [u8; 32],
        worker_consent_hash: [u8; 32],

        // Combined authorization proof anchored in Layer 1
        authorization_event_hash: [u8; 32],

        // Policy document hash
        policy_hash: [u8; 32],

        // Expiry: issued_epoch + access_duration_epochs = expires_epoch (enforced in transition)
        issued_epoch: u32,
        expires_epoch: u32,
        access_duration_epochs: u32,

        schema_v: u16,
        policy_v: u16,

        // Metadata sentinel (actual anchor height is in auth_anchor_height mapping)
        issued_height: u32,

        owner: address,
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
    // Mint authorization NFT (Option A: 3-hash dual-consent verification)
    // ---------------------------------------------------------
    fn mint_authorization_nft(
        auth_id: [u8; 32],
        request_id: [u8; 32],
        scope_hash: [u8; 32],
        authorization_event_hash: [u8; 32],
        employer_consent_hash: [u8; 32],
        worker_consent_hash: [u8; 32],
        policy_hash: [u8; 32],
        issued_epoch: u32,
        expires_epoch: u32,
        access_duration_epochs: u32,
        schema_v: u16,
        policy_v: u16
    ) -> (AuditAuthorizationNFT, Final) {
        assert(issued_epoch != 0u32);
        assert(access_duration_epochs != 0u32);
        assert(expires_epoch == issued_epoch + access_duration_epochs);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);

        // Verify employer consented to this exact scope + duration
        let f_employer: Final = payroll_audit_log.aleo::assert_event_anchored(employer_consent_hash);

        // Verify worker consented to this exact scope + duration
        let f_worker: Final = payroll_audit_log.aleo::assert_event_anchored(worker_consent_hash);

        // Verify the combined dual-consent proof is anchored
        let f_auth: Final = payroll_audit_log.aleo::assert_event_anchored(authorization_event_hash);

        let nft: AuditAuthorizationNFT = AuditAuthorizationNFT {
            auth_id: auth_id,
            request_id: request_id,
            scope_hash: scope_hash,
            employer_consent_hash: employer_consent_hash,
            worker_consent_hash: worker_consent_hash,
            authorization_event_hash: authorization_event_hash,
            policy_hash: policy_hash,
            issued_epoch: issued_epoch,
            expires_epoch: expires_epoch,
            access_duration_epochs: access_duration_epochs,
            schema_v: schema_v,
            policy_v: policy_v,
            issued_height: 0u32,
            owner: self.caller,
        };

        return (nft, final {
            f_employer.run();
            f_worker.run();
            f_auth.run();

            // Idempotency guard: auth_id must not already be anchored
            let existing: u32 = auth_anchor_height.get_or_use(auth_id, 0u32);
            assert(existing == 0u32);

            auth_anchor_height.set(auth_id, block.height);
            auth_status.set(auth_id, STATUS_ACTIVE);
            auth_expires_epoch.set(auth_id, expires_epoch);
            auth_revoked_height.set(auth_id, 0u32);
        });
    }

    // ---------------------------------------------------------
    // Revoke authorization NFT (owner-only)
    // ---------------------------------------------------------
    fn revoke_authorization_nft(nft: AuditAuthorizationNFT) -> Final {
        assert(nft.owner == self.caller);

        let id: [u8; 32] = nft.auth_id;
        return final {
            let s: u8 = auth_status.get_or_use(id, 0u8);
            assert_audit_status_valid(s);
            assert(s == STATUS_ACTIVE);
            auth_status.set(id, STATUS_REVOKED);
            auth_revoked_height.set(id, block.height);
        };
    }

    // ---------------------------------------------------------
    // Mark authorization expired (permissionless maintenance)
    // ---------------------------------------------------------
    fn mark_authorization_expired(auth_id: [u8; 32], current_epoch: u32) -> Final {
        return final {
            let s: u8 = auth_status.get_or_use(auth_id, 0u8);
            assert_audit_status_valid(s);
            assert(s == STATUS_ACTIVE);

            let exp: u32 = auth_expires_epoch.get_or_use(auth_id, 0u32);
            assert(exp != 0u32);
            assert(current_epoch > exp);

            auth_status.set(auth_id, STATUS_EXPIRED);
        };
    }

    // ---------------------------------------------------------
    // Anchor audit attestation bound to an active authorization
    // ---------------------------------------------------------
    fn anchor_audit_attestation(
        auth_id: [u8; 32],
        attestation_hash: [u8; 32],
        current_epoch: u32
    ) -> Final {
        return final {
            let s: u8 = auth_status.get_or_use(auth_id, 0u8);
            assert_audit_status_valid(s);
            assert(s == STATUS_ACTIVE);

            let exp: u32 = auth_expires_epoch.get_or_use(auth_id, 0u32);
            assert(exp != 0u32);
            assert(current_epoch <= exp);

            let existing: u32 = attestation_anchor_height.get_or_use(attestation_hash, 0u32);
            assert(existing == 0u32);
            attestation_anchor_height.set(attestation_hash, block.height);
            attestation_auth_id.set(attestation_hash, auth_id);
        };
    }

    // ---------------------------------------------------------
    // Public verification utilities
    // ---------------------------------------------------------
    fn assert_authorization_exists(auth_id: [u8; 32]) -> Final {
        return final {
            let h: u32 = auth_anchor_height.get_or_use(auth_id, 0u32);
            assert(h != 0u32);
        };
    }

    fn assert_authorization_active(auth_id: [u8; 32], current_epoch: u32) -> Final {
        return final {
            let s: u8 = auth_status.get_or_use(auth_id, 0u8);
            assert_audit_status_valid(s);
            assert(s == STATUS_ACTIVE);

            let exp: u32 = auth_expires_epoch.get_or_use(auth_id, 0u32);
            assert(exp != 0u32);
            assert(current_epoch <= exp);
        };
    }

    fn assert_attestation_anchored(attestation_hash: [u8; 32]) -> Final {
        return final {
            let h: u32 = attestation_anchor_height.get_or_use(attestation_hash, 0u32);
            assert(h != 0u32);
        };
    }

    @noupgrade constructor() {}
}
