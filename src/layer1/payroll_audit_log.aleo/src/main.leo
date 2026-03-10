program payroll_audit_log.aleo {

    // ---------------------------------------------------------
    // Payroll Audit Log (Layer 1) – PNW MVP v2
    // ---------------------------------------------------------
    // Purpose:
    // - Provide an immutable, append-only audit anchor sink
    // - Anchor payroll, tax, and agreement-related compliance events
    //
    // Design:
    // - Open write, cryptographically authorized via event_hash
    // - No identity, amount, or metadata stored on-chain
    // - event_hash must be domain-separated and authorization-bound
    //
    // Example (off-chain canonical format):
    // H("pnw:v2:audit:payroll" || agreement_id || receipt_anchor || authorized_party_hash || salt)
    //
    // Privacy:
    // - Only event_hash existence and first-seen block height are public

    // ---------------------------------------------------------
    // Canonical audit anchor mapping
    // ---------------------------------------------------------
    mapping audit_event_height:
        key as [u8; 32].public,
        value as u32.public;

    // ---------------------------------------------------------
    // Internal helper: enforce uniqueness + write height
    // ---------------------------------------------------------
    function anchor_unique(event_hash: [u8; 32]) {
        let existing: u32 = Mapping::get_or_use(audit_event_height, event_hash, 0u32);
        assert(existing == 0u32);

        let h: u32 = block.height;
        Mapping::set(audit_event_height, event_hash, h);
    }

    // ---------------------------------------------------------
    // Anchor an audit event (append-only)
    // ---------------------------------------------------------
    transition anchor_event(event_hash: [u8; 32]) {
        // Authorization is enforced cryptographically by the event_hash itself.
        // This program does not infer or store identities.
        anchor_unique(event_hash);
    }

    // ---------------------------------------------------------
    // Assertion helper: ensure an audit event exists
    // ---------------------------------------------------------
    transition assert_event_anchored(event_hash: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(audit_event_height, event_hash, 0u32);
        assert(h != 0u32);
    }

    // ---------------------------------------------------------
    // Public read utility: get first-seen block height
    // ---------------------------------------------------------
    transition get_event_height(event_hash: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(audit_event_height, event_hash, 0u32);
        return h;
    }
}
