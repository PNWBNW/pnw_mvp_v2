// Tests for pnw_worker_profiles_v2, the deployed worker-profile program
// (tests only; the program is never edited). What creating and updating a
// profile must do, and what must fail.
//
// The profile belongs to `self.caller`, who must own the worker name in the
// registry; inside a test the caller is this test program, so the registry is
// the local stub in src/stubs, seeded with its test-only `register_test_name`
// (its `assert_is_owner` is the deployed one). The program copy under test
// has @noupgrade in place of @admin (the local ledger refuses an @admin
// program whose deployer isn't the admin); everything else is as deployed.
//
// Every identity field here is a placeholder number: the point is what the
// program checks, and that nothing but the anchor's height reaches public
// state. What this can't show: `update_worker_profile`. It consumes the
// record `create` minted to `self.caller`, and inside a test the caller is
// this program, whose records no signer can spend ("input record must belong
// to the signer"), so every update call is refused before the program's own
// checks run. Its guards are the same asserts as create's, tested here; the
// revision-must-climb and owner checks are read, not run.
import pnw_name_registry_v2.aleo;
import pnw_worker_profiles_v2.aleo;
program test_pnw_worker_profiles_v2.aleo {
    const W1: field = 11field;
    const W2: field = 12field;
    const STRANGER: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;
    const ANCHOR: [u8; 32] = [7u8; 32];
    const ANCHOR2: [u8; 32] = [8u8; 32];
    // Placeholder identity fields.
    const FIRST: u128 = 101u128;
    const MIDDLE: u128 = 102u128;
    const LAST: u128 = 103u128;
    const AGE: u8 = 34u8;
    const FEMALE: u8 = 2u8;
    const PREFER_NOT: u8 = 3u8;
    const STATE: u16 = 53u16;
    const COUNTRY: u16 = 840u16;
    const STATE_ID: u128 = 9_001u128;
    const INDUSTRY: u8 = 7u8;
    const CITIZEN: u8 = 1u8;
    const SCHEMA: u16 = 1u16;
    const POLICY: u16 = 1u16;

    // ---- What must work ----

    @test
    fn test_create() -> Final {
        let me: address = self.address;
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, me);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        let f3: Final = pnw_worker_profiles_v2.aleo::assert_profile_anchored(ANCHOR);
        // The record is the caller's, bound to the name, at revision 1; the height lives in the mapping.
        assert_eq(rec.owner, me);
        assert_eq(rec.worker_name_hash, W1);
        assert_eq(rec.profile_rev, 1u16);
        assert_eq(rec.issued_height, 0u32);
        assert_eq(rec.profile_anchor, ANCHOR);
        return final {
            f1.run(); f2.run(); f3.run();
            assert_neq(pnw_worker_profiles_v2.aleo::profile_anchor_height.get(ANCHOR), 0u32);
        };
    }

    @test
    fn test_create_edges() -> Final {
        // Age 120 and "prefer not to say" are the last allowed values.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, 120u8, PREFER_NOT, 1u16, 1u16, 0u128, 1u8, 0u8, 1u16, 1u16, 1u16, ANCHOR);
        assert_eq(rec.age, 120u8);
        assert_eq(rec.gender, PREFER_NOT);
        return final { f1.run(); f2.run(); };
    }

    @test
    fn test_create_male() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, 0u8, 1u8, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        assert_eq(rec.gender, 1u8);
        return final { f1.run(); f2.run(); };
    }

    @test
    fn test_worker_exists() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        let f3: Final = pnw_worker_profiles_v2.aleo::assert_worker_exists(ANCHOR);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    fn test_two_profiles_one_name() -> Final {
        // Recorded as it is: nothing on chain limits a name to one profile, and an anchor
        // seen twice keeps its first height (the same block here, so only "still anchored" shows).
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (r1, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        let (r2, f3) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        let f4: Final = pnw_worker_profiles_v2.aleo::assert_profile_anchored(ANCHOR);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_create_unregistered_fails() -> Final {
        // No one owns the name.
        let (rec, f1) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_create_not_owner_fails() -> Final {
        // Someone else owns the name.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, STRANGER);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_create_other_name_fails() -> Final {
        // Owning one name doesn't cover another.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W2, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_gender_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, 0u8, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_gender_4_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, 4u8, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_age_121_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, 121u8, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_state_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, 0u16, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_country_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, 0u16, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_industry_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, 0u8, CITIZEN, SCHEMA, POLICY, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_schema_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, 0u16, POLICY, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_policy_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, 0u16, 1u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_rev_0_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(W1, self.address);
        let (rec, f2) = pnw_worker_profiles_v2.aleo::create_worker_profile(
            W1, FIRST, MIDDLE, LAST, AGE, FEMALE, STATE, COUNTRY, STATE_ID, INDUSTRY, CITIZEN, SCHEMA, POLICY, 0u16, ANCHOR);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_anchored_unknown_fails() -> Final {
        let f1: Final = pnw_worker_profiles_v2.aleo::assert_profile_anchored(ANCHOR2);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_exists_unknown_fails() -> Final {
        let f1: Final = pnw_worker_profiles_v2.aleo::assert_worker_exists(ANCHOR2);
        return final { f1.run(); };
    }

    @noupgrade
    constructor() {}
}
