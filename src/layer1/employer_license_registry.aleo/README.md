# employer_license_registry.aleo — README

**Layer:** 1 (Canonical)  
**Language:** Leo v3.4.0 semantics  
**Role:** Employer eligibility gate (business license verification) for employer-name registration

---

## 1) What this program does

`employer_license_registry.aleo` is a minimal on-chain registry that gates **employer name actions** behind a verified business license signal.

It does **not** store plaintext license details. Instead, it stores:
- a boolean verification flag per wallet
- an optional license commitment hash per wallet

This registry exists to support the onboarding rule:
> Employer `.pnw` names can only be purchased/registered by wallets that have been verified.

---

## 2) Threat model & privacy stance

This program is intentionally “thin”:
- No license numbers
- No business names
- No addresses
- No documents on-chain

Only minimal eligibility signals are stored:
- `is_verified(wallet) = true/false`
- `license_hash_of(wallet) = [u8;32]` (commitment to off-chain license evidence)

The license evidence (PDFs, state filings, etc.) remains off-chain and is handled by the portal / issuer process.

---

## 3) Authority model (issuer)

An issuer authority (PNW / presiding SubDAO oversight) controls verification.

- Only the `AUTHORITY` address may set verification state.
- Other programs (e.g., `pnw_name_registry.aleo`) can call an assertion function to enforce gating.

In v2, governance is intentionally out-of-scope for this repo; `AUTHORITY` acts as a placeholder for whatever governance/issuer logic is later deployed in a separate governance repository.

---

## 4) Public mappings

- `is_verified: address => bool`
  - True if the wallet is approved to register employer names.

- `license_hash_of: address => [u8; 32]`
  - Commitment to the license evidence (optional / issuer-defined).

---

## 5) Core transitions

### 5.1 `set_verified(wallet, license_hash, verified)`
Authority-only transition that:
- sets the verification flag for `wallet`
- stores/updates the license commitment hash

### 5.2 `assert_verified(wallet)`
Utility transition that:
- asserts `is_verified(wallet) == true`
- used by gating programs as a hard requirement

(Recommended additions: `get_verified`, `get_license_hash` as read utilities.)

---

## 6) Portal usage

Typical portal flow:
1. Employer submits license evidence off-chain (state business license, filing, etc.)
2. Issuer reviews + generates a commitment hash of the evidence
3. Issuer calls `set_verified(wallet, license_hash, true)`
4. Employer can now register employer `.pnw` names via `pnw_name_registry.aleo`

If the employer loses eligibility:
- issuer calls `set_verified(wallet, ZERO_32, false)` (recommended pattern)

---

## 7) License

**PROPRIETARY** — no rights are granted for reuse, redistribution, or deployment without explicit authorization.
```3
