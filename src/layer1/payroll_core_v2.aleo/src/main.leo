import test_usdcx_stablecoin.aleo;
import employer_agreement_v4.aleo;
import paystub_receipts.aleo;
import payroll_audit_log.aleo;

// ---------------------------------------------------------
// Payroll Core v2 — Leo v4.0 syntax
// ---------------------------------------------------------

// Structs (outside program block in v4)

struct PaidEpochKey {
    agreement_id: [u8; 32],
    epoch_id: u32,
}

struct WorkerPayArgs {
    worker_addr: address,
    worker_name_hash: field,
    agreement_id: [u8; 32],
    epoch_id: u32,
    gross_amount: u128,
    net_amount: u128,
    tax_withheld: u128,
    fee_amount: u128,
    receipt_anchor: [u8; 32],
    receipt_pair_hash: [u8; 32],
    payroll_inputs_hash: [u8; 32],
    utc_time_hash: [u8; 32],
    audit_event_hash: [u8; 32],
    batch_id: [u8; 32],
    row_hash: [u8; 32],
}

program payroll_core_v2.aleo {

    // Double-pay guard
    mapping paid_epoch: PaidEpochKey => bool;

    // ---------------------------------------------------------
    // Execute payroll for a single worker
    // ---------------------------------------------------------
    fn execute_payroll(
        employer_usdcx: test_usdcx_stablecoin.aleo::Token,
        employer_addr: address,
        employer_name_hash: field,
        w: WorkerPayArgs,
        merkle_proofs: [test_usdcx_stablecoin.aleo::MerkleProof; 2]
    ) -> (
        test_usdcx_stablecoin.aleo::ComplianceRecord,
        test_usdcx_stablecoin.aleo::Token,
        paystub_receipts.aleo::WorkerPaystubReceipt,
        paystub_receipts.aleo::EmployerPaystubReceipt,
        Final
    ) {

        assert(w.epoch_id != 0u32);
        assert(w.gross_amount >= w.net_amount);
        assert(w.gross_amount >= w.tax_withheld);

        let f_agreement: Final = employer_agreement_v4.aleo::assert_agreement_active(w.agreement_id);

        let (compliance, worker_usdcx, remaining_usdcx, f_transfer): (
            test_usdcx_stablecoin.aleo::ComplianceRecord,
            test_usdcx_stablecoin.aleo::Token,
            test_usdcx_stablecoin.aleo::Token,
            Final
        ) = test_usdcx_stablecoin.aleo::transfer_private(w.worker_addr, w.net_amount, employer_usdcx, merkle_proofs);

        let (worker_receipt, employer_receipt, f_receipt): (
            paystub_receipts.aleo::WorkerPaystubReceipt,
            paystub_receipts.aleo::EmployerPaystubReceipt,
            Final
        ) = paystub_receipts.aleo::mint_paystub_receipts(
            w.worker_addr,
            employer_addr,
            w.worker_name_hash,
            employer_name_hash,
            w.agreement_id,
            w.epoch_id,
            w.gross_amount,
            w.net_amount,
            w.tax_withheld,
            w.fee_amount,
            w.payroll_inputs_hash,
            w.receipt_anchor,
            w.receipt_pair_hash,
            w.utc_time_hash
        );

        let f_audit: Final = payroll_audit_log.aleo::anchor_event(w.audit_event_hash);

        return (
            compliance,
            remaining_usdcx,
            worker_receipt,
            employer_receipt,
            final {
                f_agreement.run();
                f_transfer.run();
                f_receipt.run();
                f_audit.run();

                let key: PaidEpochKey = PaidEpochKey {
                    agreement_id: w.agreement_id,
                    epoch_id: w.epoch_id,
                };
                let already_paid: bool = paid_epoch.get_or_use(key, false);
                assert(!already_paid);
                paid_epoch.set(key, true);
            }
        );
    }

    // ---------------------------------------------------------
    // Execute payroll for two workers in a single proof
    // ---------------------------------------------------------
    fn execute_payroll_batch_2(
        employer_usdcx: test_usdcx_stablecoin.aleo::Token,
        employer_addr: address,
        employer_name_hash: field,
        w1: WorkerPayArgs,
        w2: WorkerPayArgs,
        w1_merkle_proofs: [test_usdcx_stablecoin.aleo::MerkleProof; 2],
        w2_merkle_proofs: [test_usdcx_stablecoin.aleo::MerkleProof; 2]
    ) -> (
        test_usdcx_stablecoin.aleo::ComplianceRecord,
        test_usdcx_stablecoin.aleo::ComplianceRecord,
        test_usdcx_stablecoin.aleo::Token,
        paystub_receipts.aleo::WorkerPaystubReceipt,
        paystub_receipts.aleo::EmployerPaystubReceipt,
        paystub_receipts.aleo::WorkerPaystubReceipt,
        paystub_receipts.aleo::EmployerPaystubReceipt,
        Final
    ) {
        assert(w1.epoch_id != 0u32);
        assert(w1.gross_amount >= w1.net_amount);
        assert(w1.gross_amount >= w1.tax_withheld);
        assert(w2.epoch_id != 0u32);
        assert(w2.gross_amount >= w2.net_amount);
        assert(w2.gross_amount >= w2.tax_withheld);

        let f_agreement1: Final = employer_agreement_v4.aleo::assert_agreement_active(w1.agreement_id);
        let f_agreement2: Final = employer_agreement_v4.aleo::assert_agreement_active(w2.agreement_id);

        let (compliance1, worker1_usdcx, remainder1, f_transfer1): (
            test_usdcx_stablecoin.aleo::ComplianceRecord,
            test_usdcx_stablecoin.aleo::Token,
            test_usdcx_stablecoin.aleo::Token,
            Final
        ) = test_usdcx_stablecoin.aleo::transfer_private(w1.worker_addr, w1.net_amount, employer_usdcx, w1_merkle_proofs);

        let (compliance2, worker2_usdcx, remaining_usdcx, f_transfer2): (
            test_usdcx_stablecoin.aleo::ComplianceRecord,
            test_usdcx_stablecoin.aleo::Token,
            test_usdcx_stablecoin.aleo::Token,
            Final
        ) = test_usdcx_stablecoin.aleo::transfer_private(w2.worker_addr, w2.net_amount, remainder1, w2_merkle_proofs);

        let (w1_worker_receipt, w1_employer_receipt, f_receipt1): (
            paystub_receipts.aleo::WorkerPaystubReceipt,
            paystub_receipts.aleo::EmployerPaystubReceipt,
            Final
        ) = paystub_receipts.aleo::mint_paystub_receipts(
            w1.worker_addr, employer_addr, w1.worker_name_hash, employer_name_hash,
            w1.agreement_id, w1.epoch_id, w1.gross_amount, w1.net_amount,
            w1.tax_withheld, w1.fee_amount, w1.payroll_inputs_hash,
            w1.receipt_anchor, w1.receipt_pair_hash, w1.utc_time_hash
        );

        let (w2_worker_receipt, w2_employer_receipt, f_receipt2): (
            paystub_receipts.aleo::WorkerPaystubReceipt,
            paystub_receipts.aleo::EmployerPaystubReceipt,
            Final
        ) = paystub_receipts.aleo::mint_paystub_receipts(
            w2.worker_addr, employer_addr, w2.worker_name_hash, employer_name_hash,
            w2.agreement_id, w2.epoch_id, w2.gross_amount, w2.net_amount,
            w2.tax_withheld, w2.fee_amount, w2.payroll_inputs_hash,
            w2.receipt_anchor, w2.receipt_pair_hash, w2.utc_time_hash
        );

        let f_audit1: Final = payroll_audit_log.aleo::anchor_event(w1.audit_event_hash);
        let f_audit2: Final = payroll_audit_log.aleo::anchor_event(w2.audit_event_hash);

        return (
            compliance1, compliance2, remaining_usdcx,
            w1_worker_receipt, w1_employer_receipt,
            w2_worker_receipt, w2_employer_receipt,
            final {
                f_agreement1.run();
                f_agreement2.run();
                f_transfer1.run();
                f_transfer2.run();
                f_receipt1.run();
                f_receipt2.run();
                f_audit1.run();
                f_audit2.run();

                let key1: PaidEpochKey = PaidEpochKey {
                    agreement_id: w1.agreement_id,
                    epoch_id: w1.epoch_id,
                };
                let already_paid1: bool = paid_epoch.get_or_use(key1, false);
                assert(!already_paid1);
                paid_epoch.set(key1, true);

                let key2: PaidEpochKey = PaidEpochKey {
                    agreement_id: w2.agreement_id,
                    epoch_id: w2.epoch_id,
                };
                let already_paid2: bool = paid_epoch.get_or_use(key2, false);
                assert(!already_paid2);
                paid_epoch.set(key2, true);
            }
        );
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx")
    constructor() {}
}
