// Tests for hewn_cards_v1: what a card must do, and what must fail. The
// registry is the local stub, seeded with register_test_employer (a business
// name with its industry code) or register_test_name (a worker name, code 0).
// Each test runs every call's finalize in order, so a failed check fails the
// test. One signer throughout: a name someone else owns is registered to
// STRANGER, and the signer tries to use it.
import pnw_name_registry_v2.aleo;
import hewn_cards_v1.aleo;
program test_hewn_cards_v1.aleo {
    const MINE: field = 11field;    // a business .hewn name the test signer owns
    const MINE2: field = 12field;   // the signer's second business name
    const THEIRS: field = 22field;  // a business name someone else owns
    const WORKER: field = 44field;  // a worker name the test signer owns
    const THEIR_W: field = 55field; // a worker name someone else owns
    const CODE: u8 = 7u8;           // MINE's industry code
    const STRANGER: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;

    // ---- What must work ----

    @test
    fn test_business_card() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = hewn_cards_v1.aleo::issue_business_card(MINE, CODE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    fn test_two_biz_names_two_cards() -> Final {
        // A business may hold up to three names; each gets its own card.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE2, self.signer, 3u8);
        let f3: Final = hewn_cards_v1.aleo::issue_business_card(MINE, CODE);
        let f4: Final = hewn_cards_v1.aleo::issue_business_card(MINE2, 3u8);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    fn test_worker_shown_hidden_shown() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let f2: Final = hewn_cards_v1.aleo::issue_worker_card(WORKER, true);
        let f3: Final = hewn_cards_v1.aleo::hide_card(WORKER);
        let f4: Final = hewn_cards_v1.aleo::show_card(WORKER);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    fn test_worker_hidden_then_shown() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let f2: Final = hewn_cards_v1.aleo::issue_worker_card(WORKER, false);
        let f3: Final = hewn_cards_v1.aleo::show_card(WORKER);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_biz_card_unowned_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(THEIRS, STRANGER, CODE);
        let f2: Final = hewn_cards_v1.aleo::issue_business_card(THEIRS, CODE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_biz_card_unknown_fails() -> Final {
        let f1: Final = hewn_cards_v1.aleo::issue_business_card(33field, CODE);
        return final {
            f1.run();
        };
    }

    @test
    @should_fail
    fn test_biz_card_wrong_code_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = hewn_cards_v1.aleo::issue_business_card(MINE, 8u8);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_biz_card_code_zero_fails() -> Final {
        // Refused in the transition, before the registry is asked.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = hewn_cards_v1.aleo::issue_business_card(MINE, 0u8);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_biz_card_code_41_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = hewn_cards_v1.aleo::issue_business_card(MINE, 41u8);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_biz_card_on_worker_fails() -> Final {
        // A worker name has code 0 in the registry, so no business code matches it.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let f2: Final = hewn_cards_v1.aleo::issue_business_card(WORKER, CODE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_biz_card_twice_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = hewn_cards_v1.aleo::issue_business_card(MINE, CODE);
        let f3: Final = hewn_cards_v1.aleo::issue_business_card(MINE, CODE);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_worker_card_on_biz_fails() -> Final {
        // A business name's code is 1 to 40, never the 0 a worker's card checks for.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = hewn_cards_v1.aleo::issue_worker_card(MINE, true);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_worker_card_unowned_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(THEIR_W, STRANGER);
        let f2: Final = hewn_cards_v1.aleo::issue_worker_card(THEIR_W, true);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_worker_card_unknown_fails() -> Final {
        let f1: Final = hewn_cards_v1.aleo::issue_worker_card(66field, true);
        return final {
            f1.run();
        };
    }

    @test
    @should_fail
    fn test_worker_card_zero_fails() -> Final {
        let f1: Final = hewn_cards_v1.aleo::issue_worker_card(0field, true);
        return final {
            f1.run();
        };
    }

    @test
    @should_fail
    fn test_worker_card_twice_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let f2: Final = hewn_cards_v1.aleo::issue_worker_card(WORKER, true);
        let f3: Final = hewn_cards_v1.aleo::issue_worker_card(WORKER, false);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_show_before_issue_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let f2: Final = hewn_cards_v1.aleo::show_card(WORKER);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_hide_before_issue_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let f2: Final = hewn_cards_v1.aleo::hide_card(WORKER);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_show_already_shown_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let f2: Final = hewn_cards_v1.aleo::issue_worker_card(WORKER, true);
        let f3: Final = hewn_cards_v1.aleo::show_card(WORKER);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_hide_already_hidden_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let f2: Final = hewn_cards_v1.aleo::issue_worker_card(WORKER, false);
        let f3: Final = hewn_cards_v1.aleo::hide_card(WORKER);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_hide_business_card_fails() -> Final {
        // A business's card is always shown: the switch's registry check (code 0) refuses a business name.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = hewn_cards_v1.aleo::issue_business_card(MINE, CODE);
        let f3: Final = hewn_cards_v1.aleo::hide_card(MINE);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_show_others_card_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(THEIR_W, STRANGER);
        let f2: Final = hewn_cards_v1.aleo::show_card(THEIR_W);
        return final {
            f1.run();
            f2.run();
        };
    }

    @noupgrade
    constructor() {}
}
