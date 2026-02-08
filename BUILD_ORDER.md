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

## Phase 1 — Portal Workflow Definition (Highest Priority)

> **Do not begin CLI, testnet, or execution work before this phase is complete.**

### Goal
Define **canonical, end-to-end workflows** that describe *what happens*, without executing anything.

### Recommended Steps
1. Create `portal/src/workflows/`
2. Implement:
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
4. (Optional) Add:
   - `onboarding_workflow.ts` (names + profiles)
   - `profile_update_workflow.ts`

**Constraints**
- No CLI calls
- No network execution
- No wallet integration
- No testnet

This phase locks *intent*.

---

## Phase 2 — Layer 2 On-Chain Programs

### Goal
Finalize on-chain NFT primitives used by workflows.

### Recommended Steps
1. Complete `credential_nft.aleo`
   - Mint
   - Revoke
   - Scope anchoring
2. Complete `audit_nft.aleo`
   - Authorization NFT
   - Expiry enforcement
   - Audit attestation anchoring
3. Review `payroll_nfts.aleo`
   - Ensure compatibility with portal workflows
   - Confirm mint options (cycle, quarterly, YTD, EOY)

**Outcome**
All on-chain primitives required by workflows exist.

---

## Phase 3 — Portal Layer 2 Routing

### Goal
Provide the same planning abstraction for Layer 2 that already exists for Layer 1.

### Recommended Steps
1. Implement `portal/src/router/layer2_router.ts`
2. Mirror the Layer 1 router philosophy:
   - Plan, don’t execute
   - No program strings outside adapters
3. Ensure Layer 2 router consumes:
   - Workflow outputs
   - Canonical hashes
   - Commitment roots

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

---

## Phase 5 — Testnet Validation

### Goal
Confirm correctness, not performance.

### Recommended Steps
1. Deploy Layer 1 programs to testnet
2. Run a single happy-path payroll flow
3. Verify:
   - USDCx movement
   - Receipt issuance
   - Audit anchor creation
4. Mint a payroll NFT from real receipts
5. Perform a minimal audit authorization flow

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
