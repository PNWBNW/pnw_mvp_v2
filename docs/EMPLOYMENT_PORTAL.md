# Employment Portal — Product Specification

> Version: 0.1 (MVP scope)
> Last updated: 2026-03-12
> Status: Design phase — no UI built yet

---

## What This Is

The Employment Portal is a privacy-first web application that sits between users and
the Aleo blockchain. It is **not a wallet** — it never holds funds, private keys, or
cumulative spend data. It is an **employment relationship interface**: a shared space
where employers and workers can execute payroll, view their own private records,
manage credentials, and respond to audit requests.

The closest analogy is QuickBooks meets a blockchain wallet app — but with zero
plaintext wage or identity data ever leaving the user's session.

**What the portal does:**
- Authenticates both parties and holds their addresses in session only
- Builds transaction inputs from that session context
- Dispatches `snarkos developer execute` commands through the adapter layer
- Decodes the user's own private records back to them via their view key
- Presents status, history, and pending actions in a clean two-sided UI

**What the portal never does:**
- Store private keys, view keys, wages, or names in a database
- Show one party's records to the other
- Act as a custodian of any funds
- Write plaintext identity or salary data to public chain state

---

## Two-Sided Layout

The portal has two authenticated contexts — **Employer** and **Worker** — with a
shared zone for actions that require consent from both parties (audit authorization).

```
┌─────────────────────────────────────────────────────────────────┐
│                    PNW Employment Portal                        │
├────────────────────────┬────────────────────────────────────────┤
│   EMPLOYER SIDE        │   WORKER SIDE                          │
│                        │                                        │
│  Dashboard             │  Dashboard                             │
│  ├─ Active employees   │  ├─ My employment status               │
│  ├─ Pending payroll    │  ├─ My paystubs (private)              │
│  ├─ USDCx balance      │  ├─ My credentials                     │
│  └─ Pending audits     │  └─ Pending audit requests             │
│                        │                                        │
│  Payroll               │  Wallet Activity                       │
│  ├─ Run payroll        │  ├─ USDCx received (by epoch)          │
│  ├─ Payroll history    │  └─ YTD summary (private)              │
│  └─ YTD summary        │                                        │
│                        │  Credentials                           │
│  Employees             │  ├─ My active credentials              │
│  ├─ Onboard worker     │  └─ Credential history                 │
│  ├─ View agreements    │                                        │
│  └─ Revoke/supersede   │  Tax Summary (Phase 6)                 │
│                        │  ├─ W-2 data export                    │
│  Credentials           │  └─ State filing summary               │
│  ├─ Issue credential   │                                        │
│  └─ Revoke credential  ├────────────────────────────────────────┤
│                        │   SHARED — AUDIT ZONE                  │
│  Tax / Compliance      │                                        │
│  ├─ Audit log          │  Pending Audit Requests                │
│  ├─ Request audit      │  ├─ View scope + expiry                │
│  └─ State filing prep  │  ├─ Approve / Decline                  │
└────────────────────────┴────────────────────────────────────────┘
```

---

## Employer Side

### Authentication
The employer logs in once per session. Their Aleo address and view key are held in
the session only — never written to a portal database. The session token authorizes
all dispatched transactions for the session duration.

The portal injects `ALEO_ADDRESS` into scenario templates at dispatch time. No
address appears in config files or source code.

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
4. Worker receives private USDCx record + PayrollNFT in their wallet
5. Portal shows confirmation with transaction IDs (linkable to explorer)

**Payroll History**
- List of past payroll epochs for each worker
- Each row: epoch ID, gross amount, net amount, tx ID, PayrollNFT status
- All amounts decoded locally via employer view key — never stored in portal DB

**YTD Summary**
- Per-worker: total gross, net, tax withheld for current year
- Computed locally from decoded private records each session
- Exportable as CSV for internal accounting (no blockchain write required)

### Employee Management

**Onboard Worker**
1. Employer enters worker's Aleo address (or worker scans a QR from their side)
2. Portal computes name hash locally
3. Dispatches `worker_profiles` → `employer_agreement` → optional `credential_nft`
4. Employment agreement NFT anchored on-chain; both parties can verify

