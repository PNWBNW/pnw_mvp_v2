import pnw_name_registry.aleo;
import employer_license_registry.aleo;

program employer_agreement.aleo {

    // ---------------------------------------------------------
    // Employer Agreement (Layer 1) - PNW MVP v2 (Leo v3.x)
    // ---------------------------------------------------------
    //
    // Model:
    // 1) Employer creates a one-step "job offer" as a PendingAgreement record.
    // 2) Worker accepts the offer, consuming the PendingAgreement.
    // 3) A FinalAgreement record is created and custodied by the DAO address.
    // 4) Public, minimal mappings track:
    //    - agreement existence + first-seen block height
    //    - agreement status (PENDING/ACTIVE/PAUSED/TERMINATED/SUPERSEDED)
    //    - resume approvals (3-of-3: Employer + Worker + DAO)
    //
    // Privacy:
    // - No plaintext identities or terms are stored publicly.
    // - Only anchors/flags/heights are public.
    //
    // Notes on timestamps:
    // - On-chain "real time" does not exist; we store block.height on-chain.
    // - The portal supplies a UTC Zulu timestamp string hash (commitment) that
    //   can be proven later off-chain, without publishing the timestamp itself.

    // -----------------------------
    // Constants
    // -----------------------------

    // DAO custody/controller address (FinalAgreement owner).
    const DAO_ADDRESS: address = aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

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

    // Job offer (owned by employer until acceptance; then consumed).
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
        offer_time_hash: [u8; 32].private, // portal-supplied hash of UTC Zulu timestamp string

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
        accept_time_hash: [u8; 32].private, // portal-supplied hash of UTC Zulu timestamp string

        owner: address.private,
        _nonce: group.public
    }

    // -----------------------------
    // Public mappings (minimal state)
    // -----------------------------

    // Existence + first-seen height for the agreement_id (anchor).
    mapping agreement_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    // Store non-revealing parties commitment to authorize later actions.
    mapping agreement_parties_key:
        key as [u8; 32].public,
        value as [u8; 32].public;

    // Current agreement status (public, minimal; does not reveal identities/terms).
    mapping agreement_status:
        key as [u8; 32].public,
        value as u8.public;

    // Resume approvals bitmask (public, minimal).
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

    function assert_is_employer(employer_name_hash: field, industry_code: u8) {
        // Must be verified as a business AND own the employer name AND match suffix/industry code.
        employer_license_registry.aleo/assert_verified(caller);
        pnw_name_registry.aleo/assert_employer_owner(employer_name_hash, caller, industry_code);
    }

    function assert_is_worker(worker_name_hash: field) {
        // Worker must own the worker name.
        pnw_name_registry.aleo/assert_worker_owner(worker_name_hash, caller);
    }

    function assert_is_dao() {
        // Placeholder for vote-gated DAO action.
        assert(caller == DAO_ADDRESS);
    }

    // -----------------------------
    // 1) Create job offer (one-step employer)
    // -----------------------------
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
        terms_root: [u8; 32],

        offer_time_hash: [u8; 32] // portal-supplied UTC Zulu timestamp hash commitment
    ) -> PendingAgreement {

        // Employer must be verified + own employer name + match suffix/industry code.
        assert_is_employer(employer_name_hash, industry_code);

        // Official offers cannot be made to non-accounts:
        // Require worker name exists (ownership is proven at acceptance time).
        pnw_name_registry.aleo/assert_name_exists(worker_name_hash);

        assert_pay_frequency(pay_frequency_code);
        assert(agreement_rev != 0u16);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);

        // Epoch rules:
        // - end_epoch == 0 means indefinite
        // - if end_epoch != 0, it must be greater than start_epoch
        if end_epoch != 0u32 {
            assert(end_epoch > start_epoch);
        }
        assert(review_epoch >= start_epoch);

        // Anchor + store minimal public state.
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

            owner: caller.private,
            _nonce: group::rand().public
        };

        return offer;
    }

    // -----------------------------
    // 2) Accept job offer (two-step finalize)
    // -----------------------------
    transition accept_job_offer(
        offer: PendingAgreement,
        accept_time_hash: [u8; 32] // portal-supplied UTC Zulu timestamp hash commitment
    ) -> FinalAgreement {

        // The offer must be owned by the employer until accepted.
        // (Prevents third-party acceptance of a record they don’t control.)
        // Note: offer.owner is private, but we can still assert via record field access here.
        // Leo will enforce record ownership at runtime; this is an extra explicit check.
        // (If you prefer, you can omit this line and rely on record ownership rules.)
        // assert(offer.owner == offer.owner);

        let agreement_id: [u8; 32] = offer.agreement_id;
        let parties_key: [u8; 32] = offer.parties_key;

        // Agreement must exist and still be pending.
        assert_agreement_exists(agreement_id);
        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_PENDING);

        // Parties key must match stored anchor.
        assert_parties_key_matches(agreement_id, parties_key);

        // Worker must own the worker name at acceptance time.
        let worker_hash: field = offer.worker_name_hash;
        assert_is_worker(worker_hash);

        // Employer must still be verified and suffix/industry must still match.
        // (We use the employer address that created the offer: offer.owner.)
        // Also assert that the employer name still exists.
        let employer_hash: field = offer.employer_name_hash;
        pnw_name_registry.aleo/assert_name_exists(employer_hash);

        // NOTE: acceptor (worker) is caller; employer is offer.owner (private address in record).
        // We enforce employer validity via the registry using the stored employer owner.
        pnw_name_registry.aleo/assert_employer_owner(employer_hash, offer.owner, offer.industry_code);

        assert_pay_frequency(offer.pay_frequency_code);

        // Activate agreement and clear resume approvals.
        Mapping::set(agreement_status, agreement_id, STATUS_ACTIVE);
        Mapping::set(resume_approvals, agreement_id, 0u8);

        let h: u32 = block.height;

        let final: FinalAgreement = FinalAgreement {
            agreement_id: offer.agreement_id,
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

            accept_height: h.private,
            accept_time_hash: accept_time_hash.private,

            owner: DAO_ADDRESS.private,
            _nonce: group::rand().public
        };

        return final;
    }

    // -----------------------------
    // 3) Pause / terminate (any of the 3 parties can pause/terminate)
    // -----------------------------

    transition pause_agreement(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        let s: u8 = Mapping::get_or_use(agreement_status, agreement_id, 255u8);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        // Caller authorization is checked off-chain by providing parties_key only to authorized parties.
        // On-chain we enforce minimal correctness only.
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
    // 4) Resume flow (requires all 3 to sign)
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
    // 5) Supersede (new agreement replaces old)
    // -----------------------------
    transition supersede_agreement(old_agreement_id: [u8; 32], parties_key: [u8; 32]) {
        assert_agreement_exists(old_agreement_id);
        assert_parties_key_matches(old_agreement_id, parties_key);

        let s: u8 = Mapping::get_or_use(agreement_status, old_agreement_id, 255u8);
        assert_status_valid(s);
        assert(s != STATUS_SUPERSEDED);

        Mapping::set(agreement_status, old_agreement_id, STATUS_SUPERSEDED);
        Mapping::set(resume_approvals, old_agreement_id, 0u8);
    }
}        review_epoch: u32.private,          // annual/periodic review point (portal-defined)

        agreement_rev: u16.private,         // relationship sequence counter
        schema_v: u16.private,
        policy_v: u16.private,

        terms_doc_hash: [u8; 32].private,
        terms_root: [u8; 32].private,

        issued_height: u32.private,

        owner: address.private,
        _nonce: group.public
    }

    // Final agreement (custodied by DAO_ADDRESS).
    // This record is an immutable private anchor of the finalized agreement terms.
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

        issued_height: u32.private,

        owner: address.private,
        _nonce: group.public
    }

    // -----------------------------
    // Public mappings (minimal state)
    // -----------------------------

    // Existence + first-seen height for the agreement_id (anchor)
    mapping agreement_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    // Store a non-revealing parties commitment to authorize later actions
    mapping agreement_parties_key:
        key as [u8; 32].public,
        value as [u8; 32].public;

    // Current agreement status (public, minimal; does not reveal identities/terms)
    mapping agreement_status:
        key as [u8; 32].public,
        value as u8.public;

    // Resume approvals bitmask
    mapping resume_approvals:
        key as [u8; 32].public,
        value as u8.public;

    // -----------------------------
    // Internal helpers
    // -----------------------------

    function anchor_once(agreement_id: [u8; 32]) {
        let h: u32 = block.height;
        let existing: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        if existing == 0u32 {
            agreement_anchor_height.set(agreement_id, h);
        }
    }

    function assert_agreement_exists(agreement_id: [u8; 32]) {
        let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
        assert(h != 0u32);
    }

    function assert_parties_key_matches(agreement_id: [u8; 32], parties_key: [u8; 32]) {
        let stored: [u8; 32] = agreement_parties_key.get_or_use(agreement_id, [0u8; 32]);
        assert(stored == parties_key);
    }

    function assert_is_employer(employer_name_hash: field) {
        pnw_name_registry.aleo/assert_is_owner(employer_name_hash, caller);
        employer_license_registry.aleo/assert_verified(caller);
    }

    function assert_is_worker(worker_name_hash: field) {
        pnw_name_registry.aleo/assert_is_owner(worker_name_hash, caller);
    }

    function assert_is_dao() {
        // Placeholder for "vote-gated" DAO action:
        // Replace with governance artifact verification in a dedicated DAO program later.
        assert(caller == DAO_ADDRESS);
    }

    // -----------------------------
    // 1) Create job offer (one-step employer)
    // -----------------------------
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
    ) -> PendingAgreement {
        // Require both parties have accounts (names must exist & be owned).
        // Employer must be verified.
        assert_is_employer(employer_name_hash);
        // Prevent "official offer" to non-accounts:
        // Worker must own the name hash at offer time.
        pnw_name_registry.aleo/assert_is_owner(worker_name_hash, worker_name_hash.owner()); // intentionally invalid
        // NOTE: Leo cannot introspect owner from a field; this line is a placeholder and will not compile.
        // Replace with a real name-registry helper such as:
        // pnw_name_registry.aleo/assert_name_exists(worker_name_hash);
        // OR require the worker to prove ownership during acceptance only, and skip at offer-time.
        //
        // For now, enforce worker existence at acceptance (strongly recommended), and remove the above placeholder line.

        assert_pay_frequency(pay_frequency_code);
        assert(agreement_rev != 0u16);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);

        // Epoch rules:
        // - end_epoch == 0 means indefinite
        // - if end_epoch != 0, it must be greater than start_epoch
        if end_epoch != 0u32 {
            assert(end_epoch > start_epoch);
        }
        assert(review_epoch >= start_epoch);

        // Anchor + store minimal public state
        anchor_once(agreement_id);
        agreement_parties_key.set(agreement_id, parties_key);
        agreement_status.set(agreement_id, STATUS_PENDING);
        resume_approvals.set(agreement_id, 0u8);

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

            issued_height: h.private,

            owner: caller.private,
            _nonce: group::rand().public
        };

        return offer;
    }

    // -----------------------------
    // 2) Accept job offer (worker; two-step finalization)
    // -----------------------------
    transition accept_job_offer(
        pending: PendingAgreement
    ) -> FinalAgreement {
        // Worker must accept (must be caller).
        assert_is_worker(pending.worker_name_hash);

        // Re-assert employer is still verified and still owns employer name.
        // This prevents stale offers if ownership changed.
        // (We must check using the employer name hash stored inside pending.)
        // Note: This asserts the current caller is employer, which is NOT true during worker acceptance,
        // so we cannot reuse assert_is_employer here.
        // Instead, we require that the employer name is still owned by the original employer address
        // by checking it indirectly later in payroll (employer approves payroll).
        //
        // Minimal enforcement at acceptance:
        // - Ensure agreement exists, parties_key matches
        assert_agreement_exists(pending.agreement_id);
        assert_parties_key_matches(pending.agreement_id, pending.parties_key);

        // Consume the pending offer
        consume pending;

        // Update public state
        agreement_status.set(pending.agreement_id, STATUS_ACTIVE);
        resume_approvals.set(pending.agreement_id, 0u8);

        let h: u32 = block.height;

        // DAO-custodied finalized agreement record
        let final_agreement: FinalAgreement = FinalAgreement {
            agreement_id: pending.agreement_id,
            parties_key: pending.parties_key,

            employer_name_hash: pending.employer_name_hash,
            worker_name_hash: pending.worker_name_hash,

            industry_code: pending.industry_code,
            pay_frequency_code: pending.pay_frequency_code,

            start_epoch: pending.start_epoch,
            end_epoch: pending.end_epoch,
            review_epoch: pending.review_epoch,

            agreement_rev: pending.agreement_rev,
            schema_v: pending.schema_v,
            policy_v: pending.policy_v,

            terms_doc_hash: pending.terms_doc_hash,
            terms_root: pending.terms_root,

            issued_height: h.private,

            owner: DAO_ADDRESS.private,
            _nonce: group::rand().public
        };

        return final_agreement;
    }

    // -----------------------------
    // Authorization for status changes
    // -----------------------------
    transition pause_agreement(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],

        employer_name_hash: field,
        worker_name_hash: field
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        // Caller must be employer OR worker OR DAO (placeholder)
        let is_employer: boolean = false;
        let is_worker: boolean = false;

        // Employer authorization: caller owns employer name & is verified
        // (If this assert fails, it will abort; so we guard by trying only one path at a time is not possible in Leo.
        // In MVP, we provide three separate entrypoints for each party.)
        //
        // Use pause_agreement_employer / pause_agreement_worker / pause_agreement_dao below.

        // Placeholder to satisfy syntax; never executed
        if is_employer || is_worker {
            assert(false);
        }

        // No-op
    }

    transition pause_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        assert_is_employer(employer_name_hash);

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        agreement_status.set(agreement_id, STATUS_PAUSED);
        resume_approvals.set(agreement_id, 0u8);
    }

    transition pause_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        worker_name_hash: field
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        assert_is_worker(worker_name_hash);

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        agreement_status.set(agreement_id, STATUS_PAUSED);
        resume_approvals.set(agreement_id, 0u8);
    }

    transition pause_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32]
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        assert_is_dao();

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert_status_valid(s);
        assert(s == STATUS_ACTIVE);

        agreement_status.set(agreement_id, STATUS_PAUSED);
        resume_approvals.set(agreement_id, 0u8);
    }

    transition terminate_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        assert_is_employer(employer_name_hash);

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert_status_valid(s);
        assert(s != STATUS_TERMINATED);

        agreement_status.set(agreement_id, STATUS_TERMINATED);
        resume_approvals.set(agreement_id, 0u8);
    }

    transition terminate_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        worker_name_hash: field
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        assert_is_worker(worker_name_hash);

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert_status_valid(s);
        assert(s != STATUS_TERMINATED);

        agreement_status.set(agreement_id, STATUS_TERMINATED);
        resume_approvals.set(agreement_id, 0u8);
    }

    transition terminate_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32]
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        assert_is_dao();

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert_status_valid(s);
        assert(s != STATUS_TERMINATED);

        agreement_status.set(agreement_id, STATUS_TERMINATED);
        resume_approvals.set(agreement_id, 0u8);
    }

    // -----------------------------
    // 3-of-3 Resume approvals
    // -----------------------------
    transition approve_resume_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        assert_is_employer(employer_name_hash);

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert(s == STATUS_PAUSED);

        let mask: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
        resume_approvals.set(agreement_id, mask | RESUME_EMPLOYER_BIT);
    }

    transition approve_resume_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        worker_name_hash: field
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        assert_is_worker(worker_name_hash);

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert(s == STATUS_PAUSED);

        let mask: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
        resume_approvals.set(agreement_id, mask | RESUME_WORKER_BIT);
    }

    transition approve_resume_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32]
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        assert_is_dao();

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert(s == STATUS_PAUSED);

        let mask: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
        resume_approvals.set(agreement_id, mask | RESUME_DAO_BIT);
    }

    transition resume_agreement(
        agreement_id: [u8; 32],
        parties_key: [u8; 32]
    ) {
        assert_agreement_exists(agreement_id);
        assert_parties_key_matches(agreement_id, parties_key);

        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert(s == STATUS_PAUSED);

        let mask: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
        assert(mask == RESUME_ALL_BITS);

        agreement_status.set(agreement_id, STATUS_ACTIVE);
        resume_approvals.set(agreement_id, 0u8);
    }

    // -----------------------------
    // Read-only style assertions
    // -----------------------------
    transition assert_agreement_active(agreement_id: [u8; 32]) {
        let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_PENDING);
        assert(s == STATUS_ACTIVE);
    }

    transition assert_agreement_anchored(agreement_id: [u8; 32]) {
        assert_agreement_exists(agreement_id);
    }
}
