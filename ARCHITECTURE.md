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
Layer 2 on-chain programs (`payroll_nfts.aleo`, `credential_nft.aleo`, `audit_nft.aleo`) are intentionally:
- small
- single-purpose
- commitment- and permission-focused

They do not require an on-chain router because:
- they do not orchestrate complex state transitions
- they do not perform computation or aggregation
- they are invoked only after off-chain Layer 2 logic produces deterministic artifacts

---

## 6. Execution Boundary & Three-Repo Structure

### 6.1 Adapter Execution Boundary (Core Invariant)

The system enforces a strict architectural separation between **planning** and **execution**. This is one of the most important invariants in the codebase.

**Planning layer (never executes):**
- **Workflows** (`portal/src/workflows/`) define user intent — "run payroll for this agreement and epoch." They produce a typed list of steps but never touch the network, never construct CLI strings, and never hold private keys.
- **Routers** (`portal/src/router/`) translate workflow output into typed call plans. A call plan is an ordered list of `AleoCLIStep` objects, each specifying a program ID, transition name, and typed arguments. Routers resolve which Layer 1 or Layer 2 programs to call and in what order. They still do not execute.
- **Layer-specific adapters** (`layer1_adapter.ts`, `layer2_adapter.ts`) map abstract step kinds (e.g., `"mint_payroll_nft"`) to concrete program/transition pairs (e.g., `payroll_nfts.aleo` / `mint_cycle_paystub_nft`). They are lookup tables, not execution engines.

**Execution layer (the only place that talks to the network):**
- **`aleo_cli_adapter.ts`** is the sole execution boundary. It takes a resolved `AleoCLIStep` and produces a fully formed `snarkos developer execute` command string with correct flag syntax (`--endpoint`, `--broadcast`, `--private-key`), correct argument encoding (array literals like `[ 1u8, 2u8, ... ]`, not hex), and correct program/transition targeting.

**Why this matters:**
- **Security surface is minimal.** Only one module constructs commands that spend funds or modify chain state. Auditing execution behavior means auditing one file.
- **Program IDs are centralized.** If a program is redeployed with a new ID, the change propagates from the manifest through the adapter — workflows and routers don't need to change.
- **Testability is high.** Adapter codec tests (`portal/tests/phase4_adapter.test.ts`) verify command shape, argument encoding, and step kind dispatch without touching the network.
- **CLI evolution is isolated.** If `snarkos` changes flag names or syntax, only the adapter changes. The entire planning layer remains stable.
- **Portal UIs never construct CLI commands.** They call workflow functions, receive call plans, and pass them to the adapter. This prevents scattered, inconsistent command construction across the codebase.

### 6.2 CI Gate Architecture

CI is split into two independent gates with a hard security boundary between them:

**Plan Gate (`deploy.yml`):**
- Triggers on every PR and push to `main`
- Requires zero secrets — safe to run on any contributor's PR
- Runs: TypeScript typecheck (Phase 3 + Phase 4 tsconfigs), adapter codec tests, testnet manifest schema validation, Layer 1 public-state leakage guards (ensures no plaintext wages/addresses in public mappings), scenario/file mismatch negative-path guards
- Failure blocks merge — this is the quality gate for all code changes

**Execute Gate (`execute_testnet.yml`):**
- Triggers only on manual `workflow_dispatch` or push to the protected `work` branch
- Requires secrets: `ALEO_PRIVATE_KEY`, `ALEO_VIEW_KEY`, `ALEO_ADDRESS`, `WORKER_ADDRESS`, `ENDPOINT`, `USDCX_PROGRAM_ID`, broadcast command payloads
- Runs: full testnet scenario execution with real broadcast, receipt verification against the Aleo REST API, evidence bundle generation with SHA integrity checks
- Protected by GitHub environment (`testnet-staging`) with concurrency controls — only one execute run at a time per ref

**Why the split exists:**
- Plan-gate runs must never risk spending testnet funds, leaking credentials, or creating on-chain state as a side effect of a PR review
- Execute-gate runs are expensive (real transactions, real fees) and must be intentionally triggered
- The two gates validate different things: plan-gate validates code correctness, execute-gate validates on-chain behavior

