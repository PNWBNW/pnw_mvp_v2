````markdown
# ARCHITECTURE.md  
**PNW MVP v2 – Aleo-Native Payroll, Receipts, and Audit Framework**

---

## 1. Purpose

PNW MVP v2 is a privacy-first payroll and compliance framework built on Aleo. It executes payroll using USDCx, issues private receipts, and enables permissible auditability through commitment-based NFTs and selective disclosure.

The architecture is intentionally split into:
- **Layer 1 (On-chain canonical logic):** state transitions, settlement, receipts, anchors
- **Layer 2 (Off-chain aggregation + optional on-chain commitments):** reporting, summaries, and audit artifacts

---

## 2. Threat Model & Privacy Goals

### 2.1 Privacy Goals
The system is designed so that the following are **not publicly observable** on-chain:
- Worker identity (e.g., `.pnw` name)
- Employer identity (e.g., `.pnw` name)
- Customer identity
- Wage amounts, hours, invoices, deductions
- Employment terms, scope-of-work text
- Aggregated payroll totals or reports

### 2.2 Publicly Observable (Allowed)
The system allows only **non-sensitive public state**, typically:
- Commitments (hashes) to events and documents
- Existence flags (e.g., “this receipt token exists”)
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
Layer 1 programs are the sole source of truth for payroll and authorization.

Layer 1 responsibilities:
- Validate identity commitments and role gating
- Validate employer–worker agreements
- Execute payroll settlement using USDCx
- Issue private receipts (records)
- Emit public hash anchors for auditability
- Maintain minimal immutable audit logs (hash-only)

Layer 1 explicitly does **not**:
- compute reports or analytics
- store plaintext identities
- store balances in mappings
- publish payroll amounts publicly

## 3.2 Layer 2 – Off-Chain Router & Reporting (Portal)
Layer 2 runs in the employer/subDAO portal and performs private aggregation.

Layer 2 responsibilities:
- Fetch and decrypt Layer 1 receipts (authorized only)
- Normalize receipt data into deterministic “base events”
- Build paystubs, invoices, and reports off-chain
- Create commitment artifacts:
  - `doc_hash`
  - `root` (Merkle root)
  - `inputs_hash` (hash of included receipt anchors)
- Optionally mint on-chain NFT anchors (Layer 2 on-chain contracts)

Layer 2 explicitly does **not**:
- move funds (except calling Layer 1 payroll transitions)
- publish raw payroll or identity data on-chain

---

## 4. Routing Model (On-Chain vs Off-Chain)

The system intentionally contains **two distinct routing mechanisms**, each operating in a different execution environment and solving a different problem.

### 4.1 On-Chain Protocol Router (`pnw_router.aleo`)

The on-chain router is a **protocol-level control plane**.

It exists to:
- Orchestrate multi-step on-chain workflows
- Enforce prerequisite checks consistently
- Provide a single canonical entrypoint for critical state transitions

Responsibilities include:
- Routing payroll execution calls
- Routing agreement creation and validation
- Coordinating receipt issuance and audit anchor writes
- Ensuring required credentials and agreements exist before execution

The on-chain router:
- Runs entirely inside Aleo
- Does not perform aggregation or reporting
- Does not inspect or compute Layer 2 artifacts
- Exists to reduce duplicated logic and prevent inconsistent client behavior

### 4.2 Off-Chain Portal Routers (Workflow Routers)

The portal contains routing logic implemented off-chain (e.g., TypeScript), sometimes referred to as “routers” but serving a **different purpose**.

These routers:
- Decide *which* on-chain transitions to call and *when*
- Fetch and decrypt private receipts
- Assemble deterministic report artifacts
- Decide whether to mint Layer 2 commitment NFTs

Typical responsibilities:
- `protocol_router` (formerly `layer1_router`):  
  Orchestrates calls into Layer 1 on-chain programs.
- `report_router` (formerly `layer2_router`):  
  Builds reports, paystubs, and audit artifacts and optionally anchors them on-chain.

These routers:
- Do not define protocol rules
- Do not replace on-chain validation
- Exist to coordinate user workflows and private computation

### 4.3 Why There Is No Layer 2 On-Chain Router

Layer 2 on-chain programs (`receipt_nft.aleo`, `credential_nft.aleo`, `audit_nft.aleo`) are intentionally:
- Small
- Single-purpose
- Commitment- and permission-focused

They do not require an on-chain router because:
- They do not orchestrate complex state transitions
- They do not perform computation or aggregation
- They are invoked only after off-chain Layer 2 logic has already produced deterministic artifacts

Introducing an on-chain Layer 2 router would:
- Increase surface area and complexity
- Provide no additional privacy guarantees
- Duplicate logic better handled off-chain

For these reasons, **Layer 2 routing exists exclusively in the portal**, not in Leo.


## 5. Canonical Data Objects

### 5.1 Identity Hashes

All identities are represented as hashed identifiers:

* `worker_id: field`
* `employer_id: field`
* `customer_id: field` (optional)
* `agent_id: field` (auditor/tax agent)

These should be domain-separated, e.g.:

* `H("pnw:v2:worker_id" || <name-encoding> || salt)`
* `H("pnw:v2:employer_id" || <name-encoding> || salt)`

