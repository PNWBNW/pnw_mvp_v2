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

    // Prevent double-pay per agreement + epoch
    mapping paid_epoch: PaidEpochKey => bool;

    // ---------------------------------------------------------
    // Execute payroll for a single worker
    // ---------------------------------------------------------
    async transition execute_payroll(
        // Funding
        employer_usdcx: test_usdcx_stablecoin.aleo/Token,

        // Parties
        employer_addr: address,
        worker_addr: address,

        // Identity hashes
        employer_name_hash: field,
        worker_name_hash: field,

        // Agreement
        agreement_id: [u8; 32],
        epoch_id: u32,

        // Payroll amounts (minor units)
        gross_amount: u128,
        net_amount: u128,
        tax_withheld: u128,
        fee_amount: u128,

        // Receipt + audit commitments (portal supplied)
        receipt_anchor: [u8; 32],
        receipt_pair_hash: [u8; 32],
        payroll_inputs_hash: [u8; 32],
        utc_time_hash: [u8; 32],
        audit_event_hash: [u8; 32]
    ) -> (
        test_usdcx_stablecoin.aleo/Token,
        paystub_receipts.aleo/WorkerPaystubReceipt,
        paystub_receipts.aleo/EmployerPaystubReceipt,
        Future
    ) {

        // Basic sanity checks (circuit-time)
        assert(epoch_id != 0u32);
        assert(gross_amount >= net_amount);
        assert(gross_amount >= tax_withheld);

        // Assert agreement is ACTIVE (cross-program Future)
        let f_agreement: Future = employer_agreement_v2.aleo/assert_agreement_active(agreement_id);

        // Execute USDCx private transfer (employer -> worker)
        let (worker_usdcx, remaining_usdcx): (
            test_usdcx_stablecoin.aleo/Token,
            test_usdcx_stablecoin.aleo/Token
        ) = test_usdcx_stablecoin.aleo/transfer_private(employer_usdcx, worker_addr, net_amount);

        // Mint paystub receipts (worker + employer) — async, returns Future
        let (worker_receipt, employer_receipt, f_receipt): (
            paystub_receipts.aleo/WorkerPaystubReceipt,
            paystub_receipts.aleo/EmployerPaystubReceipt,
            Future
        ) = paystub_receipts.aleo/mint_paystub_receipts(
            worker_addr,
            employer_addr,
            worker_name_hash,
            employer_name_hash,
            agreement_id,
            epoch_id,
            gross_amount,
            net_amount,
            tax_withheld,
            fee_amount,
            payroll_inputs_hash,
            receipt_anchor,
            receipt_pair_hash,
            utc_time_hash
        );

        // Anchor payroll audit event
        let f_audit: Future = payroll_audit_log.aleo/anchor_event(audit_event_hash);

        return (
            remaining_usdcx,
            worker_receipt,
            employer_receipt,
            finalize_execute_payroll(f_agreement, f_receipt, f_audit, agreement_id, epoch_id)
        );
    }

    async function finalize_execute_payroll(
        f_agreement: Future,
        f_receipt: Future,
        f_audit: Future,
        agreement_id: [u8; 32],
        epoch_id: u32
    ) {
        f_agreement.await();
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
    // Design: one employer USDCx record is consumed; the circuit
    // chains two transfer_private calls internally, so no wallet
    // record-splitting or manual record management is needed.
    //
    // The double-pay guard is atomic — if either (agreement, epoch)
    // pair was already paid, the entire transaction reverts.
    // ---------------------------------------------------------
    async transition execute_payroll_batch_2(
        // Single funding record — split internally
        employer_usdcx: test_usdcx_stablecoin.aleo/Token,

        // Employer (shared across both payments)
        employer_addr: address,
        employer_name_hash: field,

        // Worker 1
        worker1_addr: address,
        worker1_name_hash: field,
        worker1_agreement_id: [u8; 32],
        worker1_epoch_id: u32,
        worker1_gross_amount: u128,
        worker1_net_amount: u128,
        worker1_tax_withheld: u128,
        worker1_fee_amount: u128,
        worker1_receipt_anchor: [u8; 32],
        worker1_receipt_pair_hash: [u8; 32],
        worker1_payroll_inputs_hash: [u8; 32],
        worker1_utc_time_hash: [u8; 32],
        worker1_audit_event_hash: [u8; 32],

        // Worker 2
        worker2_addr: address,
        worker2_name_hash: field,
        worker2_agreement_id: [u8; 32],
        worker2_epoch_id: u32,
        worker2_gross_amount: u128,
        worker2_net_amount: u128,
        worker2_tax_withheld: u128,
        worker2_fee_amount: u128,
        worker2_receipt_anchor: [u8; 32],
        worker2_receipt_pair_hash: [u8; 32],
        worker2_payroll_inputs_hash: [u8; 32],
        worker2_utc_time_hash: [u8; 32],
        worker2_audit_event_hash: [u8; 32]
    ) -> (
        test_usdcx_stablecoin.aleo/Token,              // remaining USDCx returned to employer
        test_usdcx_stablecoin.aleo/Token,              // worker 1 USDCx token
        test_usdcx_stablecoin.aleo/Token,              // worker 2 USDCx token
        paystub_receipts.aleo/WorkerPaystubReceipt,    // worker 1 receipt
        paystub_receipts.aleo/EmployerPaystubReceipt,  // employer copy for worker 1 payment
        paystub_receipts.aleo/WorkerPaystubReceipt,    // worker 2 receipt
        paystub_receipts.aleo/EmployerPaystubReceipt,  // employer copy for worker 2 payment
        Future
    ) {
        // Basic sanity checks
        assert(worker1_epoch_id != 0u32);
        assert(worker1_gross_amount >= worker1_net_amount);
        assert(worker1_gross_amount >= worker1_tax_withheld);
        assert(worker2_epoch_id != 0u32);
        assert(worker2_gross_amount >= worker2_net_amount);
        assert(worker2_gross_amount >= worker2_tax_withheld);

        // Assert both agreements are ACTIVE
        let f_agreement1: Future = employer_agreement_v2.aleo/assert_agreement_active(worker1_agreement_id);
        let f_agreement2: Future = employer_agreement_v2.aleo/assert_agreement_active(worker2_agreement_id);

        // Transfer worker1's net_amount; remainder1 is the change record
        let (worker1_usdcx, remainder1): (
            test_usdcx_stablecoin.aleo/Token,
            test_usdcx_stablecoin.aleo/Token
        ) = test_usdcx_stablecoin.aleo/transfer_private(employer_usdcx, worker1_addr, worker1_net_amount);

        // Transfer worker2's net_amount from the change; remaining_usdcx goes back to employer
        let (worker2_usdcx, remaining_usdcx): (
            test_usdcx_stablecoin.aleo/Token,
            test_usdcx_stablecoin.aleo/Token
        ) = test_usdcx_stablecoin.aleo/transfer_private(remainder1, worker2_addr, worker2_net_amount);

        // Mint paystub receipts for worker 1
        let (w1_worker_receipt, w1_employer_receipt, f_receipt1): (
            paystub_receipts.aleo/WorkerPaystubReceipt,
            paystub_receipts.aleo/EmployerPaystubReceipt,
            Future
        ) = paystub_receipts.aleo/mint_paystub_receipts(
            worker1_addr,
            employer_addr,
            worker1_name_hash,
            employer_name_hash,
            worker1_agreement_id,
            worker1_epoch_id,
            worker1_gross_amount,
            worker1_net_amount,
            worker1_tax_withheld,
            worker1_fee_amount,
            worker1_payroll_inputs_hash,
            worker1_receipt_anchor,
            worker1_receipt_pair_hash,
            worker1_utc_time_hash
        );

        // Mint paystub receipts for worker 2
        let (w2_worker_receipt, w2_employer_receipt, f_receipt2): (
            paystub_receipts.aleo/WorkerPaystubReceipt,
            paystub_receipts.aleo/EmployerPaystubReceipt,
            Future
        ) = paystub_receipts.aleo/mint_paystub_receipts(
            worker2_addr,
            employer_addr,
            worker2_name_hash,
            employer_name_hash,
            worker2_agreement_id,
            worker2_epoch_id,
            worker2_gross_amount,
            worker2_net_amount,
            worker2_tax_withheld,
            worker2_fee_amount,
            worker2_payroll_inputs_hash,
            worker2_receipt_anchor,
            worker2_receipt_pair_hash,
            worker2_utc_time_hash
        );

        // Anchor audit events for both payments
        let f_audit1: Future = payroll_audit_log.aleo/anchor_event(worker1_audit_event_hash);
        let f_audit2: Future = payroll_audit_log.aleo/anchor_event(worker2_audit_event_hash);

        return (
            remaining_usdcx,
            worker1_usdcx,
            worker2_usdcx,
            w1_worker_receipt,
            w1_employer_receipt,
            w2_worker_receipt,
            w2_employer_receipt,
            finalize_payroll_batch_2(
                f_agreement1, f_agreement2,
                f_receipt1, f_receipt2,
                f_audit1, f_audit2,
                worker1_agreement_id, worker1_epoch_id,
                worker2_agreement_id, worker2_epoch_id
            )
        );
    }

    async function finalize_payroll_batch_2(
        f_agreement1: Future,
        f_agreement2: Future,
        f_receipt1: Future,
        f_receipt2: Future,
        f_audit1: Future,
        f_audit2: Future,
        worker1_agreement_id: [u8; 32],
        worker1_epoch_id: u32,
        worker2_agreement_id: [u8; 32],
        worker2_epoch_id: u32
    ) {
        f_agreement1.await();
        f_agreement2.await();
        f_audit1.await();
        f_audit2.await();
        f_receipt1.await();
        f_receipt2.await();

        // Double-pay guard: both checks are atomic — if either fails the tx reverts
        let key1: PaidEpochKey = PaidEpochKey {
            agreement_id: worker1_agreement_id,
            epoch_id: worker1_epoch_id,
        };
        let already_paid1: bool = paid_epoch.get_or_use(key1, false);
        assert(!already_paid1);
        paid_epoch.set(key1, true);

        let key2: PaidEpochKey = PaidEpochKey {
            agreement_id: worker2_agreement_id,
            epoch_id: worker2_epoch_id,
        };
        let already_paid2: bool = paid_epoch.get_or_use(key2, false);
        assert(!already_paid2);
        paid_epoch.set(key2, true);
    }

    @noupgrade async constructor() {}
}