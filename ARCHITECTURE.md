# ARCHITECTURE.md  
**PNW MVP v2 – Aleo-Native Payroll, Receipts, and Audit Framework**

---

## 1. Purpose

PNW MVP v2 is a privacy-first payroll and compliance framework built on Aleo. It executes payroll using **USDCx**, issues private receipts, and enables permissible auditability through commitment-based NFTs and selective disclosure.

The architecture is intentionally split into:
- **Layer 1 (On-chain canonical logic):** settlement, receipts, anchors, minimal guards
- **Layer 2 (Off-chain aggregation + optional on-chain commitments):** reporting, summaries, and audit artifacts

---

## 2. Threat Model & Privacy Goals

### 2.1 Privacy Goals
The system is designed so that the following are **not publicly observable** on-chain:
- Worker identity (e.g., `.pnw` name)
- Employer identity (e.g., `.pnw` name)
- Customer identity
- Wage amounts, hours, invoices, deductions
- Employment terms / scope-of-work text
- Aggregated payroll totals or reports

### 2.2 Publicly Observable (Allowed)
The system allows only **non-sensitive public state**, typically:
- Commitments (hashes) to events and documents
- Existence flags (e.g., “this receipt exists”)
- Minimal metadata such as epoch IDs and versions (where non-linkable)

### 2.3 Linkability Minimization
All identifiers stored publicly are:
- hashed (Poseidon2/BHP256, domain-separated)
- optionally salted (per-namespace salts) to reduce cross-context linkability

### 2.4 Authorized Disclosure
Selective disclosure is supported via:
- Private receipt records (decryptable by authorized parties)
- Merkle proofs over report sections/line-items (against on-chain roots)
- Optional ZK proofs for higher-order statements (future extension)

---

## 3. System Layers

## 3.1 Layer 1 – On-Chain Canonical Logic (Leo / Aleo)
Layer 1 programs are the sole source of truth for payroll execution and state transitions.

Layer 1 responsibilities:
- Validate identity ownership (name registry)
- Validate worker/employer profile existence (anchored state)
- Validate employer–worker agreements (status, terms anchors)
- Execute payroll settlement using USDCx
- Issue private receipts (records)
- Emit public hash anchors for auditability
- Maintain minimal immutable audit logs (hash-only)
- Maintain minimal guards (e.g., prevent double pay per epoch)

Layer 1 explicitly does **not**:
- compute reports or analytics
- store plaintext identities
- store balances in mappings
- publish payroll amounts publicly
- custody pooled payroll funds

## 3.2 Layer 2 – Off-Chain Router & Reporting (Portal)
Layer 2 runs in the employer portal and performs private aggregation and reporting.

Layer 2 responsibilities:
- Fetch and decrypt Layer 1 receipts (authorized only)
- Normalize receipts into deterministic “base events”
- Build paystubs and reports off-chain
- Create commitment artifacts:
  - `doc_hash`
  - `root` (Merkle root)
  - `inputs_hash` (hash of included receipt anchors)
- Optionally mint on-chain commitment NFTs (Layer 2 on-chain contracts)

Layer 2 explicitly does **not**:
- define protocol rules
- replace Layer 1 validation
- publish raw payroll or identity data on-chain

---

## 4. Money Flow Model (No Pools)

PNW MVP v2 intentionally avoids centralized or pooled payroll funds.

- Payroll is **employer-funded** using USDCx records.
- The protocol **does not** mirror balances or maintain ledgers in mappings.
- The protocol **does not** custody pooled funds on behalf of multiple employers or workers.

This reduces:
- custodial / pooled fund risk (large attack surface “honeypots”)
- systemic blast radius
- regulatory complexity
- governance coupling to treasury mechanics

Future “employer-controlled pools” (for employer transparency or budgeting views) are treated as an **optional extension**, not a requirement of MVP v2.

---

## 5. Routing Model (On-Chain vs Off-Chain)

The system contains **two distinct routing mechanisms**, each operating in a different environment and solving a different problem.

### 5.1 On-Chain Protocol Router (`pnw_router.aleo`)
The on-chain router is a **protocol-level control plane**.

It exists to:
- Orchestrate multi-step on-chain workflows
- Enforce prerequisite checks consistently
- Provide a single canonical entrypoint for critical transitions

