// ---------------------------------------------------------
// Suffix validation (40 industry codes, same as v1)
// ---------------------------------------------------------
fn is_valid_suffix(code: u8) -> bool {
    return (code >= 1u8 && code <= 40u8);
}

program pnw_name_registry_v2.aleo {

    // ---------------------------------------------------------
    // PNW Name Registry v2 — Pure Name Storage
    // ---------------------------------------------------------
    // This program stores soulbound .pnw names for workers and employers.
    // It does NOT handle USDCx payments — that is the registrar's job.
    //
    // Write transitions are gated: only the authorized registrar
    // (or admin for setup) can call register/fulfill transitions.
    //
    // Assertion transitions (assert_is_owner, assert_employer_owner)
    // are public and callable by any program for cross-program guards.
    // ---------------------------------------------------------

    // Name kinds
    const KIND_WORKER: u8 = 1u8;
    const KIND_EMPLOYER: u8 = 2u8;

    // Admin address (for setup operations)
    const ADMIN: address = aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx;

    // Zero address sentinel
    const ZERO_ADDR: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    // ---------------------------------------------------------
    // Mappings
    // ---------------------------------------------------------
    mapping name_owner: field => address;
    mapping name_kind: field => u8;
    mapping employer_suffix_code: field => u8;
    mapping worker_primary_name_of: address => field;
    mapping employer_primary_name_of: address => field;
    mapping employer_name_count: address => u8;
    mapping employer_base_paid: field => u128;
    mapping sellback_seller: field => address;
    mapping sellback_refund_amount: field => u128;

    // Authorized registrar program address (set by admin post-deployment)
    mapping authorized_caller: u8 => address;

    // ---------------------------------------------------------
    // Admin: set the authorized registrar address
    // Call once after deploying the registrar.
    // ---------------------------------------------------------
    fn set_authorized_caller(registrar_addr: address) -> Final {
        assert(self.caller == ADMIN);
        return final {
            authorized_caller.set(0u8, registrar_addr);
        };
    }

    // ---------------------------------------------------------
    // Worker name registration (called by registrar only)
    // ---------------------------------------------------------
    fn register_worker_name(name_hash: field, owner: address) -> Final {
        let caller: address = self.caller;
        return final {
            // Access control: caller must be the authorized registrar
            let registrar: address = authorized_caller.get_or_use(0u8, ZERO_ADDR);
            assert(caller == registrar || caller == ADMIN);

            // Worker can only have one name
            let existing: field = worker_primary_name_of.get_or_use(owner, 0field);
            assert(existing == 0field);

            // Name must be unclaimed
            let current_owner: address = name_owner.get_or_use(name_hash, ZERO_ADDR);
            assert(current_owner == ZERO_ADDR);

            // Store
            name_owner.set(name_hash, owner);
            name_kind.set(name_hash, KIND_WORKER);
            employer_suffix_code.set(name_hash, 0u8);
            worker_primary_name_of.set(owner, name_hash);
        };
    }

    // ---------------------------------------------------------
    // Employer name registration (called by registrar only)
    // ---------------------------------------------------------
    fn register_employer_name(
        name_hash: field,
        suffix_code: u8,
        count: u8,
        base_price: u128,
        owner: address
    ) -> Final {
        assert(is_valid_suffix(suffix_code));
        assert(count < 3u8);
        let caller: address = self.caller;
        return final {
            // Access control
            let registrar: address = authorized_caller.get_or_use(0u8, ZERO_ADDR);
            assert(caller == registrar || caller == ADMIN);

            // Verify portal-supplied count matches on-chain state
            let actual_count: u8 = employer_name_count.get_or_use(owner, 0u8);
            assert(actual_count == count);

            // Name must be unclaimed
            let current_owner: address = name_owner.get_or_use(name_hash, ZERO_ADDR);
            assert(current_owner == ZERO_ADDR);

            // Store
            name_owner.set(name_hash, owner);
            name_kind.set(name_hash, KIND_EMPLOYER);
            employer_suffix_code.set(name_hash, suffix_code);
            employer_base_paid.set(name_hash, base_price);
            employer_name_count.set(owner, actual_count + 1u8);

            // Set as primary if this is the first name
            let current_primary: field = employer_primary_name_of.get_or_use(owner, 0field);
            if (current_primary == 0field) {
                employer_primary_name_of.set(owner, name_hash);
            }
        };
    }

    // ---------------------------------------------------------
    // Worker name release (callable directly by the worker)
    // ---------------------------------------------------------
    fn release_worker_name() -> Final {
        let caller: address = self.caller;
        return final {
            let name_hash: field = worker_primary_name_of.get_or_use(caller, 0field);
            assert(name_hash != 0field);

            let owner: address = name_owner.get_or_use(name_hash, ZERO_ADDR);
            assert(owner == caller);

            name_owner.set(name_hash, ZERO_ADDR);
            name_kind.set(name_hash, 0u8);
            worker_primary_name_of.set(caller, 0field);
        };
    }

    // ---------------------------------------------------------
    // Employer sellback request (callable directly by the employer)
    // ---------------------------------------------------------
    fn request_empl_sellback(name_hash: field) -> Final {
        let caller: address = self.caller;
        return final {
            let owner: address = name_owner.get_or_use(name_hash, ZERO_ADDR);
            assert(owner == caller);

            let kind: u8 = name_kind.get_or_use(name_hash, 0u8);
            assert(kind == KIND_EMPLOYER);

            // Clear ownership
            name_owner.set(name_hash, ZERO_ADDR);
            name_kind.set(name_hash, 0u8);
            employer_suffix_code.set(name_hash, 0u8);

            // Decrement count
            let count: u8 = employer_name_count.get_or_use(caller, 0u8);
            assert(count > 0u8);
            employer_name_count.set(caller, count - 1u8);

            // Store sellback info for fulfillment
            let base_paid: u128 = employer_base_paid.get_or_use(name_hash, 0u128);
            let refund: u128 = (base_paid * 75u128) / 100u128;
            sellback_seller.set(name_hash, caller);
            sellback_refund_amount.set(name_hash, refund);
        };
    }

    // ---------------------------------------------------------
    // Employer sellback fulfillment (called by registrar only)
    // ---------------------------------------------------------
    fn fulfill_empl_sellback(
        name_hash: field,
        seller: address,
        refund: u128
    ) -> Final {
        let caller: address = self.caller;
        return final {
            // Access control
            let registrar: address = authorized_caller.get_or_use(0u8, ZERO_ADDR);
            assert(caller == registrar || caller == ADMIN);

            // Verify matches stored sellback
            let stored_seller: address = sellback_seller.get_or_use(name_hash, ZERO_ADDR);
            assert(stored_seller == seller);
            let stored_refund: u128 = sellback_refund_amount.get_or_use(name_hash, 0u128);
            assert(stored_refund == refund);

            // Clear sellback state
            sellback_seller.set(name_hash, ZERO_ADDR);
            sellback_refund_amount.set(name_hash, 0u128);
        };
    }

    // ---------------------------------------------------------
    // Set primary employer name (callable by the employer)
    // ---------------------------------------------------------
    fn set_primary_employer_name(name_hash: field) -> Final {
        let caller: address = self.caller;
        return final {
            // Verify caller owns this name
            let owner: address = name_owner.get_or_use(name_hash, ZERO_ADDR);
            assert(owner == caller);

            // Verify it's an employer name
            let kind: u8 = name_kind.get_or_use(name_hash, 0u8);
            assert(kind == KIND_EMPLOYER);

            // Set as primary
            employer_primary_name_of.set(caller, name_hash);
        };
    }

    // ---------------------------------------------------------
    // Cross-program assertions (public, callable by any program)
    // ---------------------------------------------------------
    fn assert_is_owner(name_hash: field, owner: address) -> Final {
        return final {
            let actual: address = name_owner.get_or_use(name_hash, ZERO_ADDR);
            assert(actual == owner);
        };
    }

    fn assert_employer_owner(name_hash: field, owner: address, suffix_code: u8) -> Final {
        return final {
            let actual: address = name_owner.get_or_use(name_hash, ZERO_ADDR);
            assert(actual == owner);
            let actual_suffix: u8 = employer_suffix_code.get_or_use(name_hash, 0u8);
            assert(actual_suffix == suffix_code);
        };
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx")
    constructor() {}
}
