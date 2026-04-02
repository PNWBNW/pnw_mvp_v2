# Employment Portal — Product Specification

> Version: 0.2
> Last updated: 2026-03-12
> Status: **HISTORICAL DOCUMENT** — written pre-implementation

> **NOTE (2026-04-01):** The portal is now fully built and operational on testnet.
> For current status, architecture, and implementation details, see the
> [pnw_employment_portal_v1](https://github.com/PNWBNW/pnw_employment_portal_v1) repository.
> Key docs: `HANDSHAKE.md` (agreement flow), `BUILD_ORDER.md` (phases), `EMPLOYER_FLOWS.md` (UX).

---

## What This Is

The Employment Portal is a privacy-first web application that sits between users and
the Aleo blockchain. It is **not a wallet** — it never holds funds, private keys, or
cumulative spend data. It is an **employment relationship interface**: a shared space
where employers and workers can execute payroll, view their own private records,
manage credentials, respond to audit requests, and generate printable documents.

The closest analogy is QuickBooks meets a blockchain employment record — but with
zero plaintext wage or identity data ever leaving the user's session, and with all
source-of-truth records cryptographically anchored on-chain.

**What the portal does:**
- Authenticates both parties via wallet connection or key entry; holds credentials
  in session only
- Builds transaction inputs from that session context
- Dispatches `snarkos developer execute` commands through the adapter layer
- Decodes the user's own private records back to them via their view key
- Presents status, history, and pending actions in a clean two-sided UI
- Generates printable PDFs of NFT-backed documents (paystubs, credentials, audit
  authorizations) — client-side only, never uploaded

**What the portal never does:**
- Store private keys, view keys, wages, names, or addresses in a database
- Show one party's records to the other
- Act as a custodian of any funds
- Write plaintext identity or salary data to public chain state
- Send notifications — users are notified by their Aleo wallet when funds arrive;
  they open the portal to see the employment details

---

## Two-Sided Layout

The portal has two authenticated contexts — **Employer** and **Worker** — with a
shared zone for actions requiring consent from both parties.

```
┌──────────────────────────────────────────────────────────────────┐
│                     PNW Employment Portal                        │
├─────────────────────────┬────────────────────────────────────────┤
│   EMPLOYER SIDE         │   WORKER SIDE                          │
│                         │                                        │
│  Dashboard              │  Dashboard                             │
│  ├─ Active employees    │  ├─ My employers                       │
│  ├─ Pending payroll     │  ├─ My paystubs (private)              │
│  ├─ USDCx balance       │  ├─ My credentials                     │
│  └─ Pending audits      │  └─ Pending audit requests             │
│                         │                                        │
│  Payroll                │  Wallet Activity                       │
│  ├─ Run payroll         │  ├─ USDCx received (by epoch)          │
│  ├─ Payroll history     │  └─ YTD summary (private)              │
│  └─ YTD summary         │                                        │
│                         │  Credentials                           │
│  Employees              │  ├─ My active credentials              │
│  ├─ Onboard worker      │  ├─ Credential history                 │
│  ├─ View agreements     │  └─ Print credential certificate       │
│  └─ Revoke/supersede    │                                        │
│                         │  Documents                             │
│  Credentials            │  ├─ Print paystub                      │
│  ├─ Issue credential    │  └─ Print YTD summary                  │
│  └─ Revoke credential   │                                        │
│                         │  Tax Summary (Phase 6+)                │
│  Documents              │  ├─ W-2 / 1099 export                  │
│  ├─ Print payroll run   │  └─ State filing summary               │
│  └─ Print YTD summary   ├────────────────────────────────────────┤
│                         │   SHARED — AUDIT ZONE                  │
│  Tax / Compliance       │                                        │
│  ├─ Audit log           │  Pending Audit Requests                │
│  ├─ Request audit       │  ├─ View scope + expiry                │
│  └─ State filing prep   │  ├─ Approve / Decline                  │
│  (Phase 6+)             │  └─ Print authorization doc            │
└─────────────────────────┴────────────────────────────────────────┘
```

---

## Authentication — Wallet-Agnostic Model

**Decision: No specific wallet is required or gated.**

The portal supports two connection paths, and users can choose either:

**Path A — Wallet Connection (preferred)**
Connect any compatible Aleo wallet extension (Shield, Puzzle, Leo Wallet, or others).
The wallet signs transactions and exposes the view key to the portal session. The
private key never leaves the wallet extension. This is the most secure path and the
one most users will use once wallet extensions are common.

**Path B — Direct Key Entry (fallback)**
User pastes their private key and view key directly into a secure session input.
Portal holds them in memory only for the session duration, never writes them
anywhere. Suitable for CLI-first operators and Codespace-based testing.

**What the portal needs from the user's session:**
- `address` — public Aleo address (for record ownership / recipient identification)
- `view_key` — for decoding their own private records
- `private_key` — for signing transactions dispatched through the adapter

**What never happens:**
- No wallet is recommended over another
- No wallet-specific APIs are hardcoded — wallet integration uses a common interface
- Wallet gating decisions deferred to post-MVP

---

## Employer Side

### Dashboard
- Active worker count (from local employment agreement records)
- USDCx balance (decoded from employer's private records via view key)
- Upcoming payroll epochs (based on agreement terms)
- Pending audit authorization requests requiring employer signature

### Payroll

**Run Payroll**
1. Employer selects pay period and confirms gross/net/tax breakdown
2. Portal computes commitment hashes locally (no server round-trip for sensitive data)
3. Portal dispatches `payroll_core` → `paystub_receipts` → `payroll_nfts` via adapter
4. Worker receives private USDCx record + PayrollNFT in their Aleo wallet
5. Portal shows confirmation with transaction IDs (linkable to Provable Explorer)
6. Employer can immediately generate a printable payroll run document

**Payroll History**
- List of past payroll epochs for each worker
- Each row: epoch ID, gross, net, tax withheld, tx ID, PayrollNFT status
- All amounts decoded locally via employer view key — never stored in portal DB

**YTD Summary**
- Per-worker: total gross, net, tax withheld for current year
- Computed locally from decoded private records each session
- Exportable as CSV for internal accounting (no blockchain write required)

### Employee Management

**Onboard Worker — QR Code Flow**

The employer initiates onboarding from the portal. The portal generates a unique
QR code per employee that encodes a pre-populated onboarding package.

```
Employer fills in portal:
  - Worker's prospective role / wage agreement terms
  - State/jurisdiction (suffix code)
  - Any initial credential types to issue at hire

Portal generates:
  - Unique onboarding QR code (contains: employer address hash,
    agreement template data, portal onboarding link)
  - Pre-populated employment agreement document (printable)
  - Optional: code of conduct, wage disclosure, offer letter template

Employer provides QR to worker (printed, emailed, shown on screen)

Worker scans QR → lands on portal onboarding page:
  - Agreement terms pre-populated
  - Worker connects wallet or enters credentials
  - Worker reviews and confirms all terms
  - Portal dispatches: worker_profiles → employer_agreement → credential_nft (if any)
  - Employment agreement NFT anchored on-chain; both parties can verify
```

The portal generates these documents. Physical paperwork (I-9, W-4, state forms)
is handled outside the portal for MVP. The QR links the off-chain onboarding
paperwork to the on-chain employment agreement.

**Employment Agreements**
- View active agreements (decoded from employer's records)
- Supersede or terminate agreement (triggers on-chain revoke + new mint)
- Multi-worker view: each worker listed with their agreement status

### Credentials

**Issue Credential**
- Select worker, credential type, scope, and expiry
- Portal dispatches `credential_nft` → `mint_credential_nft`
- Credential NFT is owned by the worker; employer holds an anchor hash
- Portal can immediately generate a printable credential certificate

**Revoke Credential**
- Select active credential
- Portal dispatches `credential_nft` → `revoke_credential_nft`
- On-chain state updated; worker's NFT marked inactive

### Compliance

**Audit Log**
- Internal log of all payroll audit event hashes (not the data — just hashes)
- Maps epoch → audit_event_hash_hex stored in `payroll_audit_log`

**Request Audit Authorization**
- Employer fills in: auditor address, scope (which epochs), expiry block height
- Portal creates a pending request visible to the worker
- Audit only proceeds after both parties consent (see Audit Zone below)

---

## Worker Side

### Dashboard
- **Multi-employer aware**: lists all employers the worker has active agreements with
- For each employer: current status, most recent paystub epoch, active credentials
- Any pending audit authorization requests requiring worker consent

### Multi-Employer Support

A worker can have active employment agreements with multiple employers simultaneously.
The portal surfaces each employer relationship as a separate card/section. Payroll
history, credentials, and audit requests are always scoped to the specific employer
relationship — never mixed.

```
My Employers:
  ├─ [Employer A — Active — last paid: epoch 20260302]
  │     ├─ 3 active credentials
  │     └─ 1 pending audit request
  └─ [Employer B — Active — last paid: epoch 20260228]
        └─ 1 active credential
```

Workers do not need to notify any employer of their other employment relationships.
Each relationship is private to the parties involved.

### Paystubs

**Paystub List**
- One row per payroll epoch per employer: date, gross, net, tax withheld, USDCx received
- All decoded locally via worker's view key from their PayrollNFTs and paystub records
- Each row links to the Provable Explorer tx ID for independent verification
- Each row has a "Print Paystub" button

**Paystub Detail**
- Full breakdown: gross, deductions, net
- Receipt anchor hash (worker can verify independently)
- PayrollNFT status: active / superseded / revoked

### Wallet Activity

**USDCx Received**
- List of inbound USDCx records with amounts and epoch IDs
- **Not a wallet** — a decoded view of the worker's private records only
- Worker's Aleo wallet (Shield, Puzzle, etc.) is where actual funds live and where
  they will have been notified of receipt; this portal shows the employment context
  for those receipts

**YTD Summary (Worker View)**
- Total gross earned, total net received, total tax withheld year-to-date
- Computed from decoded records each session
- Exportable for personal tax prep

### Credentials

**Active Credentials**
- List of credential NFTs owned by worker: type, issuer, scope, expiry
- Status: active / expiring soon / expired / revoked
- "Print Certificate" button for each active credential

---

## Shared — Audit Zone

Audit authorization requires **both employer and worker to consent**. Neither can
unilaterally grant an auditor access to payroll data.

### Audit Authorization Flow

```
Employer requests audit
        │
        ▼
Portal creates pending request (no NFT yet):
  - Auditor address
  - Scope: which pay epochs
  - Expiry: block height (portal shows estimated date)
        │
        ▼
Worker sees pending request on their dashboard
Worker reviews full scope and timeline
        │
   ┌────┴────┐
   │ Approve │  → Portal dispatches audit_nft → mint_audit_authorization_nft
   │         │  → Both parties can print authorization document
   │ Decline │  → Request closed; no NFT minted; no audit proceeds
   └─────────┘
        │
        ▼
AuditAuthorizationNFT minted, owned by auditor
Auditor uses it to request scoped disclosure within the access window
        │
        ▼
At expiry block height: NFT becomes inactive automatically
```

### What the Auditor Sees
- Only the pay periods included in the authorized scope
- Only for the duration specified in the NFT
- Nothing outside that scope is accessible — the NFT is the access token

### Audit Status (Both Parties)
- Pending: awaiting worker approval
- Active: NFT minted, auditor has access window
- Expired: NFT past block height expiry
- Declined: worker rejected, no NFT minted

---

## Printable Documents — NFT-Backed PDFs

**Decision: Every major NFT action generates a printable human-readable document.**

The portal generates PDFs client-side (no server upload, no third-party service).
Each document contains enough information to be useful to a human reader — employer
HR teams, workers keeping personal records, accountants, auditors — without
exposing private wage or identity data to unauthorized parties.

### Paystub PDF

Generated from the worker's decoded PayrollNFT record.

```
┌─────────────────────────────────────────────────────┐
│             PNW Verified Paystub                    │
│                                                     │
│  Pay Period:    [Epoch 20260302]                    │
│  Employer:      [Employer display label]            │
│  Worker:        [Worker display label]              │
│                                                     │
│  Gross Pay:            $X,XXX.XX                   │
│  Federal Tax:          $  XXX.XX                   │
│  State Tax:            $   XX.XX                   │
│  Other Deductions:     $    X.XX                   │
│  ─────────────────────────────────────             │
│  Net Pay:              $X,XXX.XX                   │
│                                                     │
│  Settled via USDCx on Aleo Testnet                 │
│                                                     │
│  On-chain verification:                             │
│  TX: [transaction ID]                               │
│  PayrollNFT: [anchor hash]                          │
│  [QR code → Provable Explorer tx link]              │
│                                                     │
│  This document was generated from a private Aleo   │
│  record. The on-chain anchor is the authoritative  │
│  source of truth. No private data is published.    │
└─────────────────────────────────────────────────────┘
```

- Display labels are set by the user in their session (not stored anywhere)
- Dollar amounts are decoded from private records via view key
- The QR code links to the public tx on Provable Explorer
- No private key material, raw addresses, or unmasked identity data appears

### Credential Certificate PDF

Generated from a CredentialNFT.

```
┌─────────────────────────────────────────────────────┐
│           PNW Verified Credential                   │
│                                                     │
│  Credential Type:   [e.g., "Employment Verified"]  │
│  Issued To:         [Worker display label]          │
│  Issued By:         [Employer display label]        │
│                                                     │
│  Scope:             [e.g., "Full-time, WA State"]  │
│  Valid Through:     [Expiry date / block height]   │
│  Status:            ACTIVE                         │
│                                                     │
│  On-chain verification:                             │
│  TX: [transaction ID]                               │
│  CredentialNFT: [anchor hash]                       │
│  [QR code → Provable Explorer tx link]              │
│                                                     │
│  This credential is anchored on the Aleo network.  │
│  Verify authenticity at [explorer link].            │
└─────────────────────────────────────────────────────┘
```

Useful for workers presenting employment verification to third parties (banks,
landlords, lenders) without disclosing their blockchain address or salary.

### Audit Authorization PDF

Generated from an AuditAuthorizationNFT after both parties consent.

```
┌─────────────────────────────────────────────────────┐
│        PNW Audit Authorization Certificate          │
│                                                     │
│  Authorized Parties:                                │
│    Employer:   [Employer display label]             │
│    Worker:     [Worker display label]               │
│                                                     │
│  Authorized To:  [Auditor display label / org]     │
│                                                     │
│  Scope:          Pay epochs [X] through [Y]        │
│  Valid Through:  Block [N] (est. [date])           │
│  Status:         ACTIVE                             │
│                                                     │
│  IMPORTANT: This document confirms authorization   │
│  scope only. It does not contain private payroll   │
│  data. Payroll records are accessible only through  │
│  the authorized disclosure channel for the         │
│  duration above.                                   │
│                                                     │
│  On-chain verification:                             │
│  TX: [transaction ID]                               │
│  AuditAuthNFT: [anchor hash]                        │
│  [QR code → Provable Explorer tx link]              │
└─────────────────────────────────────────────────────┘
```

This document can be provided to auditors, regulators, or attorneys as proof
that a properly scoped and time-limited audit authorization exists on-chain —
without disclosing the actual payroll data.

### PDF Privacy Rules

| What appears in PDF | Allowed |
|---|---|
| User-chosen display labels | Yes — user controls this |
| Decoded amounts (worker's own data) | Yes — from session view key only |
| Transaction IDs (public) | Yes — public by definition |
| Anchor hashes (public commitments) | Yes — hash only, no preimage |
| Raw Aleo addresses | No — never printed |
| Private key / view key material | Never |
| Other party's private data | Never |

---

## Privacy Model Summary

| Data | Where it lives | Who can see it |
|---|---|---|
| Worker address | Session only | Worker, employer (at dispatch time) |
| Employer address | Session only | Employer |
| Wages / paystub amounts | Private Aleo records | Record owner only (via view key) |
| Name hashes | Public chain | Anyone (hash only, not name) |
| Agreement anchors | Public chain | Anyone (commitment only) |
| Audit event hashes | Public chain | Anyone (hash only) |
| Actual audit data | Off-chain, scoped | Auditor + parties, time-limited |
| PDF documents | Client-side only | User who generated it |
| Tax export CSV | Client-side only | User who exported it |

The portal never writes plaintext wages, names, or addresses to any server database.
Notifications are handled by the user's Aleo wallet — the portal is not a notification
system. Workers open the portal to see employment context for activity their wallet
already showed them.

---

## Architecture Mapping (Existing Code)

| Portal Feature | Calls | File |
|---|---|---|
| Run payroll | `payroll_core`, `paystub_receipts`, `payroll_nfts` | `portal/src/adapters/aleo_cli_adapter.ts` |
| Onboard worker | `worker_profiles`, `employer_agreement` | Layer 1 adapter |
| Issue credential | `credential_nft` | Layer 2 adapter |
| Request audit | `audit_nft` | Layer 2 adapter |
| Decode private records | View key scan | Aleo SDK (client-side) |
| Address injection | Session context → envsubst | `scripts/run_phase4_execute_scenario.sh` |
| Scenario validation | JSON schema check | `scripts/validate_phaseA_scenario.py` |
| Program ID registry | Manifest lookup | `config/testnet.manifest.json` |
| PDF generation | Client-side render | Portal UI (repo TBD — see Multi-Repo Plan) |
| QR code generation | Client-side render | Portal UI (repo TBD) |

All execution goes through `aleo_cli_adapter.ts` — the portal UI never calls
`snarkos` directly.

---

## Future: Tax & Compliance (Phase 6+)

**Scope**: Eventually all 50 states + local jurisdictions. MVP focuses on WA.
The tax export module is designed to be jurisdiction-extensible from the start —
each jurisdiction is a mapping from decoded payroll fields to a filing schema.

### W-2 / 1099 Data Export
- Worker exports decoded payroll records as structured JSON or CSV
- Fields: employer identifier, gross, federal tax withheld, state tax withheld, year
- No server involvement — computed locally from private records via view key
- Worker provides to tax preparer; preparer requires no blockchain access

### State Filing Prep (WA first, all states eventually)
- Employer exports per-worker YTD summary
- Maps to WA L&I / ESD fields for MVP; extensible to all state schemas
- Employer downloads, reviews, submits to state — portal generates the draft only

### Federal EIN / TIN Handling
- EIN held in employer session only; never written to chain
- Printed on exported tax docs at generation time

### Audit-Ready Package
- On audit: portal assembles scoped disclosure package for authorized epochs only
- Delivered through AuditAuthorizationNFT access grant

---

## What the Portal Is NOT

- Not a custodial wallet — it never holds USDCx or Aleo credits
- Not a payroll processor — it dispatches; the Aleo program executes
- Not a notification service — the user's Aleo wallet handles fund notifications
- Not a tax advisor — it exports data; filing is the user's responsibility
- Not a source of truth — the blockchain record is canonical; the portal is a view

---

## Open Questions (Deferred — Not Blocking MVP)

1. **Wallet integration API** — common interface across Shield, Puzzle, Leo wallet, and
   future wallets. No specific wallet is recommended or gated. Defer to post-MVP.
2. **Mobile** — responsive web for MVP; native app is Phase 6+ consideration.
3. **Physical onboarding docs** (I-9, W-4, state forms) — these live outside the portal
   for MVP. Integration path to be defined.
4. **Multi-repo interoperability** — see separate `MULTI_REPO_PLAN.md` (to be written
   after 3-repo structure is confirmed).