The on-chain router:
- runs entirely inside Aleo
- does not perform aggregation or reporting
- does not compute Layer 2 artifacts
- exists to reduce duplicated client logic and prevent inconsistent behavior across portals

### 5.2 Off-Chain Portal Routers (Workflow Routers)
The portal contains routing logic implemented off-chain (e.g., TypeScript). These routers:
- decide *which* on-chain transitions to call and *when*
- fetch and decrypt private receipts
- assemble deterministic report artifacts
- decide whether to mint Layer 2 commitment NFTs

Typical responsibilities:
- **protocol_router:** orchestrates calls into Layer 1 programs
- **report_router:** builds reports/paystubs and optionally anchors them on-chain

These routers:
- do not define protocol rules
- do not replace on-chain validation
- exist to coordinate user workflows and private computation

### 5.3 Why There Is No Layer 2 On-Chain Router
Layer 2 on-chain programs (`receipt_nft.aleo`, `credential_nft.aleo`, `audit_nft.aleo`) are intentionally:
- small
- single-purpose
- commitment- and permission-focused

They do not require an on-chain router because:
- they do not orchestrate complex state transitions
- they do not perform computation or aggregation
- they are invoked only after off-chain Layer 2 logic produces deterministic artifacts

---

## 6. Canonical Data Objects

### 6.1 Identity Hashes
All identities are represented as hashed identifiers:
- `worker_id: field`
- `employer_id: field`
- `customer_id: field` (optional)
- `agent_id: field` (auditor/tax agent, optional)

Domain separation example:
- `H("pnw:v2:worker_id" || <name-encoding> || salt)`
- `H("pnw:v2:employer_id" || <name-encoding> || salt)`

### 6.2 Epoch IDs
Payroll periods are referenced via:
- `epoch_id: u32`

Layer 2 defines epoch encoding rules (weekly, biweekly, monthly, quarterly).  
Layer 1 enforces only minimal constraints (e.g., epoch uniqueness per agreement).

### 6.3 Commitments
Standard commitments used across Layer 2 NFTs:
- `doc_hash: [u8; 32]` – commitment to full document representation
- `root: [u8; 32]` – Merkle root for selective disclosure
- `inputs_hash: [u8; 32]` – commitment to the set of underlying receipts/events

### 6.4 Versioning
All commitment artifacts include:
- `schema_v: u16` – document schema version
- `calc_v: u16` – calculation recipe version
- `policy_v: u16` – policy/compliance ruleset version (when applicable)

---

## 7. Layer 1 Programs (Responsibilities)

### 7.1 `pnw_name_registry.aleo`
- Registers `.pnw` identities as non-transferable ownership
- Enforces naming rules and suffix taxonomy constraints
- Provides ownership assertions for protocol guards

### 7.2 `worker_profiles.aleo`
- Stores worker profile anchors (hash-only commitments)
- Provides existence and anchored-state assertions

### 7.3 `employer_profiles.aleo`
- Stores employer profile anchors (hash-only commitments)
- Provides existence and anchored-state assertions

### 7.4 `employer_agreement.aleo`
- Defines agreement lifecycle (offer → active → pause/terminate → resume)
- Anchors agreement terms (doc commitments)
- Provides `ACTIVE` status checks for payroll gating

### 7.5 `payroll_core.aleo`
- Executes payroll settlement via **USDCx records**
- Validates:
  - worker profile exists
  - employer profile exists
  - agreement exists and status == `ACTIVE`
- Prevents double-pay per `(agreement_id, epoch_id)`
- Mints private paystub receipts (worker + employer)
- Anchors immutable payroll audit events

### 7.6 `paystub_receipts.aleo`
- Defines private receipt record formats used by Layer 2 reporting
- Stores minimal public receipt anchors and anchor heights (for ordering and existence proofs)

### 7.7 `payroll_audit_log.aleo`
- Hash-only audit anchors
- Minimal mapping:
  - `event_hash -> u32` (first-seen block height)
- No identity or amount storage

### 7.8 `pnw_router.aleo`
- Provides a stable on-chain entry surface for orchestrated flows
- Minimizes duplicated client behavior across portals
- Performs prerequisite assertions and routes to:
  - agreement transitions
  - profile/name assertions
  - payroll execution (when invoked by portal workflows)

