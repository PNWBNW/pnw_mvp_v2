# Auditor Portal — Design Reference

> This file captures the full design intent for the standalone Auditor Portal repo.
> When MVP v2 is stable on testnet, pull this document to bootstrap the new repo.
> All cryptographic primitives and SDK exports live in `pnw_mvp_v2`.

---

## What the Auditor Portal Is

The portal is the **enforcement point** for audit authorizations created on-chain via `audit_nft.aleo`. It connects the cryptographic commitments proven on Aleo to actual encrypted payroll data. Without the portal, privacy guarantees are theoretical. With it, they are operationally real and auditable.

This is the feature that differentiates PNW from every other payroll project on Aleo. Other projects prove payments are private. PNW answers the next question: *what happens when a regulator actually needs to see data?* The answer is scoped, time-limited, dual-consent disclosure — and the portal is where that answer becomes software.

---

## Core Security Properties

1. **Auditor only sees what they asked for.** The `scope_hash` on the NFT is a binding commitment to exactly the data categories, time period, and worker/employer pair the auditor declared upfront. The portal hard-filters every query against the declared scope. Nothing outside the scope exists to the auditor's session.

2. **Access is time-bound.** `expires_epoch` is enforced on-chain and re-verified by the portal on every session start. After expiry, even a valid NFT record produces no access.

3. **Both parties consented to the exact scope and duration.** `employer_consent_hash` and `worker_consent_hash` each commit to `scope_hash + access_duration_epochs + expires_epoch`. Neither party can be tricked into approving a different request.

4. **Authorization can be revoked at any time.** Either consenting party can call `revoke_authorization_nft` on-chain. The portal checks `auth_status` on every session start; revoked NFTs produce no access immediately.

5. **Every data access is logged.** The portal maintains an immutable, tamper-evident access log. Worker and Employer can query this log at any time to see who accessed what.

6. **Data is encrypted at rest.** Payroll records are stored encrypted. Decryption only happens in-memory during an active, authorized, scope-verified session. Derived keys are discarded on session end.

---

## Authentication Flow

### Step 1 — Challenge/Response (Prove NFT Ownership)

```
Portal → Auditor:  { nonce: "<random 32 bytes hex>", ttl: 60s }
Auditor → Portal:  {
  signed_nonce: sign(nonce, auditor_private_key),
  nft_record:   <full AuditAuthorizationNFT record>,
  scope_preimage: <full AuditScopeRequest object>,
}
```

