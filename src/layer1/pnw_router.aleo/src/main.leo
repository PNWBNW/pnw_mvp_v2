import employer_agreement.aleo;
import employer_profiles.aleo;
import worker_profiles.aleo;
import pnw_name_registry.aleo;

program pnw_router.aleo {

    // ---------------------------------------------------------
    // PNW Layer 1 Router - MVP v2
    // ---------------------------------------------------------
    // Purpose:
    // - Provide a single, stable entry surface for the portal.
    // - Orchestrate calls into Layer 1 programs.
    // - Enforce prerequisite ordering ONLY.
    //
    // The router:
    // - does NOT store state
    // - does NOT compute hashes
    // - does NOT aggregate data

    // ---------------------------------------------------------
    // Agreement workflows
    // ---------------------------------------------------------

    async transition create_job_offer(
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
    ) -> (employer_agreement.aleo/PendingAgreement, Future) {
        return employer_agreement.aleo/create_job_offer(
            agreement_id,
            parties_key,
            employer_name_hash,
            worker_name_hash,
            worker_address,
            industry_code,
            pay_frequency_code,
            start_epoch,
            end_epoch,
            review_epoch,
            agreement_rev,
            schema_v,
            policy_v,
            terms_doc_hash,
            terms_root,
            offer_time_hash
        );
    }

    async transition accept_job_offer(
        pending: employer_agreement.aleo/PendingAgreement,
        accept_time_hash: [u8; 32]
    ) -> (employer_agreement.aleo/FinalAgreement, Future) {
        return employer_agreement.aleo/accept_job_offer(pending, accept_time_hash);
    }

    // ---------------------------------------------------------
    // Agreement status controls
    // ---------------------------------------------------------

    async transition pause_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/pause_agreement_employer(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    async transition pause_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/pause_agreement_worker(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    async transition pause_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/pause_agreement_dao(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    async transition terminate_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/terminate_agreement_employer(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    async transition terminate_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/terminate_agreement_worker(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    async transition terminate_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/terminate_agreement_dao(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    // ---------------------------------------------------------
    // Resume approvals (3-of-3)
    // ---------------------------------------------------------

    async transition approve_resume_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/approve_resume_employer(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    async transition approve_resume_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/approve_resume_worker(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    async transition approve_resume_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/approve_resume_dao(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    async transition resume_agreement(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        return employer_agreement.aleo/resume_agreement(
            agreement_id, parties_key, employer_name_hash, worker_name_hash
        );
    }

    // ---------------------------------------------------------
    // Read-only assertions for portal guards
    // ---------------------------------------------------------

    async transition assert_agreement_active(agreement_id: [u8; 32]) -> Future {
        return employer_agreement.aleo/assert_agreement_active(agreement_id);
    }

    async transition assert_agreement_exists(agreement_id: [u8; 32]) -> Future {
        return employer_agreement.aleo/assert_agreement_anchored(agreement_id);
    }

    async transition assert_worker_profile_anchored(profile_anchor: [u8; 32]) -> Future {
        return worker_profiles.aleo/assert_profile_anchored(profile_anchor);
    }

    async transition assert_employer_profile_anchor(profile_anchor: [u8; 32]) -> Future {
        return employer_profiles.aleo/assert_profile_anchored(profile_anchor);
    }

    async transition assert_name_owner(name_hash: field, owner: address) -> Future {
        return pnw_name_registry.aleo/assert_is_owner(name_hash, owner);
    }
}
