# PNW MVP v2 — Recommended Build Order

This document defines the **ideal sequence of work** for continuing development of PNW MVP v2.

It is not a task backlog.  
It is an **order-of-operations guide** designed to minimize rework, whiplash, and premature testing.

---

## Phase 0 — Current State (Completed)

- ✅ Layer 1 Aleo programs implemented
- ✅ Layer 1 interfaces extracted and frozen (`LAYER1_INTERFACE.md`)
- ✅ Layer 1 routers and adapters defined (non-executing)
- ✅ Canonical encoding and commitment logic implemented
- ✅ Payroll normalization and aggregation logic implemented
- ✅ Extensive README and architecture documentation completed

At this point, **architecture and intent are stable**.

---

## Phase 1 — Portal Workflow Definition (Completed)

> **Do not begin CLI, testnet, or execution work before this phase is complete.**

### Goal (met)
Define **canonical, end-to-end workflows** that describe *what happens*, without executing anything.

### Completed Scope
1. Created `portal/src/workflows/`
2. Implemented:
   - `payroll_workflow.ts`
     - Inputs required
     - Step ordering
     - Required hashes and anchors
     - Outputs produced
3. Implement:
   - `audit_workflow.ts`
     - Authorization request flow
     - Scope definition
     - Batched anchoring model
     - Expiry handling
4. Added optional workflows:
   - `onboarding_workflow.ts` (names + profiles)
   - `profile_update_workflow.ts`

**Constraints**
- No CLI calls
- No network execution
- No wallet integration
- No testnet

✅ This phase now locks *intent*.

---

## Phase 2 — Layer 2 On-Chain Programs (Completed)

### Goal (met)
Finalize on-chain NFT primitives used by workflows.

### Completed Scope
1. Completed `credential_nft.aleo`
   - Mint
   - Revoke
   - Scope anchoring
2. Completed `audit_nft.aleo`
   - Authorization NFT
   - Expiry enforcement
   - Audit attestation anchoring
3. Reviewed and finalized `payroll_nfts.aleo`
   - Ensure compatibility with portal workflows
   - Confirm mint options (cycle, quarterly, YTD, EOY)

**Outcome**
✅ All on-chain primitives required by workflows exist.

---

## Current Gap Snapshot (rolled into Phase 3)

The architecture and core primitives are now in place. Remaining gap items are now treated as **Phase 3 completion criteria** so we do not jump ahead into Phase 4 prematurely:

1. **Stabilize Layer 2 routing surface**
   - ✅ `portal/src/router/layer2_router.ts` step coverage mapped for Layer 2 transitions.
   - ✅ Program/transition strings moved to `portal/src/adapters/layer2_adapter.ts` to preserve planner-only router design.
2. **Harden shared portal type contracts**
   - Validate/refine `portal/src/types/aleo_types.ts` and `portal/src/types/aleo_records.ts` against real adapter payload expectations.
   - Ensure no ambiguous scalar/record typing remains in planning modules.
3. **Add a minimal compile/typecheck gate for planning modules**
   - ✅ Added `portal/tsconfig.phase3.json` as a focused no-emit gate for Phase 3 planning contracts.
4. **Keep execution/testing work deferred**
   - Adapter execution remains Phase 4.
   - Testnet validation remains Phase 5.

---

## Phase 3 — Portal Layer 2 Routing (In Progress)

### Goal
Provide the same planning abstraction for Layer 2 that already exists for Layer 1.

### Remaining Steps (to complete Phase 3)
1. ✅ Finalize `portal/src/router/layer2_router.ts`
   - Step/transition coverage and naming consistency reviewed.
2. ✅ Mirror the Layer 1 router philosophy completely:
   - Plan, don’t execute
   - No program strings outside adapters
3. Ensure Layer 2 router consumes:
   - Workflow outputs
   - Canonical hashes
   - Commitment roots
4. Harden/freeze shared type contracts used by routers/workflows:
   - `portal/src/types/aleo_types.ts`
   - `portal/src/types/aleo_records.ts`
5. ✅ Add a minimal compile/typecheck gate for portal planning modules (`portal/tsconfig.phase3.json`).
6. Define explicit Phase 3 exit criteria:
   - Router API stable
   - Type contracts stable
   - Planning modules pass typecheck

---

## Phase 4 — Adapter Execution (CLI / Wallet)

> **Only begin after workflows and Layer 2 programs are stable.**

### Goal
Turn planned workflows into actual transactions.

### Recommended Steps
1. Implement Aleo CLI adapter (real execution)
2. Map:
   - router steps → program + transition
3. Add structured execution tracing
4. Keep adapter logic isolated and swappable
5. Add explicit error taxonomy + retry policy for recoverable failures.

---

## Phase 5 — Testnet Validation

### Goal
Confirm correctness, not performance.

### Recommended Steps
1. Deploy Layer 1 programs to testnet
2. Deploy Layer 2 NFT programs to testnet
3. Run a single happy-path payroll flow
4. Verify:
   - USDCx movement
   - Receipt issuance
   - Audit anchor creation
5. Mint a payroll NFT from real receipts
6. Perform a minimal audit authorization flow
7. Execute one negative-path check per critical invariant (revoke, expired auth, duplicate anchor).

No stress tests yet.

---

## Phase 6 — Refinement & Hardening

### Goal
Prepare for additional contributors and real users.

### Recommended Steps
- Revisit Layer 1 logic only if workflows expose gaps
- Add light integration tests
- Tighten adapter error handling
- Finalize root README and diagrams
- Add contribution guidelines
- Add release checklist (version pinning, deployment manifests, rollback notes)
- Add security review checklist for commitment encoding and disclosure boundaries

---

## Explicit Non-Goals (For This Repo)

- Governance DAO logic
- Treasury pooling
- Voting systems
- Cross-chain bridges
- Performance optimization

These belong in **separate repositories**.

---

## Guiding Rule

> **Define workflows before execution.  
> Define execution before testing.  
> Define correctness before optimization.**

Following this order preserves design integrity and developer sanity.
