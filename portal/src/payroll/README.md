# Portal Payroll Aggregation (Layer 2 – Off-Chain)

This folder contains the off-chain payroll aggregation, normalization, and NFT mint-preparation logic for PNW MVP v2.

It is responsible for transforming authorized Layer 1 payroll receipts into:
- deterministic paystubs
- deterministic payroll summaries
- commitment artifacts suitable for minting payroll NFTs on Layer 2

No funds move here.  
No private data is published here.  
This layer is purely computational and preparatory.

---

## Design Principles

- Deterministic: same inputs produce the same outputs and hashes
- Non-custodial: never holds funds or private keys
- Privacy-preserving: operates only on authorized, decrypted receipts
- Composable: bridges Layer 1 receipts and Layer 2 NFTs
- Minimal surface area: no analytics, dashboards, or business logic creep

---

## Folder Structure

    portal/src/payroll/
    ├─ types.ts
    ├─ normalize.ts
    ├─ indexer.ts
    ├─ paystub_builder.ts
    ├─ summary_builder.ts
    └─ mint_payroll_nft.ts

---

## File Responsibilities

### types.ts — Canonical Vocabulary

Defines the shared type system for all payroll portal logic.

Key concepts:
- LedgerUnits — integer base units for all money (no floats)
- DecryptedPaystubReceipt — authorized Layer 1 receipt view
- NormalizedPayrollEvent — canonical internal event format
- IndexedAgreementEpoch — grouped payroll data
- PayrollScope — cycle, quarterly, YTD, EOY NFT scopes

This file is the contract between:
- Layer 1 receipts
- portal aggregation
- Layer 2 NFT minting

---

### normalize.ts — Receipt Normalization

Pure, deterministic transformation from Layer 1 receipt to NormalizedPayrollEvent.

Responsibilities:
- validate structure and bounds (u32, bytes32, bigint)
- enforce currency consistency (USDCx)
- strip ambiguity and optionality
- standardize flags such as voids and revisions

This is the first inspection step after receipt decryption.

No I/O  
No sorting  
No aggregation

---

### indexer.ts — Deterministic Grouping

Indexes normalized events into stable, ordered buckets.

Primary grouping:
- agreement_id
- epoch_id

Responsibilities:
- stable sorting (agreement → epoch → anchor height)
- grouping events into epochs
- computing deterministic aggregates:
  - gross totals
  - net totals
  - tax totals
  - fee totals
- tracking anchor height windows

This powers summaries, audits, and selective disclosure proofs.

---

### paystub_builder.ts — Individual Paystub Documents

Builds canonical paystub documents for a single payroll event.

Each paystub:
- corresponds to one payroll execution
- binds directly to one Layer 1 receipt anchor
- can be used for worker disclosure, employer records, or NFT minting

Outputs a CanonicalDoc for the commitments layer.

Scope: Payroll cycle

---

### summary_builder.ts — Aggregate Payroll Documents

Builds aggregate payroll summaries across multiple events.

Supported scopes:
- Quarterly
- Year-to-Date (YTD)
- End-of-Year (EOY)

Responsibilities:
- deterministic aggregation across events
- stable input anchor sets
- provenance window (min and max anchor height)
- event counts including voids and revisions

These summaries support compliance and audits without exposing individual payroll data publicly.

---

### mint_payroll_nft.ts — NFT Mint Preparation

Creates deterministic mint request payloads for Layer 2 payroll NFTs.

Responsibilities:
- consume a CanonicalDoc
- compute:
  - doc_hash
  - inputs_hash
  - merkle root
  - token_id
- package metadata required by payroll_nfts.aleo

Important constraints:
- no network calls
- no wallet logic
- no broadcasting

This file prepares data only. Execution occurs elsewhere.

---

## End-to-End Flow

    Layer 1 (Aleo)
      └─ Private paystub receipt record
            ↓ authorized access
    normalize.ts
            ↓
    indexer.ts
            ↓
    paystub_builder.ts or summary_builder.ts
            ↓
    commitments canonical encoder
            ↓
    mint_payroll_nft.ts
            ↓
    Layer 2 payroll_nfts.aleo (optional mint)

---

## What This Layer Does NOT Do

- Does not move funds
- Does not perform payroll calculations
- Does not store identities
- Does not publish private data
- Does not perform audits
- Does not act as a ledger

It prepares proofs, not decisions.

---

## Relationship to Other Layers

Layer 1:
- Executes payroll
- Issues private receipts
- Anchors audit hashes

Portal (this folder):
- Aggregates and normalizes authorized data
- Builds deterministic documents
- Computes commitments

Layer 2:
- Mints commitment-only payroll NFTs
- Enables selective, permissioned disclosure (employee/employer controlled: share only selected fields/proofs)
