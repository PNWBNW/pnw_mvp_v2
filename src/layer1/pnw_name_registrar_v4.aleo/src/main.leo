import employer_license_registry.aleo;
import test_usdcx_stablecoin.aleo;
import pnw_name_registry_v2.aleo;

program pnw_name_registrar_v4.aleo {

    // ---------------------------------------------------------
    // PNW Name Registrar v4 — One Name Per Wallet
    // ---------------------------------------------------------
    // Rules:
    //   - Each wallet gets exactly ONE .pnw name
    //   - Name is either WORKER or EMPLOYER type, not both
    //   - Flat pricing: 1 USDCx for any name type (testnet)
    //   - Employer names require license verification
    //   - Worker names are soulbound (no sellback)
    //   - Employer names can be sold back
    // ---------------------------------------------------------

    // Treasury routing
    const PRESIDING_DAO_TREASURY: address =
        aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    // Flat pricing: 1 USDCx for any name (testnet)
    const NAME_PRICE: u128 = 1_000_000u128;

    // Suffix validation
    inline is_valid_suffix(code: u8) -> bool {
        return (code >= 1u8 && code <= 40u8);
    }

    // ---------------------------------------------------------
    // Register worker name — 1 per wallet, soulbound
    // ---------------------------------------------------------
    async transition register_worker_name(
        name_hash: field
    ) -> Future {
        // Payment from the SIGNER (the user)
        let pay_f: Future =
            test_usdcx_stablecoin.aleo/transfer_public_as_signer(PRESIDING_DAO_TREASURY, NAME_PRICE);

        // Store name in registry v2 (count=0, base_price=0 since worker)
        let reg_f: Future =
            pnw_name_registry_v2.aleo/register_worker_name(name_hash, self.signer);

        return finalize_register_worker(pay_f, reg_f);
    }

    async function finalize_register_worker(pay_f: Future, reg_f: Future) {
        pay_f.await();
        reg_f.await();
    }

    // ---------------------------------------------------------
    // Register employer name — 1 per wallet, sellback allowed
    // ---------------------------------------------------------
    async transition register_employer_name(
        name_hash: field,
        suffix_code: u8
    ) -> Future {
        assert(is_valid_suffix(suffix_code));

        // Verify employer license
        let verified_f: Future =
            employer_license_registry.aleo/assert_verified(self.signer);

        // Payment from the SIGNER (the user)
        let pay_f: Future =
            test_usdcx_stablecoin.aleo/transfer_public_as_signer(PRESIDING_DAO_TREASURY, NAME_PRICE);

        // Store name in registry v2
        // count=0 (first and only name), base_price=NAME_PRICE for sellback calc
        let reg_f: Future =
            pnw_name_registry_v2.aleo/register_employer_name(name_hash, suffix_code, 0u8, NAME_PRICE, self.signer);

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

        let pay_f: Future =
            test_usdcx_stablecoin.aleo/transfer_public_as_signer(seller, refund);

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
