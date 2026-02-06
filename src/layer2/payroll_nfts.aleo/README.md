# payroll_nfts.aleo

**Layer 2 – Payroll NFTs (Commitment-Only Anchors)**

---

## Purpose

`payroll_nfts.aleo` defines the **only Layer 2 NFT program** in PNW MVP v2 responsible for payroll-related NFTs.

These NFTs do **not** represent money, balances, or receipts.  
They are **commitment-only anchors** that publicly prove the existence and integrity of payroll summaries generated off-chain.

Minting is **optional** and user-controlled.

---

## What This Program Does

- Mints **payroll NFTs** that commit to:
  - paystub documents
  - quarterly summaries
  - year-to-date summaries
  - end-of-year summaries
- Verifies all NFTs are backed by:
  - an **ACTIVE Layer 1 employer agreement**
  - an existing **Layer 1 audit anchor**
- Stores **no raw payroll data**
- Provides:
  - existence proofs
  - status tracking (active / revoked / superseded)
  - anchor height utilities for verification

---

## What This Program Never Does

- ❌ Move USDCx  
- ❌ Issue payroll receipts  
- ❌ Store wages, hours, deductions, or identities  
- ❌ Perform aggregation or calculations  
- ❌ Generate documents  

All computation and rendering happens **off-chain in the portal**.

---

## NFT Types Supported

Workers or employers may mint any of the following:

- **Per-payroll-cycle NFT**
- **Quarterly NFT (Q1–Q4)**
- **Year-to-Date (YTD) NFT**
- **End-of-Year (EOY) NFT**

Each NFT is owned by the minting party and may be revoked or superseded.

---

## Privacy Model

All NFT records store only **cryptographic commitments**, including:

- `doc_hash` – commitment to the full document
- `root` – Merkle root for selective disclosure
- `inputs_hash` – commitment to the underlying Layer 1 receipts
- version metadata (schema, calculation, policy)

Public state is limited to:
- existence
- status
- anchor height

No payroll or identity data is ever exposed on-chain.

---

## Relationship to Layer 1

Layer 1 is canonical.

This program:
- **depends on** Layer 1 receipts and audit anchors
- **cannot mint** unless Layer 1 conditions are satisfied
- **adds no new truth**, only public verifiability

---

## Typical Flow

1. Payroll executes in Layer 1  
2. Portal builds a deterministic payroll document off-chain  
3. Portal computes commitments  
4. User optionally mints a payroll NFT  
5. NFT acts as a public, privacy-preserving proof of validity  

---

## License

This program is **PROPRIETARY**.

No rights are granted for reuse, redistribution, or deployment without explicit authorization.