### 6.3 Three-Repo Structure

The project is built across three independent repositories, each with a distinct audience and responsibility boundary:

| Repo | Purpose | Audience |
|------|---------|----------|
| `pnw_mvp_v2` | Foundation: Leo programs, TypeScript adapters, CI/CD, manifests, commitment utilities | Developers, operators |
| `pnw_employment_portal_v1` | Two-sided employer + worker portal UI: payroll runs, paystubs, credentials, QR onboarding, PDF generation, audit consent | Employers, workers |
| `pnw_auditing_portal_v1` | Auditor portal UI: view authorization NFTs, receive disclosure keys, decode scoped records, generate audit reports | Auditors, regulators |

**Interoperability contracts between repos:**

1. **Manifest as single source of truth.** `config/testnet.manifest.json` in `pnw_mvp_v2` is the canonical registry of deployed program IDs. Both portal repos consume this file — they never hardcode program IDs. On program redeployment, the manifest is updated here first, then both portals update their pinned reference in the same release window.

2. **Shared adapter interface types.** Both portals call the Aleo network through the same adapter interface defined in `pnw_mvp_v2`. For MVP, portals maintain a local copy of the adapter types with a version comment tracking which `pnw_mvp_v2` commit it came from. Post-MVP, this becomes a published npm package (`@pnw/adapter-types`).

3. **Audit disclosure handoff (the key interop surface).** The `AuditAuthorizationNFT` on Aleo proves an auditor is authorized to view specific payroll epochs for a specific employment relationship. But the NFT authorizes access — it does not deliver data. Actual data delivery is off-chain:
   - MVP: employer generates a scoped view key and shares it with the auditor manually. The NFT transaction ID is the handshake token both sides reference.
   - Phase 6: encrypted delivery — portal encrypts the scoped view key to the auditor's Aleo public key, eliminating manual copy.

4. **Shared privacy rules.** All three repos enforce the same privacy invariants: no private keys/view keys/wages/names stored in any database (session memory only), no real addresses committed to git, no plaintext identity or salary on public chain state, no cumulative spend counters, PDFs generated client-side only, audit disclosure scoped and time-limited.

See `docs/MULTI_REPO_PLAN.md` for the full interoperability plan including build order, versioning coordination, and open questions.

---

## 7. Canonical Data Objects

### 7.1 Identity Hashes
All identities are represented as hashed identifiers:
- `worker_id: field`
- `employer_id: field`
- `customer_id: field` (optional)
- `agent_id: field` (auditor/tax agent, optional)

Domain separation example:
- `H("pnw:v2:worker_id" || <name-encoding> || salt)`
- `H("pnw:v2:employer_id" || <name-encoding> || salt)`

### 7.2 Epoch IDs
Payroll periods are referenced via:
- `epoch_id: u32`

Layer 2 defines epoch encoding rules (weekly, biweekly, monthly, quarterly).  
Layer 1 enforces only minimal constraints (e.g., epoch uniqueness per agreement).

### 7.3 Commitments
Standard commitments used across Layer 2 NFTs:
- `doc_hash: [u8; 32]` – commitment to full document representation
- `root: [u8; 32]` – Merkle root for selective disclosure
- `inputs_hash: [u8; 32]` – commitment to the set of underlying receipts/events

### 7.4 Versioning
All commitment artifacts include:
- `schema_v: u16` – document schema version
- `calc_v: u16` – calculation recipe version
- `policy_v: u16` – policy/compliance ruleset version (when applicable)

---

## 8. Layer 1 Programs (Responsibilities)

### 8.1 `pnw_name_registry.aleo`
- Registers `.pnw` identities as non-transferable ownership
- Enforces naming rules and suffix taxonomy constraints
- Provides ownership assertions for protocol guards

### 8.2 `employer_license_registry.aleo`
- Validates employer license eligibility before payroll or agreement creation
- Stores license hash anchors (commitment-only, no plaintext license data)
- Provides verified-status assertions consumed by other Layer 1 programs

### 8.3 `worker_profiles.aleo`
- Stores worker profile anchors (hash-only commitments)
- Provides existence and anchored-state assertions

