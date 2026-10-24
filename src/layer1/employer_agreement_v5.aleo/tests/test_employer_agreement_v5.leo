// Tests for employer_agreement_v5: what an offer must carry and what must
// fail. No stubs: the program imports nothing. Every test runs as one
// signer, who can't be both employer and worker (an offer to yourself is
// refused), so acceptance and the lifecycle after it (pause, resume, the
// three ways of ending and their reasons) are checked on the network
// (docs/migrations/2026-10-23-agreement-v5.md); here: the records an offer
// mints, withdrawing, the pair tag's public state, and every refusal one
// signer can reach.
import employer_agreement_v5.aleo;

fn terms() -> employer_agreement_v5.aleo::OfferTerms {
    return employer_agreement_v5.aleo::OfferTerms {
        industry_code: 7u8, pay_frequency_code: 3u8, start_epoch: 100u32, end_epoch: 0u32, review_epoch: 100u32, agreement_rev: 1u16, schema_v: 2u16, policy_v: 1u16,
    };
}

fn hashes() -> employer_agreement_v5.aleo::OfferHashes {
    return employer_agreement_v5.aleo::OfferHashes {
        terms_doc_hash: [5u128, 55u128], terms_root: [6u128, 66u128], offer_time_hash: [7u128, 77u128],
    };
}

