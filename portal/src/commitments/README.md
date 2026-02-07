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

## Commitment & Anchoring Diagrams

### End-to-End Commitment Flow  
**Layer 1 → Portal → Commitments Toolkit → Layer 2**

```mermaid
sequenceDiagram
  autonumber
  participant L1 as Layer 1 (Aleo Programs)
  participant P as Portal (Off-chain)
  participant C as Commitments Toolkit<br/>(canonical_encoder / hash / merkle / token_id)
  participant L2 as Layer 2 (payroll_nfts.aleo)

  Note over L1: Payroll executes on-chain using USDCx records
  L1-->>P: Private paystub receipt record(s)<br/>+ public anchors (receipt_anchor, heights)
  P->>P: Decrypt + normalize receipts (authorized)
  P->>C: Build canonical PaystubDocument / SummaryDocument
  C->>C: Encode deterministically (TLV + fixed order)
  C->>C: Compute inputs_hash (sorted inputs set)
  C->>C: Compute doc_hash (canonical bytes)
  C->>C: Build Merkle leaves + root
  C->>C: Derive deterministic token_id
  P-->>L2: Optional mint request<br/>(token_id, doc_hash, inputs_hash, root, scope, versions)
  L2-->>P: Mint success + on-chain NFT commitment exists
  Note over P,L2: Reports can be generated without minting; minting is optional anchoring.

flowchart TB
  subgraph L1[Layer 1: Canonical On-Chain]
    R[Private Receipt Records<br/>paystub_receipts.aleo]
    A[Public Anchors<br/>receipt_anchor + height<br/>audit anchors monthly]
  end

  subgraph P[Portal: Off-Chain]
    D[Decrypt + Normalize<br/>authorized only]
    DOC[Deterministic Documents<br/>Paystub / Quarterly / YTD / EOY]
  end

  subgraph T[Commitments Toolkit]
    E[canonical_encoder.ts<br/>TLV + fixed order]
    H[hash.ts<br/>BLAKE3-256 + domain separation]
    M[merkle.ts<br/>leaf hashes + root]
    ID[token_id.ts<br/>deterministic token IDs]
  end

  subgraph L2[Layer 2: On-Chain Commitments]
    NFT[payroll_nfts.aleo<br/>Stores commitments only]
  end

  R --> D
  A --> D
  D --> DOC

  DOC --> E
  E --> H
  H --> M
  H --> ID

  H -->|doc_hash + inputs_hash| NFT
  M -->|root| NFT
  ID -->|token_id| NFT

  DOC -.->|never on-chain| NFT
  D -.->|never on-chain| NFT
