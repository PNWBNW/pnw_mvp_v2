// Tests for employer_agreement_v4 (edition 2), the deployed agreement program
// Hewn still reads and the one its earlier agreements were made with (tests
// only; the program is never edited). What an offer must do, what the
// lifecycle calls must do from the state a test can reach, and what must fail.
//
// Inside a test the caller is this test program, so the registry and the
// licence registry are the stubs in src/stubs, seeded with their test-only
// `register_test_name` and `set_test_verified` (their `assert_is_owner` and
// `assert_verified` are the deployed ones). The program copy under test has
// @noupgrade in place of @admin (the local ledger refuses an @admin program
// whose deployer isn't the admin); everything else is as deployed.
//
// What this can't show: `accept_job_offer`. It consumes the PendingAgreement
// record the offer minted to the worker, and a record minted inside a test
// belongs to this program, which no signer can spend. So no test reaches
// ACTIVE, and the paths that need it (pause, approving and completing a
// resume, `assert_agreement_active`, `assert_employer_authorized`) are shown
// refusing from PENDING, not succeeding. Terminate and supersede work from
// PENDING and are shown doing so. employer_agreement_v5, the successor, has
// the full lifecycle under test.
import pnw_name_registry_v2.aleo;
import employer_license_registry.aleo;
import employer_agreement_v4.aleo;
program test_employer_agreement_v4.aleo {
    const ID: [u8; 32] = [1u8; 32];
    const ID2: [u8; 32] = [2u8; 32];
    const ID3: [u8; 32] = [3u8; 32];
    const ID4: [u8; 32] = [4u8; 32];
    const ID5: [u8; 32] = [5u8; 32];
    const KEY: [u8; 32] = [50u8; 32];
    const KEY2: [u8; 32] = [51u8; 32];
    const EMP: field = 21field;
    const WRK: field = 11field;
    const STRANGER: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;
    const DOC: [u8; 32] = [9u8; 32];
    const ROOT: [u8; 32] = [10u8; 32];
    const TIME: [u8; 32] = [11u8; 32];
    const INDUSTRY: u8 = 7u8;
    const WEEKLY: u8 = 2u8;
    const START: u32 = 100u32;
    const END: u32 = 200u32;
    const REVIEW: u32 = 150u32;
    const REV: u16 = 1u16;
    const SCHEMA: u16 = 1u16;
    const POLICY: u16 = 1u16;
    const PENDING: u8 = 0u8;
    const TERMINATED: u8 = 3u8;
    const SUPERSEDED: u8 = 4u8;

    // ---- What must work ----

    @test
    fn test_offer_open() -> Final {
        // The free path Hewn uses: the business owns its name; the offer is minted to the worker.
        let me: address = self.address;
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, me);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        assert_eq(offer.owner, STRANGER);
        assert_eq(offer.worker_address, STRANGER);
        assert_eq(offer.employer_address, me);
        assert_eq(offer.agreement_id, ID);
        assert_eq(offer.parties_key, KEY);
        assert_eq(offer.offer_height, 0u32);
        return final {
            f1.run(); f2.run();
            // Public: the anchor's height, a commitment, the status, and no approvals. Nothing names the two.
            assert_neq(employer_agreement_v4.aleo::agreement_anchor_height.get(ID), 0u32);
            assert_neq(employer_agreement_v4.aleo::agreement_parties_commitment.get(ID), 0field);
            assert_eq(employer_agreement_v4.aleo::agreement_status.get(ID), PENDING);
            assert_eq(employer_agreement_v4.aleo::resume_approvals.get(ID), 0u8);
        };
    }

    @test
    fn test_offer_open_ended() -> Final {
        // No end date (0) is allowed, and the review may fall on the start.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, 0u32, START, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        assert_eq(offer.end_epoch, 0u32);
        return final { f1.run(); f2.run(); };
    }

    @test
    fn test_offer_licensed() -> Final {
        // The gated original: a licence flag and the name.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let f2: Final = employer_license_registry.aleo::set_test_verified(self.address, true);
        let (offer, f3) = employer_agreement_v4.aleo::create_job_offer(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final {
            f1.run(); f2.run(); f3.run();
            assert_eq(employer_agreement_v4.aleo::agreement_status.get(ID), PENDING);
        };
    }

    @test
    fn test_pay_frequencies() -> Final {
        // Daily to quarterly, one offer each.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (o1, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, 1u8, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let (o2, f3) = employer_agreement_v4.aleo::create_offer_open(
            ID2, KEY, EMP, WRK, STRANGER, INDUSTRY, 2u8, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let (o3, f4) = employer_agreement_v4.aleo::create_offer_open(
            ID3, KEY, EMP, WRK, STRANGER, INDUSTRY, 3u8, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let (o4, f5) = employer_agreement_v4.aleo::create_offer_open(
            ID4, KEY, EMP, WRK, STRANGER, INDUSTRY, 4u8, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let (o5, f6) = employer_agreement_v4.aleo::create_offer_open(
            ID5, KEY, EMP, WRK, STRANGER, INDUSTRY, 5u8, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final {
            f1.run(); f2.run(); f3.run(); f4.run(); f5.run(); f6.run();
            assert_neq(employer_agreement_v4.aleo::agreement_anchor_height.get(ID5), 0u32);
        };
    }

    @test
    fn test_anchored() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::assert_agreement_anchored(ID);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    fn test_terminate_open_pending() -> Final {
        // A business may withdraw an offer: terminate works from PENDING.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::terminate_employer_open(ID, KEY, EMP, WRK);
        return final {
            f1.run(); f2.run(); f3.run();
            assert_eq(employer_agreement_v4.aleo::agreement_status.get(ID), TERMINATED);
            assert_eq(employer_agreement_v4.aleo::resume_approvals.get(ID), 0u8);
        };
    }

    @test
    fn test_terminate_worker_pending() -> Final {
        // The worker may decline the same way, owning the worker name.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::register_test_name(WRK, self.address);
        let (offer, f3) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f4: Final = employer_agreement_v4.aleo::terminate_agreement_worker(ID, KEY, EMP, WRK);
        return final {
            f1.run(); f2.run(); f3.run(); f4.run();
            assert_eq(employer_agreement_v4.aleo::agreement_status.get(ID), TERMINATED);
        };
    }

    @test
    fn test_supersede_pending() -> Final {
        // Anyone who knows the parties key may mark an agreement superseded; it isn't name-gated.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::supersede_agreement(ID, KEY, EMP, WRK);
        return final {
            f1.run(); f2.run(); f3.run();
            assert_eq(employer_agreement_v4.aleo::agreement_status.get(ID), SUPERSEDED);
        };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_offer_not_owner_fails() -> Final {
        // Someone else owns the business name.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, STRANGER);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_offer_unregistered_fails() -> Final {
        let (offer, f1) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_offer_dup_id_fails() -> Final {
        // An agreement id anchors once.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (o1, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let (o2, f3) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY2, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_offer_freq_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, 0u8, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_offer_freq_6_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, 6u8, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_offer_rev_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, 0u16, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_offer_schema_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, 0u16, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_offer_policy_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, 0u16, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_offer_end_early_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, 50u32, START, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_offer_end_eq_start_fails() -> Final {
        // An end date must come after the start; the same day isn't an agreement.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, START, START, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_offer_review_early_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, 99u32, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_offer_unlicensed_fails() -> Final {
        // The gated original without the licence flag.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_job_offer(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_pause_pending_fails() -> Final {
        // Only an ACTIVE agreement pauses.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::pause_employer_open(ID, KEY, EMP, WRK);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_resume_pending_fails() -> Final {
        // Only a PAUSED agreement takes a resume approval.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::resume_employer_open(ID, KEY, EMP, WRK);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_terminate_twice_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::terminate_employer_open(ID, KEY, EMP, WRK);
        let f4: Final = employer_agreement_v4.aleo::terminate_employer_open(ID, KEY, EMP, WRK);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    @should_fail
    fn test_terminate_wrong_key_fails() -> Final {
        // The parties key must reproduce the stored commitment.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::terminate_employer_open(ID, KEY2, EMP, WRK);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_terminate_not_owner_fails() -> Final {
        // The business name changed hands after the offer.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, STRANGER);
        let f4: Final = employer_agreement_v4.aleo::terminate_employer_open(ID, KEY, EMP, WRK);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    @should_fail
    fn test_terminate_unknown_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let f2: Final = employer_agreement_v4.aleo::terminate_employer_open(ID, KEY, EMP, WRK);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_supersede_twice_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::supersede_agreement(ID, KEY, EMP, WRK);
        let f4: Final = employer_agreement_v4.aleo::supersede_agreement(ID, KEY, EMP, WRK);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    @should_fail
    fn test_active_pending_fails() -> Final {
        // A pending offer isn't an active agreement.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::assert_agreement_active(ID);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_authorized_pending_fails() -> Final {
        // Nor does it authorise the employer downstream.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::assert_employer_authorized(ID, KEY, EMP, WRK);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_anchored_unknown_fails() -> Final {
        let f1: Final = employer_agreement_v4.aleo::assert_agreement_anchored(ID);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_dao_terminate_fails() -> Final {
        // The DAO paths take the DAO's own address as caller, which this test isn't.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(EMP, self.address);
        let (offer, f2) = employer_agreement_v4.aleo::create_offer_open(
            ID, KEY, EMP, WRK, STRANGER, INDUSTRY, WEEKLY, START, END, REVIEW, REV, SCHEMA, POLICY, DOC, ROOT, TIME);
        let f3: Final = employer_agreement_v4.aleo::terminate_agreement_dao(ID, KEY, EMP, WRK);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @noupgrade
    constructor() {}
}
