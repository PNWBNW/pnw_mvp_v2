# Phase 4 follow-up split plan (3 PR sequence)

Purpose: keep reviews small and avoid one large web-editor pass.

## PR 1 — CI/runtime stability only

Scope (small, unblockers only):
- Plan gate compilation/runtime regressions.
- Execute env guard correctness (secrets/env fallback behavior).
- Evidence bundle JSON validity fixes that can fail downstream verification.

Review checklist:
- `tsc -p portal/tsconfig.phase3.json` passes.
- `tsc -p portal/tsconfig.phase4.json` passes.
- `scripts/run_phase4_adapter_tests.sh` passes.
- `scripts/require_phase4_execute_env.sh` behavior is deterministic with and without optional endpoint vars.

Out of scope:
- New scenario formats.
- New operator workflow features.
- Non-critical docs expansion.

## PR 2 — Scenario contract + validators only

Scope:
- `config/scenarios/*` schema/sample alignment.
- `scripts/validate_phaseA_scenario.py` and related deterministic helpers.
- Strict metadata/traceability requirements (`scenario_id`, field constraints).

Review checklist:
- `python3 scripts/validate_phaseA_scenario.py config/scenarios/testnet/min_spend.payroll.json`
- `python3 scripts/validate_phaseA_scenario.py config/scenarios/testnet/min_spend.onboarding.json`
- Negative fixture check for required-field failures.

Out of scope:
- Workflow topology changes.
- Execute lane receipt verification logic.

## PR 3 — Execute workflow + operator docs only

Scope:
- `.github/workflows/execute_testnet.yml` guard flow and artifact upload behavior.
- Execute helpers (`run_phase4_execute_scenario.sh`, receipt/artifact verifiers) only where required by workflow wiring.
- Operator docs/runbooks (`docs/operations/*`, `docs/context/*`) aligned to final behavior.

Review checklist:
- Workflow YAML parse checks.
- Artifact manifest/receipt verification scripts run against generated artifacts.
- Docs reflect actual required vs optional secrets and endpoint semantics.

Out of scope:
- Layer 2 adapter codec redesign.
- Layer 1 contract semantics changes.

## Process rules for all 3 PRs

- Each PR must include only files within its declared scope.
- Each PR must include a short rollback note in its description.
- Each PR must include a focused test block (only commands relevant to that PR).
- Merge order: PR 1 → PR 2 → PR 3.
