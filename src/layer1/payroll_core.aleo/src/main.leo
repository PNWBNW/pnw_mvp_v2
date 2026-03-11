import test_usdcx_stablecoin.aleo;
import worker_profiles.aleo;
import employer_profiles.aleo;
import employer_agreement.aleo;
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
        employer_usdcx: test_usdcx_stablecoin.aleo/Record,

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
        test_usdcx_stablecoin.aleo/Record,
        paystub_receipts.aleo/WorkerPaystubReceipt,
        paystub_receipts.aleo/EmployerPaystubReceipt,
        Future
    ) {

        // Basic sanity checks (circuit-time)
        assert(epoch_id != 0u32);
        assert(gross_amount >= net_amount);
        assert(gross_amount >= tax_withheld);

        // Assert agreement is ACTIVE (cross-program Future)
        let f_agreement: Future = employer_agreement.aleo/assert_agreement_active(agreement_id);

        // Execute USDCx private transfer (employer -> worker)
        let (worker_usdcx, remaining_usdcx): (
            test_usdcx_stablecoin.aleo/Record,
            test_usdcx_stablecoin.aleo/Record
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
}