The portal verifies:
- `signature` is valid for `nft_record.owner` (auditor's Aleo address)
- `computeScopeHash(scope_preimage) === nft_record.scope_hash`

### Step 2 — On-Chain Validation

The portal queries the Aleo REST API (read-only, no transaction):

```
auth_status[nft.auth_id]         === STATUS_ACTIVE   (1)
auth_expires_epoch[nft.auth_id]  >= currentEpoch
auth_revoked_height[nft.auth_id] === 0
```

All three must pass. If any fails, authentication is rejected.

### Step 3 — Session Token Issued

Portal issues a scoped JWT or equivalent session token:

```json
{
  "session_id": "<uuid>",
  "auth_id": "<hex32>",
  "scope_hash": "<hex32>",
  "data_categories": ["payroll_cycle", "quarterly_summary"],
  "period_start_epoch": 1000,
  "period_end_epoch": 2000,
  "worker_id_hash": "<hex32>",
  "employer_id_hash": "<hex32>",
  "expires_at": "<ISO timestamp matching expires_epoch>",
  "issued_at": "<ISO timestamp>"
}
```

The session token encodes the full scope. Every API call validates this token — no separate scope lookup needed per request.

---

## Data Serving

### Enforcement Rules (Applied to Every Query)

```
1. Session must be valid and not expired
2. On-chain status re-checked every N minutes (configurable, default: 5)
3. data_categories bitmask filters which record types are visible
4. period_start_epoch / period_end_epoch filter record time range
5. worker_id_hash / employer_id_hash filter whose records are visible
6. Cannot request more than scope allows — can request less
```

The data store query layer should treat scope as a mandatory `WHERE` clause injected before any user-provided filters. The auditor never has a code path to bypass this.

### API Surface

```
POST /auth/challenge
  Body: { auditor_address: string }
  Returns: { nonce: string, expires_at: string }

POST /auth/verify
  Body: { signed_nonce, nft_record, scope_preimage }
  Returns: { session_token: string, scope: AuditConsentContext }

GET /data/payroll-cycles
  Header: Authorization: Bearer <session_token>
  Query: ?from_epoch=&to_epoch=  (further narrows scope; cannot exceed it)
  Returns: paginated payroll cycle records

GET /data/quarterly-summaries
  (same pattern)

GET /data/ytd-summaries
  (same pattern)

GET /data/credentials
  (same pattern)

GET /access-log
  Header: Authorization: Bearer <session_token>
  Returns: auditor's own access log for this authorization

POST /auth/revoke
  Header: Authorization: Bearer <session_token>
  Effect: invalidates the session immediately (on-chain revoke is separate, done via wallet)
```

---

## Access Log

Every successful data response is recorded:

```typescript
interface AccessLogEntry {
  session_id: string;
  auth_id: string;           // which NFT
  auditor_addr_hash: string; // who
  endpoint: string;          // which API endpoint
  query_params_hash: string; // hash of query params (not contents)
  record_count: number;      // how many records were returned
  timestamp: string;         // ISO UTC
}
```

The log is append-only. Worker and Employer can query their own access logs via their own portal sessions. The auditor can query their own access log via the audit session.

---

## Encrypted Data Store

Payroll records are stored encrypted at rest. The encryption scheme:

- Each employment agreement has a symmetric encryption key derived from secrets known to the employer portal (pnw_mvp_v2 portal)
- When a payroll cycle completes, encrypted records are written to the audit data store
- The audit portal holds the decryption capability (key storage TBD — HSM, KMS, or threshold scheme)
- Decryption happens in-memory only, within an active authorized session
- Decrypted data is never written to disk or logged

### Key Design Choices (Defer to New Repo)

The audit repo will need to decide:
- Key storage backend (AWS KMS, HashiCorp Vault, threshold scheme)
- Database backend (PostgreSQL with encrypted columns, or encrypted blobs)
- Whether the employer portal writes to the audit store directly or via an API

---

## Repo Boundary and SDK

### What `pnw_mvp_v2` Exports (The SDK)

The new repo imports from this repo's SDK package:

```typescript
// Cryptographic primitives
import {
  computeScopeHash,
  computeConsentHash,
  computeAuthorizationEventHash,
  deriveAuditHashes,
} from "@pnw/audit-sdk/commitments";

// Types
import type {
  AuditScopeRequest,
  AuditConsentRequest,
  AuditConsentContext,
  DerivedAuditHashes,
} from "@pnw/audit-sdk/types";

// On-chain validation (hits Aleo REST API)
import { AuditAuthAdapter } from "@pnw/audit-sdk/adapters";

const adapter = new AuditAuthAdapter({ endpoint: ALEO_RPC_URL });
await adapter.validateActiveAuthorization(auth_id, current_epoch);
// throws if status != ACTIVE or expires_epoch < current_epoch
```

The SDK package should be the `portal/` directory published as `@pnw/audit-sdk`, or extracted to a `sdk/` subdirectory of this repo before the new repo is created.

### What the New Repo Owns

- HTTP API server (Express, Fastify, or similar)
- Session management (JWT issuance, validation middleware)
- Scope enforcement middleware (injected before all data route handlers)
- Encrypted data store (write path from payroll portal, read path for auditor sessions)
- Access log storage and query
- Auditor-facing UI (later phase)

---

## Build Sequence

When ready to create the audit repo:

```
1. Extract/publish SDK from pnw_mvp_v2/portal/src/commitments/ + adapters/
   as @pnw/audit-sdk (npm workspace or separate package)

2. New repo: scaffold HTTP API server
   - POST /auth/challenge + /auth/verify (Aleo signature verification)
   - Session token issuance with embedded scope

3. New repo: scope enforcement middleware
   - Inject scope WHERE clause into all data queries
   - Re-validate on-chain auth status every N minutes

4. New repo: encrypted data store
   - Write path: payroll portal pushes encrypted records post-cycle
   - Read path: audit sessions query via enforced scope filter

5. New repo: access log
   - Append-only log for every data response

6. Integration test: full flow
   - Anchor employer + worker consent hashes
   - Mint NFT (via pnw_mvp_v2 portal)
   - Authenticate with NFT to audit portal
   - Query data — verify scope enforcement
   - Revoke NFT — verify subsequent session fails

7. UI (later phase)
```

---

## On-Chain State Machine (Reference)

Transitions in `audit_nft.aleo`:

| Transition | Who Calls | Effect |
|---|---|---|
| `mint_authorization_nft` | Auditor (or portal on behalf) | Mint NFT, write active status + expires_epoch to mappings |
| `revoke_authorization_nft` | NFT owner (auditor) | Set status = REVOKED |
| `mark_authorization_expired` | Anyone (maintenance) | Set status = EXPIRED if expires_epoch passed |
| `anchor_audit_attestation` | Portal | Record that an attestation was made under this authorization |

Public mappings readable via REST API (no transaction needed):

| Mapping | Key | Value | Meaning |
|---|---|---|---|
| `auth_anchor_height` | auth_id | block.height | NFT was minted at this height |
| `auth_status` | auth_id | u8 (1=ACTIVE, 2=REVOKED, 3=EXPIRED) | Current status |
| `auth_expires_epoch` | auth_id | u32 | Epoch when access expires |
| `auth_revoked_height` | auth_id | u32 | Block height when revoked (0 if not) |

---

## Option B Upgrade Path

When ready to eliminate portal trust for consent signing:

1. Add `EmployerConsentNFT` and `WorkerConsentNFT` record types to `audit_nft.aleo` (stubs are already commented in the Leo file)
2. Add `mint_employer_consent_nft` and `mint_worker_consent_nft` transitions
3. Update `mint_authorization_nft` to consume both consent NFTs instead of taking hashes as params
4. The audit portal's authentication flow is unchanged — it still validates `auth_status` and `auth_expires_epoch` the same way
5. The SDK's hash derivation functions are unchanged — they still produce the same hashes for verification

The public mapping layout, the NFT record structure, and the API surface are all backward compatible with Option B.

---

*Generated: 2026-03-12. Pull from this file when bootstrapping the audit_repo.*