### 5.2 Epoch IDs

Payroll periods are referenced via `epoch_id`:

* `epoch_id: u32` (recommended)
* Layer 2 defines epoch encoding rules (weekly, biweekly, monthly, quarterly)
* Layer 1 enforces only consistency and ordering constraints where required

### 5.3 Commitments

Standard commitments used across Layer 2 NFTs:

* `doc_hash: [u8; 32]` – commitment to full document representation
* `root: [u8; 32]` – Merkle root for selective disclosure
* `inputs_hash: [u8; 32]` – commitment to the set of underlying receipts/events

### 5.4 Versioning

All commitment artifacts include:

* `schema_v: u16` – document schema version
* `calc_v: u16` – calculation recipe version
* `policy_v: u16` – policy/compliance ruleset version (when applicable)

---

## 6. Layer 1 Programs (Responsibilities)

### 6.1 `pnw_router.aleo`

* Routes top-level workflows (create agreement, run payroll, mint receipts, write anchors)
* Ensures required prerequisites exist (credential, agreement state)
* Minimizes repeated logic across modules

### 6.2 `payroll_core.aleo`

* Executes payroll settlement via USDCx records
* Validates agreement and eligibility conditions
* Produces worker USDCx output records
* Emits private receipt records (directly or via `paystub_receipts.aleo`)
* Writes audit anchors to `payroll_audit_log.aleo`

### 6.3 `paystub_receipts.aleo`

* Defines private receipt record formats used by Layer 2 reporting
* Optionally maintains minimal public indexes of receipt existence via hash keys

### 6.4 `payroll_audit_log.aleo`

* Hash-only audit anchors
* Minimal mapping such as:

  * `event_hash -> bool` or `event_hash -> u32` (block height)
* No identity or amount storage

---

## 7. Layer 2 NFTs (On-Chain Anchors & Permissions)

Layer 2 contracts store **commitments and permission primitives**, not raw payroll data.

### 7.1 Receipt NFTs (`receipt_nft.aleo`)

* Paystub receipt NFTs
* Payroll cycle receipt NFTs
* Invoice receipt NFTs (optional)

Each stores:

* identity hashes
* epoch
* `doc_hash`, `root`, `inputs_hash`
* versions and block height
* revocation status

### 7.2 Credential NFTs (`credential_nft.aleo`)

* Employer verification credential
* Employment relationship credential
* Auditor/tax agent credentials

Each stores:

* identity hashes
* scope or agreement commitments
* issuer commitments
* revocation fields

### 7.3 Audit NFTs (`audit_nft.aleo`)

* Audit authorization token (permission scope)
* Audit report anchor (commitment to report)
* Audit result attestation (auditor statement commitment)

Each stores:

* subject identifiers and scope
* commitment hashes/roots
* optional expirations and revocation

---

## 8. Canonical Workflows

## 8.1 Onboarding Workflow (Employer & Worker)

1. Register `.pnw` identity (hashed identifier)
2. Create employer profile / worker profile commitments
3. Issue employer verification credential (oversight/subDAO authority)
4. Create employment agreement (worker_id ↔ employer_id)

## 8.2 Payroll Execution Workflow

1. Employer funds wallet with USDCx records
2. Employer triggers payroll via Layer 1 router
3. Payroll program validates:

   * employer credential
   * active agreement
   * payroll period rules
4. Payroll consumes employer USDCx records and outputs worker USDCx records
5. Payroll emits private receipt records
6. Payroll writes hash anchors to audit log

## 8.3 Paystub & Reporting Workflow (Layer 2)

1. Portal fetches Layer 1 receipts and anchors
2. Portal decrypts authorized receipts
3. Portal builds paystub/report documents deterministically
4. Portal computes `doc_hash`, `root`, `inputs_hash`
5. Portal optionally mints receipt/audit NFTs on-chain

## 8.4 Audit Workflow (Permissible Auditability)

1. Issuer mints Audit Authorization NFT (scope + expiration)
2. Auditor requests specific proof scopes
3. Portal provides:

   * Merkle membership proofs for disclosed sections, or
   * optional ZK proofs for high-level claims
4. Auditor verifies against on-chain commitments
5. Auditor optionally mints Audit Result NFT (attestation)

---

## 9. USDCx Integration Notes

* USDCx is treated as a native Aleo stable asset settled via records.
* The protocol does not mirror balances or manage ledgers.
* USDCx identifier/program reference is configured as a placeholder until the canonical reference is officially published.

---

## 10. Non-Goals (MVP)

The MVP intentionally excludes:

* On-chain analytics and aggregation
* Public financial reporting
* Cross-chain payout adapters
* Heavy ZK proofs for complex statements (reserved for later extensions)
* Full governance systems (subDAO governance beyond credential issuance is out of scope)

---

## 11. Extension Points

Future enhancements can add:

* ZK proofs for compliance claims (wage floor, tax reserve ratios, etc.)
* Worker-controlled selective disclosure primitives
* Advanced invoice/billing workflows
* SubDAO reporting and governance-driven credential issuance
* Token registry resolution for USDCx identifier/program reference

---

```
::contentReference[oaicite:0]{index=0}
```
