import employer_license_registry.aleo;
import test_usdcx_stablecoin.aleo;

program pnw_name_registry.aleo {

    // =========================================================
    // PNW Naming Registry (Layer 1, Canonical)
    // =========================================================
    //
    // - Stores ONLY hashed name identifiers (field)
    // - Enforces soulbound ownership semantics
    // - No transfers between users
    // - All prices/fees routed to the locally presiding DAO treasury

    // ---------------------------------------------------------
    // Treasury routing (local presiding DAO)
    // ---------------------------------------------------------
    const PRESIDING_DAO_TREASURY: address =
        aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    // ---------------------------------------------------------
    // USDCx units
    // ---------------------------------------------------------
    const USDCX_SCALE: u128 = 1_000_000u128;

    // Worker pricing
    const WORKER_PRICE_BASE: u128 = 1u128 * USDCX_SCALE;

    // Employer pricing tiers
    const EMP_PRICE_1_BASE: u128 = 10u128 * USDCX_SCALE;
    const EMP_PRICE_2_BASE: u128 = 100u128 * USDCX_SCALE;
    const EMP_PRICE_3_BASE: u128 = 300u128 * USDCX_SCALE;

    // Employer sellback (75% of base price)
    const REFUND_NUM: u128 = 75u128;
    const REFUND_DEN: u128 = 100u128;

    // ---------------------------------------------------------
    // Name kind codes
    // ---------------------------------------------------------
    const KIND_WORKER: u8 = 1u8;
    const KIND_EMPLOYER: u8 = 2u8;

    // ---------------------------------------------------------
    // Employer suffix codes (5-char taxonomy)
    // ---------------------------------------------------------
    const SUF_AGRIC: u8 = 1u8;
    const SUF_FOODS: u8 = 2u8;
    const SUF_SERVC: u8 = 3u8;
    const SUF_BUSNS: u8 = 4u8;
    const SUF_WORKS: u8 = 5u8;
    const SUF_COOPS: u8 = 6u8;
    const SUF_ORGNS: u8 = 7u8;
    const SUF_INCOR: u8 = 8u8;
    const SUF_BUILD: u8 = 9u8;
    const SUF_LANDS: u8 = 10u8;
    const SUF_MANUF: u8 = 11u8;
    const SUF_TRANS: u8 = 12u8;
    const SUF_UTILT: u8 = 13u8;
    const SUF_MECHN: u8 = 14u8;
    const SUF_ELECT: u8 = 15u8;
    const SUF_METAL: u8 = 16u8;
    const SUF_TIMBR: u8 = 17u8;
    const SUF_TECHN: u8 = 18u8;
    const SUF_DATAS: u8 = 19u8;
    const SUF_CYBER: u8 = 20u8;
    const SUF_MEDIA: u8 = 21u8;
    const SUF_LABRD: u8 = 22u8;
    const SUF_HEALT: u8 = 23u8;
    const SUF_CARED: u8 = 24u8;
    const SUF_PHARM: u8 = 25u8;
    const SUF_THERA: u8 = 26u8;
    const SUF_EDUCA: u8 = 27u8;
    const SUF_TRAIN: u8 = 28u8;
    const SUF_SKILL: u8 = 29u8;
    const SUF_RETAL: u8 = 30u8;
    const SUF_HOSTL: u8 = 31u8;
    const SUF_TOURS: u8 = 32u8;
    const SUF_EVENT: u8 = 33u8;
    const SUF_FINAN: u8 = 34u8;
    const SUF_LEGAL: u8 = 35u8;
    const SUF_ACCTS: u8 = 36u8;
    const SUF_ADMIN: u8 = 37u8;
    const SUF_CIVIC: u8 = 38u8;
    const SUF_MUNIC: u8 = 39u8;
    const SUF_STATE: u8 = 40u8;

    function is_valid_suffix(code: u8) -> bool {
        return code >= 1u8 && code <= 40u8;
    }

    // ---------------------------------------------------------
    // Canonical mappings
    // ---------------------------------------------------------
    mapping name_owner: field => address;
    mapping name_kind: field => u8;
    mapping employer_suffix_code: field => u8;
    mapping worker_primary_name_of: address => field;
    mapping employer_name_count: address => u8;
    mapping employer_base_paid: field => u128;
    mapping sellback_seller: field => address;
    mapping sellback_refund_amount: field => u128;

    // ---------------------------------------------------------
    // Internal helpers (circuit-time, no mapping access)
    // ---------------------------------------------------------
    function calc_employer_base_price(count: u8) -> u128 {
        if count == 0u8 { return EMP_PRICE_1_BASE; }
        if count == 1u8 { return EMP_PRICE_2_BASE; }
        if count == 2u8 { return EMP_PRICE_3_BASE; }
        return 0u128;
    }

    function calc_refund(base_paid: u128) -> u128 {
        return (base_paid * REFUND_NUM) / REFUND_DEN;
    }

    // ---------------------------------------------------------
    // Worker flows
    // ---------------------------------------------------------

    // Portal supplies fee_amount (network fee on top of base price).
    // Uniqueness checks happen in finalize.
    async transition register_worker_name(name_hash: field, fee_amount: u128) -> Future {
        let total: u128 = WORKER_PRICE_BASE + fee_amount;
        let pay_f: Future =
            test_usdcx_stablecoin.aleo/transfer_public(PRESIDING_DAO_TREASURY, total);

        return finalize_register_worker(pay_f, self.caller, name_hash);
    }

    async function finalize_register_worker(pay_f: Future, owner: address, name_hash: field) {
        pay_f.await();

        // Uniqueness enforced in finalize
        assert(worker_primary_name_of.get_or_use(owner, 0field) == 0field);
        assert(name_owner.get_or_use(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);

        name_owner.set(name_hash, owner);
        name_kind.set(name_hash, KIND_WORKER);
        employer_suffix_code.set(name_hash, 0u8);
        worker_primary_name_of.set(owner, name_hash);
    }

    async transition release_worker_name() -> Future {
        return finalize_release_worker_name(self.caller);
    }

    async function finalize_release_worker_name(owner: address) {
        let name_hash: field = worker_primary_name_of.get_or_use(owner, 0field);
        assert(name_hash != 0field);
        assert(name_owner.get_or_use(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == owner);

        name_owner.set(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        name_kind.set(name_hash, 0u8);
        employer_suffix_code.set(name_hash, 0u8);
        worker_primary_name_of.set(owner, 0field);
    }

    // ---------------------------------------------------------
    // Employer flows
    // ---------------------------------------------------------

    // Portal supplies count (which tier: 0=first, 1=second, 2=third).
    // Finalize verifies count matches actual on-chain state.
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

        let verified_f: Future = employer_license_registry.aleo/assert_verified(self.caller);
        let pay_f: Future =
            test_usdcx_stablecoin.aleo/transfer_public(PRESIDING_DAO_TREASURY, total);

        return finalize_register_employer(verified_f, pay_f, self.caller, name_hash, suffix_code, base_price, count);
    }

    async function finalize_register_employer(
        verified_f: Future,
        pay_f: Future,
        owner: address,
        name_hash: field,
        suffix_code: u8,
        base_paid: u128,
        count: u8
    ) {
        verified_f.await();
        pay_f.await();

        // Verify portal-supplied count matches actual on-chain state
        let actual_count: u8 = employer_name_count.get_or_use(owner, 0u8);
        assert(actual_count == count);

        // Verify name not already taken
        assert(name_owner.get_or_use(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);

        name_owner.set(name_hash, owner);
        name_kind.set(name_hash, KIND_EMPLOYER);
        employer_suffix_code.set(name_hash, suffix_code);
        employer_base_paid.set(name_hash, base_paid);
        employer_name_count.set(owner, count + 1u8);
    }

    async transition request_empl_sellback(name_hash: field) -> Future {
        return finalize_request_empl_sellback(self.caller, name_hash);
    }

    async function finalize_request_empl_sellback(owner: address, name_hash: field) {
        assert(name_owner.get_or_use(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == owner);
        assert(name_kind.get_or_use(name_hash, 0u8) == KIND_EMPLOYER);

        let base_paid: u128 = employer_base_paid.get_or_use(name_hash, 0u128);
        let refund: u128 = calc_refund(base_paid);

        name_owner.set(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        name_kind.set(name_hash, 0u8);
        employer_suffix_code.set(name_hash, 0u8);

        let count: u8 = employer_name_count.get_or_use(owner, 0u8);
        employer_name_count.set(owner, count - 1u8);

        sellback_seller.set(name_hash, owner);
        sellback_refund_amount.set(name_hash, refund);
    }

    // Portal supplies seller + refund; finalize verifies they match stored values.
    async transition fulfill_empl_sellback(
        name_hash: field,
        seller: address,
        refund: u128
    ) -> Future {
        assert(self.caller == PRESIDING_DAO_TREASURY);

        let pay_f: Future =
            test_usdcx_stablecoin.aleo/transfer_public(seller, refund);

        return finalize_fulfill_empl_sellback(pay_f, name_hash, seller, refund);
    }

    async function finalize_fulfill_empl_sellback(
        pay_f: Future,
        name_hash: field,
        seller: address,
        refund: u128
    ) {
        // Verify portal-supplied values match stored state
        assert(sellback_seller.get_or_use(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == seller);
        assert(sellback_refund_amount.get_or_use(name_hash, 0u128) == refund);

        pay_f.await();

        sellback_seller.set(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc);
        sellback_refund_amount.set(name_hash, 0u128);
    }

    // ---------------------------------------------------------
    // Cross-program assertion utilities
    // ---------------------------------------------------------

    // Assert that `owner` owns `name_hash`.
    async transition assert_is_owner(name_hash: field, owner: address) -> Future {
        return finalize_assert_is_owner(name_hash, owner);
    }

    async function finalize_assert_is_owner(name_hash: field, owner: address) {
        assert(name_owner.get_or_use(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == owner);
    }

    // Assert that `owner` owns `name_hash` as an employer with matching suffix.
    async transition assert_employer_owner(name_hash: field, owner: address, suffix_code: u8) -> Future {
        return finalize_assert_employer_owner(name_hash, owner, suffix_code);
    }

    async function finalize_assert_employer_owner(name_hash: field, owner: address, suffix_code: u8) {
        assert(name_owner.get_or_use(name_hash, aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc) == owner);
        assert(employer_suffix_code.get_or_use(name_hash, 0u8) == suffix_code);
    }
}
