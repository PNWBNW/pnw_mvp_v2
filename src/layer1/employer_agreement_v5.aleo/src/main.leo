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
//
// 3) Two parties. No DAO copy, no DAO powers: resuming takes the employer's
//    and the worker's approval, and so does ending by mutual agreement. A
//    `SentOffer` record goes to the employer with the offer, so the employer
//    holds the pending offer too (to withdraw it, and to rebuild its books
//    on any device).
//
// 4) The pair tag (2026-10-24). Every agreement has a tag: one hash over
//    its random `parties_key` and the two accounts. The agreement's status
//    is kept under the tag as well as under the id, so a later program
//    (paystubs, reviews) can prove "the caller holds an agreement with this
//    person, and it is active" by recomputing the tag from private inputs:
//    `assert_pair_active`, `assert_pair_agreed`. Nothing public names the
//    agreement id in that call, and the tag names nobody: it is a hash over
//    a random key. v4's `assert_agreement_*` helpers, which took the
//    agreement id as a public input, are gone.
//
// 5) Packed bytes (2026-10-24). Every 32-byte value is two u128 (the high
//    half first, as hewn_letters_v2's `lookup`), every 64-byte half four.
//    The records carry twenty words instead of three hundred and twenty
//    bytes: smaller proofs, a cheaper deployment.
//
// 6) A reason when an agreement ends (Joshua, 2026-10-24). The party that
//    ends it gives a reason, private: it goes into that party's own copy
//    (`end_reason`) and into an `AgreementEnd` record minted to the other
//    party, who then holds the statement on chain too. The reasons a party
//    may give are its own: a worker resigns, an employer lays off or lets
//    go, either may close a finished contract, and both approve a mutual
//    end. Nothing about the reason reaches public state.
//
// Public state: by agreement id, its anchor height, its status and the two
// approval masks; by pair tag, the status again. Nothing else.

const STATUS_PENDING: u8 = 0u8;
const STATUS_ACTIVE: u8 = 1u8;
const STATUS_PAUSED: u8 = 2u8;
const STATUS_ENDED: u8 = 3u8;
const STATUS_WITHDRAWN: u8 = 4u8;
const STATUS_NONE: u8 = 255u8;

const APPROVAL_EMPLOYER_BIT: u8 = 1u8;
const APPROVAL_WORKER_BIT: u8 = 2u8;
const APPROVAL_BOTH_BITS: u8 = 3u8;

const PAY_DAILY: u8 = 1u8;
const PAY_WEEKLY: u8 = 2u8;
const PAY_BIWEEKLY: u8 = 3u8;
const PAY_MONTHLY: u8 = 4u8;
const PAY_QUARTERLY: u8 = 5u8;

// Why an agreement ended. 0 while it runs.
const END_NONE: u8 = 0u8;
const END_RESIGNED: u8 = 1u8;          // the worker
const END_LAID_OFF: u8 = 2u8;          // the employer: the position ended
const END_CONTRACT_FINISHED: u8 = 3u8; // either: the term ran out
const END_LET_GO: u8 = 4u8;            // the employer
const END_MUTUAL: u8 = 5u8;            // both approved

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
    terms_doc_hash: [u128; 2],
    terms_root: [u128; 2],
    offer_time_hash: [u128; 2],
}

