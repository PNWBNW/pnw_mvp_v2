// Tests for pnw_name_registry_v2, the deployed registry (tests only; the
// program is never edited). What a registration must do, and what must fail.
//
// The registry's writes are gated on `self.caller` being the authorised
// registrar or ADMIN, and a program's caller inside a test is the test program
// itself. So the plan gate runs these against a copy whose ADMIN constant is
// this test program's address (aleo1lmfa…, which `self.address` yields for
// `test_pnw_name_registry_v2.aleo`), and the first test makes it the registrar
// too. Everything else is the program as deployed. What this can't show: a
// stranger program being refused as registrar, since the one caller here is
// always the admin.
//
// Owners: `self.address` (the test program) is "the caller owns it", so the
// paths a name's owner calls directly (release, sellback, set primary) can be
// exercised; `self.signer` and STRANGER are names someone else owns.
import pnw_name_registry_v2.aleo;
program test_pnw_name_registry_v2.aleo {
    const W1: field = 11field;
    const W2: field = 12field;
    const E1: field = 21field;
    const E2: field = 22field;
    const E3: field = 23field;
    const E4: field = 24field;
    const CODE: u8 = 7u8;
    const PRICE: u128 = 1_000_000u128;
    const STRANGER: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;

    // ---- What must work ----

    @test
    fn test_set_registrar_and_register() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::set_authorized_caller(self.address);
        let f2: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.signer);
        return final { f1.run(); f2.run(); };
    }

    @test
    fn test_three_employer_names() -> Final {
        // A business may hold up to three names; the count the app passes must match the chain's.
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::register_employer_name(E2, 3u8, 1u8, PRICE, self.signer);
        let f3: Final = pnw_name_registry_v2.aleo::register_employer_name(E3, 40u8, 2u8, PRICE, self.signer);
        let f4: Final = pnw_name_registry_v2.aleo::assert_employer_owner(E3, self.signer, 40u8);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    fn test_worker_name_code_zero_ok() -> Final {
        // A worker name's suffix is 0, which is what hewn_cards_v1 passes for a worker card.
        let f1: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::assert_employer_owner(W1, self.signer, 0u8);
        return final { f1.run(); f2.run(); };
    }

    @test
    fn test_free_name_refund_zero() -> Final {
        // Free registration (since 2026-10-15) records a price of 0; the refund is 0 too.
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, 0u128, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::request_empl_sellback(E1);
        let f3: Final = pnw_name_registry_v2.aleo::fulfill_empl_sellback(E1, self.address, 0u128);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    fn test_sellback_refund_75() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::request_empl_sellback(E1);
        let f3: Final = pnw_name_registry_v2.aleo::fulfill_empl_sellback(E1, self.address, 750_000u128);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    fn test_sold_back_name_free_again() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::request_empl_sellback(E1);
        let f3: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, 5u8, 0u8, PRICE, self.signer);
        let f4: Final = pnw_name_registry_v2.aleo::assert_employer_owner(E1, self.signer, 5u8);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    fn test_count_drops_on_sellback() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::register_employer_name(E2, CODE, 1u8, PRICE, self.address);
        let f3: Final = pnw_name_registry_v2.aleo::request_empl_sellback(E1);
        let f4: Final = pnw_name_registry_v2.aleo::register_employer_name(E3, CODE, 1u8, PRICE, self.address);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    fn test_release_frees_name() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::release_worker_name();
        let f3: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.signer);
        let f4: Final = pnw_name_registry_v2.aleo::assert_is_owner(W1, self.signer);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    fn test_release_then_another() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::release_worker_name();
        let f3: Final = pnw_name_registry_v2.aleo::register_worker_name(W2, self.address);
        let f4: Final = pnw_name_registry_v2.aleo::assert_is_owner(W2, self.address);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    fn test_set_primary() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::register_employer_name(E2, 3u8, 1u8, PRICE, self.address);
        let f3: Final = pnw_name_registry_v2.aleo::set_primary_employer_name(E2);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_worker_second_name_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::register_worker_name(W2, self.signer);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_worker_name_taken_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, STRANGER);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_empl_name_taken_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, STRANGER);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_worker_takes_empl_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::register_worker_name(E1, STRANGER);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_suffix_zero_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, 0u8, 0u8, PRICE, self.signer);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_suffix_41_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, 41u8, 0u8, PRICE, self.signer);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_count_mismatch_fails() -> Final {
        // The app says this is the second name; the chain holds none.
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 1u8, PRICE, self.signer);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_fourth_name_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::register_employer_name(E2, CODE, 1u8, PRICE, self.signer);
        let f3: Final = pnw_name_registry_v2.aleo::register_employer_name(E3, CODE, 2u8, PRICE, self.signer);
        let f4: Final = pnw_name_registry_v2.aleo::register_employer_name(E4, CODE, 3u8, PRICE, self.signer);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    @should_fail
    fn test_release_no_name_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::release_worker_name();
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_release_not_mine_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::release_worker_name();
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_sellback_not_owner_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::request_empl_sellback(E1);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_sellback_worker_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::request_empl_sellback(W1);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_fulfill_no_request_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::fulfill_empl_sellback(E1, self.address, 750_000u128);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_fulfill_wrong_refund_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::request_empl_sellback(E1);
        let f3: Final = pnw_name_registry_v2.aleo::fulfill_empl_sellback(E1, self.address, PRICE);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_fulfill_wrong_seller_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::request_empl_sellback(E1);
        let f3: Final = pnw_name_registry_v2.aleo::fulfill_empl_sellback(E1, STRANGER, 750_000u128);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_primary_not_owner_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::set_primary_employer_name(E1);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_primary_worker_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::set_primary_employer_name(W1);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_owner_wrong_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_worker_name(W1, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::assert_is_owner(W1, STRANGER);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_empl_wrong_code_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.signer);
        let f2: Final = pnw_name_registry_v2.aleo::assert_employer_owner(E1, self.signer, 8u8);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_empl_after_sellback_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_employer_name(E1, CODE, 0u8, PRICE, self.address);
        let f2: Final = pnw_name_registry_v2.aleo::request_empl_sellback(E1);
        let f3: Final = pnw_name_registry_v2.aleo::assert_employer_owner(E1, self.address, CODE);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @noupgrade
    constructor() {}
}
