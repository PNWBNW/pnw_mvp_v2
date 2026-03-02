# Next Actions (Ordered)

_Last updated: 2026-03-01_

## Next best steps (0-3)

## Phase C readiness

_Status: Phase C started — guarded testnet execution lane is active; execute artifact integrity verifier now gates bundle consistency before upload; on-chain broadcast remains scaffold-only until broadcast wiring is implemented._

0. Finalize Phase A scenario contract and collect sample participant data.
1. Finalize Phase 4 adapter command codec.
2. Capture execute gate smoke evidence in protected environment.
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
- Adapter unit/integration checks for codec serialization and trace schema (`scripts/run_phase4_adapter_tests.sh`).
- Ensure command generation maps each `step.kind` to concrete CLI args (replace generic JSON args mode).

## 2) Execute gate smoke run in protected environment

_Status: Completed — testnet execute gate succeeded and artifacts were captured with SHA256 references._

- Execute workflow used: `.github/workflows/execute_testnet.yml` (`execute_gate`, `testnet-staging`).
- Confirmed required secrets contract and metadata/evidence artifact uploads.

**Acceptance checks**
- Execute gate passes env checks and uploads `execute-gate-metadata` artifact.
- Evidence bundle upload includes deterministic bundle manifest and verification outputs.

**Captured evidence (2026-03-02 run)**
- Raw logs: <https://productionresultssa0.blob.core.windows.net/actions-results/c446a758-f61e-4754-ac10-579dd486ff3e/workflow-job-run-50940363-c69a-5633-b98b-e49a1b8199df/logs/job/job-logs.txt?rsct=text%2Fplain&se=2026-03-02T03%3A29%3A04Z&sig=FZB3RIE%2FBL9d5Y2PR3QsnRhPVmYcMcDuCPlWyCqfjyo%3D&ske=2026-03-02T04%3A32%3A44Z&skoid=ca7593d4-ee42-46cd-af88-8b886a2f84eb&sks=b&skt=2026-03-02T00%3A32%3A44Z&sktid=398a6654-997b-47e9-b12b-9515b896b4de&skv=2025-11-05&sp=r&spr=https&sr=b&st=2026-03-02T03%3A18%3A59Z&sv=2025-11-05>
- `execute-gate-metadata` SHA256: `3d5d6ce776f140765575530a28d1449e96074c2c243989a906fbf7a7c5bf5fc3`
- `execute-evidence-bundle` SHA256: `b3107697f28fb7c4b8d041b4477be82e2c150d3257a0eaf5e7b20c37dbe0f947`

## 3) Script one reproducible happy-path testnet flow

- Prereq checks -> plan -> execute -> verify anchors/receipts.

**Acceptance checks**
- Run emits machine-readable summary and human-readable report (`scripts/run_phase4_testnet_happy_path.sh`).

## Recently completed

- ✅ C2 started: best-effort RPC receipt verification now runs in `execute_gate` and emits `receipt_verification.json`.
- ✅ C1 started: `EXECUTE_BROADCAST=true` now uses command-driven submission via `PHASE4_BROADCAST_COMMANDS_FILE` and records extracted tx IDs in execute artifacts.
- ✅ Added execute artifact integrity verifier (`scripts/verify_phase4_execute_artifacts.py`) and wired it into `execute_gate`.
- ✅ Captured first execute-gate artifact SHA references from successful testnet run.
- ✅ Added static leakage guard script (`scripts/check_layer1_public_leakage_guards.py`) and wired it into `plan_gate`.
- ✅ Added `scripts/run_phase4_adapter_tests.sh` and wired adapter codec tests into `plan_gate`.
- ✅ Split GitHub Actions into plan vs execute gates.
- ✅ Added canonical testnet manifest + validation script.
