# pnw_name_registry.aleo

**Layer:** 1 (Canonical)  
**Purpose:** Soulbound `.pnw` identity registry with DAO-routed economics

---

## Overview

`pnw_name_registry.aleo` is the canonical on-chain registry for PNW identities.
All names are stored exclusively as **hashed identifiers** (`field`), never as plaintext.

This contract enforces:
- non-transferable ownership
- deterministic pricing
- local DAO revenue routing
- minimal on-chain state

It is a foundational dependency for:
- worker profiles
- employer profiles
- employment agreements
- payroll and audit workflows

---

## Naming Economics

All naming **prices and fees** are **application-level USDCx transfers**.

They are **not** network fees.

### Payment Components

When registering a name, the consumer pays:

1. **Base price** (USDCx)
2. **Naming fee** (`fee_amount`, USDCx)
3. **Aleo network execution fees** (paid separately)

### Revenue Routing

- **Base price + naming fee**  
  → routed to the **locally presiding DAO treasury**

- **Network fees**  
  → paid to the Aleo network (out of scope)

This avoids centralized treasuries and funds local governance, compliance, and oversight.

---

## Worker Names

- Maximum: **1 active name per wallet**
- Price: **1 USDCx + naming fee**
- Non-transferable
- May be released back to the pool (no refund)

---

## Employer Names

- Requires verified business license (`employer_license_registry.aleo`)
- Maximum: **3 names per wallet**
- Tiered pricing:
  - 1st: 10 USDCx + fee
  - 2nd: 100 USDCx + fee
  - 3rd: 300 USDCx + fee
- Names may be sold **only back to the presiding DAO**
  - Refund = **75% of base price**
  - Fees are never refunded

---

## Privacy & Design Notes

- No plaintext names on-chain
- No balances stored
- No P2P name trading
- All identity logic is hash-based
- Jurisdiction-specific governance is supported without embedding DAO logic

---

## Dependencies

- `test_usdcx_stablecoin.aleo`
- `employer_license_registry.aleo`

---

## License

**PROPRIETARY**  
No rights are granted for reuse, redistribution, or deployment without explicit authorization.
