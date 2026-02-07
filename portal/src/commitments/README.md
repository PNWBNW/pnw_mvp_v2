# Portal Commitments Toolkit

**PNW MVP v2 – Deterministic Encoding, Hashing, and Merkle Construction**

This directory contains the **canonical, off-chain commitment tooling** used by the PNW portal to prepare data for Layer 2 on-chain anchoring.

Nothing in this directory moves funds or mutates on-chain state.  
Its sole responsibility is to produce **deterministic, verifiable commitments** that Layer 2 programs can anchor without ambiguity.

---

## Purpose

The commitments toolkit guarantees that:

> The same Layer 1 receipts and inputs always produce  
> the same bytes → the same hashes → the same Merkle roots.

This determinism underpins:
- payroll NFT minting
- audit NFTs
- selective disclosure
- dispute resolution
- reproducible compliance proofs

---

## Files Overview

### 1. `canonical_encoder.ts`

**Authoritative encoding specification and implementation.**

Responsibilities:
- Deterministic TLV encoding
- Canonical field ordering
- Object framing (schema + version)
- Construction of:
  - `doc_hash`
  - `inputs_hash`
  - Merkle leaf payloads

Key properties:
- No floats
- No implicit conversions
- All monetary values encoded as **ledger_units**
- Rejects malformed or non-canonical inputs

This file is the **single source of truth** for how documents become bytes.

---

### 2. `hash.ts`

**Domain-separated hashing utilities.**

Responsibilities:
- Centralizes BLAKE3-256 usage
- Enforces domain separation (e.g. `PNW::DOC`, `PNW::INPUTS`, `PNW::MERKLE`)
- Prevents cross-context hash reuse

All hashes used for:
- documents
- inputs
- Merkle leaves
- Merkle parents

must flow through this module.

---

### 3. `merkle.ts`

**Deterministic Merkle tree construction.**

Responsibilities:
- Builds Merkle trees from canonical leaf hashes
- Enforces:
  - left/right ordering
  - duplicate-last-node rule for odd layers
- Produces:
  - Merkle root
  - inclusion proofs (for selective disclosure)

Merkle trees here are intentionally:
- shallow
- fixed-shape
- auditable

This avoids complex or opaque proof systems.

---

### 4. `token_id.ts`

**Deterministic token identifier derivation.**

Responsibilities:
- Generates stable token IDs for Layer 2 NFTs
- Domain-separated by:
  - agreement_id
  - epoch or period
  - scope (cycle / quarterly / YTD / EOY)
- Ensures:
  - no collisions
  - no dependence on mint order
  - reproducibility across environments

Token IDs are derived, never guessed.

---

## Design Principles

- **Off-chain first**  
  All heavy logic lives here, not on-chain.

- **Deterministic by construction**  
  No randomness, no timestamps, no environment dependence.

- **Minimal on-chain surface**  
  Layer 2 programs only receive finalized commitments.

- **Auditor-friendly**  
  Every step is inspectable, reproducible, and explainable.

---

## Relationship to Layer 2

Layer 2 programs (e.g. `payroll_nfts.aleo`) **do not rebuild documents**.

They only accept:
- `doc_hash`
- `inputs_hash`
- `root`
- version metadata
- scope / period identifiers

This separation ensures:
- privacy
- low fees
- upgrade flexibility
- reduced attack surface

---

## Versioning

This toolkit implements **Commitment Spec v1**.

Breaking changes require:
- a new encoder version
- explicit version fields in commitments
- parallel support where necessary

Silent changes are not permitted.

---

## License

This repository and all contained tooling is **PROPRIETARY**.

No rights are granted for reuse, redistribution, or deployment  
without explicit authorization.
