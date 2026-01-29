import employer_agreement.aleo;
import employer_profiles.aleo;
import worker_profiles.aleo;
import pnw_name_registry.aleo;

program pnw_router.aleo {

    // ---------------------------------------------------------
    // PNW Layer 1 Router - MVP v2
    // ---------------------------------------------------------
    // Purpose:
    // - Provide a single, stable entry surface for the portal
    // - Orchestrate calls into Layer 1 programs
    // - Enforce prerequisite ordering ONLY
    //
    // The router:
    // - does NOT store state
    // - does NOT compute hashes
    // - does NOT aggregate data
    //
    // All hashes, documents, and summaries are portal-supplied.
    //

    // ---------------------------------------------------------
    // Agreement workflows
    // ---------------------------------------------------------

    // Employer creates a job offer
    transition create_job_offer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],

        employer_name_hash: field,
        worker_name_hash: field,

        industry_code: u8,
        pay_frequency_code: u8,

        start_epoch: u32,
        end_epoch: u32,
        review_epoch: u32,

        agreement_rev: u16,
        schema_v: u16,
        policy_v: u16,

        terms_doc_hash: [u8; 32],
        terms_root: [u8; 32]
    ) {
        employer_agreement.aleo/create_job_offer(
            agreement_id,
            parties_key,
            employer_name_hash,
            worker_name_hash,
            industry_code,
            pay_frequency_code,
            start_epoch,
            end_epoch,
            review_epoch,
            agreement_rev,
            schema_v,
            policy_v,
            terms_doc_hash,
            terms_root
        );
    }

    // Worker accepts a job offer
    transition accept_job_offer(
        pending: employer_agreement.aleo/PendingAgreement
    ) {
        employer_agreement.aleo/accept_job_offer(pending);
    }

    // ---------------------------------------------------------
    // Agreement status controls
    // ---------------------------------------------------------

    transition pause_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field
    ) {
        employer_agreement.aleo/pause_agreement_employer(
            agreement_id,
            parties_key,
            employer_name_hash
        );
    }

    transition pause_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        worker_name_hash: field
    ) {
        employer_agreement.aleo/pause_agreement_worker(
            agreement_id,
            parties_key,
            worker_name_hash
        );
    }

    transition pause_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32]
    ) {
        employer_agreement.aleo/pause_agreement_dao(
            agreement_id,
            parties_key
        );
    }

    transition terminate_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field
    ) {
        employer_agreement.aleo/terminate_agreement_employer(
            agreement_id,
            parties_key,
            employer_name_hash
        );
    }

    transition terminate_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        worker_name_hash: field
    ) {
        employer_agreement.aleo/terminate_agreement_worker(
            agreement_id,
            parties_key,
            worker_name_hash
        );
    }

    transition terminate_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32]
    ) {
        employer_agreement.aleo/terminate_agreement_dao(
            agreement_id,
            parties_key
        );
    }

    // ---------------------------------------------------------
    // Resume approvals (3-of-3)
    // ---------------------------------------------------------

    transition approve_resume_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field
    ) {
        employer_agreement.aleo/approve_resume_employer(
            agreement_id,
            parties_key,
            employer_name_hash
        );
    }

    transition approve_resume_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        worker_name_hash: field
    ) {
        employer_agreement.aleo/approve_resume_worker(
            agreement_id,
            parties_key,
            worker_name_hash
        );
    }

    transition approve_resume_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32]
    ) {
        employer_agreement.aleo/approve_resume_dao(
            agreement_id,
            parties_key
        );
    }

    transition resume_agreement(
        agreement_id: [u8; 32],
        parties_key: [u8; 32]
    ) {
        employer_agreement.aleo/resume_agreement(
            agreement_id,
            parties_key
        );
    }

    // ---------------------------------------------------------
    // Read-only assertions for portal guards
    // ---------------------------------------------------------

    transition assert_agreement_active(
        agreement_id: [u8; 32]
    ) {
        employer_agreement.aleo/assert_agreement_active(agreement_id);
    }

    transition assert_agreement_exists(
        agreement_id: [u8; 32]
    ) {
        employer_agreement.aleo/assert_agreement_anchored(agreement_id);
    }
}        let f: Future = payroll_audit_log.aleo/record_event_hash(event_hash);
        return f;
    }
}
