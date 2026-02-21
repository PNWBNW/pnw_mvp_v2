program payroll_core.aleo {

    // ---------------------------------------------------------
    // Imports
    // ---------------------------------------------------------
    // Testnet USDCx stablecoin
    import test_usdcx_stablecoin.aleo;

    // Internal PNW programs
    import worker_profiles.aleo;
    import employer_profiles.aleo;
    import employer_agreement.aleo;
    import paystub_receipts.aleo;
    import payroll_audit_log.aleo;

    // ---------------------------------------------------------
    // Prevent double-pay per agreement + epoch
    // ---------------------------------------------------------
    mapping paid_epoch:
        key as ([u8; 32], u32).public,
        value as bool.public;

    // ---------------------------------------------------------
    // Execute payroll for a single worker
    // ---------------------------------------------------------
    transition execute_payroll(
        // Funding
        employer_usdcx: test_usdcx_stablecoin.Record,

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
    ) -> (test_usdcx_stablecoin.Record, paystub_receipts.WorkerPaystubReceipt, paystub_receipts.EmployerPaystubReceipt) {

        // -----------------------------------------------------
        // Basic sanity checks
        // -----------------------------------------------------
        assert(epoch_id != 0u32);
        assert(gross_amount >= net_amount);
        assert(gross_amount >= tax_withheld);

        // -----------------------------------------------------
        // Prevent double payment for same agreement + epoch
        // -----------------------------------------------------
        let already_paid: bool = Mapping::get_or_use(paid_epoch, (agreement_id, epoch_id), false);
        assert(already_paid == false);

        // -----------------------------------------------------
        // Validate worker and employer profiles exist
        // -----------------------------------------------------
        worker_profiles.assert_worker_exists(worker_name_hash);
        employer_profiles.assert_employer_exists(employer_name_hash);

        // -----------------------------------------------------
        // Validate agreement is active
        // -----------------------------------------------------
        employer_agreement.assert_agreement_active(
            agreement_id,
            employer_name_hash,
            worker_name_hash
        );

        // -----------------------------------------------------
        // Execute USDCx transfer (employer -> worker)
        // -----------------------------------------------------
        let (worker_usdcx, remaining_usdcx) =
            test_usdcx_stablecoin.transfer_private(
                employer_usdcx,
                worker_addr,
                net_amount
            );

        // -----------------------------------------------------
        // Mark epoch as paid
        // -----------------------------------------------------
        Mapping::set(paid_epoch, (agreement_id, epoch_id), true);

        // -----------------------------------------------------
        // Mint paystub receipts (worker + employer)
        // -----------------------------------------------------
        let (worker_receipt, employer_receipt) =
            paystub_receipts.mint_paystub_receipts(
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

        // -----------------------------------------------------
        // Anchor payroll audit event
        // -----------------------------------------------------
        payroll_audit_log.anchor_event(audit_event_hash);

        // -----------------------------------------------------
        // Return outputs
        // -----------------------------------------------------
        return (worker_usdcx, worker_receipt, employer_receipt);
    }
}
