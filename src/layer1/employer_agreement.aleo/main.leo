import pnw_name_registry.aleo;
import employer_license_registry.aleo;

program employer_agreement.aleo {

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
    // - parties_key (capability commitment)
    // - resume approvals (3-of-3: Employer + Worker + DAO)
    //
    // Privacy:
    // - No plaintext identities or terms are stored publicly.
    // - Only anchors/flags/heights are public.
    //
    // Timestamp note:
    // - On-chain wall-clock does not exist; we store block.height on-chain.
    // - The portal supplies UTC Zulu timestamp hash commitments (private in records).

    // -----------------------------
    // Constants
    // -----------------------------

    // DAO custody/controller address (FinalAgreement owner).
    const DAO_ADDRESS: address =
        aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    // Agreement status enum
    const STATUS_PENDING: u8 = 0u8;
    const STATUS_ACTIVE: u8 = 1u8;
    const STATUS_PAUSED: u8 = 2u8;
    const STATUS_TERMINATED: u8 = 3u8;
    const STATUS_SUPERSEDED: u8 = 4u8;

    function assert_status_valid(s: u8) {
        assert(
            s == STATUS_PENDING ||
            s == STATUS_ACTIVE ||
            s == STATUS_PAUSED ||
            s == STATUS_TERMINATED ||
            s == STATUS_SUPERSEDED
        );
    }

    // Resume approvals (bitmask)
    // bit0 = employer, bit1 = worker, bit2 = dao
    const RESUME_EMPLOYER_BIT: u8 = 1u8; // 0b001
    const RESUME_WORKER_BIT: u8 = 2u8;   // 0b010
    const RESUME_DAO_BIT: u8 = 4u8;      // 0b100
    const RESUME_ALL_BITS: u8 = 7u8;     // 0b111

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
    // Records
    // -----------------------------

    // Job offer record (owned by worker_address; consumed by worker on acceptance).
    record PendingAgreement {
        agreement_id: [u8; 32].private,
        parties_key: [u8; 32].private,

        employer_name_hash: field.private,
        worker_name_hash: field.private,

        industry_code: u8.private,
        pay_frequency_code: u8.private,

        start_epoch: u32.private,
        end_epoch: u32.private,
        review_epoch: u32.private,

        agreement_rev: u16.private,
        schema_v: u16.private,
        policy_v: u16.private,

        terms_doc_hash: [u8; 32].private,
        terms_root: [u8; 32].private,

        offer_height: u32.private,
        offer_time_hash: [u8; 32].private,

        employer_address: address.private,
        worker_address: address.private,

        owner: address.private,
        _nonce: group.public
    }

    // Final agreement (custodied by DAO_ADDRESS).
    record FinalAgreement {
        agreement_id: [u8; 32].private,
        parties_key: [u8; 32].private,

        employer_name_hash: field.private,
        worker_name_hash: field.private,

        industry_code: u8.private,
        pay_frequency_code: u8.private,

        start_epoch: u32.private,
        end_epoch: u32.private,
        review_epoch: u32.private,

        agreement_rev: u16.private,
        schema_v: u16.private,
        policy_v: u16.private,

        terms_doc_hash: [u8; 32].private,
        terms_root: [u8; 32].private,

        offer_height: u32.private,
        offer_time_hash: [u8; 32].private,

        accept_height: u32.private,
        accept_time_hash: [u8; 32].private,

        employer_address: address.private,
        worker_address: address.private,

        owner: address.private,
        _nonce: group.public
    }

    // -----------------------------
    // Public mappings (minimal state)
    // -----------------------------

    mapping agreement_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    mapping agreement_parties_key:
        key as [u8; 32].public,
        value as [u8; 32].public;

    mapping agreement_status:
        key as [u8; 32].public,
        value as u8.public;

    mapping resume_approvals:
        key as [u8; 32].public,
        value as u8.public;

    // -----------------------------
    // Internal helpers
    // -----------------------------

    function anchor_once(agreement_id: [u8; 32]) {
        let h: u32 = block.height;
        let existing: u32 = Mapping::get_or_use(agreement_anchor_height, agreement_id, 0u32);
        if existing == 0u32 {
            Mapping::set(agreement_anchor_height, agreement_id, h);
        }
    }

    function assert_agreement_exists(agreement_id: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(agreement_anchor_height, agreement_id, 0u32);
        assert(h != 0u32);
    }

    function assert_parties_key_matches(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        let stored: [u8; 32] = Mapping::get_or_use(agreement_parties_key, agreement_id, [0u8; 32]);
        assert(stored == parties_key);
    }

    function assert_is_employer(employer_name_hash: field) {
        // Employer must be verified + own employer name hash.
        employer_license_registry.aleo/assert_verified(caller);
        pnw_name_registry.aleo/assert_is_owner(employer_name_hash, caller);
    }

    function assert_is_worker(worker_name_hash: field) {
        // Worker must own worker name hash.
        pnw_name_registry.aleo/assert_is_owner(worker_name_hash, caller);
    }

    function assert_is_dao() {
        // Placeholder for vote-gated DAO action.
        assert(caller == DAO_ADDRESS);
    }

    // -----------------------------
    // 1) Create job offer (employer)
    // -----------------------------
    transition create_job_offer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],

        employer_name_hash: field,
        worker_name_hash: field,

        // Worker wallet address must be provided by the portal (job applications imply an account).
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
    ) -> PendingAgreement {

        assert_is_employer(employer_name_hash);

        // Pay + version guards
        assert_pay_frequency(pay_frequency_code);
        assert(agreement_rev != 0u16);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);

        // Epoch rules:
        // end_epoch == 0 => indefinite
        if end_epoch != 0u32 {
            assert(end_epoch > start_epoch);
        }
        assert(review_epoch >= start_epoch);

        // Anchor + minimal public state.
        anchor_once(agreement_id);
        Mapping::set(agreement_parties_key, agreement_id, parties_key);
        Mapping::set(agreement_status, agreement_id, STATUS_PENDING);
        Mapping::set(resume_approvals, agreement_id, 0u8);

        let h: u32 = block.height;

        let offer: PendingAgreement = PendingAgreement {
            agreement_id: agreement_id.private,
            parties_key: parties_key.private,

            employer_name_hash: employer_name_hash.private,
            worker_name_hash: worker_name_hash.private,

            industry_code: industry_code.private,
            pay_frequency_code: pay_frequency_code.private,

            start_epoch: start_epoch.private,
            end_epoch: end_epoch.private,
            review_epoch: review_epoch.private,

            agreement_rev: agreement_rev.private,
            schema_v: schema_v.private,
            policy_v: policy_v.private,

            terms_doc_hash: terms_doc_hash.private,
            terms_root: terms_root.private,

            offer_height: h.private,
            offer_time_hash: offer_time_hash.private,

            employer_address: caller.private,
            worker_address: worker_address.private,

            // Offer is owned by worker so the worker can accept/consume it.
            owner: worker_address.private,
            _nonce: group::rand().public
        };

        return offer;
    }

    // -----------------------------
    // 2) Accept job offer (worker)
    // -----------------------------
    transition accept_job_offer(
        offer: PendingAgreement,
        accept_time_hash: [u8; 32]
    ) -> FinalAgreement {

        // Caller must be the intended worker address AND own the worker name hash.
        assert(offer.worker_address == caller.private);
        assert_is_worker(offer.worker_name_hash);

        let agreement_id: [u8; 32] = offer.agreement_id;
        let parties_key: [u8; 32] = offer.parties_key;

        assert_agreement_exists(agreement_id);

        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PENDING);

        assert_parties_key_matches(agreement_id, parties_key);

        consume offer;

        // Activate agreement + clear resume approvals
        Mapping::set(agreement_status, agreement_id, STATUS_ACTIVE);
        Mapping::set(resume_approvals, agreement_id, 0u8);

        let h: u32 = block.height;

        let final: FinalAgreement = FinalAgreement {
            agreement_id: agreement_id.private,
            parties_key: parties_key.private,

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

            accept_height: h.private,
            accept_time_hash: accept_time_hash.private,

            employer_address: offer.employer_address,
            worker_address: offer.worker_address,

            owner: DAO_ADDRESS.private,
            _nonce: group::rand().public
        };

        return final;
    }

    // -----------------------------
    // 3) Pause / terminate (capability-gated via parties_key)
    // -----------------------------
    transition pause_agreement(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        Mapping::set(agreement_status, agreement_id, STATUS_PAUSED);
        Mapping::set(resume_approvals, agreement_id, 0u8);
    }

    transition terminate_agreement(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s != STATUS_TERMINATED);

        Mapping::set(agreement_status, agreement_id, STATUS_TERMINATED);
        Mapping::set(resume_approvals, agreement_id, 0u8);
    }

    // -----------------------------
    // 4) Resume approvals (3-of-3)
    // -----------------------------
    transition resume_agreement_employer(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PAUSED);

        let m: u8 = Mapping::get_or_use(resume_approvals, agreement_id, 0u8);
        Mapping::set(resume_approvals, agreement_id, m | RESUME_EMPLOYER_BIT);
    }

    transition resume_agreement_worker(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PAUSED);

        let m: u8 = Mapping::get_or_use(resume_approvals, agreement_id, 0u8);
        Mapping::set(resume_approvals, agreement_id, m | RESUME_WORKER_BIT);
    }

    transition resume_agreement_dao(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        assert_is_dao();

        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PAUSED);

        let m: u8 = Mapping::get_or_use(resume_approvals, agreement_id, 0u8);
        Mapping::set(resume_approvals, agreement_id, m | RESUME_DAO_BIT);
    }

    transition finalize_resume(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PAUSED);

        let m: u8 = Mapping::get_or_use(resume_approvals, agreement_id, 0u8);
        assert(m == RESUME_ALL_BITS);

        Mapping::set(agreement_status, agreement_id, STATUS_ACTIVE);
        Mapping::set(resume_approvals, agreement_id, 0u8);
    }

    // -----------------------------
    // 5) Supersede
    // -----------------------------
    transition supersede_agreement(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s != STATUS_SUPERSEDED);

        Mapping::set(agreement_status, agreement_id, STATUS_SUPERSEDED);
        Mapping::set(resume_approvals, agreement_id, 0u8);
    }

    // -----------------------------
    // Read utilities
    // -----------------------------
    transition assert_agreement_active(agreement_id: [u8; 32]) {
        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert(s == STATUS_ACTIVE);
    }

    transition get_anchor_height(agreement_id: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(agreement_anchor_height, agreement_id, 0u32);
        return h;
    }
}
