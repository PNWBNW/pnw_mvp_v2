# PNW MVP v2  
**Proven National Workers – Aleo-Native Payroll, Receipts, and Audit Framework**

---

## Overview

`pnw_mvp_v2` is an Aleo-native payroll and compliance framework designed for **private, stable-value settlement using USDCx**, with built-in support for receipts, credentials, and permissible auditability.

The system coordinates payroll execution, reporting, and compliance without exposing worker, employer, or customer data on-chain.

All value movement, authorization, and audit anchoring occur on Aleo.  
All aggregation, reporting, and presentation occur privately off-chain.

---

## Core Design Principles

### 1. Aleo-Native Settlement (USDCx)
- Payroll is settled exclusively using **USDCx on Aleo**
- Employers and workers interact using standard Aleo wallets
- No external chains, bridges, or remittance adapters are required
- The protocol does not custody funds or maintain balances

> **Note:**  
> The canonical USDCx token identifier / program reference is treated as a configurable placeholder until officially published by Aleo and Circle.

---

### 2. Privacy by Default
- No plaintext identities on-chain
- No public wages, hours, invoices, or balances
- Public state contains **hashes and commitments only**
- Financial and identity data exists only in **private records** or off-chain summaries

---

### 3. Dual-Layer Routing Architecture

The system is organized around two distinct layers:

#### Layer 1 – On-Chain Canonical Logic
Layer 1 programs:
- Validate agreements and eligibility
- Execute payroll using USDCx records
- Mint **private receipt records**
- Write **public hash anchors** for auditability

Layer 1 programs do **not**:
- Perform aggregation or analytics
- Store balances or plaintext identities
- Generate reports or summaries

#### Layer 2 – Aggregation, Reporting, and Commitments
Layer 2 tooling:
- Combines private Layer 1 receipts off-chain
- Builds paystubs, invoices, and periodic reports
- Optionally mints **commitment-based NFTs** on-chain
- Enables selective disclosure and audit workflows

---

## Directory Structure

```text
pnw_mvp_v2/
├─ README.md
├─ ARCHITECTURE.md
├─ .env.example
│
├─ src/
│  ├─ layer1/                # Canonical on-chain programs (Leo)
│  │  ├─ pnw_router.aleo
│  │  ├─ pnw_name_registry.aleo
│  │  ├─ worker_profiles.aleo
│  │  ├─ employer_profiles.aleo
│  │  ├─ employer_agreement.aleo
│  │  ├─ payroll_core.aleo
│  │  ├─ paystub_receipts.aleo
│  │  └─ payroll_audit_log.aleo
│  │
│  └─ layer2/                # Commitment & permission NFTs (Leo)
│     ├─ receipt_nft.aleo
│     ├─ credential_nft.aleo
│     └─ audit_nft.aleo
│
├─ portal/                   # Off-chain router, aggregation, reporting
│  ├─ router/
│  │  ├─ layer1_router.ts
│  │  └─ layer2_router.ts
│  ├─ receipts/
│  ├─ reports/
│  └─ commitments/
│
└─ scripts/



Layer 1 Programs (Canonical)

Layer 1 programs define authoritative system behavior.

They are responsible for:

-Identity and role commitments

-Employer–worker agreements

-USDCx payroll execution

-Private receipt issuance

-Hash-only audit anchors


Layer 1 programs never expose:

-Identities

-Amounts

-Employment details

-Aggregated statistics




Layer 2 NFTs (Minimal Taxonomy)

Layer 2 includes three NFT categories, all commitment-based:

1. Receipt NFTs

-  Paystub receipts

-  Payroll cycle receipts

-  Invoice receipts

-  Used for presentation and selective disclosure.



2. Credential NFTs

-  Employer verification credentials

-  Employment relationship credentials

-  Auditor / tax agent credentials

-  Used as capability and authorization tokens.



3. Audit NFTs

-  Audit authorization tokens

-  Audit report anchors

-  Audit result attestations

-  Used to enable audits without revealing underlying data.



All NFTs store:

-  Commitment hashes

-  Merkle roots

-  Epochs and versions

-  Never raw payroll or identity data.



USDCx Integration Model

-  USDCx is treated as a native Aleo stable asset

-  Employers fund payroll using USDCx records

-  Payroll execution consumes employer records and produces worker records

-  The protocol does not mirror balances or wrap tokens

USDCx integration is intentionally minimal and composable.



Intended Use Cases

-  Private payroll execution

-  Worker-controlled paystub disclosure

-  Employer compliance reporting

-  SubDAO or organizational oversight

-  Selective audit workflows



Status

This repository defines the forward-looking MVP architecture and is under active development.

The focus is on:

-  Correctness

-  Privacy

-  Minimal on-chain surface area

-  Long-term extensibility

License

To be defined prior to deployment.
