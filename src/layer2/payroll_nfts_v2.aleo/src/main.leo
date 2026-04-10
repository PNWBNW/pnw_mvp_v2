// payroll_nfts_v2.aleo — redeployment targeting employer_agreement_v4.
// The original payroll_nfts.aleo was @noupgrade with v2 imports; this v2
// program replaces it by pointing at employer_agreement_v4 instead.
import employer_agreement_v4.aleo;
import payroll_audit_log.aleo;

// ---------------------------------------------------------
// Status validation helper
// ---------------------------------------------------------
fn assert_status_valid(s: u8) {
    assert(
        s == 0u8 ||
        s == 1u8 ||  // STATUS_ACTIVE
        s == 2u8 ||  // STATUS_REVOKED
        s == 3u8     // STATUS_SUPERSEDED
    );
}

program payroll_nfts_v2.aleo {

    // ---------------------------------------------------------
    // Layer 2 (On-chain) - Payroll NFTs (Commitment-only)
    // ---------------------------------------------------------

    const TYPE_CYCLE: u8 = 1u8;
    const TYPE_QUARTER: u8 = 2u8;
    const TYPE_YTD: u8 = 3u8;
    const TYPE_EOY: u8 = 4u8;

    const STATUS_ACTIVE: u8 = 1u8;
    const STATUS_REVOKED: u8 = 2u8;
    const STATUS_SUPERSEDED: u8 = 3u8;

    record PayrollNFT {
        nft_id: [u8; 32],
        agreement_id: [u8; 32],
        period_type: u8,
        period_start: u32,
        period_end: u32,
        doc_hash: [u8; 32],
        root: [u8; 32],
        inputs_hash: [u8; 32],
        schema_v: u16,
        calc_v: u16,
        policy_v: u16,
        // sentinel; actual height in nft_anchor_height mapping
        minted_height: u32,
        owner: address,
    }

    // ---------------------------------------------------------
    // Minimal public state
    // ---------------------------------------------------------
    mapping nft_anchor_height: [u8; 32] => u32;
    mapping nft_status: [u8; 32] => u8;
    mapping superseded_by: [u8; 32] => [u8; 32];

    // ---------------------------------------------------------
    // Mint: Per-payroll-cycle
    // ---------------------------------------------------------
    fn mint_cycle_nft(
        nft_id: [u8; 32],
        agreement_id: [u8; 32],
        period_start: u32,
        period_end: u32,
        doc_hash: [u8; 32],
        root: [u8; 32],
        inputs_hash: [u8; 32],
        schema_v: u16,
        calc_v: u16,
        policy_v: u16
    ) -> (PayrollNFT, Final) {
        assert(period_start != 0u32);
        assert(period_end >= period_start);
        assert(schema_v != 0u16);
        assert(calc_v != 0u16);
        assert(policy_v != 0u16);

        let f1: Final = employer_agreement_v4.aleo::assert_agreement_active(agreement_id);
        let f2: Final = payroll_audit_log.aleo::assert_event_anchored(inputs_hash);

        let nft: PayrollNFT = PayrollNFT {
            nft_id: nft_id,
            agreement_id: agreement_id,
            period_type: TYPE_CYCLE,
            period_start: period_start,
            period_end: period_end,
            doc_hash: doc_hash,
            root: root,
            inputs_hash: inputs_hash,
            schema_v: schema_v,
            calc_v: calc_v,
            policy_v: policy_v,
            minted_height: 0u32,
            owner: self.caller,
        };

        return (nft, final {
            f1.run();
            f2.run();

            let existing: u32 = nft_anchor_height.get_or_use(nft_id, 0u32);
            assert(existing == 0u32);

            nft_anchor_height.set(nft_id, block.height);
            nft_status.set(nft_id, STATUS_ACTIVE);
            superseded_by.set(nft_id, [0u8; 32]);
        });
    }

    // ---------------------------------------------------------
    // Mint: Quarterly (Q1-Q4)
    // ---------------------------------------------------------
    fn mint_quarter_nft(
        nft_id: [u8; 32],
        agreement_id: [u8; 32],
        period_start: u32,
        period_end: u32,
        doc_hash: [u8; 32],
        root: [u8; 32],
        inputs_hash: [u8; 32],
        schema_v: u16,
        calc_v: u16,
        policy_v: u16
    ) -> (PayrollNFT, Final) {
        assert(period_start != 0u32);
        assert(period_end >= period_start);
        assert(schema_v != 0u16);
        assert(calc_v != 0u16);
        assert(policy_v != 0u16);

        let f1: Final = employer_agreement_v4.aleo::assert_agreement_active(agreement_id);
        let f2: Final = payroll_audit_log.aleo::assert_event_anchored(inputs_hash);

        let nft: PayrollNFT = PayrollNFT {
            nft_id: nft_id,
            agreement_id: agreement_id,
            period_type: TYPE_QUARTER,
            period_start: period_start,
            period_end: period_end,
            doc_hash: doc_hash,
            root: root,
            inputs_hash: inputs_hash,
            schema_v: schema_v,
            calc_v: calc_v,
            policy_v: policy_v,
            minted_height: 0u32,
            owner: self.caller,
        };

        return (nft, final {
            f1.run();
            f2.run();

            let existing: u32 = nft_anchor_height.get_or_use(nft_id, 0u32);
            assert(existing == 0u32);

            nft_anchor_height.set(nft_id, block.height);
            nft_status.set(nft_id, STATUS_ACTIVE);
            superseded_by.set(nft_id, [0u8; 32]);
        });
    }

    // ---------------------------------------------------------
    // Mint: Year-to-Date
    // ---------------------------------------------------------
    fn mint_ytd_nft(
        nft_id: [u8; 32],
        agreement_id: [u8; 32],
        period_start: u32,
        period_end: u32,
        doc_hash: [u8; 32],
        root: [u8; 32],
        inputs_hash: [u8; 32],
        schema_v: u16,
        calc_v: u16,
        policy_v: u16
    ) -> (PayrollNFT, Final) {
        assert(period_start != 0u32);
        assert(period_end >= period_start);
        assert(schema_v != 0u16);
        assert(calc_v != 0u16);
        assert(policy_v != 0u16);

        let f1: Final = employer_agreement_v4.aleo::assert_agreement_active(agreement_id);
        let f2: Final = payroll_audit_log.aleo::assert_event_anchored(inputs_hash);

        let nft: PayrollNFT = PayrollNFT {
            nft_id: nft_id,
            agreement_id: agreement_id,
            period_type: TYPE_YTD,
            period_start: period_start,
            period_end: period_end,
            doc_hash: doc_hash,
            root: root,
            inputs_hash: inputs_hash,
            schema_v: schema_v,
            calc_v: calc_v,
            policy_v: policy_v,
            minted_height: 0u32,
            owner: self.caller,
        };

        return (nft, final {
            f1.run();
            f2.run();

            let existing: u32 = nft_anchor_height.get_or_use(nft_id, 0u32);
            assert(existing == 0u32);

            nft_anchor_height.set(nft_id, block.height);
            nft_status.set(nft_id, STATUS_ACTIVE);
            superseded_by.set(nft_id, [0u8; 32]);
        });
    }

    // ---------------------------------------------------------
    // Mint: End-of-Year
    // ---------------------------------------------------------
    fn mint_eoy_nft(
        nft_id: [u8; 32],
        agreement_id: [u8; 32],
        period_start: u32,
        period_end: u32,
        doc_hash: [u8; 32],
        root: [u8; 32],
        inputs_hash: [u8; 32],
        schema_v: u16,
        calc_v: u16,
        policy_v: u16
    ) -> (PayrollNFT, Final) {
        assert(period_start != 0u32);
        assert(period_end >= period_start);
        assert(schema_v != 0u16);
        assert(calc_v != 0u16);
        assert(policy_v != 0u16);

        let f1: Final = employer_agreement_v4.aleo::assert_agreement_active(agreement_id);
        let f2: Final = payroll_audit_log.aleo::assert_event_anchored(inputs_hash);

        let nft: PayrollNFT = PayrollNFT {
            nft_id: nft_id,
            agreement_id: agreement_id,
            period_type: TYPE_EOY,
            period_start: period_start,
            period_end: period_end,
            doc_hash: doc_hash,
            root: root,
            inputs_hash: inputs_hash,
            schema_v: schema_v,
            calc_v: calc_v,
            policy_v: policy_v,
            minted_height: 0u32,
            owner: self.caller,
        };

        return (nft, final {
            f1.run();
            f2.run();

            let existing: u32 = nft_anchor_height.get_or_use(nft_id, 0u32);
            assert(existing == 0u32);

            nft_anchor_height.set(nft_id, block.height);
            nft_status.set(nft_id, STATUS_ACTIVE);
            superseded_by.set(nft_id, [0u8; 32]);
        });
    }

    // ---------------------------------------------------------
    // Revoke
    // ---------------------------------------------------------
    fn revoke_nft(nft: PayrollNFT) -> Final {
        assert(nft.owner == self.caller);

        let id: [u8; 32] = nft.nft_id;
        return final {
            let s: u8 = nft_status.get_or_use(id, 0u8);
            assert_status_valid(s);
            assert(s == STATUS_ACTIVE);
            nft_status.set(id, STATUS_REVOKED);
        };
    }

    // ---------------------------------------------------------
    // Supersede
    // ---------------------------------------------------------
    fn mark_superseded(old_nft: PayrollNFT, new_nft_id: [u8; 32]) -> Final {
        assert(old_nft.owner == self.caller);

        let old_id: [u8; 32] = old_nft.nft_id;
        return final {
            let s: u8 = nft_status.get_or_use(old_id, 0u8);
            assert_status_valid(s);
            assert(s == STATUS_ACTIVE);
            nft_status.set(old_id, STATUS_SUPERSEDED);
            superseded_by.set(old_id, new_nft_id);
        };
    }

    // ---------------------------------------------------------
    // Public assertion utilities
    // ---------------------------------------------------------
    fn assert_nft_exists(nft_id: [u8; 32]) -> Final {
        return final {
            let h: u32 = nft_anchor_height.get_or_use(nft_id, 0u32);
            assert(h != 0u32);
        };
    }

    @noupgrade constructor() {}
}
