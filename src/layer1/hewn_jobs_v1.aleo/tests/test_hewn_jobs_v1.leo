// Tests for hewn_jobs_v1: what a posting must do, and what must fail. The
// registry is the local stub, seeded with register_test_employer (a business
// name with its industry code) or register_test_name (a worker name). Each
// test runs every call's finalize in order, so a failed check fails the test.
import pnw_name_registry_v2.aleo;
import hewn_jobs_v1.aleo;
program test_hewn_jobs_v1.aleo {
    const MINE: field = 11field;   // a business .hewn name the test signer owns
    const THEIRS: field = 22field; // a business name someone else owns
    const WORKER: field = 44field; // a worker name the test signer owns
    const CODE: u8 = 7u8;          // MINE's industry code
    const STRANGER: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;

    // ---- What must work ----

    @test
    fn test_post_update_close() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(1field, MINE, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        let f3: Final = hewn_jobs_v1.aleo::update(1field, MINE, CODE, 2u8, 7000000u64, 7000000u64, 1u8, 400u16, 1u8, body);
        let f4: Final = hewn_jobs_v1.aleo::close(1field, MINE, CODE);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    fn test_post_without_pay() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [0field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(2field, MINE, CODE, 0u8, 0u64, 0u64, 0u8, 0u16, 0u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    fn test_two_postings() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [1field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(3field, MINE, CODE, 1u8, 2000u64, 2000u64, 2u8, 100u16, 3u8, body);
        let f3: Final = hewn_jobs_v1.aleo::post(4field, MINE, CODE, 1u8, 2000u64, 2500u64, 3u8, 1680u16, 1u8, body);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_post_unowned_name_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(THEIRS, STRANGER, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(5field, THEIRS, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_post_unregistered_fails() -> Final {
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f1: Final = hewn_jobs_v1.aleo::post(6field, 33field, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
        };
    }

    @test
    @should_fail
    fn test_duplicate_id_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(7field, MINE, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        let f3: Final = hewn_jobs_v1.aleo::post(7field, MINE, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
            f3.run();
        };
    }

    @test
    @should_fail
    fn test_update_other_name_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = pnw_name_registry_v2.aleo::register_test_employer(THEIRS, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f3: Final = hewn_jobs_v1.aleo::post(8field, MINE, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        // Owning another name doesn't let you edit a posting made under this one.
        let f4: Final = hewn_jobs_v1.aleo::update(8field, THEIRS, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    @should_fail
    fn test_update_after_close_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(9field, MINE, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        let f3: Final = hewn_jobs_v1.aleo::close(9field, MINE, CODE);
        let f4: Final = hewn_jobs_v1.aleo::update(9field, MINE, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    @should_fail
    fn test_close_twice_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(10field, MINE, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        let f3: Final = hewn_jobs_v1.aleo::close(10field, MINE, CODE);
        let f4: Final = hewn_jobs_v1.aleo::close(10field, MINE, CODE);
        return final {
            f1.run();
            f2.run();
            f3.run();
            f4.run();
        };
    }

    @test
    @should_fail
    fn test_close_unknown_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let f2: Final = hewn_jobs_v1.aleo::close(99field, MINE, CODE);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_pay_backwards_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(12field, MINE, CODE, 1u8, 4000u64, 3500u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_hidden_pay_amount_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(13field, MINE, CODE, 0u8, 0u64, 4000u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_bad_employment_type_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(14field, MINE, CODE, 1u8, 3500u64, 4000u64, 6u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_too_many_hours_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(15field, MINE, CODE, 1u8, 3500u64, 4000u64, 1u8, 1681u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_bad_place_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(16field, MINE, CODE, 1u8, 3500u64, 4000u64, 1u8, 200u16, 4u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_zero_id_fails() -> Final {
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(0field, MINE, CODE, 1u8, 3500u64, 4000u64, 1u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_post_worker_name_fails() -> Final {
        // A worker's own name, with the code a worker name has (none): not a business.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(17field, WORKER, 0u8, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_post_worker_code_fails() -> Final {
        // A worker's own name with a made-up industry code: the registry says otherwise.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_name(WORKER, self.signer);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(18field, WORKER, CODE, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @test
    @should_fail
    fn test_post_wrong_code_fails() -> Final {
        // The right business name under the wrong industry code.
        let f1: Final = pnw_name_registry_v2.aleo::register_test_employer(MINE, self.signer, CODE);
        let body: hewn_jobs_v1.aleo::Body = hewn_jobs_v1.aleo::Body { words: [7field; 40] };
        let f2: Final = hewn_jobs_v1.aleo::post(19field, MINE, 8u8, 1u8, 3500u64, 4000u64, 5u8, 200u16, 2u8, body);
        return final {
            f1.run();
            f2.run();
        };
    }

    @noupgrade
    constructor() {}
}
