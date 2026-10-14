import pnw_name_registry_v2.aleo;

// Suffix validation
fn is_valid_suffix(code: u8) -> bool {
    return (code >= 1u8 && code <= 40u8);
}

program pnw_name_registrar_v5.aleo {

    // ---------------------------------------------------------
    // PNW Name Registrar v5 — One Name Per Wallet + Reverse Resolver
    // ---------------------------------------------------------
    // Rules (edition 2, 2026-10-14: open registration):
    //   - Each wallet gets exactly ONE name
    //   - Name is either WORKER or EMPLOYER type, not both
    //   - Free: no payment and no license approval (a price returns later)
    //   - Worker names are soulbound (no sellback)
    //   - Employer names can be sold back
    //
    // Added in v5:
    //   - name_plaintext mapping for reverse resolution
    //   - Given a name_hash, anyone can look up the .pnw name string
    //   - Names are public identities (like domain names)
    // ---------------------------------------------------------

    // Treasury routing (sellback refunds only)
    const PRESIDING_DAO_TREASURY: address =
        aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    // Free registration. base_price 0 means a sellback refunds nothing.
    const NAME_PRICE: u128 = 0u128;

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
        // Store name in registry v2 (free)
        let reg_f: Final =
            pnw_name_registry_v2.aleo::register_worker_name(name_hash, self.signer);

        return final {
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

        // Store name in registry v2 (free, no license approval)
        // count=0 (first and only name), base_price=NAME_PRICE for sellback calc
        let reg_f: Final =
            pnw_name_registry_v2.aleo::register_employer_name(name_hash, suffix_code, 0u8, NAME_PRICE, self.signer);

        return final {
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
        // Names are free, so there is nothing to refund: the registry only releases the name.
        assert(refund == 0u128);

        let reg_f: Final =
            pnw_name_registry_v2.aleo::fulfill_empl_sellback(name_hash, seller, refund);

        return final {
            reg_f.run();
        };
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx")
    constructor() {}
}
