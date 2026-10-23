// Tests for employer_agreement_v5: what an offer must carry and what must
// fail. No stubs: the program imports nothing. Every test runs as one
// signer, who can't be both employer and worker (an offer to yourself is
// refused), so acceptance and the lifecycle after it are checked on the
// network (docs/migrations/2026-10-23-agreement-v5.md); here: the records
// an offer mints, withdrawing, the public state, and every refusal that one
// signer can reach.
import employer_agreement_v5.aleo;
program test_employer_agreement_v5.aleo {
    const STRANGER: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;
    const EMPLOYER_NAME: field = 11field;
    const WORKER_NAME: field = 22field;

    // ---- What must work ----

    @test
    fn test_offer_records() -> Final {
        let (pending, sent, f) = employer_agreement_v5.aleo::create_offer([1u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        assert_eq(pending.owner, STRANGER);
        assert_eq(pending.worker_address, STRANGER);
        assert_eq(pending.employer_address, self.signer);
        assert_eq(pending.employer_half[63u32], 4u8);
        assert_eq(pending.parties_key[0u32], 9u8);
        assert_eq(pending.terms_doc_hash[0u32], 5u8);
        assert_eq(sent.owner, self.signer);
        assert_eq(sent.agreement_id[0u32], 1u8);
        assert_eq(sent.employer_half[0u32], 4u8);
        return final {
            f.run();
        };
    }

    @test
    fn test_withdraw_pending() -> Final {
        let (pending, sent, f1) = employer_agreement_v5.aleo::create_offer([2u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        let f2: Final = employer_agreement_v5.aleo::withdraw_offer(sent);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    fn test_offer_is_anchored() -> Final {
        let (pending, sent, f1) = employer_agreement_v5.aleo::create_offer([3u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        let f2: Final = employer_agreement_v5.aleo::assert_agreement_anchored([3u8; 32]);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    fn test_open_and_dated_offers() -> Final {
        let dated: employer_agreement_v5.aleo::OfferTerms = employer_agreement_v5.aleo::OfferTerms {
            industry_code: 7u8, pay_frequency_code: 2u8, start_epoch: 100u32, end_epoch: 500u32, review_epoch: 300u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16,
        };
        let (p1, s1, f1) = employer_agreement_v5.aleo::create_offer([4u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        let (p2, s2, f2) = employer_agreement_v5.aleo::create_offer([5u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, dated, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        return final {
            f1.run();
            f2.run();
        };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_offer_to_self_fails() -> Final {
        let (pending, sent, f) = employer_agreement_v5.aleo::create_offer([10u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, self.signer, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_accept_by_other_fails() -> Final {
        // The offer went to STRANGER; the signer can't accept it.
        let (pending, sent, f1) = employer_agreement_v5.aleo::create_offer([11u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        let (e, w, f2) = employer_agreement_v5.aleo::accept_offer(pending, [8u8; 32], [3u8; 64]);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_same_id_twice_fails() -> Final {
        let (p1, s1, f1) = employer_agreement_v5.aleo::create_offer([12u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        let (p2, s2, f2) = employer_agreement_v5.aleo::create_offer([12u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_withdrawn_not_active() -> Final {
        let (p1, s1, f1) = employer_agreement_v5.aleo::create_offer([13u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        let f2: Final = employer_agreement_v5.aleo::withdraw_offer(s1);
        let f3: Final = employer_agreement_v5.aleo::assert_agreement_active([13u8; 32]);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_bad_frequency_fails() -> Final {
        let bad: employer_agreement_v5.aleo::OfferTerms = employer_agreement_v5.aleo::OfferTerms {
            industry_code: 7u8, pay_frequency_code: 9u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16,
        };
        let (p, s, f) = employer_agreement_v5.aleo::create_offer([15u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, bad, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_end_before_start_fails() -> Final {
        let bad: employer_agreement_v5.aleo::OfferTerms = employer_agreement_v5.aleo::OfferTerms {
            industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 50u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16,
        };
        let (p, s, f) = employer_agreement_v5.aleo::create_offer([16u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, bad, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_review_before_start_fails() -> Final {
        let bad: employer_agreement_v5.aleo::OfferTerms = employer_agreement_v5.aleo::OfferTerms {
            industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 99u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16,
        };
        let (p, s, f) = employer_agreement_v5.aleo::create_offer([17u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, bad, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_zero_revision_fails() -> Final {
        let bad: employer_agreement_v5.aleo::OfferTerms = employer_agreement_v5.aleo::OfferTerms {
            industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 0u16, schema_v: 2u16, policy_v: 1u16,
        };
        let (p, s, f) = employer_agreement_v5.aleo::create_offer([18u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, bad, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_unknown_not_anchored() -> Final {
        let f: Final = employer_agreement_v5.aleo::assert_agreement_anchored([99u8; 32]);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_pending_is_not_active() -> Final {
        let (p, s, f1) = employer_agreement_v5.aleo::create_offer([19u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        let f2: Final = employer_agreement_v5.aleo::assert_agreement_active([19u8; 32]);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_wrong_key_not_authorized() -> Final {
        let (p, s, f1) = employer_agreement_v5.aleo::create_offer([20u8; 32], [9u8; 32], EMPLOYER_NAME, WORKER_NAME, STRANGER, employer_agreement_v5.aleo::OfferTerms { industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16 }, employer_agreement_v5.aleo::OfferHashes { terms_doc_hash: [5u8; 32], terms_root: [6u8; 32], offer_time_hash: [7u8; 32] }, [4u8; 64]);
        let f2: Final = employer_agreement_v5.aleo::assert_employer_authorized([20u8; 32], [8u8; 32], EMPLOYER_NAME, WORKER_NAME);
        return final {
            f1.run();
            f2.run();
        };
    }

    @noupgrade
    constructor() {}
}
