import test_usdcx_stablecoin.aleo;
import employer_agreement_v2.aleo;
import paystub_receipts.aleo;
import payroll_audit_log.aleo;

program payroll_core.aleo {

    // ---------------------------------------------------------
    // Payroll Core (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Executes private payroll:
    // - Transfers USDCx from employer record to worker record
    // - Mints private paystub receipts for both parties
    // - Anchors an audit event in payroll_audit_log

    // Struct key for the double-pay guard mapping
    struct PaidEpochKey {
        agreement_id: [u8; 32],
        epoch_id: u32,
    }

    // Per-worker payment arguments — keeps transition param counts
    // within Leo's 16-input limit.
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
    }

    // Prevent double-pay per agreement + epoch
    mapping paid_epoch: PaidEpochKey => bool;

    // ---------------------------------------------------------
    // Execute payroll for a single worker
    //
    // merkle_proofs: [MerkleProof; 2] required by transfer_private
    // to prove neither employer nor worker is on the USDCx freeze list.
    // ---------------------------------------------------------
    async transition execute_payroll(
        employer_usdcx: test_usdcx_stablecoin.aleo/Token,
        employer_addr: address,
        employer_name_hash: field,
        w: WorkerPayArgs,
        merkle_proofs: [test_usdcx_stablecoin.aleo/MerkleProof; 2]
    ) -> (
        test_usdcx_stablecoin.aleo/ComplianceRecord,
        test_usdcx_stablecoin.aleo/Token,
        paystub_receipts.aleo/WorkerPaystubReceipt,
        paystub_receipts.aleo/EmployerPaystubReceipt,
        Future
    ) {

        // Basic sanity checks (circuit-time)
        assert(w.epoch_id != 0u32);
        assert(w.gross_amount >= w.net_amount);
        assert(w.gross_amount >= w.tax_withheld);

        // Assert agreement is ACTIVE (cross-program Future)
        let f_agreement: Future = employer_agreement_v2.aleo/assert_agreement_active(w.agreement_id);

        // Execute USDCx private transfer (employer -> worker)
        // Signature: transfer_private(from, amount, token, merkle_proofs)
        // Returns: (ComplianceRecord, worker_token, change_token, Future)
        let (compliance, worker_usdcx, remaining_usdcx, f_transfer): (
            test_usdcx_stablecoin.aleo/ComplianceRecord,
            test_usdcx_stablecoin.aleo/Token,
            test_usdcx_stablecoin.aleo/Token,
            Future
        ) = test_usdcx_stablecoin.aleo/transfer_private(employer_addr, w.net_amount, employer_usdcx, merkle_proofs);

        // Mint paystub receipts (worker + employer)
        let (worker_receipt, employer_receipt, f_receipt): (
            paystub_receipts.aleo/WorkerPaystubReceipt,
            paystub_receipts.aleo/EmployerPaystubReceipt,
            Future
        ) = paystub_receipts.aleo/mint_paystub_receipts(
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

        // Anchor payroll audit event
        let f_audit: Future = payroll_audit_log.aleo/anchor_event(w.audit_event_hash);

        return (
            compliance,
            remaining_usdcx,
            worker_receipt,
            employer_receipt,
            finalize_execute_payroll(f_agreement, f_transfer, f_receipt, f_audit, w.agreement_id, w.epoch_id)
        );
    }

    async function finalize_execute_payroll(
        f_agreement: Future,
        f_transfer: Future,
        f_receipt: Future,
        f_audit: Future,
        agreement_id: [u8; 32],
        epoch_id: u32
    ) {
        f_agreement.await();
        f_transfer.await();
        f_audit.await();
        f_receipt.await();

        // Prevent double payment for same agreement + epoch
        let key: PaidEpochKey = PaidEpochKey {
            agreement_id: agreement_id,
            epoch_id: epoch_id,
        };
        let already_paid: bool = paid_epoch.get_or_use(key, false);
        assert(!already_paid);

        paid_epoch.set(key, true);
    }

    // ---------------------------------------------------------
    // Execute payroll for two workers in a single proof
    //
    // Uses WorkerPayArgs struct to stay within Leo's 16-param limit.
    // One employer USDCx record is consumed; the circuit chains two
    // transfer_private calls so no manual record splitting is needed.
    // The double-pay guard is atomic — if either (agreement, epoch)
    // pair was already paid, the entire transaction reverts.
    //
    // Each worker requires its own [MerkleProof; 2] for the freeze
    // list compliance check inside transfer_private.
    // ---------------------------------------------------------
    async transition execute_payroll_batch_2(
        employer_usdcx: test_usdcx_stablecoin.aleo/Token,
        employer_addr: address,
        employer_name_hash: field,
        w1: WorkerPayArgs,
        w2: WorkerPayArgs,
        w1_merkle_proofs: [test_usdcx_stablecoin.aleo/MerkleProof; 2],
        w2_merkle_proofs: [test_usdcx_stablecoin.aleo/MerkleProof; 2]
    ) -> (
        test_usdcx_stablecoin.aleo/ComplianceRecord,   // compliance record for worker 1 transfer
        test_usdcx_stablecoin.aleo/ComplianceRecord,   // compliance record for worker 2 transfer
        test_usdcx_stablecoin.aleo/Token,              // remaining USDCx returned to employer
        paystub_receipts.aleo/WorkerPaystubReceipt,    // worker 1 receipt
        paystub_receipts.aleo/EmployerPaystubReceipt,  // employer copy for worker 1 payment
        paystub_receipts.aleo/WorkerPaystubReceipt,    // worker 2 receipt
        paystub_receipts.aleo/EmployerPaystubReceipt,  // employer copy for worker 2 payment
        Future
    ) {
        // Basic sanity checks
        assert(w1.epoch_id != 0u32);
        assert(w1.gross_amount >= w1.net_amount);
        assert(w1.gross_amount >= w1.tax_withheld);
        assert(w2.epoch_id != 0u32);
        assert(w2.gross_amount >= w2.net_amount);
        assert(w2.gross_amount >= w2.tax_withheld);

        // Assert both agreements are ACTIVE
        let f_agreement1: Future = employer_agreement_v2.aleo/assert_agreement_active(w1.agreement_id);
        let f_agreement2: Future = employer_agreement_v2.aleo/assert_agreement_active(w2.agreement_id);

        // Transfer worker1's net_amount; remainder1 is the change record
        let (compliance1, worker1_usdcx, remainder1, f_transfer1): (
            test_usdcx_stablecoin.aleo/ComplianceRecord,
            test_usdcx_stablecoin.aleo/Token,
            test_usdcx_stablecoin.aleo/Token,
            Future
        ) = test_usdcx_stablecoin.aleo/transfer_private(employer_addr, w1.net_amount, employer_usdcx, w1_merkle_proofs);

        // Transfer worker2's net_amount from the change; remaining_usdcx goes back to employer
        let (compliance2, worker2_usdcx, remaining_usdcx, f_transfer2): (
            test_usdcx_stablecoin.aleo/ComplianceRecord,
            test_usdcx_stablecoin.aleo/Token,
            test_usdcx_stablecoin.aleo/Token,
            Future
        ) = test_usdcx_stablecoin.aleo/transfer_private(employer_addr, w2.net_amount, remainder1, w2_merkle_proofs);

        // Mint paystub receipts for worker 1
        let (w1_worker_receipt, w1_employer_receipt, f_receipt1): (
            paystub_receipts.aleo/WorkerPaystubReceipt,
            paystub_receipts.aleo/EmployerPaystubReceipt,
            Future
        ) = paystub_receipts.aleo/mint_paystub_receipts(
            w1.worker_addr,
            employer_addr,
            w1.worker_name_hash,
            employer_name_hash,
            w1.agreement_id,
            w1.epoch_id,
            w1.gross_amount,
            w1.net_amount,
            w1.tax_withheld,
            w1.fee_amount,
            w1.payroll_inputs_hash,
            w1.receipt_anchor,
            w1.receipt_pair_hash,
            w1.utc_time_hash
        );

        // Mint paystub receipts for worker 2
        let (w2_worker_receipt, w2_employer_receipt, f_receipt2): (
            paystub_receipts.aleo/WorkerPaystubReceipt,
            paystub_receipts.aleo/EmployerPaystubReceipt,
            Future
        ) = paystub_receipts.aleo/mint_paystub_receipts(
            w2.worker_addr,
            employer_addr,
            w2.worker_name_hash,
            employer_name_hash,
            w2.agreement_id,
            w2.epoch_id,
            w2.gross_amount,
            w2.net_amount,
            w2.tax_withheld,
            w2.fee_amount,
            w2.payroll_inputs_hash,
            w2.receipt_anchor,
            w2.receipt_pair_hash,
            w2.utc_time_hash
        );

        // Anchor audit events for both payments
        let f_audit1: Future = payroll_audit_log.aleo/anchor_event(w1.audit_event_hash);
        let f_audit2: Future = payroll_audit_log.aleo/anchor_event(w2.audit_event_hash);

        return (
            compliance1,
            compliance2,
            remaining_usdcx,
            w1_worker_receipt,
            w1_employer_receipt,
            w2_worker_receipt,
            w2_employer_receipt,
            finalize_payroll_batch_2(
                f_agreement1, f_agreement2,
                f_transfer1, f_transfer2,
                f_receipt1, f_receipt2,
                f_audit1, f_audit2,
                w1.agreement_id, w1.epoch_id,
                w2.agreement_id, w2.epoch_id
            )
        );
    }

    async function finalize_payroll_batch_2(
        f_agreement1: Future,
        f_agreement2: Future,
        f_transfer1: Future,
        f_transfer2: Future,
        f_receipt1: Future,
        f_receipt2: Future,
        f_audit1: Future,
        f_audit2: Future,
        w1_agreement_id: [u8; 32],
        w1_epoch_id: u32,
        w2_agreement_id: [u8; 32],
        w2_epoch_id: u32
    ) {
        f_agreement1.await();
        f_agreement2.await();
        f_transfer1.await();
        f_transfer2.await();
        f_audit1.await();
        f_audit2.await();
        f_receipt1.await();
        f_receipt2.await();

        // Double-pay guard: both checks are atomic — if either fails the tx reverts
        let key1: PaidEpochKey = PaidEpochKey {
            agreement_id: w1_agreement_id,
            epoch_id: w1_epoch_id,
        };
        let already_paid1: bool = paid_epoch.get_or_use(key1, false);
        assert(!already_paid1);
        paid_epoch.set(key1, true);

        let key2: PaidEpochKey = PaidEpochKey {
            agreement_id: w2_agreement_id,
            epoch_id: w2_epoch_id,
        };
        let already_paid2: bool = paid_epoch.get_or_use(key2, false);
        assert(!already_paid2);
        paid_epoch.set(key2, true);
    }

    @noupgrade async constructor() {}
}
