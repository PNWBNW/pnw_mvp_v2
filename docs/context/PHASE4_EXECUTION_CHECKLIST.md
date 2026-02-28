# Phase 4 Execution Checklist (GitHub Actions + Secrets)

_Last updated: 2026-02-27_

This checklist is the **operator-focused sequence** to move from planning-only to testnet execution with minimal risk.

---

## 1) Freeze toolchain and runtime assumptions

- Confirm pinned versions in one place and keep workflow/docs in sync:
  - `LEO_VERSION=canary-v3.5.0`
  - `SNARKOS_VERSION=v4.4.0`
- Verify local and CI with `scripts/verify_provable_cli.sh`.
- Treat any version mismatch as a stop-ship for execute mode.

**Exit condition:** identical CLI versions across operators + CI evidence attached to PR.

---

## 2) Split CI into two enforcement lanes

### Lane A — `plan_gate` (PR-safe, required)

Runs on `pull_request` and `push`:
- Phase 3 planner type gate
- Phase 4 adapter type gate
- no secrets
- no transaction execution

### Lane B — `execute_gate` (manual + protected)

Runs only on `workflow_dispatch` and protected environments:
- requires environment reviewers
- consumes GitHub Secrets
- executes limited happy-path script
- uploads artifacts (trace JSON, tx IDs, verification summary)

**Exit condition:** branch protection requires `plan_gate`; `execute_gate` cannot run from PR context.

---

## 3) Define minimum viable secret contract

Start with least-privilege secrets:
- `ALEO_PRIVATE_KEY`
- `ALEO_VIEW_KEY` (if receipt verification/indexing needed)
- `ALEO_ADDRESS`
- `RPC_URL`
- `USDCX_PROGRAM_ID`

Recommended GitHub environment variables (non-secret):
- `PNW_NETWORK=testnet`
- `PHASE4_RUN_MODE=execute`
- `MANIFEST_PATH=config/testnet.manifest.json`

Rules:
- secrets only in environment-scoped context (`testnet-staging`, then `testnet-prod`)
- never log keys or raw command payloads containing secrets
- mask any derived sensitive values in workflow output

**Exit condition:** execute workflow fails fast when required secrets are absent.

---

## 4) Add canonical testnet manifest before real execution

Create versioned manifest for environment-specific IDs:
- Layer 1 program IDs
- Layer 2 program IDs
- external program IDs (USDCx)
- schema version

Run manifest validation before adapter execution.

**Exit condition:** adapter refuses to execute when manifest is invalid/incomplete.

---

## 5) Finalize adapter command codec and observability

- Replace generic `--args-json` scaffold with explicit per-step argument codecs.
- Add typed error taxonomy:
  - validation/input
  - chain rejection
  - transient/retryable transport/runtime
  - invariant violations
- Emit stable trace schema for every step:
  - `step_index`, `step_kind`, `program`, `transition`, `args_fingerprint`, `status`, `tx_id?`, `error_code?`

**Exit condition:** deterministic command generation for each supported `step.kind` + replayable traces.

---

## 6) Run the first constrained testnet happy path

Flow:
1. prerequisites + manifest validation
2. planning
3. execute minimal transition set
4. verify expected anchors/records
5. upload evidence artifacts

Validation targets:
- active agreement invariant
- duplicate `(agreement_id, epoch_id)` prevention
- audit anchor presence
- receipt path available for Layer 2 follow-up

**Exit condition:** one reproducible runbook command with artifacts attached.

---

## 7) Expand into Phase 5/6 after first green run

Phase 5 (correctness):
- add one negative-path test per critical invariant
- confirm payroll NFT mint from real receipts
- confirm minimal audit auth + attestation lifecycle

Phase 6 (hardening):
- adapter codec tests
- incident/rollback playbook
- release checklist (pins, manifest, secrets, verification)

**Exit condition:** repeatable execution with bounded failure handling and operator docs.
