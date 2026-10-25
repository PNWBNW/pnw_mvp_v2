// ---------------------------------------------------------
// employer_license_registry.aleo — LOCAL STUB
// ---------------------------------------------------------
// The part of the deployed licence registry other programs
// call, so `leo build` and `leo test` run without a network
// fetch: `assert_verified` as deployed (is_verified, false by
// default), and a test-only `set_test_verified` to seed it.
// On chain only the authority can set a wallet's flag
// (`set_verified`); the stub drops that gate so a test can
// play the authority. Never deployed. Programs that depend
// on it switch to the network copy to deploy
// (deploy_program.yml).
// ---------------------------------------------------------

program employer_license_registry.aleo {
    // wallet -> verified flag
    mapping is_verified: address => bool;

    // Test-only: on chain this is `set_verified`, the authority's alone.
    fn set_test_verified(wallet: address, verified: bool) -> Final {
        return final {
            is_verified.set(wallet, verified);
        };
    }

    fn assert_verified(wallet: address) -> Final {
        return final {
            let ok: bool = is_verified.get_or_use(wallet, false);
            assert(ok);
        };
    }

    @noupgrade constructor() {}
}