### 8.4 `employer_profiles.aleo`
- Stores employer profile anchors (hash-only commitments)
- Provides existence and anchored-state assertions

### 8.5 `employer_agreement.aleo`
- Defines agreement lifecycle (offer → active → pause/terminate → resume)
- Anchors agreement terms (doc commitments)
- Provides `ACTIVE` status checks for payroll gating

### 8.6 `payroll_core.aleo`
- Executes payroll settlement via **USDCx records**
- Validates:
  - worker profile exists
  - employer profile exists
  - agreement exists and status == `ACTIVE`
- Prevents double-pay per `(agreement_id, epoch_id)`
- Mints private paystub receipts (worker + employer)
- Anchors immutable payroll audit events

### 8.7 `paystub_receipts.aleo`
- Defines private receipt record formats used by Layer 2 reporting
- Stores minimal public receipt anchors and anchor heights (for ordering and existence proofs)

### 8.8 `payroll_audit_log.aleo`
- Hash-only audit anchors
- Minimal mapping:
  - `event_hash -> u32` (first-seen block height)
- No identity or amount storage

### 8.9 `pnw_router.aleo`
- Provides a stable on-chain entry surface for orchestrated flows
- Minimizes duplicated client behavior across portals
- Performs prerequisite assertions and routes to:
  - agreement transitions
  - profile/name assertions
  - payroll execution (when invoked by portal workflows)

---

## 9. Layer 2 NFTs (On-Chain Anchors & Permissions)

Layer 2 contracts store **commitments and permission primitives**, not raw payroll data.

### 9.1 Payroll NFTs (`payroll_nfts.aleo`)
Used for anchoring:
- payroll cycle paystub commitments
- quarterly summary commitments
- YTD and EOY summary commitments

Stores:
- identity hashes (worker, employer)
- epoch and period identifiers
- `doc_hash`, `root`, `inputs_hash`
- schema/calc/policy versions and block height
- revocation and supersede status

### 9.2 Credential NFTs (`credential_nft.aleo`)
Used for:
- employer verification credential (future governance repo)
- employment relationship credential (optional)
- auditor/tax agent credentials (optional)

Stores:
- identity hashes
- scope or agreement commitments
- issuer commitments
- revocation fields

### 9.3 Audit NFTs (`audit_nft.aleo`)
Used for:
- audit authorization tokens (scope + expiration)
- audit report anchors (commitment to report)
- audit result attestations (auditor statement commitment)

Stores:
- subject identifiers and scope
- commitment hashes/roots
- optional expirations and revocation

---

## 10. Canonical Workflows

## 10.1 Onboarding Workflow (Employer & Worker)
1. Register `.pnw` identity (name registry)
2. Create worker profile / employer profile anchors
3. Create an employment job offer and finalize agreement (agreement program)

MVP v2 intentionally treats “issuer / governance credentials” as **external** (extension point).

## 10.2 Payroll Execution Workflow
1. Employer funds wallet with USDCx records
2. Portal calls Layer 1 router / payroll core
3. Payroll core validates:
   - worker and employer profiles exist
   - agreement status == `ACTIVE`
   - `(agreement_id, epoch_id)` not previously paid
4. Payroll core consumes employer USDCx and outputs worker USDCx
5. Payroll core mints private paystub receipts (worker + employer)
6. Payroll core anchors payroll audit event hash

## 10.3 Paystub & Reporting Workflow (Layer 2)
1. Portal fetches Layer 1 receipts and anchors
2. Portal decrypts authorized receipts
3. Portal builds paystub/report documents deterministically
4. Portal computes `doc_hash`, `root`, `inputs_hash`
5. Portal optionally mints receipt/audit NFTs on-chain

## 10.4 Audit Workflow (Permissible Auditability)

This system supports audits without exposing raw payroll or identity data on-chain.

> **MVP vs Future scope:** Sections 10.4.1 through 10.4.2 describe the MVP audit model (on-chain authorization + manual scoped view key share). Sections 10.4.3 through 10.4.6 describe the full target architecture for Phase 6 and beyond (release sessions, confidential activity logging, delayed batched anchoring). The MVP model is simpler but delivers the core privacy guarantee: authorization does not equal disclosure.

