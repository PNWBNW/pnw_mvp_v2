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

---

## Repository Structure

```text
pnw_mvp_v2/
├─ README.md
├─ ARCHITECTURE.md
├─ .env.example
│
├─ src/
│  ├─ layer1/                          # Canonical on-chain logic
│  │  ├─ pnw_router.aleo/              # Orchestration (no analytics)
│  │  ├─ pnw_name_registry.aleo/       # .pnw identity registry (hashed)
│  │  ├─ worker_profiles.aleo/         # Worker profile commitments
│  │  ├─ employer_profiles.aleo/       # Employer profile commitments
│  │  ├─ employer_agreement.aleo/      # Employment agreements
│  │  ├─ payroll_core.aleo/            # USDCx payroll execution
│  │  ├─ paystub_receipts.aleo/        # Private paystub receipts + anchors
│  │  └─ payroll_audit_log.aleo/       # Immutable audit anchors
│  │
│  └─ layer2/                          # Commitment-only NFTs
│     ├─ receipt_nft.aleo              # Paystub / report receipt NFTs
│     ├─ credential_nft.aleo           # Employer / employment credentials
│     └─ audit_nft.aleo                # Audit authorization + attestations
│
├─ portal/                             # Off-chain aggregation + UX
│  ├─ src/
│  │  ├─ config/                       # Network + program IDs
│  │  ├─ router/                       # Layer1 / Layer2 orchestration
│  │  ├─ receipts/                     # Receipt decryption + indexing
│  │  ├─ reports/                      # Paystub / quarterly builders
│  │  ├─ commitments/                  # Hashing + Merkle utilities
│  │  └─ cli/                          # Dev workflows
│
└─ scripts/                            # Build / deploy helpers│  │  │
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

---

## Repository Structure

```text
pnw_mvp_v2/
├─ README.md
├─ ARCHITECTURE.md
├─ .env.example
│
├─ src/
│  ├─ layer1/                          # Canonical on-chain logic
│  │  ├─ pnw_router.aleo/              # Orchestration (no analytics)
│  │  ├─ pnw_name_registry.aleo/       # .pnw identity registry (hashed)
│  │  ├─ worker_profiles.aleo/         # Worker profile commitments
│  │  ├─ employer_profiles.aleo/       # Employer profile commitments
│  │  ├─ employer_agreement.aleo/      # Employment agreements
│  │  ├─ payroll_core.aleo/            # USDCx payroll execution
│  │  ├─ paystub_receipts.aleo/        # Private paystub receipts + anchors
│  │  └─ payroll_audit_log.aleo/       # Immutable audit anchors
│  │
│  └─ layer2/                          # Commitment-only NFTs
│     ├─ receipt_nft.aleo              # Paystub / report receipt NFTs
│     ├─ credential_nft.aleo           # Employer / employment credentials
│     └─ audit_nft.aleo                # Audit authorization + attestations
│
├─ portal/                             # Off-chain aggregation + UX
│  ├─ src/
│  │  ├─ config/                       # Network + program IDs
│  │  ├─ router/                       # Layer1 / Layer2 orchestration
│  │  ├─ receipts/                     # Receipt decryption + indexing
│  │  ├─ reports/                      # Paystub / quarterly builders
│  │  ├─ commitments/                  # Hashing + Merkle utilities
│  │  └─ cli/                          # Dev workflows
│
└─ scripts/                            # Build / deploy helpersto deployment.


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
