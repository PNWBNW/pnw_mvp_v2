program paystub_receipts.aleo {

    // ---------------------------------------------------------
    // Paystub Receipts (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Purpose:
    // - Mint private receipt records for BOTH worker and employer.
    // - Publish a minimal public anchor index: receipt_anchor -> first-seen block height.
    //
    // Privacy:
    // - All identity/amount/epoch fields are PRIVATE in records.
    // - Public state is minimal and non-identifying.

    const KIND_PAYSTUB: u8 = 1u8;
    const KIND_REVERSAL: u8 = 2u8;

    // -----------------------------
    // Receipt record: Worker copy
    // -----------------------------
    record WorkerPaystubReceipt {
        receipt_anchor: [u8; 32],
        pair_hash: [u8; 32],
        kind: u8,
        worker_name_hash: field,
        employer_name_hash: field,
        agreement_id: [u8; 32],
        epoch_id: u32,
        gross_amount: u128,
        net_amount: u128,
        tax_withheld: u128,
        fee_amount: u128,
        payroll_inputs_hash: [u8; 32],
        utc_time_hash: [u8; 32],
        // sentinel 0u32; actual height in receipt_anchor_height mapping
        issued_height: u32,
        owner: address,
    }

    // -----------------------------
    // Receipt record: Employer copy
    // -----------------------------
    record EmployerPaystubReceipt {
        receipt_anchor: [u8; 32],
        pair_hash: [u8; 32],
        kind: u8,
        worker_name_hash: field,
        employer_name_hash: field,
        agreement_id: [u8; 32],
        epoch_id: u32,
        gross_amount: u128,
        net_amount: u128,
        tax_withheld: u128,
        fee_amount: u128,
        payroll_inputs_hash: [u8; 32],
        utc_time_hash: [u8; 32],
        // sentinel 0u32; actual height in receipt_anchor_height mapping
        issued_height: u32,
        owner: address,
    }

    // ---------------------------------------------------------
    // Minimal public anchor index: receipt_anchor -> first-seen height
    // ---------------------------------------------------------
    mapping receipt_anchor_height: [u8; 32] => u32;

    // ---------------------------------------------------------
    // Mint paystub receipts (worker + employer)
    // ---------------------------------------------------------
    async transition mint_paystub_receipts(
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
    ) -> (WorkerPaystubReceipt, EmployerPaystubReceipt, Future) {

        assert(epoch_id != 0u32);
        assert(gross_amount >= net_amount);
        assert(gross_amount >= tax_withheld);

        let worker_receipt: WorkerPaystubReceipt = WorkerPaystubReceipt {
            receipt_anchor: receipt_anchor,
            pair_hash: pair_hash,
            kind: KIND_PAYSTUB,
            worker_name_hash: worker_name_hash,
            employer_name_hash: employer_name_hash,
            agreement_id: agreement_id,
            epoch_id: epoch_id,
            gross_amount: gross_amount,
            net_amount: net_amount,
            tax_withheld: tax_withheld,
            fee_amount: fee_amount,
            payroll_inputs_hash: payroll_inputs_hash,
            utc_time_hash: utc_time_hash,
            issued_height: 0u32,
            owner: worker_owner,
        };

        let employer_receipt: EmployerPaystubReceipt = EmployerPaystubReceipt {
            receipt_anchor: receipt_anchor,
            pair_hash: pair_hash,
            kind: KIND_PAYSTUB,
            worker_name_hash: worker_name_hash,
            employer_name_hash: employer_name_hash,
            agreement_id: agreement_id,
            epoch_id: epoch_id,
            gross_amount: gross_amount,
            net_amount: net_amount,
            tax_withheld: tax_withheld,
            fee_amount: fee_amount,
            payroll_inputs_hash: payroll_inputs_hash,
            utc_time_hash: utc_time_hash,
            issued_height: 0u32,
            owner: employer_owner,
        };

        return (worker_receipt, employer_receipt, finalize_anchor_unique(receipt_anchor));
    }

    async function finalize_anchor_unique(receipt_anchor: [u8; 32]) {
        let existing: u32 = receipt_anchor_height.get_or_use(receipt_anchor, 0u32);
        assert(existing == 0u32);
        receipt_anchor_height.set(receipt_anchor, block.height);
    }

    // ---------------------------------------------------------
    // Mint reversal/correction receipts (append-only)
    // ---------------------------------------------------------
    async transition mint_reversal_receipts(
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
    ) -> (WorkerPaystubReceipt, EmployerPaystubReceipt, Future) {

        assert(epoch_id != 0u32);
        assert(gross_amount >= net_amount);
        assert(gross_amount >= tax_withheld);

        let worker_receipt: WorkerPaystubReceipt = WorkerPaystubReceipt {
            receipt_anchor: reversal_anchor,
            pair_hash: pair_hash,
            kind: KIND_REVERSAL,
            worker_name_hash: worker_name_hash,
            employer_name_hash: employer_name_hash,
            agreement_id: agreement_id,
            epoch_id: epoch_id,
            gross_amount: gross_amount,
            net_amount: net_amount,
            tax_withheld: tax_withheld,
            fee_amount: fee_amount,
            payroll_inputs_hash: payroll_inputs_hash,
            utc_time_hash: utc_time_hash,
            issued_height: 0u32,
            owner: worker_owner,
        };

        let employer_receipt: EmployerPaystubReceipt = EmployerPaystubReceipt {
            receipt_anchor: reversal_anchor,
            pair_hash: pair_hash,
            kind: KIND_REVERSAL,
            worker_name_hash: worker_name_hash,
            employer_name_hash: employer_name_hash,
            agreement_id: agreement_id,
            epoch_id: epoch_id,
            gross_amount: gross_amount,
            net_amount: net_amount,
            tax_withheld: tax_withheld,
            fee_amount: fee_amount,
            payroll_inputs_hash: payroll_inputs_hash,
            utc_time_hash: utc_time_hash,
            issued_height: 0u32,
            owner: employer_owner,
        };

        return (worker_receipt, employer_receipt, finalize_anchor_unique(reversal_anchor));
    }

    // ---------------------------------------------------------
    // Public assertion: anchor exists
    // ---------------------------------------------------------
    async transition assert_receipt_anchored(receipt_anchor: [u8; 32]) -> Future {
        return finalize_assert_receipt_anchor(receipt_anchor);
    }

    async function finalize_assert_receipt_anchor(receipt_anchor: [u8; 32]) {
        let h: u32 = receipt_anchor_height.get_or_use(receipt_anchor, 0u32);
        assert(h != 0u32);
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx") async constructor() {}
}