### 10.4.1 On-Chain Authorization (MVP + Future)

Both employer and worker consent to an audit via the employment portal's shared audit zone. After both parties consent:

1. An **Audit Authorization NFT** is minted on-chain via `audit_nft.aleo`:
   - Stores only commitment metadata: `scope_hash`, `subject_binding_hash`, `expiry_height`
   - The NFT is owned by the auditor's Aleo address
   - Does **not** contain private payroll data and does **not** decrypt receipts
2. The NFT transaction ID serves as the handshake token that both portals reference

**MVP:** Employer and worker approval happens in the employment portal UI. No SubDAO vote required for MVP.

**Future (Phase 6+):** SubDAO approval may be added as a third required approval for certain audit types. The vote mechanics would live outside MVP v2, but the approval commitment would be recorded on-chain.

### 10.4.2 Data Disclosure (MVP: Scoped View Key Share)

The Audit Authorization NFT proves the auditor *may* access data — but it does not deliver data. Actual disclosure is off-chain:

**MVP model:**
1. After authorization, the employer (or worker) generates a scoped view key for the authorized epochs
   - For MVP, this is the full view key; scoped derivation is a Phase 6 hardening item
2. The employer shares the view key with the auditor through the portal's disclosure flow
   - The NFT transaction ID is the handshake token both sides reference
3. In the auditing portal, the auditor pastes the view key + NFT tx ID
4. The auditing portal verifies the NFT is active on-chain, decodes authorized records, and generates an audit report
5. The auditor can print or export the report

**Phase 6 upgrade:** Replace manual view key share with encrypted delivery — the employment portal encrypts the scoped view key to the auditor's Aleo public key, the auditor decrypts with their private key. No manual copy needed.

### 10.4.3 Release Sessions (Phase 6+)

> **This section describes target architecture, not MVP behavior.**

In the full model, even after an Audit Authorization NFT exists, **actual disclosure requires fresh “release” confirmation** from both parties at time-of-access:

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
- authorization does not equal disclosure
- disclosure is scoped, explicit, and time-limited
- compromised auditor credentials alone are insufficient to extract data

Security properties of the Release Session model:
- possession of public NFT metadata alone is insufficient to obtain data
- compromised auditor credentials cannot bypass worker/employer consent
- access is revocable by simply refusing to sign a new release
- expired or revoked authorizations cannot be exercised

### 10.4.4 Confidential Activity Logging (Phase 6+)

> **This section describes target architecture, not MVP behavior.**

Each scoped disclosure action produces an **Access Event** recorded off-chain in an append-only log.

An Access Event commits to (non-exhaustive):
- `request_id`, `scope_hash`
- authorization reference (commitment to the Audit Authorization NFT)
- auditor identity hash, session identifier
- `bundle_hash` (hash of the disclosed bundle)
- hashes of worker/employer release signatures
- auditor receipt/acknowledgement signature hash

The log is treated as confidential operational security data and is not published in real time.

### 10.4.5 Monthly Delayed Batched Anchoring (Phase 6+)

> **This section describes target architecture, not MVP behavior.**

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

### 10.4.6 Proving an Access Event (Phase 6+)

> **This section describes target architecture, not MVP behavior.**

If a dispute or compliance review requires proof that an access occurred:

1. The disclosing party reveals the specific `access_event_hash` (and optionally its underlying signed components).
2. They provide a Merkle membership proof that the event is included in the on-chain monthly `root(period_id)`.
3. Verifiers confirm inclusion against the on-chain root, without requiring public disclosure of payroll contents.
---

## 11. USDCx Integration Notes

- USDCx is treated as a native Aleo stable asset settled via records.
- The protocol does not mirror balances or manage ledgers.
- Network references:
  - **Testnet:** `test_usdcx_stablecoin.aleo`
  - **Mainnet:** `usdcx_stablecoin.aleo`
 
## Layered Compliance Model: USDCx and PNW

PNW is intentionally designed to be **complementary to USDCx**, not competitive with it.

These two systems operate at **different layers of compliance**, solving different problems that must not be conflated.

