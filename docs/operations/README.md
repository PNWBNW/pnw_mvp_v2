# Operations Docs Index

This folder centralizes execution-phase and operator-facing documents that were previously at the repo root.

## Start here

1. `BUILD_ORDER.md` — canonical phase sequence and non-goals.
2. `PHASE3_SIGNOFF.md` — completed Phase 3 exit checklist.
3. `PHASE4_CLI_SETUP.md` — pinned Leo/snarkOS setup and verification.
4. `PHASE4_TESTNET_GAMEPLAN.md` — Phase 4→6 execution and testnet plan.

## Related context hub

For thread continuity and action tracking, also review:
- `../context/README.md`
- `../context/PHASE_TRACKER.md`
- `../context/NEXT_ACTIONS.md`
- `../context/DECISIONS_LOG.md`
## Supporting config/scripts

- `../../config/testnet.manifest.json` — canonical testnet program-ID manifest for execute workflows.
- `../../scripts/validate_testnet_manifest.py` — manifest schema validator used by CI gates.
- `../../scripts/require_phase4_execute_env.sh` — execute-mode env/secrets presence gate.
- `../../scripts/check_layer1_public_leakage_guards.py` — CI guardrail against cumulative public spend-counter patterns in Layer 1 Leo sources.
- `../../scripts/run_phase4_adapter_tests.sh` — compile + execute Phase 4 adapter codec tests (uses local `tsc` when available, falls back to `npx` in CI).
- `../../config/scenarios/schema.phaseA.json` — canonical scenario input contract for test + app dispatch parity.
- `../../scripts/validate_phaseA_scenario.py` — dependency-free Phase A scenario validator.
- `../../scripts/derive_phaseA_name_hash.py` — deterministic local hash helper for raw worker/employer names.
