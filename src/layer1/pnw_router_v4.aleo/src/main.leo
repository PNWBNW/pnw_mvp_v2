import employer_agreement_v4.aleo;
import employer_profiles_v2.aleo;
import pnw_worker_profiles_v2.aleo;
import pnw_name_registry_v2.aleo;

// ---------------------------------------------------------
// PNW Layer 1 Router v4 — Leo v4.0 syntax
// ---------------------------------------------------------
// Stable entry surface for the portal. Pass-through only.
// No state, no hashes, no aggregation.

program pnw_router_v4.aleo {

    // ---------------------------------------------------------
    // Agreement workflows
    // ---------------------------------------------------------

    fn create_job_offer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field,
        worker_address: address,
        industry_code: u8,
        pay_frequency_code: u8,
        start_epoch: u32,
        end_epoch: u32,
        review_epoch: u32,
        agreement_rev: u16,
        schema_v: u16,
        policy_v: u16,
        terms_doc_hash: [u8; 32],
        terms_root: [u8; 32],
        offer_time_hash: [u8; 32]
    ) -> (employer_agreement_v4.aleo::PendingAgreement, Final) {
        let (rec, f): (employer_agreement_v4.aleo::PendingAgreement, Final) =
            employer_agreement_v4.aleo::create_job_offer(
                agreement_id, parties_key, employer_name_hash, worker_name_hash,
                worker_address, industry_code, pay_frequency_code,
                start_epoch, end_epoch, review_epoch,
                agreement_rev, schema_v, policy_v,
                terms_doc_hash, terms_root, offer_time_hash
            );
        return (rec, final { f.run(); });
    }

    fn accept_job_offer(
        pending: employer_agreement_v4.aleo::PendingAgreement,
        accept_time_hash: [u8; 32]
    ) -> (employer_agreement_v4.aleo::FinalAgreement, employer_agreement_v4.aleo::FinalAgreement, employer_agreement_v4.aleo::FinalAgreement, Final) {
        let (emp, wrk, dao, f): (employer_agreement_v4.aleo::FinalAgreement, employer_agreement_v4.aleo::FinalAgreement, employer_agreement_v4.aleo::FinalAgreement, Final) =
            employer_agreement_v4.aleo::accept_job_offer(pending, accept_time_hash);
        return (emp, wrk, dao, final { f.run(); });
    }

    // Pause
    fn pause_agreement_employer(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::pause_agreement_employer(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    fn pause_agreement_worker(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::pause_agreement_worker(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    fn pause_agreement_dao(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::pause_agreement_dao(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    // Terminate
    fn terminate_agreement_employer(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::terminate_agreement_employer(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    fn terminate_agreement_worker(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::terminate_agreement_worker(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    fn terminate_agreement_dao(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::terminate_agreement_dao(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    // Resume approvals
    fn approve_resume_employer(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::approve_resume_employer(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    fn approve_resume_worker(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::approve_resume_worker(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    fn approve_resume_dao(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::approve_resume_dao(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    fn resume_agreement(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field, worker_name_hash: field) -> Final {
        let f: Final = employer_agreement_v4.aleo::resume_agreement(agreement_id, parties_key, employer_name_hash, worker_name_hash);
        return final { f.run(); };
    }

    // Cross-program assertions
    fn assert_agreement_active(agreement_id: [u8; 32]) -> Final {
        let f: Final = employer_agreement_v4.aleo::assert_agreement_active(agreement_id);
        return final { f.run(); };
    }

    fn assert_agreement_exists(agreement_id: [u8; 32]) -> Final {
        let f: Final = employer_agreement_v4.aleo::assert_agreement_anchored(agreement_id);
        return final { f.run(); };
    }

    // Profile assertions
    fn assert_worker_profile_anchored(profile_anchor: [u8; 32]) -> Final {
        let f: Final = pnw_worker_profiles_v2.aleo::assert_profile_anchored(profile_anchor);
        return final { f.run(); };
    }

    fn assert_employer_profile_anchor(profile_anchor: [u8; 32]) -> Final {
        let f: Final = employer_profiles_v2.aleo::assert_profile_anchored(profile_anchor);
        return final { f.run(); };
    }

    // Name assertion
    fn assert_name_owner(name_hash: field, owner: address) -> Final {
        let f: Final = pnw_name_registry_v2.aleo::assert_is_owner(name_hash, owner);
        return final { f.run(); };
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx")
    constructor() {}
}
