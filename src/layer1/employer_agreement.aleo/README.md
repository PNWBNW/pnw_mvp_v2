# employer_agreement.aleo — README

**Layer:** 1 (Canonical)  
**Language:** Leo v3.4.0 semantics  
**Role:** Private employer↔worker agreement lifecycle + minimal public status anchoring

---

## 1) What this program does

`employer_agreement.aleo` is the **canonical agreement contract** that binds an employer and worker to a specific job relationship without exposing identities or terms on-chain.

It supports a two-step flow:

1. **Employer creates a job offer** → mints a **private `PendingAgreement` record** (owned by the employer).
2. **Worker accepts the offer** → consumes the `PendingAgreement` and mints a **private `FinalAgreement` record** (custodied by a DAO address).

On-chain, the program stores **only minimal public state**:
- agreement existence + first-seen `block.height`
- agreement status enum
- a parties-commitment key (non-revealing)
- 3-of-3 “resume approvals” bitmask (Employer + Worker + DAO)

This matches the model documented in the program header comments.

---

## 2) Privacy properties (core design goal)

This program **does not** publish:
- employer identity or worker identity (only name hashes exist privately)
- agreement terms (only `terms_doc_hash` + `terms_root` exist privately)
- wages, hours, scope-of-work text, invoices, etc.

This program **does** publish (allowed):
- existence/status flags and block heights
- non-revealing commitment keys used for authorization gating

---

## 3) Key records

### 3.1 `PendingAgreement` (private job offer)
- Created by employer in a single step.
- Owned by employer until accepted.
- Intended to be **consumed** upon acceptance.

### 3.2 `FinalAgreement` (private finalized contract anchor)
- Minted only after worker acceptance.
- Custodied by the DAO controller address (DAO owns the record).
- Treated as an immutable private anchor of the finalized agreement.

> Important: “minting” here means **minting private records**, not NFTs.

---

## 4) Public mappings (minimal state)

This program maintains public mappings for:
- `agreement_anchor_height` → `[u8;32] => u32`  
  First-seen anchor height for `agreement_id`.
- `agreement_parties_key` → `[u8;32] => [u8;32]`  
  Commitment key used to authorize later agreement actions.
- `agreement_status` → `[u8;32] => u8`  
  Status enum: PENDING / ACTIVE / PAUSED / TERMINATED / SUPERSEDED.
- `resume_approvals` → `[u8;32] => u8`  
  Bitmask approvals used to require 3-of-3 resume.

---

## 5) Agreement lifecycle (high-level)

### 5.1 Create job offer (Employer)
- Preconditions:
  - employer must own the employer name hash
  - employer must be verified via employer license registry
  - offer is created for a worker name hash that already exists (worker must have an account/name)

- Effects:
  - anchors agreement once
  - stores public minimal state
  - returns `PendingAgreement` record

### 5.2 Accept job offer (Worker)
- Preconditions:
  - agreement exists and status == PENDING
  - parties_key matches stored value
  - worker must own worker name hash at acceptance time
  - employer name must still exist

- Effects:
  - consumes `PendingAgreement`
  - mints DAO-custodied `FinalAgreement`
  - updates agreement status → ACTIVE

### 5.3 Pause / terminate (Employer, Worker, DAO)
- Any of the 3 parties can pause or terminate independently.
- DAO controls are represented as `caller == DAO_ADDRESS` for now (placeholder for later governance integration).

### 5.4 Resume (3-of-3)
- Resume requires **three approvals**:
  - employer approval bit
  - worker approval bit
  - DAO approval bit
- Only once all bits are set can `resume_agreement` transition restore ACTIVE.

### 5.5 Revision / supersede model
When renegotiation, annual review, or a material update is needed:
- A **new agreement** is created and finalized
- The old agreement is not destroyed (not “deleted”), but can be marked SUPERSEDED
- This provides clean tenure/version tracking without rewriting history

---

## 6) Time model

Aleo does not provide real-world timestamps on-chain. This program uses:
- `block.height` on-chain for deterministic anchoring
- a **portal-supplied UTC Zulu timestamp hash commitment** (e.g., `offer_time_hash`, `accept_time_hash`)
  - proves timing off-chain later without revealing timestamps publicly

---

## 7) Dependencies

This program depends on:
- `pnw_name_registry.aleo`
  - for ownership and existence checks of hashed `.pnw` identities
- `employer_license_registry.aleo`
  - for verifying employers before allowing offer creation

(See this folder’s `program.json` for the dependency wiring.)

---

## 8) Portal usage (recommended)

The portal should treat this program as:
- **the only source of truth** for “does an agreement exist and what is its status?”
- a producer of **private agreement records** used in later payroll flows

The portal should:
- generate and persist `agreement_id` deterministically (stable anchor)
- generate `parties_key` deterministically (commitment to employer/worker pair)
- generate `terms_doc_hash` + `terms_root` from the agreement document

---

## 9) License

**PROPRIETARY** — no rights are granted for reuse, redistribution, or deployment without explicit authorization.
