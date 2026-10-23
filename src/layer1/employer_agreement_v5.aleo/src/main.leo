// ---------------------------------------------------------
// Employer Agreement v5 — Leo v4.0 syntax
// ---------------------------------------------------------
// Job offers and the agreements they become, between two parties only.
//
// What changed from v4 (docs/migrations/2026-10-23-agreement-v5.md):
//
// 1) Twin-curve from the first letter. The employer puts the public half
//    of a P-256 key pair into the offer (`employer_half`); the worker puts
//    theirs into the acceptance (`worker_half`). Both halves ride in every
//    FinalAgreement copy, so each side's app makes the pair's key (ECDH +
//    HKDF) from its own private half, which never leaves its vault. A view
//    key opens the records and sees two public halves: not the key.
//    `parties_key` stays: random, it seals the offer's terms and the
//    negotiation before acceptance, and names the conversation.
//
// 2) Who works for whom stays off the public chain. v4 called the name
//    registry's `assert_is_owner` with a name hash and an account as public
//    finalize inputs. v5 calls nothing: the offer binds `self.signer` as the
//    employer inside the record; accepting takes the worker's own
//    PendingAgreement and checks `worker_address == self.signer`; every
//    later step takes the holder's own record and checks the caller's role
//    inside it. The app checks name ownership off chain, as it already does.
//    The only public finalize inputs are the 32-byte agreement id and the
//    parties commitment (a hash over a random key).
//
// 3) Two parties. No DAO copy, no DAO powers: resuming takes the employer's
//    and the worker's approval. A `SentOffer` record goes to the employer
//    with the offer, so the employer holds the pending offer too (to
//    withdraw it, and to rebuild its books on any device).
//
// Public state is keyed by the agreement id only: its anchor height, the
// parties commitment, its status, and the resume approvals.

const STATUS_PENDING: u8 = 0u8;
const STATUS_ACTIVE: u8 = 1u8;
const STATUS_PAUSED: u8 = 2u8;
const STATUS_TERMINATED: u8 = 3u8;

const RESUME_EMPLOYER_BIT: u8 = 1u8;
const RESUME_WORKER_BIT: u8 = 2u8;
const RESUME_BOTH_BITS: u8 = 3u8;

const PAY_DAILY: u8 = 1u8;
const PAY_WEEKLY: u8 = 2u8;
const PAY_BIWEEKLY: u8 = 3u8;
const PAY_MONTHLY: u8 = 4u8;
const PAY_QUARTERLY: u8 = 5u8;

struct PartiesCommitmentInput {
    parties_key: [u8; 32],
    employer_name_hash: field,
    worker_name_hash: field,
}

// The offer's terms as numbers, one input (a transition takes 16 at most).
struct OfferTerms {
    industry_code: u8,
    pay_frequency_code: u8,
    start_epoch: u32,
    end_epoch: u32,
    review_epoch: u32,
    agreement_rev: u16,
    schema_v: u16,
    policy_v: u16,
}

// What the offer commits to, one input.
struct OfferHashes {
    terms_doc_hash: [u8; 32],
    terms_root: [u8; 32],
    offer_time_hash: [u8; 32],
}

