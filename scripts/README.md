# scripts/

Helpers for CI and for operating the programs from a terminal. Three groups.

**The plan gate** (`.github/workflows/deploy.yml`, runs on every pull request; no secrets):

| Script | Does |
|---|---|
| `verify_provable_cli.sh` | Checks the installed `leo` and `snarkos` match the pinned versions |
| `run_phase4_adapter_tests.sh` | Runs `portal/tests/phase4_adapter.test.ts` |
| `validate_testnet_manifest.py` | Checks `config/testnet.manifest.json` against its schema |
| `check_layer2_moves_no_funds.py` | Fails if a Layer 2 program imports anything but the money-free Layer 1 programs, calls another program's function that isn't an `assert_` check, or names a token program or a transfer |
| `check_public_state.py` | Fails if `docs/PUBLIC_STATE.md` misses a mapping in a program's source, lists one that doesn't exist, leaves out an active program, or misstates which programs have Leo tests in this gate |
| `check_layer1_public_leakage_guards.py` | Fails if any Layer 1 program (archive included) names a cumulative counter in public state, the kind that leaks wages by difference |
| `check_phase4_negative_path_guards.sh` | Checks a scenario of the wrong kind is refused |
| `validate_workflow_yaml.sh` | Lints the workflow files |

**The execute gate** (`.github/workflows/execute_testnet.yml`, manual dispatch with secrets).
This is the command-line path, kept as a testing harness; Hewn signs everything in the wallet.

| Script | Does |
|---|---|
| `require_phase4_execute_env.sh` | Refuses to run without the environment it needs |
| `dispatch_phase4_execute.sh`, `run_phase4_execute_scenario.sh`, `run_phase4_testnet_happy_path.sh` | Run a scenario from `config/scenarios/` and collect an evidence bundle |
| `build_onboarding_broadcast_commands.py`, `validate_phase4_broadcast_commands.py` | Build and check the `snarkos developer execute` commands a scenario needs |
| `validate_phaseA_scenario.py`, `derive_phaseA_name_hash.py` | Check a scenario file; derive a name hash the way the programs do |
| `verify_phase4_execute_artifacts.py`, `verify_phase4_receipts.py` | Check the bundle's integrity and look its transactions up on the network |

**By hand:** `scan_usdcx_records.sh` lists an account's USDCx records; `resolve_provable_cli_latest.sh`
finds the newest Leo and snarkOS releases when it's time to bump the pins.

Nothing here holds a key. Keys come from the environment or a GitHub secret, and are never printed.
