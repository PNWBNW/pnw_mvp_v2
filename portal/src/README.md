# Portal — Source Layer

This directory contains the **off-chain orchestration layer** for the PNW MVP.

The Portal does **not** replace on-chain logic.  
It coordinates, normalizes, and prepares data for interaction with Layer 1 and Layer 2 Aleo programs in a deterministic and auditable way.

---

## Purpose

The Portal is responsible for:

- Orchestrating workflows across multiple Layer 1 programs
- Normalizing and aggregating private on-chain receipts
- Producing canonical documents (paystubs, summaries, reports)
- Generating cryptographic commitments (hashes, Merkle roots, token IDs)
- Planning on-chain interactions via routers and adapters

The Portal **plans and proves** — it does not act as a source of truth.

### How the Portal operates (human narrative)
Think of the Portal as a deterministic coordinator with four responsibilities:

1. **Understand intent**
   - Workflows describe business intent in human-readable, ordered steps.

2. **Translate intent into callable plans**
   - Routers transform workflow intent into typed `CallPlanStep[]` actions.

3. **Attach cryptographic commitments**
   - Commitments modules produce hashes/roots so off-chain artifacts stay verifiable.

4. **Hand execution to adapters (later phase)**
   - Adapters are the only place where signing/broadcasting happens.

Why this separation exists:
- It keeps privacy assumptions explicit.
- It makes reviews easier (intent vs execution are separate concerns).
- It lowers onboarding cost for new contributors.

---

## Directory Overview

### `adapters/`
Execution adapters that translate planned actions into concrete calls
(e.g. Aleo CLI, SDKs, or future wallet integrations).

Adapters are intentionally isolated so execution logic can be swapped
without changing workflows or routers.

---

### `workflows/`
Planning-only workflow definitions that describe end-to-end intent.

- `payroll_workflow.ts`
  - declares required payroll inputs
  - defines canonical step ordering
  - returns stable outputs (anchors/hashes) for downstream stages
- `audit_workflow.ts`
  - models authorization scope and audit anchoring plans
  - returns stable authorization outputs for downstream checks

Workflows do not execute transactions; they produce deterministic plans consumed by routers/adapters.

If you are new to the repo, start with `workflows/` first, then `router/`, then `adapters/`. That order mirrors how the system is designed to be understood.

---

### `router/`
Declarative routers that map **intent → ordered actions**.

- `layer1_router.ts`  
  Plans interactions with Layer 1 Aleo programs using canonical interfaces.

Routers do not execute transactions — they define *what should happen*.

---

### `payroll/`
Payroll-specific logic and document construction.

Includes:
- receipt normalization
- index lookups
- paystub generation
- summary generation
- payroll NFT mint preparation

This folder is intentionally scoped **only to payroll**.

---

### `commitments/`
Shared cryptographic tooling used across workflows.

Includes:
- canonical encoding
- hashing
- Merkle tree construction
- deterministic token ID derivation

These utilities enforce:
- determinism
- reproducibility
- cross-system verifiability

---

### `config/`
Portal configuration and environment resolution.

Includes:
- network selection
- program identifiers
- environment variables

Execution-specific configuration (CLI, wallets, etc.) is deferred until later phases.

---

## Design Principles

- **Off-chain first**: build and verify privately before anchoring
- **Deterministic**: same inputs always produce the same outputs
- **Composable**: workflows, routers, and adapters are separable
- **Minimal trust**: no hidden state, no implicit side effects

---

## What This Folder Does *Not* Do

- It does not store money
- It does not replace Aleo programs
- It does not enforce business logic independently
- It does not perform governance

Those responsibilities belong on-chain or in separate repositories.

---
