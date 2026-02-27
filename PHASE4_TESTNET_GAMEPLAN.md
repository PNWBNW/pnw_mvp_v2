# Phase 4+ Testnet Gameplan (Pre-PR Alignment)

This document captures a practical execution plan for moving from current **Phase 3 signoff** into **Phase 4 adapter execution**, then through **Phase 5 testnet validation** and **Phase 6 hardening**.

It is intended as the repo-level alignment artifact before opening implementation PRs.

---

## 0) Current State Summary (from repo review)

- Layer 1 programs are implemented and documented with a stable interface contract (`src/layer1/LAYER1_INTERFACE.md`).
- Layer 2 NFT programs are implemented and documented.
- Portal workflows/routers are planning-first and Phase 3 has explicit signoff criteria already met.
- Phase 4 scaffold exists:
  - pinned CLI versions in docs and CI,
  - a bootstrap workflow (`.github/workflows/deploy.yml`),
  - plan-only execution adapter scaffold (`portal/src/adapters/aleo_cli_adapter.ts`).

Conclusion: the project is in a good position to begin Phase 4 with disciplined sequencing.

---

## 1) Phase 4 Objective (Execution Boundary Only)

**Primary objective:** convert planner output into deterministic, observable transaction execution without changing protocol semantics.

### Success criteria

- Router/workflow modules remain planning-only.
- Adapters become the only execution boundary.
- CLI command building and arg encoding are deterministic and versioned.
- Execution traces are structured enough for replay/debugging.
- CI can run a no-secret plan gate on every change and a secret-backed execute gate on manual dispatch.

---

## 2) Immediate Workstreams (recommended PR sequence)

### PR A — Adapter command codec finalization

Scope:
- Replace scaffold command builder in `portal/src/adapters/aleo_cli_adapter.ts` with real Aleo CLI syntax per transition shape.
- Add explicit input codec helpers (scalar formatting, address handling, field/u64 normalization, record refs).
- Add an adapter-level error taxonomy:
  - retryable transport/runtime,
  - deterministic input/validation,
  - invariant violation.

Deliverables:
- Deterministic command map: `step.kind -> {program, transition, argCodec}`.
- Typed execution error classes.
- Structured execution trace with stable JSON schema.

---

### PR B — Secrets-aware GitHub Actions split

Scope:
- Keep current workflow as base bootstrap.
- Add split jobs:
  - `plan_gate` (no secrets, PR-safe),
  - `execute_gate` (manual `workflow_dispatch`, environment-protected, requires secrets).
- Add concurrency and environment controls for execute runs.

Recommended GitHub configuration:
- **Environments**: `testnet-staging`, `testnet-prod` (with required reviewers).
- **Protected branches**: require `plan_gate` status checks.

Recommended secrets (start minimal):
- `ALEO_PRIVATE_KEY` (or equivalent signing secret strategy).
- `ALEO_VIEW_KEY` (if needed for receipt/indexing verification steps).
- `ALEO_ADDRESS` (optional but useful for consistency checks).
- `RPC_URL` (if not using default public endpoint).
- `USDCX_PROGRAM_ID` and other deploy-time program IDs (if environment-specific).

Notes:
- Never print secrets; mask all sensitive outputs.
- Do not run execute jobs on `pull_request` events.

---

### PR C — Testnet manifest + environment resolution

Scope:
- Add a canonical manifest file for program IDs by network/environment.
- Wire portal config resolution to this manifest (instead of ad hoc values).
- Add validation that all required IDs are present before execution.

Deliverables:
- `config/testnet.manifest.json` (or similar) with explicit schema versioning.
- Startup/CI validation script for manifest integrity.

---

### PR D — End-to-end happy path executor script

Scope:
- Script one full happy path for testnet:
  1. prerequisites checks,
  2. planning,
  3. execute transitions,
  4. verify expected anchors/records.
- Emit artifact bundle (step traces + transaction IDs + verification summary).

Deliverables:
- Reproducible runbook command for operators.
- CI artifact uploads for execute runs.

---

## 3) Phase 5 Validation Plan (correctness-first)

Run order should match `BUILD_ORDER.md` intent:

1. Deploy/confirm Layer 1 + Layer 2 program IDs for target testnet environment.
2. Execute one happy-path payroll flow.
3. Verify invariants:
   - agreement must be active,
   - duplicate payroll for same `(agreement_id, epoch_id)` prevented,
   - audit anchor existence,
   - receipt issuance available to downstream steps.
4. Mint payroll NFT anchored to real payroll outputs.
5. Run minimal audit authorization + attestation flow.
6. Execute one negative-path check per critical invariant.

Exit criteria:
- All validations pass with preserved evidence artifacts.
- Any known gaps captured as bounded issues (not tribal knowledge).

---

## 4) Phase 6 Hardening (post-first execute)

- Add integration tests for adapter codec + trace schema stability.
- Add rollback/replay operator notes.
- Freeze release checklist:
  - CLI pin checks,
  - manifest version checks,
  - environment/secrets checks,
  - post-run verification checks.
- Add incident playbook for failed/partial execute runs.

---

## 5) Risk Register (watch now)

- **CLI drift risk:** pinned versions are good; enforce in CI and local checks.
- **Arg encoding mismatch risk:** highest likelihood failure in early Phase 4.
- **Secret handling risk:** execute mode must be environment-gated and manually approved.
- **Config drift risk:** without a canonical manifest, testnet IDs can desync across contributors.
- **Observability gap risk:** insufficient step trace detail slows debugging and signoff.

---

## 6) Operational Guardrails (recommended)

- Keep all execution logic behind adapter interfaces.
- No workflow/router direct CLI calls.
- Any new transition requires:
  - planner step type,
  - adapter endpoint mapping,
  - codec test/update,
  - docs update.
- Every execute run must produce downloadable artifacts.

---

## 8) Context Continuity (new-thread resilience)

To minimize context loss across interrupted conversations, maintain a single handoff surface in `docs/context/`:

- `PHASE_TRACKER.md` for phase state + exit criteria
- `DECISIONS_LOG.md` for durable decisions
- `NEXT_ACTIONS.md` for ordered implementation queue

Rule: any PR that changes roadmap/execution posture should update these files in the same change.

---

## 9) Definition of Ready for First Phase 4 Implementation PR

A Phase 4 implementation PR is ready when:

- pinned toolchain is verified (`scripts/verify_provable_cli.sh`),
- adapter codec plan is documented for included step kinds,
- workflow split (`plan_gate` vs `execute_gate`) is defined,
- required secrets/environment strategy is agreed,
- acceptance checks and artifacts are listed in PR description.

