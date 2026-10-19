// ---------------------------------------------------------
// pnw_name_registry_v2.aleo — LOCAL STUB
// ---------------------------------------------------------
// The part of the deployed registry other programs call,
// so `leo build` and `leo test` run without a network fetch:
// `assert_is_owner` and `assert_employer_owner` as deployed
// (name_owner and employer_suffix_code, zero defaults), and
// two test-only calls to seed them: `register_test_name`
// (a worker name: no industry code) and
// `register_test_employer` (a business name with its code).
// Never deployed. Programs that depend on it switch to the
// network copy to deploy (deploy_program.yml).
// ---------------------------------------------------------

program pnw_name_registry_v2.aleo {
    const ZERO_ADDR: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    mapping name_owner: field => address;
    mapping employer_suffix_code: field => u8;

    // Test-only: the real registry registers names through the registrar.
    // A worker name: the registry stores no industry code for it (0).
    fn register_test_name(name_hash: field, owner: address) -> Final {
        return final {
            name_owner.set(name_hash, owner);
            employer_suffix_code.set(name_hash, 0u8);
        };
    }

    // Test-only: a business name, registered under an industry code (1 to 40).
    fn register_test_employer(name_hash: field, owner: address, suffix_code: u8) -> Final {
        assert(suffix_code >= 1u8 && suffix_code <= 40u8);
        return final {
            name_owner.set(name_hash, owner);
            employer_suffix_code.set(name_hash, suffix_code);
        };
    }

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

    @noupgrade
    constructor() {}
}