---

## 8. Layer 2 NFTs (On-Chain Anchors & Permissions)

Layer 2 contracts store **commitments and permission primitives**, not raw payroll data.

### 8.1 Receipt NFTs (`receipt_nft.aleo`)
Used for anchoring:
- paystub commitments
- payroll cycle summaries
- invoice receipts (optional)

Stores:
- identity hashes
- epoch
- `doc_hash`, `root`, `inputs_hash`
- versions and block height
- revocation status

### 8.2 Credential NFTs (`credential_nft.aleo`)
Used for:
- employer verification credential (future governance repo)
- employment relationship credential (optional)
- auditor/tax agent credentials (optional)

Stores:
- identity hashes
- scope or agreement commitments
- issuer commitments
- revocation fields

### 8.3 Audit NFTs (`audit_nft.aleo`)
Used for:
- audit authorization tokens (scope + expiration)
- audit report anchors (commitment to report)
- audit result attestations (auditor statement commitment)

Stores:
- subject identifiers and scope
- commitment hashes/roots
- optional expirations and revocation

---

## 9. Canonical Workflows

## 9.1 Onboarding Workflow (Employer & Worker)
1. Register `.pnw` identity (name registry)
2. Create worker profile / employer profile anchors
3. Create an employment job offer and finalize agreement (agreement program)

MVP v2 intentionally treats “issuer / governance credentials” as **external** (extension point).

## 9.2 Payroll Execution Workflow
1. Employer funds wallet with USDCx records
2. Portal calls Layer 1 router / payroll core
3. Payroll core validates:
   - worker and employer profiles exist
   - agreement status == `ACTIVE`
   - `(agreement_id, epoch_id)` not previously paid
4. Payroll core consumes employer USDCx and outputs worker USDCx
5. Payroll core mints private paystub receipts (worker + employer)
6. Payroll core anchors payroll audit event hash

## 9.3 Paystub & Reporting Workflow (Layer 2)
1. Portal fetches Layer 1 receipts and anchors
2. Portal decrypts authorized receipts
3. Portal builds paystub/report documents deterministically
4. Portal computes `doc_hash`, `root`, `inputs_hash`
5. Portal optionally mints receipt/audit NFTs on-chain

## 9.4 Audit Workflow (Permissible Auditability)

This system supports audits without exposing raw payroll or identity data on-chain.

### 9.4.1 On-Chain Request + Authorization (Official)
1. **Auditor creates an official audit request on-chain**:
   - Includes `request_id`, `scope_hash`, `subject_binding_hash`, and `expiry_height`.
2. Required approvals are recorded on-chain:
   - Employer approval
   - Worker approval
   - Presiding SubDAO approval (vote-gated; the vote mechanics live outside MVP v2, but the approval is committed on-chain)
3. After approvals, an **Audit Authorization NFT** is minted on-chain:
   - Stores only commitment metadata (e.g., `request_id`, `scope_hash`, `issuer_set_hash`, `expiry_height`)
   - Does **not** contain private payroll data and does **not** decrypt receipts

### 9.4.2 Time-of-Access Release (Off-Chain, Scoped)
Even after an Audit Authorization NFT exists, **actual disclosure requires fresh “release” confirmation** from both parties at time-of-access:

1. When the auditor attempts to access information, the tooling/portal generates a `release_hash` bound to:
   - `request_id`
   - `scope_hash`
   - auditor identity (hash/address)
   - a session identifier / nonce
   - a short-lived session expiry (e.g., 12 hours)
2. The **worker** and **employer** each sign the `release_hash` (off-chain).
3. Only after both signatures are received does the tooling produce a disclosure bundle:
   - strictly limited to the approved scope (`scope_hash`)
   - redacted and/or proven via Merkle membership proofs against document roots
   - optionally encrypted to an auditor session key to prevent replay/leakage beyond the approved session

This ensures:
- authorization ≠ disclosure
- disclosure is scoped, explicit, and time-limited
- compromised auditor credentials alone are insufficient to extract data

### 9.4.3 Confidential Activity Logging (Off-Chain)
Each scoped disclosure action produces an **Access Event** recorded off-chain in an append-only log.