program test_employer_agreement_v5.aleo {
    const STRANGER: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;
    const OTHER: address = aleo1s3ws5tra87fjycnjrwsjcrnw2qxr8jfqqdugnf0xzqqw29q9m5pqem2u4t;
    const EMPLOYER_NAME: field = 11field;
    const WORKER_NAME: field = 22field;
    const KEY: [u128; 2] = [9u128, 99u128];
    const HALF: [u128; 4] = [4u128, 44u128, 444u128, 4444u128];

    // ---- What must work ----

    @test
    fn test_offer_records() -> Final {
        let (pending, sent, f) = employer_agreement_v5.aleo::create_offer([1u128, 10u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        assert_eq(pending.owner, STRANGER);
        assert_eq(pending.worker_address, STRANGER);
        assert_eq(pending.employer_address, self.signer);
        assert_eq(pending.agreement_id[0u32], 1u128);
        assert_eq(pending.agreement_id[1u32], 10u128);
        assert_eq(pending.parties_key[1u32], 99u128);
        assert_eq(pending.employer_half[3u32], 4444u128);
        assert_eq(pending.terms_doc_hash[0u32], 5u128);
        assert_eq(pending.terms_root[1u32], 66u128);
        assert_eq(pending.pay_frequency_code, 3u8);
        assert_eq(sent.owner, self.signer);
        assert_eq(sent.agreement_id[1u32], 10u128);
        assert_eq(sent.parties_key[0u32], 9u128);
        assert_eq(sent.employer_half[0u32], 4u128);
        assert_eq(sent.offer_time_hash[1u32], 77u128);
        return final {
            f.run();
        };
    }

    @test
    fn test_withdraw_pending() -> Final {
        let (pending, sent, f1) = employer_agreement_v5.aleo::create_offer([2u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let f2: Final = employer_agreement_v5.aleo::withdraw_offer(sent);
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
        let (p1, s1, f1) = employer_agreement_v5.aleo::create_offer([4u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let (p2, s2, f2) = employer_agreement_v5.aleo::create_offer([5u128, 0u128], [8u128, 88u128], EMPLOYER_NAME, WORKER_NAME, STRANGER, dated, hashes(), HALF);
        return final {
            f1.run();
            f2.run();
        };
    }

    // The same two people again (a rehire): a new id and a new key, a new tag.
    @test
    fn test_two_offers_same_pair() -> Final {
        let (p1, s1, f1) = employer_agreement_v5.aleo::create_offer([6u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let f2: Final = employer_agreement_v5.aleo::withdraw_offer(s1);
        let (p3, s3, f3) = employer_agreement_v5.aleo::create_offer([7u128, 0u128], [8u128, 88u128], EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_offer_to_self_fails() -> Final {
        let (pending, sent, f) = employer_agreement_v5.aleo::create_offer([10u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, self.signer, terms(), hashes(), HALF);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_accept_by_other_fails() -> Final {
        // The offer went to STRANGER; the signer can't accept it.
        let (pending, sent, f1) = employer_agreement_v5.aleo::create_offer([11u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let (e, w, f2) = employer_agreement_v5.aleo::accept_offer(pending, [8u128, 0u128], [3u128, 0u128, 0u128, 0u128]);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_same_id_twice_fails() -> Final {
        let (p1, s1, f1) = employer_agreement_v5.aleo::create_offer([12u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let (p2, s2, f2) = employer_agreement_v5.aleo::create_offer([12u128, 0u128], [8u128, 88u128], EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        return final {
            f1.run();
            f2.run();
        };
    }

    // A new id with a key already used: the pair tag is taken.
    @test
    @should_fail
    fn test_same_key_twice_fails() -> Final {
        let (p1, s1, f1) = employer_agreement_v5.aleo::create_offer([13u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let (p2, s2, f2) = employer_agreement_v5.aleo::create_offer([14u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_zero_key_fails() -> Final {
        let (p, s, f) = employer_agreement_v5.aleo::create_offer([15u128, 0u128], [0u128, 0u128], EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_withdraw_twice_fails() -> Final {
        let (p, s, f1) = employer_agreement_v5.aleo::create_offer([16u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let f2: Final = employer_agreement_v5.aleo::withdraw_offer(s);
        let f3: Final = employer_agreement_v5.aleo::withdraw_offer(s);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_withdrawn_not_agreed() -> Final {
        let (p, s, f1) = employer_agreement_v5.aleo::create_offer([17u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let f2: Final = employer_agreement_v5.aleo::withdraw_offer(s);
        let f3: Final = employer_agreement_v5.aleo::assert_pair_agreed(KEY, self.signer, STRANGER);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_withdrawn_not_active() -> Final {
        let (p, s, f1) = employer_agreement_v5.aleo::create_offer([18u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let f2: Final = employer_agreement_v5.aleo::withdraw_offer(s);
        let f3: Final = employer_agreement_v5.aleo::assert_pair_active(KEY, self.signer, STRANGER);
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
        let (p, s, f) = employer_agreement_v5.aleo::create_offer([19u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, bad, hashes(), HALF);
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
        let (p, s, f) = employer_agreement_v5.aleo::create_offer([20u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, bad, hashes(), HALF);
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
        let (p, s, f) = employer_agreement_v5.aleo::create_offer([21u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, bad, hashes(), HALF);
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
        let (p, s, f) = employer_agreement_v5.aleo::create_offer([22u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, bad, hashes(), HALF);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_unknown_pair_not_active() -> Final {
        let f: Final = employer_agreement_v5.aleo::assert_pair_active([99u128, 0u128], self.signer, STRANGER);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_unknown_pair_not_agreed() -> Final {
        let f: Final = employer_agreement_v5.aleo::assert_pair_agreed([99u128, 0u128], self.signer, STRANGER);
        return final {
            f.run();
        };
    }

    @test
    @should_fail
    fn test_pending_not_active() -> Final {
        let (p, s, f1) = employer_agreement_v5.aleo::create_offer([23u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let f2: Final = employer_agreement_v5.aleo::assert_pair_active(KEY, self.signer, STRANGER);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_pending_not_agreed() -> Final {
        let (p, s, f1) = employer_agreement_v5.aleo::create_offer([24u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let f2: Final = employer_agreement_v5.aleo::assert_pair_agreed(KEY, self.signer, STRANGER);
        return final {
            f1.run();
            f2.run();
        };
    }

    // The right people, the wrong key: another tag, unknown.
    @test
    @should_fail
    fn test_wrong_key_not_active() -> Final {
        let (p, s, f1) = employer_agreement_v5.aleo::create_offer([25u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let f2: Final = employer_agreement_v5.aleo::assert_pair_active([8u128, 88u128], self.signer, STRANGER);
        return final {
            f1.run();
            f2.run();
        };
    }

    // The right key, the wrong worker: another tag, unknown.
    @test
    @should_fail
    fn test_wrong_worker_not_agreed() -> Final {
        let (p, s, f1) = employer_agreement_v5.aleo::create_offer([26u128, 0u128], KEY, EMPLOYER_NAME, WORKER_NAME, STRANGER, terms(), hashes(), HALF);
        let f2: Final = employer_agreement_v5.aleo::assert_pair_agreed(KEY, self.signer, OTHER);
        return final {
            f1.run();
            f2.run();
        };
    }

    @noupgrade
    constructor() {}
}
