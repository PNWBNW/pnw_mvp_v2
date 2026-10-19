// ---------------------------------------------------------
// pnw_name_registry_v2.aleo — LOCAL STUB
// ---------------------------------------------------------
// The part of the deployed registry other programs call,
// so `leo build` and `leo test` run without a network fetch:
// `assert_is_owner` as deployed (name_owner, zero-address
// default), and `register_test_name` to seed it in tests.
// Never deployed. Programs that depend on it switch to the
// network copy to deploy (deploy_program.yml).
// ---------------------------------------------------------

program pnw_name_registry_v2.aleo {
    const ZERO_ADDR: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    mapping name_owner: field => address;

    // Test-only: the real registry registers names through the registrar.
    fn register_test_name(name_hash: field, owner: address) -> Final {
        return final {
            name_owner.set(name_hash, owner);
        };
    }

    fn assert_is_owner(name_hash: field, owner: address) -> Final {
        return final {
            let actual: address = name_owner.get_or_use(name_hash, ZERO_ADDR);
            assert(actual == owner);
        };
    }

    @noupgrade
    constructor() {}
}