An Access Event commits to (non-exhaustive):
- `request_id`
- `scope_hash`
- authorization reference (commitment to the Audit Authorization NFT)
- auditor identity hash
- session identifier
- `bundle_hash` (hash of the disclosed bundle)
- hashes of worker/employer release signatures
- auditor receipt/acknowledgement signature hash

The log is treated as confidential operational security data and is not published in real time.

### 9.4.4 Monthly Delayed Batched Anchoring (On-Chain, Non-Real-Time)
To provide immutable accountability **without revealing real-time audit activity**, access events are anchored on-chain in **monthly batches**:

1. At the end of each month, the tooling:
   - computes `access_event_hash` for each off-chain access event
   - sorts deterministically
   - builds a Merkle tree over all `access_event_hash` values for that month
2. The tooling publishes **one on-chain anchor** for the month:
   - `period_id` (month identifier)
   - `root` (Merkle root of access events)
   - `count` (number of access events committed)
   - `schema_v` (event schema version)
3. The on-chain anchor is published with a **delayed posting window** (not immediate at the moment of access), reducing timing correlation risk.

### 9.4.5 Proving an Access Event (When Needed)
If a dispute or compliance review requires proof that an access occurred:

1. The disclosing party reveals the specific `access_event_hash` (and optionally its underlying signed components).
2. They provide a Merkle membership proof that the event is included in the on-chain monthly `root(period_id)`.
3. Verifiers confirm inclusion against the on-chain root, without requiring public disclosure of payroll contents.

This provides:
- immutable accountability when required
- minimal on-chain signal leakage
- strong privacy preservation by default

### 9.4.6 Disclosure Release Session Model (Off-Chain Gate)

The protocol intentionally separates **authorization** from **disclosure**.

- **Authorization (on-chain)** establishes that disclosure *may* occur (Audit Request + approvals + Audit Authorization NFT).
- **Disclosure (off-chain)** is the act of actually releasing private information, and must be explicitly re-confirmed at time-of-access.

#### A) Release sessions are required for any disclosure

Even if an Audit Authorization NFT exists and is valid, the tooling must require a **Release Session** before producing any disclosure bundle.

A Release Session is an off-chain, time-limited permission envelope that proves:
- the request is being exercised by the authorized auditor
- the worker and employer explicitly approved the release **at time of access**
- the release is strictly bounded to the approved scope

Release Sessions enforce:
- auditor identity verification (wallet signature challenge)
- fresh worker and employer signatures over a `release_hash`
- strict scope binding (`scope_hash`)
- a short-lived session TTL (e.g., 12 hours)

Release Sessions are not recorded on-chain in real time and do not emit public signals.
They exist solely to gate access to private information.

#### B) Security properties

The Release Session model ensures:
- possession of public NFT metadata alone is insufficient to obtain data
- compromised auditor credentials cannot bypass worker/employer consent
- access is revocable by simply refusing to sign a new release
- expired or revoked authorizations cannot be exercised

#### C) Optional accountability anchoring

While individual Release Sessions remain private, disclosure activity may later be committed on-chain via **delayed, batched anchoring** (see Section 9.4.4).

This provides non-repudiation and accountability without exposing real-time audit behavior or access patterns.
---

## 10. USDCx Integration Notes

- USDCx is treated as a native Aleo stable asset settled via records.
- The protocol does not mirror balances or manage ledgers.
- Network references:
  - **Testnet:** `test_usdcx_stablecoin.aleo`
  - **Mainnet:** `usdcx_stablecoin.aleo`

---

## 11. Non-Goals (MVP)

The MVP intentionally excludes:
- On-chain analytics and aggregation
- Public financial reporting
- Cross-chain payout adapters
- Centralized or pooled payroll treasuries
- Full governance systems (DAOs, voting, dispute courts, treasury policy)

Governance is planned as a **separate interoperable repository** that issues credentials and authority proofs consumed by MVP v2.

---

## 12. Extension Points

Future enhancements can add:
- Governance repo interoperability (issuer credentials, revocation, disputes)
- Employer-controlled pools (budget views / earmarked funds) without protocol custody
- ZK proofs for compliance claims (wage floor, tax reserve ratios, etc.)
- Worker-controlled selective disclosure primitives
- Advanced invoice/billing workflows
- Token registry resolution and formal USDCx metadata bindings
