# Next Actions (Ordered)

_Last updated: 2026-03-03_

## Next best steps (0-3)

0. Finalize Phase A scenario contract and collect sample participant data.
1. Finalize Phase 4 adapter command codec.
2. Run execute gate smoke in protected environment.
3. Script one reproducible happy-path testnet flow.


## 0) Phase A/B scenario contract (new)

_Status: In progress — canonical schema, validator, and Phase B `scenario_file` ingestion are wired; payroll + onboarding min-spend samples now include provided raw names, locally-derived hashes, worker destination address, and WA State suffix mapping._

- Keep one canonical payload format for test deploy + future app/backend dispatch.
- Collect real participant/test values (name hashes, addresses, agreement/epoch, anchors).
- Validate every scenario file before execute runs.
- Keep onboarding tests on tier-1 employer registration path only (10 USDCx base + fee).

**Acceptance checks**
- `python3 scripts/validate_phaseA_scenario.py config/scenarios/testnet/min_spend.payroll.json`
- `python3 scripts/validate_phaseA_scenario.py config/scenarios/testnet/min_spend.onboarding.json`
- `scripts/derive_phaseA_name_hash.py "John D. Doe"`
- `scripts/derive_phaseA_name_hash.py "Acme Inc."`
- `scripts/run_phase4_execute_scenario.sh --scenario payroll_smoke --scenario-file config/scenarios/testnet/min_spend.payroll.json`
- Scenario payload remains compatible with Layer 1 `execute_payroll` field requirements.

## 1) Finalize Phase 4 adapter command codec

_Status: In progress — deterministic `step.kind` command/codec mapping + typed adapter errors + trace schema are now scaffolded in `portal/src/adapters/aleo_cli_adapter.ts`; retry boundary scaffold added for retryable execution errors; baseline adapter tests added in `portal/tests/phase4_adapter.test.ts`; exhaustive plan-only command coverage now includes all Layer 2 `step.kind` variants._

- Add anti-leak invariants for public-state surfaces (no cumulative spend counters in public mappings).
- Add an audit evidence taxonomy note/checklist for operator docs (anchor vs commitment vs scope vs proof).
- Keep pooled custody as extension-only; do not introduce budget pot semantics in MVP execute path.

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

- ✅ Added static leakage guard script (`scripts/check_layer1_public_leakage_guards.py`) and wired it into `plan_gate`.
- ✅ Split GitHub Actions into plan vs execute gates.
- ✅ Added canonical testnet manifest + validation script.
