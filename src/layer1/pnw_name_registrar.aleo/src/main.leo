import employer_license_registry.aleo;
import test_usdcx_stablecoin.aleo;
import pnw_name_registry_v2.aleo;

program pnw_name_registrar.aleo {

    // ---------------------------------------------------------
    // PNW Name Registrar — Payment + Business Logic
    // ---------------------------------------------------------
    // Handles USDCx payment via transfer_public_as_signer (deducts
    // from the original transaction signer, not this program).
    // Then delegates name storage to pnw_name_registry_v2.aleo.
    //
    // This program is @admin and can be upgraded for pricing changes,
    // new features, promo codes, etc. The registry stays stable.
    // ---------------------------------------------------------

    // Treasury routing
    const PRESIDING_DAO_TREASURY: address =
        aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    // USDCx units
    const USDCX_SCALE: u128 = 1_000_000u128;

    // Worker base price: 1 USDCx
    const WORKER_PRICE_BASE: u128 = 1u128 * USDCX_SCALE;

    // Employer tiered pricing
    const EMP_PRICE_1_BASE: u128 = 10u128 * USDCX_SCALE;
    const EMP_PRICE_2_BASE: u128 = 100u128 * USDCX_SCALE;
    const EMP_PRICE_3_BASE: u128 = 300u128 * USDCX_SCALE;

    // ---------------------------------------------------------
    // Pricing helper
    // ---------------------------------------------------------
    inline calc_employer_base_price(count: u8) -> u128 {
        if count == 0u8 { return EMP_PRICE_1_BASE; }
        if count == 1u8 { return EMP_PRICE_2_BASE; }
        if count == 2u8 { return EMP_PRICE_3_BASE; }
        return 0u128;
    }

    // Suffix validation
    inline is_valid_suffix(code: u8) -> bool {
        return (code >= 1u8 && code <= 40u8);
    }

    // ---------------------------------------------------------
    // Register worker name
    // ---------------------------------------------------------
    async transition register_worker_name(
        name_hash: field,
        fee_amount: u128
    ) -> Future {
        let total: u128 = WORKER_PRICE_BASE + fee_amount;

        // Payment from the SIGNER (the user), not from this program
        let pay_f: Future =
            test_usdcx_stablecoin.aleo/transfer_public_as_signer(PRESIDING_DAO_TREASURY, total);

        // Store name in registry v2
        let reg_f: Future =
            pnw_name_registry_v2.aleo/register_worker_name(name_hash, self.signer);

        return finalize_register_worker(pay_f, reg_f);
    }

    async function finalize_register_worker(pay_f: Future, reg_f: Future) {
        pay_f.await();
        reg_f.await();
    }

    // ---------------------------------------------------------
    // Register employer name
    // ---------------------------------------------------------
    async transition register_employer_name(
        name_hash: field,
        suffix_code: u8,
        count: u8,
        fee_amount: u128
    ) -> Future {
        assert(is_valid_suffix(suffix_code));
        assert(count < 3u8);

        let base_price: u128 = calc_employer_base_price(count);
        let total: u128 = base_price + fee_amount;

        // Verify employer license (pass signer address, not self.caller)
        let verified_f: Future =
            employer_license_registry.aleo/assert_verified(self.signer);

        // Payment from the SIGNER (the user)
        let pay_f: Future =
            test_usdcx_stablecoin.aleo/transfer_public_as_signer(PRESIDING_DAO_TREASURY, total);

        // Store name in registry v2
        let reg_f: Future =
            pnw_name_registry_v2.aleo/register_employer_name(name_hash, suffix_code, count, base_price, self.signer);

        return finalize_register_employer(verified_f, pay_f, reg_f);
    }

    async function finalize_register_employer(verified_f: Future, pay_f: Future, reg_f: Future) {
        verified_f.await();
        pay_f.await();
        reg_f.await();
    }

    // ---------------------------------------------------------
    // Fulfill employer sellback (DAO treasury only)
    // ---------------------------------------------------------
    async transition fulfill_empl_sellback(
        name_hash: field,
        seller: address,
        refund: u128
    ) -> Future {
        assert(self.caller == PRESIDING_DAO_TREASURY);

        // Refund payment from treasury to seller
        let pay_f: Future =
            test_usdcx_stablecoin.aleo/transfer_public_as_signer(seller, refund);

        // Clear sellback state in registry
        let reg_f: Future =
            pnw_name_registry_v2.aleo/fulfill_empl_sellback(name_hash, seller, refund);

        return finalize_fulfill_empl_sellback(pay_f, reg_f);
    }

    async function finalize_fulfill_empl_sellback(pay_f: Future, reg_f: Future) {
        pay_f.await();
        reg_f.await();
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx")
    async constructor() {}
}
