import pnw_name_registry.aleo;
import employer_license_registry.aleo;

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

    // ------------------------------------
    // Naming Registry Routes (Layer 1)
    // ------------------------------------

    async transition route_register_worker_name(name_hash: field, fee_amount: u128) -> Future {
        let f: Future = pnw_name_registry.aleo/register_worker_name(name_hash, fee_amount);
        return f;
    }

    transition route_release_worker_name() {
        pnw_name_registry.aleo/release_worker_name();
    }

    async transition route_register_employer_name(name_hash: field, suffix_code: u8, fee_amount: u128) -> Future {
        let f: Future = pnw_name_registry.aleo/register_employer_name(name_hash, suffix_code, fee_amount);
        return f;
    }

    transition route_request_employer_sellback(name_hash: field) {
        pnw_name_registry.aleo/request_employer_sellback(name_hash);
    }

    async transition route_fulfill_employer_sellback(name_hash: field) -> Future {
        let f: Future = pnw_name_registry.aleo/fulfill_employer_sellback(name_hash);
        return f;
    }

    // ------------------------------------------
    // Employer License Registry Routes (Layer 1)
    // ------------------------------------------

    transition route_set_employer_verified(wallet: address, license_hash: [u8; 32], verified: bool) {
        employer_license_registry.aleo/set_verified(wallet, license_hash, verified);
    }

    // ---------------------------------
    // Route: create employment agreement
    // ---------------------------------

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

    async transition route_record_payroll_anchor(event_hash: [u8; 32]) -> Future {
        let f: Future = payroll_audit_log.aleo/record_event_hash(event_hash);
        return f;
    }
}
