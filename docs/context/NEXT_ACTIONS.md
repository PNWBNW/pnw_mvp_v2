# Next Actions (Ordered)

_Last updated: 2026-02-27_

## 1) Finalize Phase 4 adapter command codec

- Map each `step.kind` to exact `{program, transition, argCodec}`.
- Replace scaffold command generation with concrete Aleo CLI syntax.
- Add typed error taxonomy and retry policy boundaries.

**Acceptance checks**
- `npx --yes tsc -p portal/tsconfig.phase4.json`
- Adapter unit/integration checks for codec serialization and trace schema.

## 2) Split GitHub Actions into plan vs execute gates

- Keep PR checks secrets-free.
- Execute path only on manual dispatch and protected environments.
- Add artifact upload for traces and verification outputs.

**Acceptance checks**
- PR run proves plan gate passes without secrets.
- Manual execute run requires environment reviewers and emits artifacts.

## 3) Add testnet manifest + validation

- Canonical program-ID manifest per environment.
- Validation step before execution begins.

**Acceptance checks**
- Validation fails fast when manifest is incomplete or malformed.

## 4) Script one reproducible happy-path testnet flow

- Prereq checks -> plan -> execute -> verify anchors/receipts.

**Acceptance checks**
- Run emits machine-readable summary and human-readable report.