---

### USDCx: Monetary Compliance (Issuer Layer)

USDCx, as issued and governed by Circle, provides **monetary compliance**.

USDCx is responsible for proving that:
- funds are not illicit
- AML requirements are met
- sanctions rules are enforced
- regulatory and law-enforcement obligations can be satisfied

This is achieved via **issuer-accessible compliance records** that are:
- private from the public ledger
- accessible to Circle under lawful request

In short:

> **USDCx proves the money is clean.**

This is necessary and appropriate at the asset-issuance layer.

---

### PNW: Relationship Compliance (Application Layer)

PNW operates at a higher layer: **the employment and payroll relationship itself**.

PNW is responsible for proving that:
- an employment relationship exists
- wages were calculated correctly
- payments align with agreements
- disclosures are consensual and scoped
- workers and employers have equal cryptographic standing

PNW achieves this through:
- private records
- commitment anchors
- multi-party authorization
- time-bounded, scope-limited disclosure

No single party (including PNW) has standing access to private data.

In short:

> **PNW proves the relationship is lawful.**

---

### Why These Models Are Complementary

These two compliance layers address **orthogonal concerns**:

| Layer | Proves | Controlled By |
|-----|-------|--------------|
| USDCx | Monetary legitimacy | Issuer (Circle) |
| PNW | Employment legitimacy | Participants (Worker + Employer + DAO) |

USDCx ensures:
- the *money* is compliant

PNW ensures:
- the *context* of the money is legitimate

PNW does **not** replace:
- KYC
- AML
- sanctions enforcement

And USDCx does **not** attempt to govern:
- labor agreements
- wage correctness
- consented auditability
- worker–employer parity

This separation is intentional.

---

### Layered Compliance Is the Goal

PNW builds **on top of** USDCx, not around it.

- USDCx handles **asset-level compliance**
- PNW handles **relationship-level compliance**

Together, they form a layered system where:
- regulators can trust the currency
- participants retain control over their data
- audits are possible without blanket surveillance
- compliance does not imply forfeiture of privacy

This is the intended architecture.

---

## 12. Non-Goals (MVP)

The MVP intentionally excludes:
- On-chain analytics and aggregation
- Public financial reporting
- Cross-chain payout adapters
- Centralized or pooled payroll treasuries
- Full governance systems (DAOs, voting, dispute courts, treasury policy)

Governance is planned as a **separate interoperable repository** that issues credentials and authority proofs consumed by MVP v2.

---

## 13. Extension Points

Future enhancements can add:
- Governance repo interoperability (issuer credentials, revocation, disputes)
- Employer-controlled pools (budget views / earmarked funds) without protocol custody
- ZK proofs for compliance claims (wage floor, tax reserve ratios, etc.)
- Worker-controlled selective disclosure primitives
- Advanced invoice/billing workflows
- Token registry resolution and formal USDCx metadata bindings

## 14. External Review Alignment (Privacy, Audit Semantics, Custody)

This section captures our alignment with common payroll-program review feedback (including concerns raised in buildathon reviews):

### 14.1 Prevent cumulative-total leakage

We do **not** expose cumulative payroll totals in public mappings (for example `total_spent` deltas).

Instead:
- payroll amounts are processed in private records,
- public Layer 1 state is commitment-first,
- and audit anchoring stores hash-only events.

This avoids salary inference from "before/after" public counters.

### 14.2 Distinguish audit evidence classes

Audit data is intentionally separated by evidence type:
- **existence/order anchors** (Layer 1 hash logs),
- **document commitments** (`doc_hash` / `root` / `inputs_hash`),
- **authorization scope** (credential/audit NFTs),
- **selective disclosure proofs** (Merkle proofs, future ZK extensions).

This is more useful for auditors than a single generic "spent total" record.

### 14.3 Custody model is intentionally non-pooled in MVP

MVP v2 intentionally avoids protocol-level pooled custody.

Current model:
- employer-owned USDCx input records are consumed,
- worker-owned output records are created,
- no protocol treasury or shared payroll pot is maintained.

If budget custody features are introduced later, they will be explicit extension modules with separate risk/compliance controls.