fn assert_status_valid(s: u8) {
    assert(
        s == STATUS_PENDING ||
        s == STATUS_ACTIVE ||
        s == STATUS_PAUSED ||
        s == STATUS_TERMINATED
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

// The same commitment as v4, so programs that prove it (credentials) carry over.
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

program employer_agreement_v5.aleo {

    // -----------------------------
    // Records
    // -----------------------------

    // The offer, as the worker holds it.
    record PendingAgreement {
        owner: address,
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
        offer_time_hash: [u8; 32],
        employer_address: address,
        worker_address: address,
        employer_half: [u8; 64],
    }

    // The offer, as the employer holds it: enough to withdraw it, and to
    // rebuild the employer's books on another device.
    record SentOffer {
        owner: address,
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field,
        terms_doc_hash: [u8; 32],
        offer_time_hash: [u8; 32],
        employer_address: address,
        worker_address: address,
        employer_half: [u8; 64],
    }

    // The agreement, one copy each.
    record FinalAgreement {
        owner: address,
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
        offer_time_hash: [u8; 32],
        accept_time_hash: [u8; 32],
        employer_address: address,
        worker_address: address,
        employer_half: [u8; 64],
        worker_half: [u8; 64],
    }

    // -----------------------------
    // Public mappings, by agreement id
    // -----------------------------

    mapping agreement_anchor_height: [u8; 32] => u32;
    mapping agreement_parties_commitment: [u8; 32] => field;
    mapping agreement_status: [u8; 32] => u8;
    mapping resume_approvals: [u8; 32] => u8;

    // -----------------------------
    // 1) Offer (employer)
    // -----------------------------
    fn create_offer(
        agreement_id: [u8; 32],
        parties_key: [u8; 32],
        employer_name_hash: field,
        worker_name_hash: field,
        worker_address: address,
        terms: OfferTerms,
        hashes: OfferHashes,
        employer_half: [u8; 64]
    ) -> (PendingAgreement, SentOffer, Final) {
        assert_pay_frequency(terms.pay_frequency_code);
        assert(terms.agreement_rev != 0u16);
        assert(terms.schema_v != 0u16);
        assert(terms.policy_v != 0u16);
        if terms.end_epoch != 0u32 {
            assert(terms.end_epoch > terms.start_epoch);
        }
        assert(terms.review_epoch >= terms.start_epoch);
        assert(worker_address != self.signer);

        let commitment: field = compute_parties_commitment(parties_key, employer_name_hash, worker_name_hash);

        let offer: PendingAgreement = PendingAgreement {
            agreement_id: agreement_id,
            parties_key: parties_key,
            employer_name_hash: employer_name_hash,
            worker_name_hash: worker_name_hash,
            industry_code: terms.industry_code,
            pay_frequency_code: terms.pay_frequency_code,
            start_epoch: terms.start_epoch,
            end_epoch: terms.end_epoch,
            review_epoch: terms.review_epoch,
            agreement_rev: terms.agreement_rev,
            schema_v: terms.schema_v,
            policy_v: terms.policy_v,
            terms_doc_hash: hashes.terms_doc_hash,
            terms_root: hashes.terms_root,
            offer_time_hash: hashes.offer_time_hash,
            employer_address: self.signer,
            worker_address: worker_address,
            employer_half: employer_half,
            owner: worker_address,
        };

        let sent: SentOffer = SentOffer {
            agreement_id: agreement_id,
            parties_key: parties_key,
            employer_name_hash: employer_name_hash,
            worker_name_hash: worker_name_hash,
            terms_doc_hash: hashes.terms_doc_hash,
            offer_time_hash: hashes.offer_time_hash,
            employer_address: self.signer,
            worker_address: worker_address,
            employer_half: employer_half,
            owner: self.signer,
        };

        return (offer, sent, final {
            let existing: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
            assert(existing == 0u32);
            agreement_anchor_height.set(agreement_id, block.height);
            agreement_parties_commitment.set(agreement_id, commitment);
            agreement_status.set(agreement_id, STATUS_PENDING);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    // -----------------------------
    // 2) Accept (worker): two copies, the employer's and the worker's
    // -----------------------------
    fn accept_offer(
        offer: PendingAgreement,
        accept_time_hash: [u8; 32],
        worker_half: [u8; 64]
    ) -> (FinalAgreement, FinalAgreement, Final) {
        assert(offer.worker_address == self.signer);

        let agreement_id: [u8; 32] = offer.agreement_id;
        let commitment: field = compute_parties_commitment(offer.parties_key, offer.employer_name_hash, offer.worker_name_hash);

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
            offer_time_hash: offer.offer_time_hash,
            accept_time_hash: accept_time_hash,
            employer_address: offer.employer_address,
            worker_address: offer.worker_address,
            employer_half: offer.employer_half,
            worker_half: worker_half,
            owner: offer.employer_address,
        };

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
            offer_time_hash: offer.offer_time_hash,
            accept_time_hash: accept_time_hash,
            employer_address: offer.employer_address,
            worker_address: offer.worker_address,
            employer_half: offer.employer_half,
            worker_half: worker_half,
            owner: offer.worker_address,
        };

        return (employer_copy, worker_copy, final {
            let h: u32 = agreement_anchor_height.get_or_use(agreement_id, 0u32);
            assert(h != 0u32);
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert(s == STATUS_PENDING);
            let stored: field = agreement_parties_commitment.get_or_use(agreement_id, 0field);
            assert(stored == commitment);
            agreement_status.set(agreement_id, STATUS_ACTIVE);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    // -----------------------------
    // 3) Withdraw an offer not yet accepted (employer)
    // -----------------------------
    fn withdraw_offer(sent: SentOffer) -> Final {
        assert(sent.employer_address == self.signer);
        let agreement_id: [u8; 32] = sent.agreement_id;
        return final {
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert(s == STATUS_PENDING);
            agreement_status.set(agreement_id, STATUS_TERMINATED);
        };
    }

    // -----------------------------
    // 4) Pause, terminate, resume: each party with its own copy, which
    //    comes back to it unchanged (a fresh record, the same fields)
    // -----------------------------
    fn pause_employer(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.employer_address == self.signer);
        let agreement_id: [u8; 32] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert(s == STATUS_ACTIVE);
            agreement_status.set(agreement_id, STATUS_PAUSED);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    fn pause_worker(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.worker_address == self.signer);
        let agreement_id: [u8; 32] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert(s == STATUS_ACTIVE);
            agreement_status.set(agreement_id, STATUS_PAUSED);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    fn terminate_employer(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.employer_address == self.signer);
        let agreement_id: [u8; 32] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert_status_valid(s);
            assert(s != STATUS_TERMINATED);
            agreement_status.set(agreement_id, STATUS_TERMINATED);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    fn terminate_worker(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.worker_address == self.signer);
        let agreement_id: [u8; 32] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert_status_valid(s);
            assert(s != STATUS_TERMINATED);
            agreement_status.set(agreement_id, STATUS_TERMINATED);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    fn approve_resume_employer(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.employer_address == self.signer);
        let agreement_id: [u8; 32] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert(s == STATUS_PAUSED);
            let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
            resume_approvals.set(agreement_id, m | RESUME_EMPLOYER_BIT);
        });
    }

    fn approve_resume_worker(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.worker_address == self.signer);
        let agreement_id: [u8; 32] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert(s == STATUS_PAUSED);
            let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
            resume_approvals.set(agreement_id, m | RESUME_WORKER_BIT);
        });
    }

    // Either party, once both have approved.
    fn resume(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.employer_address == self.signer || a.worker_address == self.signer);
        let agreement_id: [u8; 32] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, 255u8);
            assert(s == STATUS_PAUSED);
            let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
            assert(m == RESUME_BOTH_BITS);
            agreement_status.set(agreement_id, STATUS_ACTIVE);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    // -----------------------------
    // 5) For other programs (as v4)
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

    // The caller can reproduce the private parties commitment, so it holds
    // a copy of the agreement, and the agreement is active. The calling
    // program decides which party it needs (the record it holds says).
    fn assert_employer_authorized(
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
            assert(s == STATUS_ACTIVE);
        };
    }

    // Immutable: no admin key can change what an agreement means. A change ships as employer_agreement_v6.
    @noupgrade
    constructor() {}
}
