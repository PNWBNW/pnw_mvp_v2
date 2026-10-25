# src/stubs — local stand-ins for deployed programs

`leo build` and `leo test` want every imported program on disk. For programs we don't own, or
whose live copy would pull in the whole network, a program here carries just the interface the
others call, so a program can be compiled and its tests run offline.

| Stub | Stands in for | What it carries |
|---|---|---|
| `test_usdcx_stablecoin.aleo` | The testnet USDCx stablecoin | The `Token` record, the `account` mapping, `transfer_private`, `transfer_public`, `transfer_public_as_signer`, and a test-only `mint_test` |
| `pnw_name_registry_v2.aleo` | Our own deployed registry | `assert_is_owner` and `assert_employer_owner` as deployed, plus test-only `register_test_name` and `register_test_employer` to seed names |
| `employer_agreement_v5.aleo` | Our own deployed agreement program | The pair tag (the same hash over the same struct as deployed), `pair_status`, `assert_pair_active` and `assert_pair_agreed` as deployed, plus a test-only `set_test_pair` to seed a pair's status |

A program's `program.json` points at a stub with a relative path (`../../stubs/...`). The
deploy workflow (`.github/workflows/deploy_program.yml`) swaps those for the deployed programs
before it compiles the bytecode it deploys, so a stub never reaches the chain. The test-only
functions exist only here.
