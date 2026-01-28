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
├─ .gitignore
├─ .env.example
│
├─ src/
│  ├─ layer1/                            # Canonical on-chain business logic (private receipts + public anchors)
│  │  ├─ pnw_router.aleo/                # Orchestrates layer1 workflows (no analytics)
│  │  │  ├─ main.leo
│  │  │  └─ program.json
│  │  │
│  │  ├─ pnw_name_registry.aleo/         # .pnw naming registry (hashed identifiers only)
│  │  │  ├─ main.leo
│  │  │  └─ program.json
│  │  │
│  │  ├─ worker_profiles.aleo/           # Worker profile commitments + eligibility anchors
│  │  │  ├─ main.leo
│  │  │  └─ program.json
│  │  │
│  │  ├─ employer_profiles.aleo/         # Employer profile commitments + role anchors
│  │  │  ├─ main.leo
│  │  │  └─ program.json
│  │  │
│  │  ├─ employer_agreement.aleo/        # Relationship / scope commitments (hashed)
│  │  │  ├─ main.leo
│  │  │  └─ program.json
│  │  │
│  │  ├─ payroll_core.aleo/              # Executes payroll + mints private receipts (USDCx-native transfers)
│  │  │  ├─ main.leo
│  │  │  └─ program.json
│  │  │
│  │  ├─ paystub_receipts.aleo/          # Private receipts (records) + minimal public anchors (hash index)
│  │  │  ├─ main.leo
│  │  │  └─ program.json
│  │  │
│  │  └─ payroll_audit_log.aleo/         # Hash-only log (event_hash -> bool/u32), immutable anchors
│  │     ├─ main.leo
│  │     └─ program.json
│  │
│  └─ layer2/                            # On-chain NFTs/records: commitments + permissions only (no payroll math)
│     ├─ receipt_nft.aleo/               # Paystub/PayrollCycle/Invoice receipt NFTs (commitment objects)
│     │  ├─ main.leo
│     │  └─ program.json
│     │
│     ├─ credential_nft.aleo/            # Employer/Employment/Auditor credentials (capabilities + revocation)
│     │  ├─ main.leo
│     │  └─ program.json
│     │
│     └─ audit_nft.aleo/                 # Audit authorization, audit report anchor, audit result attestation
│        ├─ main.leo
│        └─ program.json
│
├─ portal/                               # Off-chain Layer 2 router + report builder (private aggregation)
│  ├─ README.md
│  ├─ package.json
│  ├─ tsconfig.json
│  ├─ src/
│  │  ├─ config/
│  │  │  ├─ env.ts                       # reads .env, network selection, program IDs
│  │  │  └─ programs.ts                  # layer1 + layer2 program addresses/ids
│  │  │
│  │  ├─ router/
│  │  │  ├─ layer1_router.ts             # orchestrates on-chain actions (register, agreement, payroll)
│  │  │  └─ layer2_router.ts             # builds summaries + mints NFTs (receipt/credential/audit)
│  │  │
│  │  ├─ receipts/
│  │  │  ├─ decrypt.ts                   # decrypts private receipt records (employer/worker views)
│  │  │  ├─ normalize.ts                 # canonical “base events” format
│  │  │  └─ indexer.ts                   # pulls anchors + receipts from chain
│  │  │
│  │  ├─ reports/
│  │  │  ├─ paystub_builder.ts           # builds paystub doc + root + doc_hash + inputs_hash
│  │  │  ├─ employer_quarterly.ts        # quarterly report builder
│  │  │  └─ subdao_quarterly.ts          # subDAO report builder
│  │  │
│  │  ├─ commitments/
│  │  │  ├─ merkle.ts                    # Merkle tree builder (deterministic)
│  │  │  ├─ hash.ts                      # domain-separated hashing helpers
│  │  │  └─ token_id.ts                  # deterministic token_id builder
│  │  │
│  │  └─ cli/
│  │     ├─ run_payroll.ts               # example workflow runner (dev)
│  │     ├─ mint_paystub_nft.ts          # calls receipt_nft.aleo
│  │     └─ mint_audit_report.ts         # calls audit_nft.aleo
│  │
│  └─ testdata/
│     └─ fixtures/                       # non-sensitive fixtures (no raw identities)
│
└─ scripts/
   ├─ init_repo.sh                       # scaffolding helper
   ├─ build_all.sh                       # build layer1 + layer2 programs
   └─ deploy_order.md                    # deterministic deploy order notes



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
