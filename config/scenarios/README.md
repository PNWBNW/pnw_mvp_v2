# Scenario Inputs (Phase A)

This folder defines canonical, reusable scenario payloads for test and future app-backed execution.

## Goal

Use one stable shape for:
- operator test runs,
- CI smoke execution wiring,
- and future React/backend dispatch.

This avoids reformatting payloads between "test deploy" and "real deploy" paths.

## Files

- `schema.phaseA.json` — canonical scenario schema for current planning/execution boundary.
- `testnet/min_spend.payroll.json` — starter low-value payroll sample using provided worker/employer inputs.
- `testnet/min_spend.onboarding.json` — starter low-value onboarding sample (including employer suffix code).
- `testnet/broadcast_commands.sample.json` — sample command list (placeholder output only; not for strict receipt mode).
- `testnet/broadcast_commands.onboarding.template.json` — template for real command-driven submissions when `RECEIPT_VERIFICATION_MODE=required`.

## Name hash derivation

When only raw names are available, derive deterministic local hashes with:

```bash
scripts/derive_phaseA_name_hash.py "John D. Doe"
scripts/derive_phaseA_name_hash.py "Acme Inc."
```

These are local planning hashes for scenario wiring. Real execution should still rely on canonical commitment/hash generation in the production pipeline.

## Phase B wiring

`scripts/run_phase4_execute_scenario.sh` supports optional scenario payload ingestion:

```bash
scripts/run_phase4_execute_scenario.sh \
  --scenario payroll_smoke \
  --scenario-file config/scenarios/testnet/min_spend.payroll.json
```

If a scenario file is provided, the runner validates it with `scripts/validate_phaseA_scenario.py` and includes scenario metadata in emitted evidence artifacts.

## Notes

- These files are **non-secret** and can be committed.
- Wallet keys, RPC endpoints, and signing credentials remain in environment secrets.
- Replace placeholder wallet values before real execution.
