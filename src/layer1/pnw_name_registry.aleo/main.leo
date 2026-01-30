import employer_license_registry.aleo;
import test_usdcx_stablecoin.aleo;

program pnw_name_registry.aleo {

    // ---------------------------------------------------------
    // PNW Naming Registry (Layer 1, soulbound-by-design)
    // ---------------------------------------------------------
    // Names are registered as hashed identifiers (field).
    // - No plaintext strings on-chain.
    // - No transfers or sales between users.
    //
    // Workers:
    // - 1 active name per address
    // - purchase: 1 USDCx + fee_amount (fees non-refundable)
    // - can release to pool and switch (no refund)
    //
    // Employers:
    // - max 3 names per address
    // - purchase tiers: 10 / 100 / 300 USDCx + fee_amount (fees non-refundable)
    // - requires business verification (employer_license_registry)
    // - can sell back ONLY to registrar for 75% of BASE price (fees never refunded)
    // ---------------------------------------------------------

    // -------------------
    // Environment constants
    // -------------------
    const REGISTRAR_TREASURY: address =
        aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    const USDCX_SCALE: u128 = 1_000_000u128;

    const WORKER_PRICE_BASE: u128 = 1u128 * USDCX_SCALE;

    const EMP_PRICE_1_BASE: u128 = 10u128 * USDCX_SCALE;
    const EMP_PRICE_2_BASE: u128 = 100u128 * USDCX_SCALE;
    const EMP_PRICE_3_BASE: u128 = 300u128 * USDCX_SCALE;

    const REFUND_NUM: u128 = 75u128;
    const REFUND_DEN: u128 = 100u128;

    // -------------------
    // Name kind codes
    // -------------------
    const KIND_WORKER: u8 = 1u8;
    const KIND_EMPLOYER: u8 = 2u8;

    // -------------------
    // Employer 5-char suffix codes
    // -------------------
    const SUF_AGRIC: u8 = 1u8;   // agric
    const SUF_FOODS: u8 = 2u8;   // foods
    const SUF_SERVC: u8 = 3u8;   // servc
    const SUF_BUSNS: u8 = 4u8;   // busns
    const SUF_WORKS: u8 = 5u8;   // works

    const SUF_COOPS: u8 = 6u8;   // coops
    const SUF_ORGNS: u8 = 7u8;   // orgns
    const SUF_INCOR: u8 = 8u8;   // incor
    const SUF_BUILD: u8 = 9u8;   // build
    const SUF_LANDS: u8 = 10u8;  // lands

    const SUF_MANUF: u8 = 11u8;  // manuf
    const SUF_TRANS: u8 = 12u8;  // trans
    const SUF_UTILT: u8 = 13u8;  // utilt
    const SUF_MECHN: u8 = 14u8;  // mechn
    const SUF_ELECT: u8 = 15u8;  // elect

    const SUF_METAL: u8 = 16u8;  // metal
    const SUF_TIMBR: u8 = 17u8;  // timbr

    const SUF_TECHN: u8 = 18u8;  // techn
    const SUF_DATAS: u8 = 19u8;  // datas
    const SUF_CYBER: u8 = 20u8;  // cyber
    const SUF_MEDIA: u8 = 21u8;  // media
    const SUF_LABRD: u8 = 22u8;  // labrd (research labs / R&D)

    const SUF_HEALT: u8 = 23u8;  // healt
    const SUF_CARED: u8 = 24u8;  // cared
    const SUF_PHARM: u8 = 25u8;  // pharm
    const SUF_THERA: u8 = 26u8;  // thera

    const SUF_EDUCA: u8 = 27u8;  // educa
    const SUF_TRAIN: u8 = 28u8;  // train
    const SUF_SKILL: u8 = 29u8;  // skill

    const SUF_RETAL: u8 = 30u8;  // retal
    const SUF_HOSTL: u8 = 31u8;  // hostl
    const SUF_TOURS: u8 = 32u8;  // tours (tourism, guides)
    const SUF_EVENT: u8 = 33u8;  // event

    const SUF_FINAN: u8 = 34u8;  // finan
    const SUF_LEGAL: u8 = 35u8;  // legal
    const SUF_ACCTS: u8 = 36u8;  // accts
    const SUF_ADMIN: u8 = 37u8;  // admin

    const SUF_CIVIC: u8 = 38u8;  // civic
    const SUF_MUNIC: u8 = 39u8;  // munic
    const SUF_STATE: u8 = 40u8;  // state

    function is_valid_suffix(code: u8) -> bool {
        let ok: bool =
            code == SUF_AGRIC || code == SUF_FOODS || code == SUF_SERVC || code == SUF_BUSNS || code == SUF_WORKS
            || code == SUF_COOPS || code == SUF_ORGNS || code == SUF_INCOR || code == SUF_BUILD || code == SUF_LANDS
            || code == SUF_MANUF || code == SUF_TRANS || code == SUF_UTILT || code == SUF_MECHN || code == SUF_ELECT
            || code == SUF_METAL || code == SUF_TIMBR
            || code == SUF_TECHN || code == SUF_DATAS || code == SUF_CYBER || code == SUF_MEDIA || code == SUF_LABRD
            || code == SUF_HEALT || code == SUF_CARED || code == SUF_PHARM || code == SUF_THERA
            || code == SUF_EDUCA || code == SUF_TRAIN || code == SUF_SKILL
            || code == SUF_RETAL || code == SUF_HOSTL || code == SUF_TOURS || code == SUF_EVENT
            || code == SUF_FINAN || code == SUF_LEGAL || code == SUF_ACCTS || code == SUF_ADMIN
            || code == SUF_CIVIC || code == SUF_MUNIC || code == SUF_STATE;

        return ok;
    }

    // -------------------
    // On-chain mappings
    // -------------------
    mapping name_owner:
        key as field.public,
        value as address.public;

    mapping name_kind:
        key as field.public,
        value as u8.public;

    mapping employer_suffix_code:
        key as field.public,
        value as u8.public;

    // Workers: 1 active name per address
    mapping worker_primary_name_of:
        key as address.public,
        value as field.public;

    // Employers: count of owned names (0..3)
    mapping employer_name_count:
        key as address.public,
        value as u8.public;

    // Employer name_hash -> base price paid (USDCx base units)
    mapping employer_base_paid:
        key as field.public,
        value as u128.public;

    // Sellback claim: name_hash -> seller address (0address if none)
    mapping sellback_seller:
        key as field.public,
        value as address.public;

    // Sellback claim: name_hash -> refund amount (USDCx base units)
    mapping sellback_refund_amount:
        key as field.public,
        value as u128.public;

    // -------------------
    // Internal helpers
    // -------------------
    function calc_employer_base_price(current_count: u8) -> u128 {
        if current_count == 0u8 { return EMP_PRICE_1_BASE; }
        if current_count == 1u8 { return EMP_PRICE_2_BASE; }
        if current_count == 2u8 { return EMP_PRICE_3_BASE; }
        return 0u128;
    }

    function calc_refund(base_paid: u128) -> u128 {
        return (base_paid * REFUND_NUM) / REFUND_DEN;
    }

    // -------------------
    // Worker flows
    // -------------------
    async transition register_worker_name(name_hash: field, fee_amount: u128) -> Future {
        // Enforce: one active worker name per address
        let existing_primary: field = worker_primary_name_of.get_or_use(caller, 0field);
        assert(existing_primary == 0field);

        // Enforce: name must be unowned
        let existing_owner: address = name_owner.get_or_use(name_hash, 0address);
        assert(existing_owner == 0address);

        // Collect payment: 1 USDCx + fee_amount (fees are non-refundable)
        let total: u128 = WORKER_PRICE_BASE + fee_amount;
        let pay_f: Future = test_usdcx_stablecoin.aleo/transfer_public(REGISTRAR_TREASURY, total);

        let f: Future = finalize_register_worker(pay_f, caller, name_hash);
        return f;
    }

    async function finalize_register_worker(pay_f: Future, owner: address, name_hash: field) -> Future {
        await pay_f;

        name_owner.set(name_hash, owner);
        name_kind.set(name_hash, KIND_WORKER);
        employer_suffix_code.set(name_hash, 0u8);

        worker_primary_name_of.set(owner, name_hash);

        return 0future;
    }

    transition release_worker_name() {
        let current: field = worker_primary_name_of.get_or_use(caller, 0field);
        assert(current != 0field);

        let owner: address = name_owner.get_or_use(current, 0address);
        assert(owner == caller);

        // Release back to pool (no refunds)
        name_owner.set(current, 0address);
        name_kind.set(current, 0u8);
        employer_suffix_code.set(current, 0u8);

        worker_primary_name_of.set(caller, 0field);
    }

    // -------------------
    // Employer flows
    // -------------------
    async transition register_employer_name(name_hash: field, suffix_code: u8, fee_amount: u128) -> Future {
        // Must be verified as a business
        employer_license_registry.aleo/assert_verified(caller);

        // Validate suffix
        assert(is_valid_suffix(suffix_code));

        // Enforce: name must be unowned
        let existing_owner: address = name_owner.get_or_use(name_hash, 0address);
        assert(existing_owner == 0address);

        // Enforce: max 3 names per address
        let count: u8 = employer_name_count.get_or_use(caller, 0u8);
        assert(count < 3u8);

        let base_paid: u128 = calc_employer_base_price(count);
        assert(base_paid != 0u128);

        // Collect payment: base + fee_amount (fees are non-refundable)
        let total: u128 = base_paid + fee_amount;
        let pay_f: Future = test_usdcx_stablecoin.aleo/transfer_public(REGISTRAR_TREASURY, total);

        let f: Future = finalize_register_employer(pay_f, caller, name_hash, suffix_code, base_paid, count);
        return f;
    }

    async function finalize_register_employer(
        pay_f: Future,
        owner: address,
        name_hash: field,
        suffix_code: u8,
        base_paid: u128,
        count: u8
    ) -> Future {
        await pay_f;

        name_owner.set(name_hash, owner);
        name_kind.set(name_hash, KIND_EMPLOYER);
        employer_suffix_code.set(name_hash, suffix_code);

        employer_base_paid.set(name_hash, base_paid);
        employer_name_count.set(owner, count + 1u8);

        return 0future;
    }

    // Employer requests sellback to registrar (refund paid later by treasury).
    transition request_employer_sellback(name_hash: field) {
        let owner: address = name_owner.get_or_use(name_hash, 0address);
        assert(owner == caller);

        let k: u8 = name_kind.get_or_use(name_hash, 0u8);
        assert(k == KIND_EMPLOYER);

        // Ensure no existing claim
        let existing_claim_seller: address = sellback_seller.get_or_use(name_hash, 0address);
        assert(existing_claim_seller == 0address);

        let base_paid: u128 = employer_base_paid.get_or_use(name_hash, 0u128);
        assert(base_paid != 0u128);

        let refund: u128 = calc_refund(base_paid);
        assert(refund > 0u128);

        // Release name back to pool immediately
        name_owner.set(name_hash, 0address);
        name_kind.set(name_hash, 0u8);
        employer_suffix_code.set(name_hash, 0u8);

        // Decrement employer count
        let count: u8 = employer_name_count.get_or_use(caller, 0u8);
        assert(count > 0u8);
        employer_name_count.set(caller, count - 1u8);

        // Record sellback claim for registrar fulfillment
        sellback_seller.set(name_hash, caller);
        sellback_refund_amount.set(name_hash, refund);
    }

    async transition fulfill_employer_sellback(name_hash: field) -> Future {
        // Only registrar treasury may fulfill refunds.
        assert(caller == REGISTRAR_TREASURY);

        let seller: address = sellback_seller.get_or_use(name_hash, 0address);
        assert(seller != 0address);

        let refund: u128 = sellback_refund_amount.get_or_use(name_hash, 0u128);
        assert(refund > 0u128);

        let pay_f: Future = test_usdcx_stablecoin.aleo/transfer_public(seller, refund);

        let f: Future = finalize_fulfill_sellback(pay_f, name_hash);
        return f;
    }

    async function finalize_fulfill_sellback(pay_f: Future, name_hash: field) -> Future {
        await pay_f;

        // Clear claim
        sellback_seller.set(name_hash, 0address);
        sellback_refund_amount.set(name_hash, 0u128);

        return 0future;
    }

    // =========================================================
    // Read-only assertion helpers (NO STATE MUTATION)
    // =========================================================

    transition assert_name_exists(name_hash: field) {
        let owner: address = name_owner.get_or_use(name_hash, 0address);
        assert(owner != 0address);
    }

    transition assert_worker_owner(name_hash: field, owner: address) {
        let existing_owner: address = name_owner.get_or_use(name_hash, 0address);
        let k: u8 = name_kind.get_or_use(name_hash, 0u8);

        assert(existing_owner == owner);
        assert(k == KIND_WORKER);
    }

    transition assert_employer_owner(name_hash: field, owner: address, expected_suffix: u8) {
        let existing_owner: address = name_owner.get_or_use(name_hash, 0address);
        let k: u8 = name_kind.get_or_use(name_hash, 0u8);
        let suffix: u8 = employer_suffix_code.get_or_use(name_hash, 0u8);

        assert(existing_owner == owner);
        assert(k == KIND_EMPLOYER);
        assert(suffix == expected_suffix);
    }

    transition assert_is_owner(name_hash: field, owner: address) {
        let existing_owner: address = name_owner.get_or_use(name_hash, 0address);
        assert(existing_owner == owner);
    }
}
