import pnw_name_registry_v2.aleo;
import employer_license_registry.aleo;

// ---------------------------------------------------------
// Employer Agreement v4 — Leo v4.0 syntax
// ---------------------------------------------------------
// 3-party agreement records: employer, worker, and DAO each
// receive their own copy of the FinalAgreement on acceptance.
//
// Model:
// 1) Employer creates offer → PendingAgreement owned by worker
// 2) Worker accepts → 3 FinalAgreement copies minted
// 3) All lifecycle ops (pause/terminate/resume) remain unchanged

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

const RESUME_EMPLOYER_BIT: u8 = 1u8;
const RESUME_WORKER_BIT: u8 = 2u8;
const RESUME_DAO_BIT: u8 = 4u8;
const RESUME_ALL_BITS: u8 = 7u8;

const PAY_DAILY: u8 = 1u8;
const PAY_WEEKLY: u8 = 2u8;
const PAY_BIWEEKLY: u8 = 3u8;
const PAY_MONTHLY: u8 = 4u8;
const PAY_QUARTERLY: u8 = 5u8;

// -----------------------------
// Structs (outside program block in v4)
// -----------------------------

struct PartiesCommitmentInput {
    parties_key: [u8; 32],
    employer_name_hash: field,
    worker_name_hash: field,
}

// -----------------------------
// Helper functions (outside program block in v4)
// -----------------------------

fn assert_status_valid(s: u8) {
    assert(
        s == STATUS_PENDING ||
        s == STATUS_ACTIVE ||
        s == STATUS_PAUSED ||
        s == STATUS_TERMINATED ||
        s == STATUS_SUPERSEDED
    );
}

fn assert_pay_frequency(code: u8) {
    assert(
        code == PAY_DAILY ||
        code == PAY_WEEKLY ||
        code == PAY_BIWEEKLY ||
        code == PAY_MONTHLY ||
        code == PAY_QUARTERLY
    );
}

