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
    //   (prevents minting “phantom” summaries not backed by Layer 1 anchors).
    //
    // NOTE:
    // - This program does NOT transfer USDCx and does NOT issue Layer 1 receipts.
    // - It is safe to skip minting for “view-only” reports; minting is optional.

    // -----------------------------
    // Period types (enum)
    // -----------------------------
    const TYPE_CYCLE: u8 = 1u8;
    const TYPE_QUARTER: u8 = 2u8;
    const TYPE_YTD: u8 = 3u8;
    const TYPE_EOY: u8 = 4u8;

    function assert_type(t: u8) {
        assert(
            t == TYPE_CYCLE ||
            t == TYPE_QUARTER ||
            t == TYPE_YTD ||
            t == TYPE_EOY
        );
    }

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

        // Metadata
        minted_height: u32.private,

        // Ownership
        owner: address.private,
        _nonce: group.public
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
    // Internal: anchor once + set active
    // ---------------------------------------------------------
    function anchor_unique(nft_id: [u8; 32]) {
        let existing: u32 = Mapping::get_or_use(nft_anchor_height, nft_id, 0u32);
        assert(existing == 0u32);

        let h: u32 = block.height;
        Mapping::set(nft_anchor_height, nft_id, h);
        Mapping::set(nft_status, nft_id, STATUS_ACTIVE);
        Mapping::set(superseded_by, nft_id, [0u8; 32]);
    }

    // ---------------------------------------------------------
    // Internal: shared mint path
    // ---------------------------------------------------------
    function mint_common(
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
        policy_v: u16
    ) -> PayrollNFT {

        assert_type(period_type);

        // Period rules:
        // - For cycle/quarter/YTD/EOY, portal supplies a canonical encoding.
        // - period_end must be >= period_start, and non-zero for bounded periods.
        assert(period_start != 0u32);
        assert(period_end >= period_start);

        // Versions must be non-zero to avoid ambiguous schemas.
        assert(schema_v != 0u16);
        assert(calc_v != 0u16);
        assert(policy_v != 0u16);

        // Layer 1 prerequisite: agreement must be ACTIVE.
        employer_agreement.aleo/assert_agreement_active(agreement_id);

        // Layer 1 prerequisite: the inputs_hash must be anchored (monthly batched anchor model).
        // This prevents minting summaries not backed by Layer 1 audit anchors.
        payroll_audit_log.aleo/assert_event_anchored(inputs_hash);

        // Uniqueness + minimal public state
        anchor_unique(nft_id);

        let h: u32 = block.height;

        let nft: PayrollNFT = PayrollNFT {
            nft_id: nft_id.private,

            agreement_id: agreement_id.private,

            period_type: period_type.private,
            period_start: period_start.private,
            period_end: period_end.private,

            doc_hash: doc_hash.private,
            root: root.private,
            inputs_hash: inputs_hash.private,

            schema_v: schema_v.private,
            calc_v: calc_v.private,
            policy_v: policy_v.private,

            minted_height: h.private,

            owner: caller.private,
            _nonce: group::rand().public
        };

        return nft;
    }

    // ---------------------------------------------------------
    // Mint: Per-payroll-cycle
    // ---------------------------------------------------------
    transition mint_cycle_nft(
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
    ) -> PayrollNFT {
        return mint_common(
            nft_id,
            agreement_id,
            TYPE_CYCLE,
            period_start,
            period_end,
            doc_hash,
            root,
            inputs_hash,
            schema_v,
            calc_v,
            policy_v
        );
    }

    // ---------------------------------------------------------
    // Mint: Quarterly (Q1–Q4)
    // ---------------------------------------------------------
    transition mint_quarter_nft(
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
    ) -> PayrollNFT {
        return mint_common(
            nft_id,
            agreement_id,
            TYPE_QUARTER,
            period_start,
            period_end,
            doc_hash,
            root,
            inputs_hash,
            schema_v,
            calc_v,
            policy_v
        );
    }

    // ---------------------------------------------------------
    // Mint: Year-to-Date
    // ---------------------------------------------------------
    transition mint_ytd_nft(
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
    ) -> PayrollNFT {
        return mint_common(
            nft_id,
            agreement_id,
            TYPE_YTD,
            period_start,
            period_end,
            doc_hash,
            root,
            inputs_hash,
            schema_v,
            calc_v,
            policy_v
        );
    }

    // ---------------------------------------------------------
    // Mint: End-of-Year
    // ---------------------------------------------------------
    transition mint_eoy_nft(
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
    ) -> PayrollNFT {
        return mint_common(
            nft_id,
            agreement_id,
            TYPE_EOY,
            period_start,
            period_end,
            doc_hash,
            root,
            inputs_hash,
            schema_v,
            calc_v,
            policy_v
        );
    }

    // ---------------------------------------------------------
    // Revoke: consume record + set status
    // ---------------------------------------------------------
    transition revoke_nft(nft: PayrollNFT) {
        assert(nft.owner == caller.private);

        let id: [u8; 32] = nft.nft_id;
        let s: u8 = Mapping::get_or_use(nft_status, id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        consume nft;

        Mapping::set(nft_status, id, STATUS_REVOKED);
    }

    // ---------------------------------------------------------
    // Supersede: consume old record, mint new separately, and mark linkage
    // ---------------------------------------------------------
    transition mark_superseded(old_nft: PayrollNFT, new_nft_id: [u8; 32]) {
        assert(old_nft.owner == caller.private);

        let old_id: [u8; 32] = old_nft.nft_id;
        let s: u8 = Mapping::get_or_use(nft_status, old_id, 0u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        consume old_nft;

        Mapping::set(nft_status, old_id, STATUS_SUPERSEDED);
        Mapping::set(superseded_by, old_id, new_nft_id);
    }

    // ---------------------------------------------------------
    // Public utilities
    // ---------------------------------------------------------
    transition assert_nft_exists(nft_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(nft_anchor_height, nft_id, 0u32);
        assert(h != 0u32);
    }

    transition get_anchor_height(nft_id: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(nft_anchor_height, nft_id, 0u32);
        return h;
    }

    transition get_status(nft_id: [u8; 32]) -> u8 {
        let s: u8 = Mapping::get_or_use(nft_status, nft_id, 0u8);
        assert_status_valid(s);
        return s;
    }

    transition get_superseded_by(nft_id: [u8; 32]) -> [u8; 32] {
        let x: [u8; 32] = Mapping::get_or_use(superseded_by, nft_id, [0u8; 32]);
        return x;
    }
}
