# src/layer1/

Layer 1 contains the **canonical on-chain programs** for PNW MVP v2. These programs define the authoritative rules for identity ownership, profiles, agreements, payroll settlement (USDCx), receipt issuance, and audit anchoring. Layer 1 is intentionally minimal: it avoids public disclosure of identities, wages, terms, or aggregates, and relies on private records plus commitment anchors.

## What’s in this folder

- **`pnw_name_registry.aleo`** — `.pnw` name registration and ownership rules (worker names + employer names with suffix taxonomy and fee logic).
- **`employer_license_registry.aleo`** — employer eligibility gating (e.g., license verification) used as a prerequisite for employer name registration.
- **`worker_profiles.aleo`** — private worker profile records + anchor utilities (existence/height).
- **`employer_profiles.aleo`** — private employer profile records + anchor utilities (existence/height).
- **`employer_agreement.aleo`** — employment agreement lifecycle (offer → acceptance → active/pause/terminate/resume) with anchored agreement IDs.
- **`payroll_core.aleo`** — payroll settlement using **USDCx records**; consumes employer USDCx and outputs worker USDCx; issues paystub receipts; anchors audit events.
- **`paystub_receipts.aleo`** — private paystub receipt minting (worker + employer receipts) and reversal/correction receipts; anchor utilities.
- **`payroll_audit_log.aleo`** — minimal hash-only audit anchoring and height lookup for payroll events.
- **`pnw_router.aleo`** — Layer 1 orchestration surface for the Portal (routes common workflows across Layer 1 programs).
- **`LAYER1_INTERFACE.md`** — the canonical “callable surface” reference (transitions/records/functions) used by the Portal router and adapters.

## Notes
- Layer 1 programs are the **source of truth** for settlement and eligibility.
- Aggregation, reporting, and NFT minting are handled outside Layer 1 (Portal + Layer 2), using deterministic encodings and commitment anchors.
```
