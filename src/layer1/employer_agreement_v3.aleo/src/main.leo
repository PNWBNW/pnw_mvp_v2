import pnw_name_registry_v2.aleo;
import employer_license_registry.aleo;

program employer_agreement_v3.aleo {

    // ---------------------------------------------------------
    // Employer Agreement (Layer 1) - PNW MVP v2 (Leo v3.x)
    // ---------------------------------------------------------
    //
    // Model:
    // 1) Employer creates an offer as a PendingAgreement record owned by worker_address.
    // 2) Worker accepts the offer, consuming PendingAgreement.
    // 3) FinalAgreement record is created and custodied by DAO_ADDRESS.
    //
    // Public minimal mappings:
    // - agreement existence + first-seen height (anchor)
    // - agreement status (PENDING/ACTIVE/PAUSED/TERMINATED/SUPERSEDED)
    // - parties_commitment (BHP1024 hash of parties_key + employer_name_hash + worker_name_hash)
    // - resume approvals (3-of-3: Employer + Worker + DAO)

    // -----------------------------
    // Constants
    // -----------------------------

    const DAO_ADDRESS: address =
        aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    const STATUS_PENDING: u8 = 0u8;
    const STATUS_ACTIVE: u8 = 1u8;
    const STATUS_PAUSED: u8 = 2u8;
    const STATUS_TERMINATED: u8 = 3u8;
    const STATUS_SUPERSEDED: u8 = 4u8;

    inline assert_status_valid(s: u8) {
        assert(
            s == STATUS_PENDING ||
            s == STATUS_ACTIVE ||
            s == STATUS_PAUSED ||
            s == STATUS_TERMINATED ||
            s == STATUS_SUPERSEDED
        );
    }

    // Resume approvals bitmask: bit0=employer, bit1=worker, bit2=dao
    const RESUME_EMPLOYER_BIT: u8 = 1u8;
    const RESUME_WORKER_BIT: u8 = 2u8;
    const RESUME_DAO_BIT: u8 = 4u8;
    const RESUME_ALL_BITS: u8 = 7u8;

    // Pay frequency enum
    const PAY_DAILY: u8 = 1u8;
    const PAY_WEEKLY: u8 = 2u8;
    const PAY_BIWEEKLY: u8 = 3u8;
    const PAY_MONTHLY: u8 = 4u8;
    const PAY_QUARTERLY: u8 = 5u8;

    function assert_pay_frequency(code: u8) {
        assert(
            code == PAY_DAILY ||
            code == PAY_WEEKLY ||
            code == PAY_BIWEEKLY ||
            code == PAY_MONTHLY ||
            code == PAY_QUARTERLY
        );
    }

    // -----------------------------
    // Structs
    // -----------------------------

    struct PartiesCommitmentInput {
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field,
    }

    // -----------------------------
    // Records
    // -----------------------------

    record PendingAgreement {
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
        terms_root: [u8; 32],
        // sentinel 0u32; actual height in agreement_anchor_height mapping
        offer_height: u32,
        offer_time_hash: [u8; 32],
        employer_address: address,
        worker_address: address,
        owner: address,
    }

    record FinalAgreement {
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
        terms_root: [u8; 32],
        // sentinels; actual heights in agreement_anchor_height mapping
        offer_height: u32,
        offer_time_hash: [u8; 32],
        accept_height: u32,
        accept_time_hash: [u8; 32],
        employer_address: address,
        worker_address: address,
        owner: address,
    }

    // -----------------------------
    // Public mappings (minimal state)
    // -----------------------------

    mapping agreement_anchor_height: [u8; 32] => u32;
    mapping agreement_parties_commitment: [u8; 32] => field;
    mapping agreement_status: [u8; 32] => u8;
    mapping resume_approvals: [u8; 32] => u8;

    // -----------------------------
    // Circuit-time helpers
    // -----------------------------

    function compute_parties_commitment(
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> field {
        return BHP1024::hash_to_field(PartiesCommitmentInput {
            parties_key: parties_key,
            employer_name_hash: employer_name_hash,
            worker_name_hash: worker_name_hash,
        });
    }

    // -----------------------------
    // 1) Create job offer (employer)
    // -----------------------------
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
    ) -> (PendingAgreement, Future) {

        // Circuit-time guards
        assert_pay_frequency(pay_frequency_code);
        assert(agreement_rev != 0u16);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        if end_epoch != 0u32 {
            assert(end_epoch > start_epoch);
        }
        assert(review_epoch >= start_epoch);

        // Employer must be verified AND own the employer name hash
        let f1: Future = employer_license_registry.aleo/assert_verified(self.caller);
        let f2: Future = pnw_name_registry_v2.aleo/assert_is_owner(employer_name_hash, self.caller);

        // Compute parties commitment in circuit
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);

        let offer: PendingAgreement = PendingAgreement {
            agreement_id: agreement_id,
            parties_key: parties_key,
            employer_name_hash: employer_name_hash,
            worker_name_hash: worker_name_hash,
            industry_code: industry_code,
            pay_frequency_code: pay_frequency_code,
            start_epoch: start_epoch,
            end_epoch: end_epoch,
            review_epoch: review_epoch,
            agreement_rev: agreement_rev,
            schema_v: schema_v,
            policy_v: policy_v,
            terms_doc_hash: terms_doc_hash,
            terms_root: terms_root,
            offer_height: 0u32,
            offer_time_hash: offer_time_hash,
            employer_address: self.caller,
            worker_address: worker_address,
            owner: worker_address,
        };

        return (offer, finalize_create_job_offer(f1, f2, agreement_id, commitment));
    }

    async function finalize_create_job_offer(
        f1: Future,
        f2: Future,
        agreement_id: [u8; 32],
        commitment: field
    ) {
        f1.await();
        f2.await();

        // Ensure fresh agreement ID
        let existing: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(existing == 0u32);

        agreement_anchor_height.set(agreement_id, block.height);
        agreement_parties_commitment.set(agreement_id, commitment);
        agreement_status.set(agreement_id, STATUS_PENDING);
        resume_approvals.set(agreement_id, 0u8);
    }

    // -----------------------------
    // 2) Accept job offer (worker)
    // -----------------------------
    async transition accept_job_offer(
        offer: PendingAgreement,
        accept_time_hash: [u8; 32]
    ) -> (FinalAgreement, Future) {

        assert(offer.worker_address == self.caller);

        let agreement_id: [u8; 32] = offer.agreement_id;

        // Worker must own the worker name hash
        let f1: Future = pnw_name_registry_v2.aleo/assert_is_owner(offer.worker_name_hash, self.caller);

        // Compute parties commitment in circuit for finalize verification
        let commitment: field = compute_parties_commitment(
            offer.parties_key,
            offer.employer_name_hash,
            offer.worker_name_hash
        );

        let final_agreement: FinalAgreement = FinalAgreement {
            agreement_id: agreement_id,
            parties_key: offer.parties_key,
            employer_name_hash: offer.employer_name_hash,
            worker_name_hash: offer.worker_name_hash,
            industry_code: offer.industry_code,
            pay_frequency_code: offer.pay_frequency_code,
            start_epoch: offer.start_epoch,
            end_epoch: offer.end_epoch,
            review_epoch: offer.review_epoch,
            agreement_rev: offer.agreement_rev,
            schema_v: offer.schema_v,
            policy_v: offer.policy_v,
            terms_doc_hash: offer.terms_doc_hash,
            terms_root: offer.terms_root,
            offer_height: offer.offer_height,
            offer_time_hash: offer.offer_time_hash,
            accept_height: 0u32,
            accept_time_hash: accept_time_hash,
            employer_address: offer.employer_address,
            worker_address: offer.worker_address,
            owner: DAO_ADDRESS,
        };

        return (final_agreement, finalize_accept_job_offer(f1, agreement_id, commitment));
    }

    async function finalize_accept_job_offer(
        f1: Future,
        agreement_id: [u8; 32],
        commitment: field
    ) {
        f1.await();

        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert(s == STATUS_PENDING);

        // Verify commitment matches stored value
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        agreement_status.set(agreement_id, STATUS_ACTIVE);
        resume_approvals.set(agreement_id, 0u8);
    }

    // -----------------------------
    // 3) Pause (role-specific, identity-verified)
    // -----------------------------
    async transition pause_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        let f1: Future = employer_license_registry.aleo/assert_verified(self.caller);
        let f2: Future = pnw_name_registry_v2.aleo/assert_is_owner(employer_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_pause_agreement(f1, f2, agreement_id, commitment);
    }

    async transition pause_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        let f1: Future = pnw_name_registry_v2.aleo/assert_is_owner(worker_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_pause_agreement_single(f1, agreement_id, commitment);
    }

    async transition pause_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        assert(self.caller == DAO_ADDRESS);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_pause_agreement_dao(agreement_id, commitment);
    }

    async function finalize_pause_agreement(
        f1: Future,
        f2: Future,
        agreement_id: [u8; 32],
        commitment: field
    ) {
        f1.await();
        f2.await();

        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        agreement_status.set(agreement_id, STATUS_PAUSED);
        resume_approvals.set(agreement_id, 0u8);
    }

    async function finalize_pause_agreement_single(
        f1: Future,
        agreement_id: [u8; 32],
        commitment: field
    ) {
        f1.await();

        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        agreement_status.set(agreement_id, STATUS_PAUSED);
        resume_approvals.set(agreement_id, 0u8);
    }

    async function finalize_pause_agreement_dao(agreement_id: [u8; 32], commitment: field) {
        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        agreement_status.set(agreement_id, STATUS_PAUSED);
        resume_approvals.set(agreement_id, 0u8);
    }

    // -----------------------------
    // 4) Terminate (role-specific, identity-verified)
    // -----------------------------
    async transition terminate_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        let f1: Future = employer_license_registry.aleo/assert_verified(self.caller);
        let f2: Future = pnw_name_registry_v2.aleo/assert_is_owner(employer_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_terminate_agreement(f1, f2, agreement_id, commitment);
    }

    async transition terminate_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        let f1: Future = pnw_name_registry_v2.aleo/assert_is_owner(worker_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_terminate_agmt_single(f1, agreement_id, commitment);
    }

    async transition terminate_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        assert(self.caller == DAO_ADDRESS);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_terminate_agmt_dao(agreement_id, commitment);
    }

    async function finalize_terminate_agreement(
        f1: Future,
        f2: Future,
        agreement_id: [u8; 32],
        commitment: field
    ) {
        f1.await();
        f2.await();

        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s != STATUS_TERMINATED);

        agreement_status.set(agreement_id, STATUS_TERMINATED);
        resume_approvals.set(agreement_id, 0u8);
    }

    async function finalize_terminate_agmt_single(
        f1: Future,
        agreement_id: [u8; 32],
        commitment: field
    ) {
        f1.await();

        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s != STATUS_TERMINATED);

        agreement_status.set(agreement_id, STATUS_TERMINATED);
        resume_approvals.set(agreement_id, 0u8);
    }

    async function finalize_terminate_agmt_dao(agreement_id: [u8; 32], commitment: field) {
        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s != STATUS_TERMINATED);

        agreement_status.set(agreement_id, STATUS_TERMINATED);
        resume_approvals.set(agreement_id, 0u8);
    }

    // -----------------------------
    // 5) Resume approvals (3-of-3, identity-verified)
    // -----------------------------
    async transition approve_resume_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        let f1: Future = employer_license_registry.aleo/assert_verified(self.caller);
        let f2: Future = pnw_name_registry_v2.aleo/assert_is_owner(employer_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_approve_resume(f1, f2, agreement_id, commitment, RESUME_EMPLOYER_BIT);
    }

    async transition approve_resume_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        let f1: Future = pnw_name_registry_v2.aleo/assert_is_owner(worker_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_approve_resume_single(f1, agreement_id, commitment, RESUME_WORKER_BIT);
    }

    async transition approve_resume_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        assert(self.caller == DAO_ADDRESS);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_approve_resume_dao(agreement_id, commitment);
    }

    async function finalize_approve_resume(
        f1: Future,
        f2: Future,
        agreement_id: [u8; 32],
        commitment: field,
        bit: u8
    ) {
        f1.await();
        f2.await();

        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PAUSED);

        let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
        resume_approvals.set(agreement_id, m | bit);
    }

    async function finalize_approve_resume_single(
        f1: Future,
        agreement_id: [u8; 32],
        commitment: field,
        bit: u8
    ) {
        f1.await();

        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PAUSED);

        let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
        resume_approvals.set(agreement_id, m | bit);
    }

    async function finalize_approve_resume_dao(agreement_id: [u8; 32], commitment: field) {
        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PAUSED);

        let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
        resume_approvals.set(agreement_id, m | RESUME_DAO_BIT);
    }

    // -----------------------------
    // 6) Finalize resume (requires all 3 approvals)
    // -----------------------------
    async transition resume_agreement(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_resume_agreement(agreement_id, commitment);
    }

    async function finalize_resume_agreement(agreement_id: [u8; 32], commitment: field) {
        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PAUSED);

        let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
        assert(m == RESUME_ALL_BITS);

        agreement_status.set(agreement_id, STATUS_ACTIVE);
        resume_approvals.set(agreement_id, 0u8);
    }

    // -----------------------------
    // 7) Supersede
    // -----------------------------
    async transition supersede_agreement(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Future {
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return finalize_supersede_agreement(agreement_id, commitment);
    }

    async function finalize_supersede_agreement(agreement_id: [u8; 32], commitment: field) {
        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
        let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
        assert(stored != 0field);
        assert(stored == commitment);

        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert_status_valid(s);
        assert(s != STATUS_SUPERSEDED);

        agreement_status.set(agreement_id, STATUS_SUPERSEDED);
        resume_approvals.set(agreement_id, 0u8);
    }

    // -----------------------------
    // 8) Cross-program assertions
    // Called by payroll_nfts, payroll_core, pnw_router, etc.
    // -----------------------------

    // Assert agreement is anchored (exists)
    async transition assert_agreement_anchored(agreement_id: [u8; 32]) -> Future {
        return finalize_assert_agmt_anchored(agreement_id);
    }

    async function finalize_assert_agmt_anchored(agreement_id: [u8; 32]) {
        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
    }

    // Assert agreement is ACTIVE — called as cross-program Future by payroll_nfts.
    async transition assert_agreement_active(agreement_id: [u8; 32]) -> Future {
        return finalize_assert_agmt_active(agreement_id);
    }

    async function finalize_assert_agmt_active(agreement_id: [u8; 32]) {
        let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
        assert(s == STATUS_ACTIVE);
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx")
    async constructor() {}
}