import employer_license_registry.aleo;
import test_usdcx_stablecoin.aleo;
import pnw_name_registry_v2.aleo;

// Suffix validation
fn is_valid_suffix(code: u8) -> bool {
    return (code >= 1u8 && code <= 40u8);
}

program pnw_name_registrar_v5.aleo {

    // ---------------------------------------------------------
    // PNW Name Registrar v5 — One Name Per Wallet + Reverse Resolver
    // ---------------------------------------------------------
    // Same rules as v4:
    //   - Each wallet gets exactly ONE .pnw name
    //   - Name is either WORKER or EMPLOYER type, not both
    //   - Flat pricing: 1 USDCx for any name type (testnet)
    //   - Employer names require license verification
    //   - Worker names are soulbound (no sellback)
    //   - Employer names can be sold back
    //
    // Added in v5:
    //   - name_plaintext mapping for reverse resolution
    //   - Given a name_hash, anyone can look up the .pnw name string
    //   - Names are public identities (like domain names)
    // ---------------------------------------------------------

    // Treasury routing
    const PRESIDING_DAO_TREASURY: address =
        aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    // Flat pricing: 1 USDCx for any name (testnet)
    const NAME_PRICE: u128 = 1_000_000u128;

    // ---------------------------------------------------------
    // Reverse resolver: name_hash → encoded plaintext name
    // Names are up to 16 chars, big-endian encoded as u128
    // ---------------------------------------------------------
    mapping name_plaintext: field => u128;

    // ---------------------------------------------------------
    // Register worker name — 1 per wallet, soulbound
    // ---------------------------------------------------------
    fn register_worker_name(
        name_hash: field,
        name_encoded: u128
    ) -> Final {
        // Payment from the SIGNER (the user)
        let pay_f: Final =
            test_usdcx_stablecoin.aleo::transfer_public_as_signer(PRESIDING_DAO_TREASURY, NAME_PRICE);

        // Store name in registry v2
        let reg_f: Final =
            pnw_name_registry_v2.aleo::register_worker_name(name_hash, self.signer);

        return final {
            pay_f.run();
            reg_f.run();
            // Store plaintext for reverse resolution
            name_plaintext.set(name_hash, name_encoded);
        };
    }

    // ---------------------------------------------------------
    // Register employer name — 1 per wallet, sellback allowed
    // ---------------------------------------------------------
    fn register_employer_name(
        name_hash: field,
        name_encoded: u128,
        suffix_code: u8
    ) -> Final {
        assert(is_valid_suffix(suffix_code));

        // Verify employer license
        let verified_f: Final =
            employer_license_registry.aleo::assert_verified(self.signer);

        // Payment from the SIGNER (the user)
        let pay_f: Final =
            test_usdcx_stablecoin.aleo::transfer_public_as_signer(PRESIDING_DAO_TREASURY, NAME_PRICE);

        // Store name in registry v2
        // count=0 (first and only name), base_price=NAME_PRICE for sellback calc
        let reg_f: Final =
            pnw_name_registry_v2.aleo::register_employer_name(name_hash, suffix_code, 0u8, NAME_PRICE, self.signer);

        return final {
            verified_f.run();
            pay_f.run();
            reg_f.run();
            // Store plaintext for reverse resolution
            name_plaintext.set(name_hash, name_encoded);
        };
    }

    // ---------------------------------------------------------
    // Fulfill employer sellback (DAO treasury only)
    // ---------------------------------------------------------
    fn fulfill_empl_sellback(
        name_hash: field,
        seller: address,
        refund: u128
    ) -> Final {
        assert(self.caller == PRESIDING_DAO_TREASURY);

        let pay_f: Final =
            test_usdcx_stablecoin.aleo::transfer_public_as_signer(seller, refund);

        let reg_f: Final =
            pnw_name_registry_v2.aleo::fulfill_empl_sellback(name_hash, seller, refund);

        return final {
            pay_f.run();
            reg_f.run();
        };
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx")
    constructor() {}
}