// What the pair tag is made of. Private: only the two parties hold the key.
struct PairTagInput {
    parties_key: [u128; 2],
    employer: address,
    worker: address,
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

// The reasons each party may give. Mutual is only reached through end_mutual.
fn assert_employer_reason(reason: u8) {
    assert(reason == END_LAID_OFF || reason == END_CONTRACT_FINISHED || reason == END_LET_GO);
}

fn assert_worker_reason(reason: u8) {
    assert(reason == END_RESIGNED || reason == END_CONTRACT_FINISHED);
}

fn pair_tag(parties_key: [u128; 2], employer: address, worker: address) -> field {
    return BHP1024::hash_to_field(PairTagInput {
        parties_key: parties_key,
        employer: employer,
        worker: worker,
    });
}

program employer_agreement_v5.aleo {

    // -----------------------------
    // Records
    // -----------------------------

    // The offer, as the worker holds it.
    record PendingAgreement {
        owner: address,
        agreement_id: [u128; 2],
        parties_key: [u128; 2],
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
        terms_doc_hash: [u128; 2],
        terms_root: [u128; 2],
        offer_time_hash: [u128; 2],
        employer_address: address,
        worker_address: address,
        employer_half: [u128; 4],
    }

    // The offer, as the employer holds it: enough to withdraw it, and to
    // rebuild the employer's books on another device.
    record SentOffer {
        owner: address,
        agreement_id: [u128; 2],
        parties_key: [u128; 2],
        employer_name_hash: field,
        worker_name_hash: field,
        terms_doc_hash: [u128; 2],
        offer_time_hash: [u128; 2],
        employer_address: address,
        worker_address: address,
        employer_half: [u128; 4],
    }

    // The agreement, one copy each. `end_reason` is 0 while it runs and is
    // set only in the copy of the party that ended it.
    record FinalAgreement {
        owner: address,
        agreement_id: [u128; 2],
        parties_key: [u128; 2],
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
        terms_doc_hash: [u128; 2],
        terms_root: [u128; 2],
        offer_time_hash: [u128; 2],
        accept_time_hash: [u128; 2],
        employer_address: address,
        worker_address: address,
        employer_half: [u128; 4],
        worker_half: [u128; 4],
        end_reason: u8,
    }

    // The other party's statement of how the agreement ended, minted to the
    // party that did not end it. Its own copy stays as it was.
    record AgreementEnd {
        owner: address,
        agreement_id: [u128; 2],
        parties_key: [u128; 2],
        ended_by: address,
        reason: u8,
    }

    // -----------------------------
    // Public mappings
    // -----------------------------

    mapping agreement_anchor_height: [u128; 2] => u32;
    mapping agreement_status: [u128; 2] => u8;
    mapping resume_approvals: [u128; 2] => u8;
    mapping end_approvals: [u128; 2] => u8;
    // The same status, under the pair tag, for other programs.
    mapping pair_status: field => u8;

    // -----------------------------
    // 1) Offer (employer)
    // -----------------------------
    fn create_offer(
        agreement_id: [u128; 2],
        parties_key: [u128; 2],
        employer_name_hash: field,
        worker_name_hash: field,
        worker_address: address,
        terms: OfferTerms,
        hashes: OfferHashes,
        employer_half: [u128; 4]
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
        // A zero key would give a guessable tag.
        assert(parties_key[0u32] != 0u128 || parties_key[1u32] != 0u128);

        let tag: field = pair_tag(parties_key, self.signer, worker_address);

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
            let known: u8 = pair_status.get_or_use(tag, STATUS_NONE);
            assert(known == STATUS_NONE);
            agreement_anchor_height.set(agreement_id, block.height);
            agreement_status.set(agreement_id, STATUS_PENDING);
            resume_approvals.set(agreement_id, 0u8);
            end_approvals.set(agreement_id, 0u8);
            pair_status.set(tag, STATUS_PENDING);
        });
    }

    // -----------------------------
    // 2) Accept (worker): two copies, the employer's and the worker's
    // -----------------------------
    fn accept_offer(
        offer: PendingAgreement,
        accept_time_hash: [u128; 2],
        worker_half: [u128; 4]
    ) -> (FinalAgreement, FinalAgreement, Final) {
        assert(offer.worker_address == self.signer);

        let agreement_id: [u128; 2] = offer.agreement_id;
        let tag: field = pair_tag(offer.parties_key, offer.employer_address, offer.worker_address);

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
            end_reason: END_NONE,
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
            end_reason: END_NONE,
            owner: offer.worker_address,
        };

        return (employer_copy, worker_copy, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_PENDING);
            let p: u8 = pair_status.get_or_use(tag, STATUS_NONE);
            assert(p == STATUS_PENDING);
            agreement_status.set(agreement_id, STATUS_ACTIVE);
            pair_status.set(tag, STATUS_ACTIVE);
        });
    }

    // -----------------------------
    // 3) Withdraw an offer not yet accepted (employer)
    // -----------------------------
    fn withdraw_offer(sent: SentOffer) -> Final {
        assert(sent.employer_address == self.signer);
        let agreement_id: [u128; 2] = sent.agreement_id;
        let tag: field = pair_tag(sent.parties_key, sent.employer_address, sent.worker_address);
        return final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_PENDING);
            agreement_status.set(agreement_id, STATUS_WITHDRAWN);
            pair_status.set(tag, STATUS_WITHDRAWN);
        };
    }

    // -----------------------------
    // 4) Pause and resume: each party with its own copy, which comes back
    //    to it unchanged (a fresh record, the same fields)
    // -----------------------------
    fn pause_employer(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.employer_address == self.signer);
        let agreement_id: [u128; 2] = a.agreement_id;
        let tag: field = pair_tag(a.parties_key, a.employer_address, a.worker_address);
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_ACTIVE);
            agreement_status.set(agreement_id, STATUS_PAUSED);
            pair_status.set(tag, STATUS_PAUSED);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    fn pause_worker(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.worker_address == self.signer);
        let agreement_id: [u128; 2] = a.agreement_id;
        let tag: field = pair_tag(a.parties_key, a.employer_address, a.worker_address);
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_ACTIVE);
            agreement_status.set(agreement_id, STATUS_PAUSED);
            pair_status.set(tag, STATUS_PAUSED);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    fn approve_resume_employer(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.employer_address == self.signer);
        let agreement_id: [u128; 2] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_PAUSED);
            let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
            resume_approvals.set(agreement_id, m | APPROVAL_EMPLOYER_BIT);
        });
    }

    fn approve_resume_worker(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.worker_address == self.signer);
        let agreement_id: [u128; 2] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_PAUSED);
            let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
            resume_approvals.set(agreement_id, m | APPROVAL_WORKER_BIT);
        });
    }

    // Either party, once both have approved.
    fn resume(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.employer_address == self.signer || a.worker_address == self.signer);
        let agreement_id: [u128; 2] = a.agreement_id;
        let tag: field = pair_tag(a.parties_key, a.employer_address, a.worker_address);
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_PAUSED);
            let m: u8 = resume_approvals.get_or_use(agreement_id, 0u8);
            assert(m == APPROVAL_BOTH_BITS);
            agreement_status.set(agreement_id, STATUS_ACTIVE);
            pair_status.set(tag, STATUS_ACTIVE);
            resume_approvals.set(agreement_id, 0u8);
        });
    }

    // -----------------------------
    // 5) Ending, with a reason: the ending party's copy carries it, the
    //    other party gets an AgreementEnd saying so. Active or paused.
    // -----------------------------
    fn terminate_employer(a: FinalAgreement, reason: u8) -> (FinalAgreement, AgreementEnd, Final) {
        assert(a.employer_address == self.signer);
        assert_employer_reason(reason);
        let agreement_id: [u128; 2] = a.agreement_id;
        let tag: field = pair_tag(a.parties_key, a.employer_address, a.worker_address);
        let mine: FinalAgreement = FinalAgreement {
            agreement_id: a.agreement_id,
            parties_key: a.parties_key,
            employer_name_hash: a.employer_name_hash,
            worker_name_hash: a.worker_name_hash,
            industry_code: a.industry_code,
            pay_frequency_code: a.pay_frequency_code,
            start_epoch: a.start_epoch,
            end_epoch: a.end_epoch,
            review_epoch: a.review_epoch,
            agreement_rev: a.agreement_rev,
            schema_v: a.schema_v,
            policy_v: a.policy_v,
            terms_doc_hash: a.terms_doc_hash,
            terms_root: a.terms_root,
            offer_time_hash: a.offer_time_hash,
            accept_time_hash: a.accept_time_hash,
            employer_address: a.employer_address,
            worker_address: a.worker_address,
            employer_half: a.employer_half,
            worker_half: a.worker_half,
            end_reason: reason,
            owner: a.owner,
        };
        let theirs: AgreementEnd = AgreementEnd {
            owner: a.worker_address,
            agreement_id: agreement_id,
            parties_key: a.parties_key,
            ended_by: self.signer,
            reason: reason,
        };
        return (mine, theirs, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_ACTIVE || s == STATUS_PAUSED);
            agreement_status.set(agreement_id, STATUS_ENDED);
            pair_status.set(tag, STATUS_ENDED);
            resume_approvals.set(agreement_id, 0u8);
            end_approvals.set(agreement_id, 0u8);
        });
    }

    fn terminate_worker(a: FinalAgreement, reason: u8) -> (FinalAgreement, AgreementEnd, Final) {
        assert(a.worker_address == self.signer);
        assert_worker_reason(reason);
        let agreement_id: [u128; 2] = a.agreement_id;
        let tag: field = pair_tag(a.parties_key, a.employer_address, a.worker_address);
        let mine: FinalAgreement = FinalAgreement {
            agreement_id: a.agreement_id,
            parties_key: a.parties_key,
            employer_name_hash: a.employer_name_hash,
            worker_name_hash: a.worker_name_hash,
            industry_code: a.industry_code,
            pay_frequency_code: a.pay_frequency_code,
            start_epoch: a.start_epoch,
            end_epoch: a.end_epoch,
            review_epoch: a.review_epoch,
            agreement_rev: a.agreement_rev,
            schema_v: a.schema_v,
            policy_v: a.policy_v,
            terms_doc_hash: a.terms_doc_hash,
            terms_root: a.terms_root,
            offer_time_hash: a.offer_time_hash,
            accept_time_hash: a.accept_time_hash,
            employer_address: a.employer_address,
            worker_address: a.worker_address,
            employer_half: a.employer_half,
            worker_half: a.worker_half,
            end_reason: reason,
            owner: a.owner,
        };
        let theirs: AgreementEnd = AgreementEnd {
            owner: a.employer_address,
            agreement_id: agreement_id,
            parties_key: a.parties_key,
            ended_by: self.signer,
            reason: reason,
        };
        return (mine, theirs, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_ACTIVE || s == STATUS_PAUSED);
            agreement_status.set(agreement_id, STATUS_ENDED);
            pair_status.set(tag, STATUS_ENDED);
            resume_approvals.set(agreement_id, 0u8);
            end_approvals.set(agreement_id, 0u8);
        });
    }

    fn approve_end_employer(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.employer_address == self.signer);
        let agreement_id: [u128; 2] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_ACTIVE || s == STATUS_PAUSED);
            let m: u8 = end_approvals.get_or_use(agreement_id, 0u8);
            end_approvals.set(agreement_id, m | APPROVAL_EMPLOYER_BIT);
        });
    }

    fn approve_end_worker(a: FinalAgreement) -> (FinalAgreement, Final) {
        assert(a.worker_address == self.signer);
        let agreement_id: [u128; 2] = a.agreement_id;
        return (a, final {
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_ACTIVE || s == STATUS_PAUSED);
            let m: u8 = end_approvals.get_or_use(agreement_id, 0u8);
            end_approvals.set(agreement_id, m | APPROVAL_WORKER_BIT);
        });
    }

    // Either party, once both have approved: the reason is mutual.
    fn end_mutual(a: FinalAgreement) -> (FinalAgreement, AgreementEnd, Final) {
        let is_employer: bool = a.employer_address == self.signer;
        assert(is_employer || a.worker_address == self.signer);
        let agreement_id: [u128; 2] = a.agreement_id;
        let tag: field = pair_tag(a.parties_key, a.employer_address, a.worker_address);
        let mine: FinalAgreement = FinalAgreement {
            agreement_id: a.agreement_id,
            parties_key: a.parties_key,
            employer_name_hash: a.employer_name_hash,
            worker_name_hash: a.worker_name_hash,
            industry_code: a.industry_code,
            pay_frequency_code: a.pay_frequency_code,
            start_epoch: a.start_epoch,
            end_epoch: a.end_epoch,
            review_epoch: a.review_epoch,
            agreement_rev: a.agreement_rev,
            schema_v: a.schema_v,
            policy_v: a.policy_v,
            terms_doc_hash: a.terms_doc_hash,
            terms_root: a.terms_root,
            offer_time_hash: a.offer_time_hash,
            accept_time_hash: a.accept_time_hash,
            employer_address: a.employer_address,
            worker_address: a.worker_address,
            employer_half: a.employer_half,
            worker_half: a.worker_half,
            end_reason: END_MUTUAL,
            owner: a.owner,
        };
        let other: address = is_employer ? a.worker_address : a.employer_address;
        let theirs: AgreementEnd = AgreementEnd {
            owner: other,
            agreement_id: agreement_id,
            parties_key: a.parties_key,
            ended_by: self.signer,
            reason: END_MUTUAL,
        };
        return (mine, theirs, final {
            let m: u8 = end_approvals.get_or_use(agreement_id, 0u8);
            assert(m == APPROVAL_BOTH_BITS);
            let s: u8 = agreement_status.get_or_use(agreement_id, STATUS_NONE);
            assert(s == STATUS_ACTIVE || s == STATUS_PAUSED);
            agreement_status.set(agreement_id, STATUS_ENDED);
            pair_status.set(tag, STATUS_ENDED);
            resume_approvals.set(agreement_id, 0u8);
            end_approvals.set(agreement_id, 0u8);
        });
    }

    // -----------------------------
    // 6) For other programs: the pair tag, from private inputs
    // -----------------------------

    // The caller knows the agreement's key and both accounts (it holds a
    // copy), and the agreement is active. The calling program checks which
    // party the signer is against the same inputs.
    fn assert_pair_active(parties_key: [u128; 2], employer: address, worker: address) -> Final {
        let tag: field = pair_tag(parties_key, employer, worker);
        return final {
            let p: u8 = pair_status.get_or_use(tag, STATUS_NONE);
            assert(p == STATUS_ACTIVE);
        };
    }

    // The two accounts did agree, at some point: active, paused or ended.
    // Not a pending offer, not a withdrawn one.
    fn assert_pair_agreed(parties_key: [u128; 2], employer: address, worker: address) -> Final {
        let tag: field = pair_tag(parties_key, employer, worker);
        return final {
            let p: u8 = pair_status.get_or_use(tag, STATUS_NONE);
            assert(p == STATUS_ACTIVE || p == STATUS_PAUSED || p == STATUS_ENDED);
        };
    }

    // Immutable: no admin key can change what an agreement means. A change ships as employer_agreement_v6.
    @noupgrade
    constructor() {}
}
