import employer_agreement.aleo;
import payroll_core.aleo;
import payroll_audit_log.aleo;

program pnw_router.aleo {

    // -----------------------------
    // Router input structs (Layer 1)
    // -----------------------------

    struct AgreementRoute {
        worker_id: field,
        employer_id: field,
        agreement_id: [u8; 32],
        scope_hash: [u8; 32],
        start_epoch: u32,
        end_epoch: u32
    }

    struct PayrollRoute {
        employer_id: field,
        worker: address,
        amount: u128,
        epoch_id: u32
    }

    // ---------------------------------
    // Route: create employment agreement
    // ---------------------------------
    //
    // Notes:
    // - Router only coordinates the on-chain workflow.
    // - Agreement details remain commitment-based.
    //
    async transition route_create_employment_agreement(route: AgreementRoute) -> Future {
        let f: Future = employer_agreement.aleo/create_employment_agreement(
            route.worker_id,
            route.employer_id,
            route.agreement_id,
            route.scope_hash,
            route.start_epoch,
            route.end_epoch
        );
        return f;
    }

    // -------------------------
    // Route: execute payroll
    // -------------------------
    //
    // Notes:
    // - Router does NOT call USDCx directly.
    // - payroll_core.aleo is responsible for calling:
    //   test_usdcx_stablecoin.aleo (testnet) or usdcx_stablecoin.aleo (mainnet).
    //
    async transition route_run_payroll(route: PayrollRoute) -> Future {
        let f: Future = payroll_core.aleo/execute_payroll(
            route.employer_id,
            route.worker,
            route.amount,
            route.epoch_id
        );
        return f;
    }

    // ---------------------------------------
    // Route: record hash-only audit anchor
    // ---------------------------------------
    //
    // Notes:
    // - event_hash is a commitment produced by payroll_core and/or the portal.
    // - audit log stores only hash -> height/bool (no identities/amounts).
    //
    async transition route_record_payroll_anchor(event_hash: [u8; 32]) -> Future {
        let f: Future = payroll_audit_log.aleo/record_event_hash(event_hash);
        return f;
    }
}
