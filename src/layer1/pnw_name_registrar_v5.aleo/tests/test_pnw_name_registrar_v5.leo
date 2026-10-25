// Tests for pnw_name_registrar_v5, the deployed registrar (tests only; the
// program is never edited). What registering a name must do, and what must
// fail: the free paths Hewn uses at setup and the paid, licence-gated paths
// that stay on chain unused.
//
// The registrar writes names into pnw_name_registry_v2, which gates its writes
// on `self.caller` being the authorised registrar or ADMIN; the caller of a
// program the registrar calls is the registrar. So the plan gate runs these
// with the real registry as a local dependency whose ADMIN constant is the
// registrar's own program address (aleo182yu…, which `self.address` yields for
// `pnw_name_registrar_v5.aleo`), and with @noupgrade in place of @admin on both
// programs (the local ledger refuses an @admin program whose deployer isn't the
// admin). The stablecoin and the licence registry are the stubs in src/stubs,
// seeded with their test-only `mint_test` and `set_test_verified`. Everything
// else is the programs as deployed.
//
// Every name here is registered to `self.signer`, the one wallet a test has, so
// the one-name-per-wallet rules are exercised directly. Two tests record that
// the chain does not yet keep a wallet to one kind of name (the app does; see
// test_worker_then_empl_allowed). What this can't show:
// a completed sellback (the registry's request must come from the name's owner,
// and the refund from the treasury, which no test caller can be), and a name
// taken by another wallet (covered by the registry's own tests).
import employer_license_registry.aleo;
import test_usdcx_stablecoin.aleo;
import pnw_name_registry_v2.aleo;
import pnw_name_registrar_v5.aleo;
program test_pnw_name_registrar_v5.aleo {
    const W1: field = 11field;
    const W2: field = 12field;
    const E1: field = 21field;
    const E2: field = 22field;
    // The packed readable name; the registrar stores it as given.
    const ENC1: u128 = 1_001u128;
    const ENC2: u128 = 1_002u128;
    const CODE: u8 = 7u8;
    const PRICE: u128 = 1_000_000u128;
    const TREASURY: address = aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    // ---- What must work ----

    @test
    fn test_worker_free() -> Final {
        let f1: Final = pnw_name_registrar_v5.aleo::register_worker_free(W1, ENC1);
        let f2: Final = pnw_name_registry_v2.aleo::assert_is_owner(W1, self.signer);
        return final { f1.run(); f2.run(); };
    }

    @test
    fn test_worker_free_plaintext() -> Final {
        // The readable name is kept beside the hash (the reverse resolver).
        let f1: Final = pnw_name_registrar_v5.aleo::register_worker_free(W1, ENC1);
        return final {
            f1.run();
            assert_eq(pnw_name_registrar_v5.aleo::name_plaintext.get(W1), ENC1);
        };
    }

    @test
    fn test_employer_free() -> Final {
        let f1: Final = pnw_name_registrar_v5.aleo::register_employer_free(E1, ENC1, CODE);
        let f2: Final = pnw_name_registry_v2.aleo::assert_employer_owner(E1, self.signer, CODE);
        return final {
            f1.run(); f2.run();
            assert_eq(pnw_name_registrar_v5.aleo::name_plaintext.get(E1), ENC1);
        };
    }

    @test
    fn test_employer_free_suffix_1() -> Final {
        let f1: Final = pnw_name_registrar_v5.aleo::register_employer_free(E1, ENC1, 1u8);
        let f2: Final = pnw_name_registry_v2.aleo::assert_employer_owner(E1, self.signer, 1u8);
        return final { f1.run(); f2.run(); };
    }

    @test
    fn test_employer_free_suffix_40() -> Final {
        let f1: Final = pnw_name_registrar_v5.aleo::register_employer_free(E1, ENC1, 40u8);
        let f2: Final = pnw_name_registry_v2.aleo::assert_employer_owner(E1, self.signer, 40u8);
        return final { f1.run(); f2.run(); };
    }

    @test
    fn test_worker_paid() -> Final {
        // 1 USDCx moves from the signer to the treasury; the name is the signer's.
        let me: address = self.signer;
        let f1: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE);
        let f2: Final = pnw_name_registrar_v5.aleo::register_worker_name(W1, ENC1);
        let f3: Final = pnw_name_registry_v2.aleo::assert_is_owner(W1, self.signer);
        return final {
            f1.run(); f2.run(); f3.run();
            assert_eq(test_usdcx_stablecoin.aleo::account.get(TREASURY), PRICE);
            assert_eq(test_usdcx_stablecoin.aleo::account.get(me), 0u128);
            assert_eq(pnw_name_registrar_v5.aleo::name_plaintext.get(W1), ENC1);
        };
    }

    @test
    fn test_worker_paid_change_kept() -> Final {
        let me: address = self.signer;
        let f1: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE + 5u128);
        let f2: Final = pnw_name_registrar_v5.aleo::register_worker_name(W1, ENC1);
        return final {
            f1.run(); f2.run();
            assert_eq(test_usdcx_stablecoin.aleo::account.get(me), 5u128);
        };
    }

    @test
    fn test_employer_paid() -> Final {
        // Licensed and funded: the name is the signer's under its code, the price paid.
        let f1: Final = employer_license_registry.aleo::set_test_verified(self.signer, true);
        let f2: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE);
        let f3: Final = pnw_name_registrar_v5.aleo::register_employer_name(E1, ENC1, CODE);
        let f4: Final = pnw_name_registry_v2.aleo::assert_employer_owner(E1, self.signer, CODE);
        return final {
            f1.run(); f2.run(); f3.run(); f4.run();
            assert_eq(test_usdcx_stablecoin.aleo::account.get(TREASURY), PRICE);
            assert_eq(pnw_name_registrar_v5.aleo::name_plaintext.get(E1), ENC1);
        };
    }

    @test
    fn test_worker_then_empl_allowed() -> Final {
        // Recorded as it is, not as the rule reads: the chain today lets one wallet hold a
        // worker name and an employer name (the registry counts the two kinds apart). Hewn
        // refuses it in the app (`chain/account_kind.ts`); the mainnet registrar will on chain.
        // When it does, this test and the next flip to @should_fail.
        let f1: Final = pnw_name_registrar_v5.aleo::register_worker_free(W1, ENC1);
        let f2: Final = pnw_name_registrar_v5.aleo::register_employer_free(E1, ENC2, CODE);
        let f3: Final = pnw_name_registry_v2.aleo::assert_is_owner(W1, self.signer);
        let f4: Final = pnw_name_registry_v2.aleo::assert_employer_owner(E1, self.signer, CODE);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    fn test_empl_then_worker_allowed() -> Final {
        let f1: Final = pnw_name_registrar_v5.aleo::register_employer_free(E1, ENC1, CODE);
        let f2: Final = pnw_name_registrar_v5.aleo::register_worker_free(W1, ENC2);
        let f3: Final = pnw_name_registry_v2.aleo::assert_is_owner(W1, self.signer);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_worker_second_free_fails() -> Final {
        // One name per wallet.
        let f1: Final = pnw_name_registrar_v5.aleo::register_worker_free(W1, ENC1);
        let f2: Final = pnw_name_registrar_v5.aleo::register_worker_free(W2, ENC2);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_employer_second_free_fails() -> Final {
        // The registrar always passes count 0: a second employer name doesn't match the chain's count.
        let f1: Final = pnw_name_registrar_v5.aleo::register_employer_free(E1, ENC1, CODE);
        let f2: Final = pnw_name_registrar_v5.aleo::register_employer_free(E2, ENC2, CODE);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_free_then_paid_wrk_fails() -> Final {
        let f1: Final = pnw_name_registrar_v5.aleo::register_worker_free(W1, ENC1);
        let f2: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE);
        let f3: Final = pnw_name_registrar_v5.aleo::register_worker_name(W2, ENC2);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_paid_then_free_empl_fails() -> Final {
        let f1: Final = employer_license_registry.aleo::set_test_verified(self.signer, true);
        let f2: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE);
        let f3: Final = pnw_name_registrar_v5.aleo::register_employer_name(E1, ENC1, CODE);
        let f4: Final = pnw_name_registrar_v5.aleo::register_employer_free(E2, ENC2, CODE);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    @should_fail
    fn test_free_suffix_0_fails() -> Final {
        let f1: Final = pnw_name_registrar_v5.aleo::register_employer_free(E1, ENC1, 0u8);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_free_suffix_41_fails() -> Final {
        let f1: Final = pnw_name_registrar_v5.aleo::register_employer_free(E1, ENC1, 41u8);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_paid_suffix_0_fails() -> Final {
        let f1: Final = employer_license_registry.aleo::set_test_verified(self.signer, true);
        let f2: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE);
        let f3: Final = pnw_name_registrar_v5.aleo::register_employer_name(E1, ENC1, 0u8);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_paid_suffix_41_fails() -> Final {
        let f1: Final = employer_license_registry.aleo::set_test_verified(self.signer, true);
        let f2: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE);
        let f3: Final = pnw_name_registrar_v5.aleo::register_employer_name(E1, ENC1, 41u8);
        return final { f1.run(); f2.run(); f3.run(); };
    }

    @test
    @should_fail
    fn test_worker_paid_no_funds_fails() -> Final {
        // Nothing minted: the payment can't be made, so no name.
        let f1: Final = pnw_name_registrar_v5.aleo::register_worker_name(W1, ENC1);
        return final { f1.run(); };
    }

    @test
    @should_fail
    fn test_worker_paid_short_fails() -> Final {
        // One micro-USDCx short of the price.
        let f1: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE - 1u128);
        let f2: Final = pnw_name_registrar_v5.aleo::register_worker_name(W1, ENC1);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_employer_unlicensed_fails() -> Final {
        // Funded but never verified by the licence registry.
        let f1: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE);
        let f2: Final = pnw_name_registrar_v5.aleo::register_employer_name(E1, ENC1, CODE);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_employer_revoked_fails() -> Final {
        // Verified once, then revoked.
        let f1: Final = employer_license_registry.aleo::set_test_verified(self.signer, true);
        let f2: Final = employer_license_registry.aleo::set_test_verified(self.signer, false);
        let f3: Final = test_usdcx_stablecoin.aleo::mint_test(self.signer, PRICE);
        let f4: Final = pnw_name_registrar_v5.aleo::register_employer_name(E1, ENC1, CODE);
        return final { f1.run(); f2.run(); f3.run(); f4.run(); };
    }

    @test
    @should_fail
    fn test_empl_paid_no_funds_fails() -> Final {
        let f1: Final = employer_license_registry.aleo::set_test_verified(self.signer, true);
        let f2: Final = pnw_name_registrar_v5.aleo::register_employer_name(E1, ENC1, CODE);
        return final { f1.run(); f2.run(); };
    }

    @test
    @should_fail
    fn test_sellback_not_dao_fails() -> Final {
        // Only the treasury completes a sellback; the caller here is this test program.
        let f1: Final = pnw_name_registrar_v5.aleo::register_employer_free(E1, ENC1, CODE);
        let f2: Final = pnw_name_registrar_v5.aleo::fulfill_empl_sellback(E1, self.signer, 0u128);
        return final { f1.run(); f2.run(); };
    }

    @noupgrade
    constructor() {}
}
