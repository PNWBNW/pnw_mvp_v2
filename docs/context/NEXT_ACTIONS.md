# Next Actions (Ordered)

_Last updated: 2026-02-28_

## Next best steps (1-3)

1. Finalize Phase 4 adapter command codec.
2. Run execute gate smoke in protected environment.
3. Script one reproducible happy-path testnet flow.

## 1) Finalize Phase 4 adapter command codec

_Status: In progress — deterministic `step.kind` command/codec mapping + typed adapter errors + trace schema are now scaffolded in `portal/src/adapters/aleo_cli_adapter.ts`; codec/integration tests remain._

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
