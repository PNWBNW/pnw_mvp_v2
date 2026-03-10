import employer_agreement.aleo;
import payroll_audit_log.aleo;

program payroll_nfts.aleo {

    // ---------------------------------------------------------
    // Layer 2 (On-chain) - Payroll NFTs (Commitment-only)
    // ---------------------------------------------------------
    //
    // Purpose:
    // - Mint commitment-only payroll NFTs that anchor off-chain paystubs/reports publicly
    //   WITHOUT revealing wages, names, hours, deductions, or plaintext identities.
    //
    // Model:
    // - Portal deterministically constructs a report document off-chain (cycle/quarter/YTD/EOY),
    //   computes commitments (doc_hash, root, inputs_hash), then optionally mints an NFT.
    //
    // Privacy:
    // - The NFT record stores commitment fields privately.
    // - Public state is minimal: existence/status + first-seen height keyed by nft_id.
    //
    // Validation:
    // - Requires Layer 1 agreement is ACTIVE (prevents orphan mints).
    // - Requires an audit anchor exists in payroll_audit_log for the same inputs_hash
    //   (prevents minting "phantom" summaries not backed by Layer 1 anchors).
    //
    // NOTE:
    // - This program does NOT transfer USDCx and does NOT issue Layer 1 receipts.
    // - It is safe to skip minting for "view-only" reports; minting is optional.

    // -----------------------------
    // Period types
    // -----------------------------
    const TYPE_CYCLE: u8 = 1u8;
    const TYPE_QUARTER: u8 = 2u8;
    const TYPE_YTD: u8 = 3u8;
    const TYPE_EOY: u8 = 4u8;

    // -----------------------------
    // NFT status (public mapping)
    // -----------------------------
    const STATUS_ACTIVE: u8 = 1u8;
    const STATUS_REVOKED: u8 = 2u8;
    const STATUS_SUPERSEDED: u8 = 3u8;

    function assert_status_valid(s: u8) {
        assert(
            s == 0u8 ||
            s == STATUS_ACTIVE ||
            s == STATUS_REVOKED ||
            s == STATUS_SUPERSEDED
        );
    }

    // ---------------------------------------------------------
    // Record: PayrollNFT (commitment-only; owned by minter)
    // ---------------------------------------------------------
    //
    // All fields are PRIVATE to reduce linkability.
    // Public verification is performed via mappings keyed by nft_id.
    // minted_height is always 0u32 in the record; the authoritative anchor
    // height is stored in the nft_anchor_height mapping (set during finalize).
    record PayrollNFT {
        nft_id: [u8; 32].private,

        // Binding
        agreement_id: [u8; 32].private,

        // Period encoding
        period_type: u8.private,
        period_start: u32.private,
        period_end: u32.private,

        // Commitments
        doc_hash: [u8; 32].private,
        root: [u8; 32].private,
        inputs_hash: [u8; 32].private,

        // Versions
        schema_v: u16.private,
        calc_v: u16.private,
        policy_v: u16.private,

        // Metadata (sentinel; actual height in nft_anchor_height mapping)
        minted_height: u32.private,

        // Ownership
        owner: address.private,
    }

    // ---------------------------------------------------------
    // Minimal public state (existence + status)
    // ---------------------------------------------------------
    mapping nft_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    mapping nft_status:
        key as [u8; 32].public,
        value as u8.public;

    mapping superseded_by:
        key as [u8; 32].public,
        value as [u8; 32].public;

    // ---------------------------------------------------------
    // Shared finalize for all mint transitions
    // Awaits Layer 1 cross-program futures, then anchors the nft_id.
    // ---------------------------------------------------------
    async function finalize_mint_nft(f1: Future, f2: Future, nft_id: [u8; 32]) {
        f1.await();
        f2.await();

        let existing: u32 = Mapping::get_or_use(nft_anchor_height, nft_id, 0u32);
        assert(existing == 0u32);

        Mapping::set(nft_anchor_height, nft_id, block.height);
        Mapping::set(nft_status, nft_id, STATUS_ACTIVE);
        Mapping::set(superseded_by, nft_id, [0u8; 32]);
    }

    // ---------------------------------------------------------
    // Mint: Per-payroll-cycle
    // ---------------------------------------------------------
    async transition mint_cycle_nft(
        nft_id: [u8; 32],
        agreement_id: [u8; 32],

        // For a single payroll cycle, portal can set start=end=epoch_id, or a range.
        period_start: u32,
        period_end: u32,

        doc_hash: [u8; 32],
        root: [u8; 32],
        inputs_hash: [u8; 32],

        schema_v: u16,
        calc_v: u16,
        policy_v: u16
    ) -> (PayrollNFT, Future) {
        assert(period_start != 0u32);
        assert(period_end >= period_start);
        assert(schema_v != 0u16);
        assert(calc_v != 0u16);
        assert(policy_v != 0u16);

        let f1: Future = employer_agreement.aleo/assert_agreement_active(agreement_id);
        let f2: Future = payroll_audit_log.aleo/assert_event_anchored(inputs_hash);

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
            owner: caller,
        };

        return (nft, finalize_mint_nft(f1, f2, nft_id));
    }

    // ---------------------------------------------------------
    // Mint: Quarterly (Q1–Q4)
    // ---------------------------------------------------------
    async transition mint_quarter_nft(
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
    ) -> (PayrollNFT, Future) {
        assert(period_start != 0u32);
        assert(period_end >= period_start);
        assert(schema_v != 0u16);
        assert(calc_v != 0u16);
        assert(policy_v != 0u16);

        let f1: Future = employer_agreement.aleo/assert_agreement_active(agreement_id);
        let f2: Future = payroll_audit_log.aleo/assert_event_anchored(inputs_hash);

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
            owner: caller,
        };

        return (nft, finalize_mint_nft(f1, f2, nft_id));
    }

    // ---------------------------------------------------------
    // Mint: Year-to-Date
    // ---------------------------------------------------------
    async transition mint_ytd_nft(
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
    ) -> (PayrollNFT, Future) {
        assert(period_start != 0u32);
        assert(period_end >= period_start);
        assert(schema_v != 0u16);
        assert(calc_v != 0u16);
        assert(policy_v != 0u16);

        let f1: Future = employer_agreement.aleo/assert_agreement_active(agreement_id);
        let f2: Future = payroll_audit_log.aleo/assert_event_anchored(inputs_hash);

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
            owner: caller,
        };

        return (nft, finalize_mint_nft(f1, f2, nft_id));
    }

    // ---------------------------------------------------------
    // Mint: End-of-Year
    // ---------------------------------------------------------
    async transition mint_eoy_nft(
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
    ) -> (PayrollNFT, Future) {
        assert(period_start != 0u32);
        assert(period_end >= period_start);
        assert(schema_v != 0u16);
        assert(calc_v != 0u16);
        assert(policy_v != 0u16);

        let f1: Future = employer_agreement.aleo/assert_agreement_active(agreement_id);
        let f2: Future = payroll_audit_log.aleo/assert_event_anchored(inputs_hash);

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
            owner: caller,
        };

        return (nft, finalize_mint_nft(f1, f2, nft_id));
    }

    // ---------------------------------------------------------
    // Revoke: consume record + set status
    // ---------------------------------------------------------
    async transition revoke_nft(nft: PayrollNFT) -> Future {
        // Bug #4 fix: caller (not caller.private)
        assert(nft.owner == caller);

        let id: [u8; 32] = nft.nft_id;
        // Bug #4c fix: no "consume nft;" — record is implicitly consumed as transition input
        return finalize_revoke_nft(id);
    }

    async function finalize_revoke_nft(id: [u8; 32]) {
        let s: u8 = Mapping::get_or_use(nft_status, id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);
        Mapping::set(nft_status, id, STATUS_REVOKED);
    }

    // ---------------------------------------------------------
    // Supersede: consume old record, mint new separately, and mark linkage
    // ---------------------------------------------------------
    async transition mark_superseded(old_nft: PayrollNFT, new_nft_id: [u8; 32]) -> Future {
        // Bug #4 fix: caller (not caller.private)
        assert(old_nft.owner == caller);

        let old_id: [u8; 32] = old_nft.nft_id;
        // Bug #4c fix: no "consume old_nft;"
        return finalize_mark_superseded(old_id, new_nft_id);
    }

    async function finalize_mark_superseded(old_id: [u8; 32], new_nft_id: [u8; 32]) {
        let s: u8 = Mapping::get_or_use(nft_status, old_id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);
        Mapping::set(nft_status, old_id, STATUS_SUPERSEDED);
        Mapping::set(superseded_by, old_id, new_nft_id);
    }

    // ---------------------------------------------------------
    // Public utilities
    // Mapping reads are only valid in async function (finalize).
    // These transitions assert conditions on-chain; use the REST API
    // to query actual mapping values off-chain.
    // ---------------------------------------------------------
    async transition assert_nft_exists(nft_id: [u8; 32]) -> Future {
        return finalize_assert_nft_exists(nft_id);
    }

    async function finalize_assert_nft_exists(nft_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(nft_anchor_height, nft_id, 0u32);
        assert(h != 0u32);
    }

    async transition get_anchor_height(nft_id: [u8; 32]) -> Future {
        return finalize_get_anchor_height(nft_id);
    }

    async function finalize_get_anchor_height(nft_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(nft_anchor_height, nft_id, 0u32);
        assert(h != 0u32);
    }

    async transition get_status(nft_id: [u8; 32]) -> Future {
        return finalize_get_status(nft_id);
    }

    async function finalize_get_status(nft_id: [u8; 32]) {
        let s: u8 = Mapping::get_or_use(nft_status, nft_id, 0u8);
        assert_status_valid(s);
    }

    async transition get_superseded_by(nft_id: [u8; 32]) -> Future {
        return finalize_get_superseded_by(nft_id);
    }

    async function finalize_get_superseded_by(nft_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(nft_anchor_height, nft_id, 0u32);
        assert(h != 0u32);
    }
}
