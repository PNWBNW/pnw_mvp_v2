# PNW MVP v2  
**Proven National Workers — Aleo-Native Payroll, Receipts, and Audit Framework**

---

## Overview

**PNW MVP v2** is a privacy-first payroll and compliance framework built natively on **Aleo**, using **USDCx** for stable-value settlement.

The system enables employers, workers, and oversight entities to:
- execute payroll privately,
- issue verifiable paystub receipts,
- generate compliant reports,
- and support permissible audits,

**without exposing identities, wages, or business data on-chain**.

All authoritative state changes occur on Aleo.  
All aggregation, reporting, and presentation occur privately off-chain.

---

## Core Principles

### 1. Aleo-Native Settlement (USDCx)
- Payroll is settled using **USDCx on Aleo**
- Employers and workers use standard Aleo wallets
- No bridges, custodial pools, or external remittance rails
- The protocol does **not** track balances or custody funds

> **Note**  
> USDCx is treated as a standalone Aleo program (`test_usdcx_stablecoin.aleo` on testnet).  
> Token references are configurable and resolved at deploy time.

---

### 2. Privacy by Default
- No plaintext identities on-chain
- No public wages, hours, invoices, or balances
- Public state contains **hashes and commitments only**
- Financial and identity data exist only in:
  - private Aleo records, or
  - encrypted off-chain summaries

---

### 3. Append-Only, Verifiable History
- All payroll and compliance events are:
  - append-only
  - immutable once anchored
- Corrections and reversals are represented as **new artifacts**, not mutations
- On-chain data provides **existence and ordering proofs**, not content disclosure

---

## Dual-Layer Architecture

### Layer 1 — Canonical On-Chain Logic (Leo / Aleo)

Layer 1 programs are the **source of truth**.

They are responsible for:
- identity and role commitments
- employer–worker agreements
- USDCx payroll execution
- minting **private receipt records**
- anchoring **hash-only audit events**

Layer 1 programs explicitly do **not**:
- compute reports or analytics
- store balances or aggregates
- expose identities or wages
- generate presentation artifacts

  ## Layer 1 Programs (Canonical)

Layer 1 defines authoritative behavior.

They handle:
- identity commitments
- agreements and eligibility
- payroll settlement
- receipt issuance
- audit anchoring

They never expose:
- identities
- wages or deductions
- employment terms
- aggregated statistics

---

### Layer 2 — Aggregation, Reporting, and Commitments (Portal + NFTs)

Layer 2 tooling operates off-chain and optionally anchors results on-chain.

Responsibilities:
- decrypt authorized Layer 1 receipts
- normalize receipts into deterministic base events
- build paystubs, invoices, and periodic reports
- compute Merkle roots and document commitments
- optionally mint **commitment-based NFTs** for disclosure or audit

Layer 2 never:
- moves funds
- alters Layer 1 state
- bypasses Layer 1 validation rules

--

## Layer 2 NFTs — Minimal Taxonomy

Layer 2 includes commitment-only NFTs used for disclosure and audit.

### 1. Receipt NFTs
- Paystub receipts
- Payroll cycle summaries
- Invoice receipts

Used for:
- presentation
- selective disclosure
- worker-controlled sharing


### 2. Credential NFTs
- Employer verification credentials
- Employment relationship credentials
- Auditor / tax agent credentials

Used as:
- capability tokens
- authorization proofs
- revocable permissions


### 3. Audit NFTs
- Audit authorization tokens
- Audit report anchors
- Audit result attestations

Used to:
- enable audits without exposing raw data
- prove compliance against on-chain anchors

All NFTs store:
- commitment hashes
- Merkle roots
- epoch and version metadata
- **never raw payroll or identity data**

## USDCx Integration Model

- USDCx is treated as a native Aleo asset
- Employers fund payroll via USDCx records
- Payroll consumes employer records and outputs worker records
- No wrapping, mirroring, or balance accounting

The design is intentionally minimal and composable.

## Layered Compliance Model

PNW MVP v2 is designed to **complement**, not replace, the compliance guarantees provided by USDCx.

- **USDCx compliance** ensures the *money* is lawful  
  (AML, sanctions screening, monetary controls)
- **PNW compliance** ensures the *relationship* is lawful  
  (employment legitimacy, wage correctness, consented auditability)

These layers operate independently but reinforce each other:

> USDCx proves the funds are clean.  
> PNW proves the payroll relationship is legitimate.

PNW never bypasses or obscures issuer-level compliance. Instead, it adds a privacy-preserving employment and audit framework **on top of** compliant stablecoin settlement.

For a detailed technical explanation, see:  
📄 **[ARCHITECTURE.md — Layered Compliance & Auditability](./ARCHITECTURE.md)**

## Intended Use Cases

- Private payroll execution
- Worker-controlled paystub disclosure
- Employer compliance reporting
- SubDAO or organizational oversight
- Selective, permissioned audits


## Status

This repository defines the forward-looking MVP architecture and is under active development.

Current priorities:
- correctness
- privacy
- minimal on-chain surface area
- long-term extensibility


## License

This repository and all contained programs are **PROPRIETARY**.  
No rights are granted for reuse, redistribution, or deployment without explicit authorization.

