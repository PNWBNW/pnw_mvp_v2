# paystub_receipts.aleo

**Layer:** 1 (Canonical)  
**Purpose:** Private payroll receipt issuance for workers and employers

---

## Overview

`paystub_receipts.aleo` is the canonical Layer 1 program responsible for issuing **private payroll receipt records** for both workers and employers after payroll execution.

This program does **not** move funds, calculate payroll, or manage agreements.  
It strictly handles **receipt materialization and anchoring**.

Each payroll event results in:
- one **WorkerPaystubReceipt** (owned by the worker)
- one **EmployerPaystubReceipt** (owned by the employer)

Both receipts are cryptographically linked and anchored immutably on-chain.

---

## Design Goals

- **Privacy-first:**  
  All payroll details remain private inside records.
- **Append-only:**  
  Receipts are never mutated or deleted.
- **Audit-friendly:**  
  Each receipt emits a public hash anchor for later verification.
- **Composable:**  
  Layer 2 can safely aggregate receipts into NFTs, reports, and disclosures.

---

## What This Program Does

### ✅ Issues private payroll receipts
- Worker copy
- Employer copy

### ✅ Anchors receipt existence
- Stores `receipt_anchor -> first_seen_block_height`
- Hash-only, no identifying data

### ✅ Supports corrections
- Reversals and adjustments are issued as **new receipts**
- Original receipts remain immutable

---

## What This Program Does NOT Do

- ❌ Does not transfer USDCx
- ❌ Does not calculate wages or taxes
- ❌ Does not expose payroll amounts publicly
- ❌ Does not create NFTs
- ❌ Does not aggregate reports

Those responsibilities belong to:
- `payroll_core.aleo` (execution)
- Layer 2 programs (`payroll_nfts.aleo`, audit tooling, portal)

---

## Receipt Types

### WorkerPaystubReceipt (private record)
Owned by the worker wallet.

Contains:
- receipt_anchor
- pairing hash
- agreement + epoch
- gross / net / tax / fees
- payroll input hash
- issuance height

### EmployerPaystubReceipt (private record)
Owned by the employer wallet.

Contains the same payload as the worker receipt, enabling:
- independent record ownership
- symmetric verification
- selective disclosure

---

## Anchoring Model

A **public, minimal anchor index** is maintained:
Properties:
- Write-once
- Non-identifying
- Enables:
  - proof of existence
  - timestamp verification
  - audit correlation

---

## Transitions

### `mint_paystub_receipts(...)`
Mints a matched worker + employer receipt pair.

Requirements:
- unique receipt anchor
- valid epoch
- basic amount consistency

Returns:
- `(WorkerPaystubReceipt, EmployerPaystubReceipt)`

---

### `mint_reversal_receipts(...)`
Issues corrective receipts.

Use cases:
- payroll corrections
- voids
- retroactive adjustments

Original receipts are never altered.

---

### `assert_receipt_anchored(anchor)`
Public assertion utility to verify existence.

---

### `get_anchor_height(anchor) -> u32`
Public read utility to fetch first-seen block height.

---

## Portal Responsibilities

The portal must:
- compute deterministic receipt anchors
- compute pairing hashes
- compute payroll_inputs_hash
- compute UTC time hash
- decide whether and when to mint Layer 2 NFTs

---

## Security Model

- All sensitive payroll data remains private
- Public state is hash-only
- Receipts are immutable
- Corrections are append-only
- Anchors enable auditability without disclosure

---

## License

**PROPRIETARY**

This program and all related logic are proprietary to the PNW ecosystem.  
No rights are granted for reuse, redistribution, or deployment without explicit authorization.
