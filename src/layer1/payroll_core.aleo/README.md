# payroll_core.aleo

## Purpose

`payroll_core.aleo` is the **canonical Layer 1 payroll execution engine** for PNW MVP v2.

It is responsible for:
- settling payroll using private USDCx records
- enforcing agreement and eligibility constraints
- issuing private paystub receipts
- anchoring audit events on-chain

This program is the **only place** where payroll funds move on-chain.

---

## Design Principles

### 1. Canonical Settlement
All payroll execution must pass through this program.  
There are no alternative settlement paths.

### 2. Minimal On-Chain Surface
The program:
- does **not** store balances
- does **not** track histories in mappings
- does **not** expose wages, identities, or terms publicly

It consumes private records and produces private records only.

### 3. Privacy by Construction
All sensitive data:
- identities
- wage amounts
- deductions
- fees
- timestamps

are either:
- private record fields, or
- represented as hashes/anchors

No plaintext payroll data is publicly observable.

---

## Inputs

The primary transition consumes:
- an **employer-owned USDCx record**
- agreement and identity commitments
- epoch identifiers
- payroll amounts (gross, net, tax, fees)
- precomputed hash anchors supplied by the portal

All hashes are computed **off-chain** by the portal using canonical encoding.

---

## Outputs

On successful execution, the program produces:

1. **Worker USDCx Record**
   - containing the net pay amount via `transfer_private`
   - owned by the worker

2. **Worker Paystub Receipt (private record)**
   - decryptable by the worker
   - used for off-chain reporting and optional NFT minting

3. **Employer Paystub Receipt (private record)**
   - decryptable by the employer
   - mirrors the worker receipt for accounting symmetry

No public payroll data is emitted.

---

## Audit Anchoring

Each payroll execution includes an `audit_event_hash` which is:
- deterministically derived off-chain
- anchored via `payroll_audit_log.aleo`

This provides:
- immutable proof that a payroll event occurred
- block-height timestamping
- zero disclosure of payroll contents

---

## Relationship to Other Programs

- **Depends on**
  - `employer_agreement.aleo` (agreement validity)
  - `paystub_receipts.aleo` (receipt record types)
  - `payroll_audit_log.aleo` (audit anchoring)
  - `test_usdcx_stablecoin.aleo` (USDCx records)

- **Does NOT**
  - mint NFTs
  - aggregate reports
  - manage identities or profiles
  - perform governance logic

---

## Portal Interaction

The portal:
- prepares all hashes and canonical encodings
- selects input USDCx records
- calls this program via an adapter
- receives the resulting records

The portal may later:
- aggregate receipts off-chain
- mint Layer 2 payroll NFTs
- produce reports for workers, employers, or auditors

---

## Non-Goals

This program intentionally does **not**:
- support invoicing or billing
- perform tax remittance
- enforce jurisdiction-specific labor law
- store historical payroll data
- support