**Employment Agreements**
- View active agreements (decoded from employer's records)
- Supersede or terminate agreement (triggers on-chain revoke + new mint)

### Credentials

**Issue Credential**
- Select worker, credential type, scope, and expiry
- Portal dispatches `credential_nft` → `mint_credential_nft`
- Credential NFT is owned by the worker; employer holds an anchor hash

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
- Portal creates an `AuditAuthorizationNFT` request visible to the worker
- Audit only proceeds after both parties sign (see Audit Zone below)

---

## Worker Side

### Authentication
Workers log in with their Aleo address and view key. The portal uses the view key
to decode only records owned by that worker — no other records are visible.

`WORKER_ADDRESS` is injected into transactions from session context. The portal
never stores it persistently.

### Dashboard
- Current employer name (decoded from agreement record)
- Most recent paystub (net amount, epoch, tx ID)
- Active credentials summary
- Any pending audit authorization requests requiring worker consent

### Paystubs

**Paystub List**
- One row per payroll epoch: date, gross, net, tax withheld, USDCx received
- All decoded locally via worker's view key from their PayrollNFTs and paystub records
- Each row links to the Provable Explorer tx ID for independent verification

**Paystub Detail**
- Full breakdown: gross, deductions, net
- Receipt anchor hash (worker can verify independently)
- PayrollNFT status: active / superseded / revoked

### Wallet Activity

**USDCx Received**
- List of inbound USDCx records with amounts and epoch IDs
- Not a wallet — just a decoded view of the worker's private records
- Worker can copy their address to receive in any compatible Aleo wallet

**YTD Summary (Worker View)**
- Total gross earned, total net received, total tax withheld year-to-date
- Computed from decoded records each session
- Exportable for personal tax prep

### Credentials

**Active Credentials**
- List of credential NFTs owned by worker: type, issuer, scope, expiry
- Status: active / expiring soon / expired / revoked

**Credential History**
- All credentials ever issued, including revoked ones, with timestamps

---

## Shared — Audit Zone

Audit authorization requires **both employer and worker to consent**. Neither can
unilaterally grant an auditor access to payroll data.

### Audit Authorization Flow

```
Employer requests audit
        │
        ▼
Portal creates pending AuditAuthorizationNFT (not yet minted)
        │
        ▼
Worker sees pending request on their dashboard
        │
   Worker reviews:
   - Auditor address
   - Scope: which pay periods
   - Expiry: how long access lasts
        │
   ┌────┴────┐
   │ Approve │  → Portal dispatches audit_nft → mint_audit_authorization_nft
   │ Decline │  → Request closed; no NFT minted; no audit proceeds
   └─────────┘
        │
        ▼
AuditAuthorizationNFT minted, owned by auditor
Auditor can use it to request scoped disclosure
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

## Privacy Model Summary

| Data | Where it lives | Who can see it |
|---|---|---|
| Worker address | Session only | Worker, employer (at dispatch) |
| Employer address | Session only | Employer |
| Wages / paystub amounts | Private Aleo records | Record owner only (via view key) |
| Name hashes | Public chain | Anyone (hash only, not name) |
| Agreement anchors | Public chain | Anyone (commitment only) |
| Audit event hashes | Public chain | Anyone (hash only) |
| Actual audit data | Off-chain, scoped | Auditor + parties, time-limited |
| Tax export CSV | Client-side only | User who exported it |

The portal never writes plaintext wages, names, or addresses to any server database.

---

## Architecture Mapping (Existing Code)

| Portal Feature | Calls | File |
|---|---|---|
| Run payroll | `payroll_core`, `paystub_receipts`, `payroll_nfts` | `portal/src/adapters/aleo_cli_adapter.ts` |
| Onboard worker | `worker_profiles`, `employer_agreement` | Layer 1 adapter |
| Issue credential | `credential_nft` | Layer 2 adapter |
| Request audit | `audit_nft` | Layer 2 adapter |
| Decode private records | View key scan | Aleo SDK (client-side) |
| Address injection | `envsubst` / session context | `scripts/run_phase4_execute_scenario.sh` |
| Scenario validation | JSON schema check | `scripts/validate_phaseA_scenario.py` |
| Program ID registry | Manifest lookup | `config/testnet.manifest.json` |

All execution goes through `aleo_cli_adapter.ts` — the portal UI never calls `snarkos` directly.

---

## Future: Tax & Compliance (Phase 6+)

### W-2 / 1099 Data Export
- Worker exports their decoded payroll records as a structured JSON or CSV
- Fields: employer name hash, gross, federal tax withheld, state tax withheld, year
- No server involvement — computed locally from private records via view key
- Worker submits to their tax preparer; preparer has no blockchain access required

### State Filing Prep (Washington / PNW)
- Employer exports per-worker YTD summary
- Maps to WA L&I / ESD reporting fields
- Employer downloads, reviews, submits to state — portal generates the draft only

### Federal EIN / TIN Handling
- EIN stored as a hash anchor only — never plaintext on-chain
- Portal holds EIN in employer session for form population
- Printed on exported tax docs, never written to chain

### Audit-Ready Package
- On audit request: portal assembles a scoped disclosure package
- Contains decoded records for the authorized epochs only
- Delivered to auditor address via the AuditAuthorizationNFT access grant

---

## What the Portal Is NOT

- Not a custodial wallet — it never holds USDCx or Aleo credits
- Not a payroll processor — it dispatches; the Aleo program executes
- Not a tax advisor — it exports data; filing is the user's responsibility
- Not a source of truth — the blockchain record is canonical; the portal is a view

---

## Open Questions (To Resolve Before UI Build)

1. **Authentication method** — Aleo wallet extension (Puzzle/Leo wallet) vs. private key
   paste vs. hardware wallet? Determines how view key is obtained at session start.
2. **Worker onboarding UX** — does the employer paste the worker's address, or does the
   worker scan a QR code from the employer's portal session?
3. **Multi-employer support** — can one worker address have agreements with multiple
   employers? Yes per the protocol, but the UI needs to handle this.
4. **Notification layer** — how does a worker know a payroll was run or an audit was
   requested if they're not watching the portal? Push notification, email digest, or
   polling?
5. **Mobile** — responsive web only for MVP, or native app for Phase 6?
