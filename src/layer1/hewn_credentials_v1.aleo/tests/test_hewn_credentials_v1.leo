// Tests for hewn_credentials_v1: what a credential must do, and what must
// fail. The agreement program is the local stub, seeded with set_test_pair
// (a parties key, the two accounts, a status). One signer throughout: on the
// network it can't be both employer and worker (employer_agreement_v5
// refuses an offer to yourself), so where a test has to spend the subject's
// copy the stub seeds the signer on both sides; the wrong-copy refusals the
// network enforces by record ownership are checked here through the role
// byte. Each test runs every call's finalize in order, so a failed check
// fails the test.
import employer_agreement_v5.aleo;
import hewn_credentials_v1.aleo;
program test_hewn_credentials_v1.aleo {
    const STRANGER: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;
    const OTHER: address = aleo1s3ws5tra87fjycnjrwsjcrnw2qxr8jfqqdugnf0xzqqw29q9m5pqem2u4t;
    const KEY: [u128; 2] = [9u128, 99u128];
    const KEY2: [u128; 2] = [8u128, 88u128];
    const SCOPE: [u128; 2] = [5u128, 55u128];
    const NONCE: [u128; 2] = [7u128, 77u128];
    const NONCE2: [u128; 2] = [0u128, 2u128];
    // employer_agreement_v5's pair statuses
    const PENDING: u8 = 0u8;
    const ACTIVE: u8 = 1u8;
    const PAUSED: u8 = 2u8;
    const ENDED: u8 = 3u8;
    const WITHDRAWN: u8 = 4u8;
    // this program's kinds
    const EMPLOYMENT: u8 = 1u8;
    const SKILLS: u8 = 2u8;
    const CLEARANCE: u8 = 3u8;
    const CUSTOM: u8 = 4u8;

    // ---- What must work ----

    @test
    fn test_issue_records() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        assert_eq(i.owner, self.signer);
        assert_eq(i.role, 1u8);
        assert_eq(i.issuer, self.signer);
        assert_eq(i.subject, STRANGER);
        assert_eq(s.owner, STRANGER);
        assert_eq(s.role, 2u8);
        assert_eq(s.issuer, self.signer);
        assert_eq(s.subject, STRANGER);
        assert_eq(s.kind, EMPLOYMENT);
        assert_eq(s.scope[1u32], 55u128);
        assert_eq(s.nonce[0u32], 7u128);
        assert_eq(i.commitment, s.commitment);
        return final {
            f1.run();
            f2.run();
        };
    }

    // A past employer may still vouch: paused and ended agreements count, as active ones do.
    @test
    fn test_issue_paused_and_ended() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, PAUSED);
        let (i1, s1, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, SKILLS, SCOPE, NONCE);
        let f3: Final = employer_agreement_v5.aleo::set_test_pair(KEY2, self.signer, OTHER, ENDED);
        let (i2, s2, f4) = hewn_credentials_v1.aleo::issue(KEY2, OTHER, CLEARANCE, SCOPE, NONCE2);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    // Every kind, and two credentials of the same kind to the same person (two jobs, two cabins).
    @test
    fn test_every_kind_and_twice() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i1, s1, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, [1u128, 0u128]);
        let (i2, s2, f3) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, SKILLS, SCOPE, [2u128, 0u128]);
        let (i3, s3, f4) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, CLEARANCE, SCOPE, [3u128, 0u128]);
        let (i4, s4, f5) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, CUSTOM, SCOPE, [4u128, 0u128]);
        let (i5, s5, f6) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, [5u128, 0u128]);
        assert_neq(i1.commitment, i5.commitment);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
            f5.run();
            f6.run();
        };
    }

    @test
    fn test_accept() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let (kept, f3) = hewn_credentials_v1.aleo::accept(s);
        assert_eq(kept.commitment, s.commitment);
        assert_eq(kept.role, 2u8);
        assert_eq(kept.owner, self.signer);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    fn test_decline() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, SKILLS, SCOPE, NONCE);
        let f3: Final = hewn_credentials_v1.aleo::decline(s);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    fn test_revoke_offered() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        let f3: Final = hewn_credentials_v1.aleo::revoke(i);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    fn test_revoke_active() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let (kept, f3) = hewn_credentials_v1.aleo::accept(s);
        let f4: Final = hewn_credentials_v1.aleo::revoke(i);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    fn test_active_stands() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, CLEARANCE, SCOPE, NONCE);
        let (kept, f3) = hewn_credentials_v1.aleo::accept(s);
        let f4: Final = hewn_credentials_v1.aleo::assert_active(kept.commitment);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_issue_pending_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, PENDING);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_issue_withdrawn_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, WITHDRAWN);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_issue_no_agreement_fails() -> Final {
        let (i, s, f) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        return final {
            f.run();
        };
    }

    // The signer is the worker of the agreement, not its employer: a worker can't vouch for themself.
    @test
    @should_fail
    fn test_issue_as_worker_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, STRANGER, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        return final {
            f1.run();
            f2.run();
        };
    }

    // The agreement is with STRANGER; the credential goes to OTHER.
    @test
    @should_fail
    fn test_issue_other_subject_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, OTHER, EMPLOYMENT, SCOPE, NONCE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_issue_wrong_key_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY2, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_kind_zero_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, 0u8, SCOPE, NONCE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_kind_five_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, 5u8, SCOPE, NONCE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_zero_nonce_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, [0u128, 0u128]);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_same_commitment_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i1, s1, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        let (i2, s2, f3) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_accept_twice_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let (kept, f3) = hewn_credentials_v1.aleo::accept(s);
        let (again, f4) = hewn_credentials_v1.aleo::accept(kept);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    @should_fail
    fn test_accept_issuer_copy_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let (kept, f3) = hewn_credentials_v1.aleo::accept(i);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_decline_after_accept_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let (kept, f3) = hewn_credentials_v1.aleo::accept(s);
        let f4: Final = hewn_credentials_v1.aleo::decline(kept);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    @should_fail
    fn test_decline_issuer_copy_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let f3: Final = hewn_credentials_v1.aleo::decline(i);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_revoke_subject_copy_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let f3: Final = hewn_credentials_v1.aleo::revoke(s);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_revoke_declined_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let f3: Final = hewn_credentials_v1.aleo::decline(s);
        let f4: Final = hewn_credentials_v1.aleo::revoke(i);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    @should_fail
    fn test_accept_revoked_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let f3: Final = hewn_credentials_v1.aleo::revoke(i);
        let (kept, f4) = hewn_credentials_v1.aleo::accept(s);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    @should_fail
    fn test_offered_not_active_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, STRANGER, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, STRANGER, EMPLOYMENT, SCOPE, NONCE);
        let f3: Final = hewn_credentials_v1.aleo::assert_active(i.commitment);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_revoked_not_active_fails() -> Final {
        let f1: Final = employer_agreement_v5.aleo::set_test_pair(KEY, self.signer, self.signer, ACTIVE);
        let (i, s, f2) = hewn_credentials_v1.aleo::issue(KEY, self.signer, EMPLOYMENT, SCOPE, NONCE);
        let (kept, f3) = hewn_credentials_v1.aleo::accept(s);
        let f4: Final = hewn_credentials_v1.aleo::revoke(i);
        let f5: Final = hewn_credentials_v1.aleo::assert_active(kept.commitment);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
            f5.run();
        };
    }

    @test
    @should_fail
    fn test_unknown_not_active_fails() -> Final {
        let f: Final = hewn_credentials_v1.aleo::assert_active(123field);
        return final {
            f.run();
        };
    }

    @noupgrade
    constructor() {}
}
