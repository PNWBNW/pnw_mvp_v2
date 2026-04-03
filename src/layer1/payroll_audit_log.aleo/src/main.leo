program payroll_audit_log.aleo {

    // ---------------------------------------------------------
    // Payroll Audit Log (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Purpose:
    // - Provide an immutable, append-only audit anchor sink.
    // - Anchor payroll, tax, and agreement-related compliance events.
    //
    // Privacy:
    // - Only event_hash existence and first-seen block height are public.

    // ---------------------------------------------------------
    // Canonical audit anchor mapping
    // ---------------------------------------------------------
    mapping audit_event_height: [u8; 32] => u32;

    // ---------------------------------------------------------
    // Anchor an audit event (append-only)
    // ---------------------------------------------------------
    fn anchor_event(event_hash: [u8; 32]) -> Final {
        return final {
            let existing: u32 = audit_event_height.get_or_use(event_hash, 0u32);
            assert(existing == 0u32);
            audit_event_height.set(event_hash, block.height);
        };
    }

    // ---------------------------------------------------------
    // Cross-program assertion: ensure an audit event exists
    // Called by audit_nft.aleo and payroll_nfts.aleo.
    // ---------------------------------------------------------
    fn assert_event_anchored(event_hash: [u8; 32]) -> Final {
        return final {
            let h: u32 = audit_event_height.get_or_use(event_hash, 0u32);
            assert(h != 0u32);
        };
    }

    @noupgrade constructor() {}
}
