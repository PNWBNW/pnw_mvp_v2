# src/stubs — local stand-ins for deployed programs

`leo build` and `leo test` want every imported program on disk. For programs we don't own, or
whose live copy would pull in the whole network, a program here carries just the interface the
others call, so a program can be compiled and its tests run offline.

| Stub | Stands in for | What it carries |
|---|---|---|
| `test_usdcx_stablecoin.aleo` | The testnet USDCx stablecoin | The `Token`, `ComplianceRecord` and `Credentials` records, the `balances` mapping, and `transfer_private`, `transfer_public_to_private`, `split`, `join`, `transfer_public`, `transfer_public_as_signer` with the deployed program's names, input order and output order (read from its bytecode, 2026-11-07); plus a test-only `mint_test` (a public balance from nothing) and an open `mint_private` (on chain only a minter may). The freeze-list proofs are taken, not checked. Its own tests (`tests/`, 11, in CI) pin the record flow, so a local devnode can rehearse Hewn's payroll against it |
| `pnw_name_registry_v2.aleo` | Our own deployed registry | `assert_is_owner` and `assert_employer_owner` as deployed, plus test-only `register_test_name` and `register_test_employer` to seed names |
| `employer_license_registry.aleo` | Our own deployed licence registry | `assert_verified` as deployed, plus a test-only `set_test_verified` to flag a wallet (on chain only the authority can) |
| `employer_agreement_v5.aleo` | Our own deployed agreement program | The pair tag (the same hash over the same struct as deployed), `pair_status`, `assert_pair_active` and `assert_pair_agreed` as deployed, plus a test-only `set_test_pair` to seed a pair's status |

A program's `program.json` points at a stub with a relative path (`../../stubs/...`). The
deploy workflow (`.github/workflows/deploy_program.yml`) swaps those for the deployed programs
before it compiles the bytecode it deploys, so a stub never reaches the chain. The test-only
functions exist only here.

The USDCx stand-in is the one a devnode runs (Hewn's `apps/business/test/devnode/`): its bytecode,
built by Leo 4.0.0 from the source here, is pinned there by sha256 beside the live programs. It is
never deployed to testnet, where the real program already owns the name.
