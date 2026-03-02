# Next Actions (Ordered)

_Last updated: 2026-03-01_

## Next best steps (0-3)

0. Finalize Phase A scenario contract and collect sample participant data.
1. Finalize Phase 4 adapter command codec.
2. Run execute gate smoke in protected environment.
3. Script one reproducible happy-path testnet flow.


## 0) Phase A scenario contract (new)

_Status: Started — canonical scenario schema and a low-spend testnet sample are now committed under `config/scenarios/`; dependency-free validator added at `scripts/validate_phaseA_scenario.py`._

- Keep one canonical payload format for test deploy + future app/backend dispatch.
- Collect real participant/test values (name hashes, addresses, agreement/epoch, anchors).
- Validate every scenario file before execute runs.

**Acceptance checks**
- `python3 scripts/validate_phaseA_scenario.py config/scenarios/testnet/min_spend.payroll.json`
- Scenario payload remains compatible with Layer 1 `execute_payroll` field requirements.

## 1) Finalize Phase 4 adapter command codec

_Status: In progress — deterministic `step.kind` command/codec mapping + typed adapter errors + trace schema are now scaffolded in `portal/src/adapters/aleo_cli_adapter.ts`; retry boundary scaffold added for retryable execution errors; baseline adapter tests added in `portal/tests/phase4_adapter.test.ts`; expand coverage as new transitions are wired._

- Map each `step.kind` to exact `{program, transition, argCodec}`.
- Replace scaffold command generation with concrete Aleo CLI syntax.
- Add typed error taxonomy and retry policy boundaries.

**Acceptance checks**
- `npx --yes --package typescript tsc -p portal/tsconfig.phase4.json`
- Adapter unit/integration checks for codec serialization and trace schema.
- Ensure command generation maps each `step.kind` to concrete CLI args (replace generic JSON args mode).

## 2) Execute gate smoke run in protected environment

- Run `execute_gate` via manual dispatch (`run_mode=execute`) using `testnet-staging` environment.
- Confirm required secrets contract is satisfied and metadata artifact uploads.

**Acceptance checks**
- Manual execute run requires environment reviewers.
- Execute gate passes env checks and uploads `execute-gate-metadata` artifact.

## 3) Script one reproducible happy-path testnet flow

- Prereq checks -> plan -> execute -> verify anchors/receipts.

**Acceptance checks**
- Run emits machine-readable summary and human-readable report.

## Recently completed

- ✅ Split GitHub Actions into plan vs execute gates.
- ✅ Added canonical testnet manifest + validation script.
