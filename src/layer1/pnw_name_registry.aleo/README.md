# pnw_name_registry.aleo — README

**Layer:** 1 (Canonical)  
**Language:** Leo v3.4.0 semantics  
**Role:** Soulbound `.pnw` naming registry (hashed identities) + pricing + sellback-to-registrar

---

## 1) What this program does

`pnw_name_registry.aleo` is the canonical on-chain registry for `.pnw` identities, represented only as hashed identifiers (`field`).

It enforces:
- **No plaintext names** on-chain (only hashes).
- **No peer-to-peer transfers or sales** of names.
- Deterministic, minimal state: ownership + type + suffix classification.
- Payment in **USDCx** (testnet program used during development).

This file is the root dependency for Layer 1 onboarding:
- Worker profiles, employer profiles, and agreements all rely on this registry for identity ownership assertions.

(Your current working file shows the intended imports, ownership mappings, and new assertion helpers. 0)

---

## 2) Core concepts

### 2.1 Name hash (identity primitive)
A `.pnw` name is represented as:
- `name_hash: field`

The portal is responsible for:
- normalizing the name string
- encoding (ARC-style or deterministic ASCII → field strategy)
- domain-separating and hashing into `name_hash`

### 2.2 Name kinds
Each registered name is labeled:
- `KIND_WORKER = 1`
- `KIND_EMPLOYER = 2`

### 2.3 Employer suffix taxonomy
Employers register names with a required 5-character suffix *code* (represented on-chain as `suffix_code: u8`).
Example (off-chain string, on-chain code):
- `weberfarms.agric.pnw` → `suffix_code = SUF_AGRIC`

The portal maintains the human-readable taxonomy mapping.

---

## 3) On-chain state (minimal mappings)

This program maintains only the following public mappings:

- `name_owner: field => address`
  - `0address` means unowned / available.

- `name_kind: field => u8`
  - worker vs employer.

- `employer_suffix_code: field => u8`
  - `0` for worker names; non-zero for employer names.

- `worker_primary_name_of: address => field`
  - enforces **1 active worker name per wallet**.

- `employer_name_count: address => u8`
  - enforces **max 3 employer names per wallet**.

- `employer_base_paid: field => u128`
  - the base tier price paid for that employer name (fees excluded).

- `sellback_seller: field => address`
- `sellback_refund_amount: field => u128`
  - tracks registrar-only sellback fulfillment.

---

## 4) Pricing model (USDCx)

All amounts are represented in base units using:
- `USDCX_SCALE = 1_000_000` (USDC-style decimals)

### 4.1 Worker names
- **Price:** `1 USDCx + fee_amount`
- **Fee policy:** fees are **always non-refundable**
- **Constraint:** 1 active name per address
- **Release:** worker may release name back to pool with **no refund**

### 4.2 Employer names
- **Eligibility:** caller must be verified in `employer_license_registry.aleo`
- **Max names:** 3 per address
- **Tiered base price (by count):**
  1. `10 USDCx + fee_amount`
  2. `100 USDCx + fee_amount`
  3. `300 USDCx + fee_amount`
- **Fee policy:** fees are **always non-refundable**
- **Sellback:** employer may sell name back only to registrar at **75% of base price**
  - sellback does not refund fee_amount

---

## 5) Canonical transitions

### 5.1 Worker registration
- `register_worker_name(name_hash, fee_amount)`
  - verifies caller has no active worker name
  - verifies name is unowned
  - transfers `1 USDCx + fee_amount` to registrar treasury
  - sets ownership/kind and assigns `worker_primary_name_of`

- `release_worker_name()`
  - releases back to pool (no refund)
  - clears worker’s primary mapping

### 5.2 Employer registration
- `register_employer_name(name_hash, suffix_code, fee_amount)`
  - asserts employer license verification
  - validates suffix_code
  - enforces 3-name limit
  - transfers tiered base + fee to registrar treasury
  - records base price paid for sellback accounting

### 5.3 Employer sellback (registrar-only resale loop)
- `request_employer_sellback(name_hash)`
  - requires caller owns name and it is employer-kind
  - releases name back to pool immediately
  - decrements employer count
  - records `sellback_seller` + `sellback_refund_amount`

- `fulfill_employer_sellback(name_hash)`
  - **registrar treasury only**
  - transfers refund to recorded seller
  - clears sellback claim state

---

## 6) Assertion helpers (used by other Layer 1 programs)

These utilities allow other programs to enforce onboarding + ownership without duplicating registry logic:

- `assert_name_exists(name_hash)`
- `assert_worker_owner(name_hash, owner)`
- `assert_employer_owner(name_hash, owner, expected_suffix)`
- `assert_is_owner(name_hash, owner)`

These are intentionally “read-only assertions”: no state mutation.

---

## 7) Dependencies

- `test_usdcx_stablecoin.aleo`
  - used for testnet USDCx transfers during development.

- `employer_license_registry.aleo`
  - required for employer name purchase gating.

---

## 8) Portal responsibilities (off-chain)

The portal must provide:
- deterministic name normalization + hashing → `name_hash`
- suffix taxonomy UI and suffix_code mapping
- fee computation (`fee_amount`) passed into register transitions
- user-facing receipt / confirmation UX (off-chain)

---

## 9) License

**PROPRIETARY** — no rights are granted for reuse, redistribution, or deployment without explicit authorization.
```1
