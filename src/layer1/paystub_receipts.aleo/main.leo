program paystub_receipts.aleo {

    // ---------------------------------------------------------
    // Paystub Receipts (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Purpose:
    // - Mint private receipt records for BOTH worker and employer.
    // - Publish a minimal public anchor index: receipt_anchor -> first-seen block height.
    //
    // Design:
    // - Portal supplies deterministic receipt anchors and pairing hashes.
    // - Receipts are append-only (never consumed).
    // - Corrections use reversal/void receipts (new anchors), never mutation of old anchors.
    //
    // Privacy:
    // - All identity/amount/epoch fields are PRIVATE in records.
    // - Public state is minimal and non-identifying.

    // -----------------------------
    // Receipt kinds (private enum)
    // -----------------------------
    const KIND_PAYSTUB: u8 = 1u8;
    const KIND_REVERSAL: u8 = 2u8;

    // -----------------------------
    // Receipt record: Worker copy
    // -----------------------------
    record WorkerPaystubReceipt {
        receipt_anchor: [u8; 32].private,
        pair_hash: [u8; 32].private,

        kind: u8.private,

        worker_name_hash: field.private,
        employer_name_hash: field.private,

        agreement_id: [u8; 32].private,
        epoch_id: u32.private,

        gross_amount: u128.private,
        net_amount: u128.private,
        tax_withheld: u128.private,
        fee_amount: u128.private,

        payroll_inputs_hash: [u8; 32].private,
        utc_time_hash: [u8; 32].private,

        issued_height: u32.private,

        owner: address.private,
        _nonce: group.public
    }

    // -----------------------------
    // Receipt record: Employer copy
    // -----------------------------
    record EmployerPaystubReceipt {
        receipt_anchor: [u8; 32].private,
        pair_hash: [u8; 32].private,

        kind: u8.private,

        worker_name_hash: field.private,
        employer_name_hash: field.private,

        agreement_id: [u8; 32].private,
        epoch_id: u32.private,

        gross_amount: u128.private,
        net_amount: u128.private,
        tax_withheld: u128.private,
        fee_amount: u128.private,

        payroll_inputs_hash: [u8; 32].private,
        utc_time_hash: [u8; 32].private,

        issued_height: u32.private,

        owner: address.private,
        _nonce: group.public
    }

    // ---------------------------------------------------------
    // Minimal public anchor index: receipt_anchor -> first-seen height
    // ---------------------------------------------------------
    mapping receipt_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    // ---------------------------------------------------------
    // Internal: anchor once + enforce uniqueness
    // ---------------------------------------------------------
    function anchor_unique(receipt_anchor: [u8; 32]) {
        let existing: u32 = Mapping::get_or_use(receipt_anchor_height, receipt_anchor, 0u32);
        assert(existing == 0u32);

        let h: u32 = block.height;
        Mapping::set(receipt_anchor_height, receipt_anchor, h);
    }

    // ---------------------------------------------------------
    // Mint paystub receipts (worker + employer)
    // ---------------------------------------------------------
    transition mint_paystub_receipts(
        worker_owner: address,
        employer_owner: address,

        worker_name_hash: field,
        employer_name_hash: field,

        agreement_id: [u8; 32],
        epoch_id: u32,

        gross_amount: u128,
        net_amount: u128,
        tax_withheld: u128,
        fee_amount: u128,

        payroll_inputs_hash: [u8; 32],
        receipt_anchor: [u8; 32],
        pair_hash: [u8; 32],
        utc_time_hash: [u8; 32]
    ) -> (WorkerPaystubReceipt, EmployerPaystubReceipt) {

        assert(epoch_id != 0u32);
        assert(gross_amount >= net_amount);
        assert(gross_amount >= tax_withheld);

        anchor_unique(receipt_anchor);

        let h: u32 = block.height;

        let worker_receipt: WorkerPaystubReceipt = WorkerPaystubReceipt {
            receipt_anchor: receipt_anchor.private,
            pair_hash: pair_hash.private,

            kind: KIND_PAYSTUB.private,

            worker_name_hash: worker_name_hash.private,
            employer_name_hash: employer_name_hash.private,

            agreement_id: agreement_id.private,
            epoch_id: epoch_id.private,

            gross_amount: gross_amount.private,
            net_amount: net_amount.private,
            tax_withheld: tax_withheld.private,
            fee_amount: fee_amount.private,

            payroll_inputs_hash: payroll_inputs_hash.private,
            utc_time_hash: utc_time_hash.private,

            issued_height: h.private,

            owner: worker_owner.private,
            _nonce: group::rand().public
        };

        let employer_receipt: EmployerPaystubReceipt = EmployerPaystubReceipt {
            receipt_anchor: receipt_anchor.private,
            pair_hash: pair_hash.private,

            kind: KIND_PAYSTUB.private,

            worker_name_hash: worker_name_hash.private,
            employer_name_hash: employer_name_hash.private,

            agreement_id: agreement_id.private,
            epoch_id: epoch_id.private,

            gross_amount: gross_amount.private,
            net_amount: net_amount.private,
            tax_withheld: tax_withheld.private,
            fee_amount: fee_amount.private,

            payroll_inputs_hash: payroll_inputs_hash.private,
            utc_time_hash: utc_time_hash.private,

            issued_height: h.private,

            owner: employer_owner.private,
            _nonce: group::rand().public
        };

        return (worker_receipt, employer_receipt);
    }

    // ---------------------------------------------------------
    // Mint reversal/correction receipts (append-only)
    // ---------------------------------------------------------
    transition mint_reversal_receipts(
        worker_owner: address,
        employer_owner: address,

        worker_name_hash: field,
        employer_name_hash: field,

        agreement_id: [u8; 32],
        epoch_id: u32,

        gross_amount: u128,
        net_amount: u128,
        tax_withheld: u128,
        fee_amount: u128,

        payroll_inputs_hash: [u8; 32],
        reversal_anchor: [u8; 32],
        pair_hash: [u8; 32],
        utc_time_hash: [u8; 32]
    ) -> (WorkerPaystubReceipt, EmployerPaystubReceipt) {

        assert(epoch_id != 0u32);
        assert(gross_amount >= net_amount);
        assert(gross_amount >= tax_withheld);

        anchor_unique(reversal_anchor);

        let h: u32 = block.height;

        let worker_receipt: WorkerPaystubReceipt = WorkerPaystubReceipt {
            receipt_anchor: reversal_anchor.private,
            pair_hash: pair_hash.private,

            kind: KIND_REVERSAL.private,

            worker_name_hash: worker_name_hash.private,
            employer_name_hash: employer_name_hash.private,

            agreement_id: agreement_id.private,
            epoch_id: epoch_id.private,

            gross_amount: gross_amount.private,
            net_amount: net_amount.private,
            tax_withheld: tax_withheld.private,
            fee_amount: fee_amount.private,

            payroll_inputs_hash: payroll_inputs_hash.private,
            utc_time_hash: utc_time_hash.private,

            issued_height: h.private,

            owner: worker_owner.private,
            _nonce: group::rand().public
        };

        let employer_receipt: EmployerPaystubReceipt = EmployerPaystubReceipt {
            receipt_anchor: reversal_anchor.private,
            pair_hash: pair_hash.private,

            kind: KIND_REVERSAL.private,

            worker_name_hash: worker_name_hash.private,
            employer_name_hash: employer_name_hash.private,

            agreement_id: agreement_id.private,
            epoch_id: epoch_id.private,

            gross_amount: gross_amount.private,
            net_amount: net_amount.private,
            tax_withheld: tax_withheld.private,
            fee_amount: fee_amount.private,

            payroll_inputs_hash: payroll_inputs_hash.private,
            utc_time_hash: utc_time_hash.private,

            issued_height: h.private,

            owner: employer_owner.private,
            _nonce: group::rand().public
        };

        return (worker_receipt, employer_receipt);
    }

    // ---------------------------------------------------------
    // Public assertion: anchor exists
    // ---------------------------------------------------------
    transition assert_receipt_anchored(receipt_anchor: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(receipt_anchor_height, receipt_anchor, 0u32);
        assert(h != 0u32);
    }

    // ---------------------------------------------------------
    // Public read utility: get receipt anchor height
    // ---------------------------------------------------------
    transition get_anchor_height(receipt_anchor: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(receipt_anchor_height, receipt_anchor, 0u32);
        return h;
    }
}