fn compute_parties_commitment(
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

// =============================================================
// Program block
// =============================================================

program employer_agreement_v4.aleo {

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
        offer_height: u32,
        offer_time_hash: [u8; 32],
        accept_height: u32,
        accept_time_hash: [u8; 32],
        employer_address: address,
        worker_address: address,
        owner: address,
    }

    // -----------------------------
    // Public mappings
    // -----------------------------

    mapping agreement_anchor_height: [u8; 32] => u32;
    mapping agreement_parties_commitment: [u8; 32] => field;
    mapping agreement_status: [u8; 32] => u8;
    mapping resume_approvals: [u8; 32] => u8;

    // -----------------------------
    // 1) Create job offer (employer)
    // -----------------------------
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
    ) -> (PendingAgreement, Final) {

        assert_pay_frequency(pay_frequency_code);
        assert(agreement_rev != 0u16);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        if end_epoch != 0u32 {
            assert(end_epoch > start_epoch);
        }
        assert(review_epoch >= start_epoch);

        let f1: Final = employer_license_registry.aleo::assert_verified(self.caller);
        let f2: Final = pnw_name_registry_v2.aleo::assert_is_owner(employer_name_hash, self.caller);

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

        return (offer, final {
            f1.run();
            f2.run();

            let existing: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
            assert(existing == 0u32);

            agreement_anchor_height.set(agreement_id, block.height);
            agreement_parties_commitment.set(agreement_id, commitment);
            agreement_status.set(agreement_id, STATUS_PENDING);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    // -----------------------------
    // 2) Accept job offer (worker)
    // Mints 3 copies: employer, worker, DAO
    // -----------------------------
    fn accept_job_offer(
        offer: PendingAgreement,
        accept_time_hash: [u8; 32]
    ) -> (FinalAgreement, FinalAgreement, FinalAgreement, Final) {

        assert(offer.worker_address == self.caller);

        let agreement_id: [u8; 32] = offer.agreement_id;

        let f1: Final = pnw_name_registry_v2.aleo::assert_is_owner(offer.worker_name_hash, self.caller);

        let commitment: field = compute_parties_commitment(
            offer.parties_key,
            offer.employer_name_hash,
            offer.worker_name_hash
        );

        // Employer's copy
        let employer_copy: FinalAgreement = FinalAgreement {
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
            owner: offer.employer_address,
        };

        // Worker's copy
        let worker_copy: FinalAgreement = FinalAgreement {
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
            owner: offer.worker_address,
        };

        // DAO's authoritative copy
        let dao_copy: FinalAgreement = FinalAgreement {
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

        return (employer_copy, worker_copy, dao_copy, final {
            f1.run();

            let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
            assert(h != 0u32);

            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert(s == STATUS_PENDING);

            let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
            assert(stored != 0field);
            assert(stored == commitment);

            agreement_status.set(agreement_id, STATUS_ACTIVE);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    // -----------------------------
    // 3) Pause (role-specific)
    // -----------------------------
    fn pause_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        let f1: Final = employer_license_registry.aleo::assert_verified(self.caller);
        let f2: Final = pnw_name_registry_v2.aleo::assert_is_owner(employer_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
            f1.run();
            f2.run();
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
        };
    }

    fn pause_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::assert_is_owner(worker_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
            f1.run();
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
        };
    }

    fn pause_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        assert(self.caller == DAO_ADDRESS);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
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
        };
    }

    // -----------------------------
    // 4) Terminate (role-specific)
    // -----------------------------
    fn terminate_agreement_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        let f1: Final = employer_license_registry.aleo::assert_verified(self.caller);
        let f2: Final = pnw_name_registry_v2.aleo::assert_is_owner(employer_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
            f1.run();
            f2.run();
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
        };
    }

    fn terminate_agreement_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::assert_is_owner(worker_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
            f1.run();
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
        };
    }

    fn terminate_agreement_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        assert(self.caller == DAO_ADDRESS);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
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
        };
    }

    // -----------------------------
    // 5) Resume approvals (3-of-3)
    // -----------------------------
    fn approve_resume_employer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        let f1: Final = employer_license_registry.aleo::assert_verified(self.caller);
        let f2: Final = pnw_name_registry_v2.aleo::assert_is_owner(employer_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
            f1.run();
            f2.run();
            let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
            assert(h != 0u32);
            let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
            assert(stored != 0field);
            assert(stored == commitment);
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert_status_valid(s);
            assert(s == STATUS_PAUSED);
            let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
            resume_approvals.set(agreement_id, m | RESUME_EMPLOYER_BIT);
        };
    }

    fn approve_resume_worker(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::assert_is_owner(worker_name_hash, self.caller);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
            f1.run();
            let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
            assert(h != 0u32);
            let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
            assert(stored != 0field);
            assert(stored == commitment);
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert_status_valid(s);
            assert(s == STATUS_PAUSED);
            let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
            resume_approvals.set(agreement_id, m | RESUME_WORKER_BIT);
        };
    }

    fn approve_resume_dao(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        assert(self.caller == DAO_ADDRESS);
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
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
        };
    }

    // -----------------------------
    // 6) Finalize resume (all 3 approvals)
    // -----------------------------
    fn resume_agreement(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
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
        };
    }

    // -----------------------------
    // 7) Supersede
    // -----------------------------
    fn supersede_agreement(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);
        return final {
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
        };
    }

    // -----------------------------
    // 8) Cross-program assertions
    // -----------------------------
    fn assert_agreement_anchored(agreement_id: [u8; 32]) -> Final {
        return final {
            let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
            assert(h != 0u32);
        };
    }

    fn assert_agreement_active(agreement_id: [u8; 32]) -> Final {
        return final {
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert(s == STATUS_ACTIVE);
        };
    }

    // -----------------------------
    // 9) Strong employer authorization (added 2026-04-12)
    // -----------------------------
    // Proves the caller is authorized to act as the employer for a
    // specific agreement, without requiring the cross-program caller
    // to consume or re-emit the private FinalAgreement record (Leo
    // forbids external programs from creating records of types they
    // don't own).
    //
    // The authorization happens in two layers:
    //
    //   1) The parties commitment check below — a commitment over
    //      (parties_key || employer_name_hash || worker_name_hash)
    //      was written to `agreement_parties_commitment` at the time
    //      the offer was created. Reproducing that commitment on-chain
    //      proves the caller knows the private `parties_key`, which
    //      only the three parties to the agreement (employer, worker,
    //      DAO) ever see, because it lives inside their private
    //      FinalAgreement records.
    //
    //   2) The calling program is expected to separately verify that
    //      `self.caller` is the actual employer (not the worker or DAO)
    //      by calling `pnw_name_registry_v2::assert_is_owner`
    //      (employer_name_hash, self.caller) BEFORE invoking this
    //      transition. This binds the commitment proof to the employer
    //      role specifically.
    //
    // Combined, these checks make it impossible for a random attacker
    // to impersonate the employer for this agreement — they would need
    // to both steal the employer's `.pnw` name ownership AND read the
    // private `parties_key` out of the employer's FinalAgreement record,
    // which requires the employer's private Aleo view key.
    //
    // Also asserts the agreement is currently in ACTIVE state, so
    // paused/terminated/superseded agreements can't authorize new
    // operations downstream.
    fn assert_employer_authorized(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field
    ) -> Final {
        let commitment: field = compute_parties_commitment(
            parties_key,
            employer_name_hash,
            worker_name_hash
        );
        return final {
            let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
            assert(h != 0u32);

            let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
            assert(stored != 0field);
            assert(stored == commitment);

            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert_status_valid(s);
            assert(s == STATUS_ACTIVE);
        };
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx")
    constructor() {}
}
