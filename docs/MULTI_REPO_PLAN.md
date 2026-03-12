# Multi-Repo Architecture Plan

> Version: 0.1
> Last updated: 2026-03-12
> Status: Design — no portal repos created yet

---

## The Three Repos

| Repo | Purpose | Audience |
|---|---|---|
| `pnw_mvp_v2` | Core: Leo programs, adapters, CI, manifests | Developers, operators |
| `pnw_employment_portal_v1` | Employer + Worker two-sided portal UI | Employers, Workers |
| `pnw_auditing_portal_v1` | Auditor portal UI | Auditors, Regulators |

These will be renamed to production names at mainnet. Until then, `_v1` and `_mvp_v2`
suffixes make the development stage explicit.

---

## What Each Repo Owns

### pnw_mvp_v2 (this repo) — The Foundation

**Owns:**
- All Leo programs (Layer 1 + Layer 2 NFTs)
- TypeScript adapter and router layer (`portal/src/adapters/`, `portal/src/router/`)
- Program ID manifests (`config/testnet.manifest.json`, later `mainnet.manifest.json`)
- CI/CD workflows (plan_gate, execute_gate)
- Scenario test infrastructure and validators
- Commitment utilities: TLV encoding, BLAKE3, Merkle trees, name hash derivation
- Deploy toolchain (Leo + snarkOS version pins, install scripts)

**Exports to other repos (shared contract):**
- `testnet.manifest.json` — canonical deployed program IDs; portals consume this
- TypeScript adapter interface types — `AleoCLIStep`, adapter command shapes
- Scenario JSON schema (`phaseA.scenario.v1`) — portals validate against this
- Commitment utilities — name hash, TLV encode, anchor computation

**Does NOT own:**
- Any UI
- Session management or auth
- PDF generation
- QR code generation

---

### pnw_employment_portal_v1 — Employer + Worker Interface

**Owns:**
- Employer side UI: payroll runs, employee management, credentials, compliance, YTD
- Worker side UI: paystubs, credentials, wallet activity, YTD, multi-employer view
- Shared audit consent zone: both parties consent to authorize an audit here
- QR code onboarding generation (employer creates, worker scans)
- PDF document generation: paystubs, credential certificates, audit authorization certs
- Wallet-agnostic connection interface (Shield, Puzzle, Leo wallet, key paste)
- Session state management (in-memory only — no persistent storage of credentials)

**Does NOT own:**
- Leo programs or on-chain logic
- Auditor experience
- The disclosure package delivery mechanism (see interop section)

---

### pnw_auditing_portal_v1 — Auditor Interface

**Owns:**
- Auditor wallet connection / key entry
- View of auditor's active AuditAuthorizationNFTs (decoded from their records)
- Scope display: which employer/worker relationship, which epochs, expiry block
- Disclosure request flow: auditor requests scoped data from the authorized parties
- Audit report generation (printable)
- Expiry countdown: estimates remaining time at current block production rate

**Does NOT own:**
- Issuing or revoking audit authorization (that happens in the employment portal)
- Employer or worker experience
- Any payroll execution

---

## How the Repos Interoperate

### 1. Manifest as Single Source of Truth

`pnw_mvp_v2` maintains `config/testnet.manifest.json` (and future `mainnet.manifest.json`).
Both portals consume this file to know which deployed program IDs to target.

```
pnw_mvp_v2
  └── config/testnet.manifest.json
           │
           ├── consumed by pnw_employment_portal_v1
           └── consumed by pnw_auditing_portal_v1
```

On program re-deployment or upgrade, the manifest is updated in `pnw_mvp_v2` first.
Both portals then update their pinned manifest reference. No portal ever hardcodes
a program ID — they always read from the manifest.

### 2. Shared TypeScript Interface (Adapter Types)

Both portals call the Aleo network through the same adapter interface defined in
`pnw_mvp_v2/portal/src/adapters/`. For MVP, portals copy the relevant type definitions.
Long-term, this becomes a published npm package (`@pnw/adapter-types` or similar).

**MVP approach:** copy-on-change
- Portal repos maintain a local `src/lib/pnw-adapter/` copy of the adapter types
- When `aleo_cli_adapter.ts` changes in pnw_mvp_v2, portals update their copy
- A simple version comment in each copy tracks which pnw_mvp_v2 commit it came from

**Post-MVP:** publish as versioned npm package
- `pnw_mvp_v2` publishes `@pnw/adapter-types` to npm (or GitHub Packages)
- Portals declare it as a dependency with a pinned version
- Manifest changes ship as a new version of the package

### 3. The Audit Disclosure Handoff (Key Interop Surface)

This is the most architecturally significant connection between the portals.

**The chain side:**
The `AuditAuthorizationNFT` on Aleo proves that an auditor is authorized to see
specific payroll epochs for a specific employment relationship. This is the
cryptographic grant. It lives on-chain.

**The data side:**
The actual payroll record data is private. It lives in the employer's and worker's
private Aleo records. The NFT authorizes access but does not deliver data —
delivery is off-chain.

**MVP disclosure model — Scoped View Key Share:**

```
Both parties consent in employment portal
        │
        ▼
AuditAuthorizationNFT minted on-chain (auditor's address owns it)
        │
        ▼
Employer (or worker) generates a scoped view key for the authorized epochs
  - This is a derived key that decrypts only the records in scope
  - (Full view key works for MVP; scoped derivation is a Phase 6 hardening)
        │
        ▼
Scoped view key is shared with auditor through a private channel
  - For MVP: employer copies it into the auditing portal's "receive disclosure" flow
  - The AuditAuthNFT tx ID is the handshake token both sides reference
        │
        ▼
Auditing portal: auditor pastes scoped view key + NFT tx ID
  → Portal decodes only the authorized epoch records
  → Generates audit report
  → Auditor can print or export
```

**What this means for each portal:**

`pnw_employment_portal_v1` — employer side adds a step after audit authorization:
"Share disclosure key with auditor" — generates the key and provides copy instructions.

`pnw_auditing_portal_v1` — auditor has a "Receive Disclosure" flow:
paste the NFT tx ID + scoped view key → portal verifies the NFT is active on-chain
→ decodes and displays authorized records.

**Phase 6 hardening**: Replace manual view key share with encrypted delivery — portal
encrypts scoped view key to auditor's Aleo public key, auditor decrypts with their
private key. No manual copy needed. Same NFT tx ID as handshake.

---

## Data Flow Diagram

```
                    ┌─────────────────────┐
                    │    Aleo Testnet      │
                    │  (program state,     │
                    │   private records,   │
                    │   public anchors)    │
                    └──────────┬──────────┘
                               │ read/write via snarkos
                    ┌──────────┴──────────┐
                    │    pnw_mvp_v2        │
                    │  adapters + router   │
                    │  manifest.json       │
                    └──────┬───────┬───────┘
                    exports│       │exports
               ┌───────────┘       └────────────┐
               ▼                                ▼
 ┌─────────────────────────┐   ┌────────────────────────────┐
 │  pnw_employment_        │   │  pnw_auditing_             │
 │  portal_v1              │   │  portal_v1                 │
 │                         │   │                            │
 │  Employer session       │   │  Auditor session           │
 │  Worker session         │   │  View active NFTs          │
 │  Run payroll            │   │  Receive disclosure key    │
 │  Manage employees       │   │  Decode authorized records │
 │  Issue credentials      │   │  Generate audit report     │
 │  Consent to audit       │   │  Print audit certificate   │
 │  Generate PDFs + QR     │   │                            │
 └──────────┬──────────────┘   └────────────────────────────┘
            │ scoped view key share
            │ (manual for MVP, encrypted post-MVP)
            └──────────────────────────────────────────────▶
                                                    (to auditor)
```

---

## Shared Privacy Rules (All Three Repos)

These rules apply to every repo — no exceptions.

1. **No private keys, view keys, wages, names, or addresses stored in any database.**
   All sensitive values exist in session memory only.

2. **No real addresses or credentials committed to git** in any repo. Use env vars or
   secrets. Scenario files are templates; real values are injected at runtime.

3. **No plaintext identity or salary on public chain state.** Public mappings hold
   hashes and anchors only.

4. **No cumulative spend counters** in public mappings. They leak salary via delta.

5. **PDFs generated client-side only.** Never uploaded. No third-party PDF service
   that would receive private data.

6. **Audit disclosure is scoped and time-limited.** No auditor gets a master view key.

---

## Versioning and Release Coordination

### Normal development flow
Each repo ships independently. The only hard coordination point is manifest updates.

### When pnw_mvp_v2 changes program IDs (re-deployment)
1. Update `config/testnet.manifest.json` in pnw_mvp_v2
2. Tag the commit with the manifest version (e.g., `manifest-testnet-v2`)
3. Both portals update their manifest reference in the same release window
4. Deploy both portals together before any users execute transactions

### When adapter interface changes
1. Make the change in pnw_mvp_v2
2. Update the copied types in both portal repos
3. Add a comment: `// synced from pnw_mvp_v2 @ <commit-sha>`
4. Test both portals against the updated adapter before merging

### Mainnet rename
When ready for mainnet, the three repos are renamed to production names. The
`_v1` / `_mvp_v2` suffixes are dropped. A clean mainnet manifest is generated.
The testnet manifest is preserved in an archive branch.

---

## Branch Strategy (Consistent Across All Repos)

| Branch | Purpose |
|---|---|
| `main` | Stable, tested, demo-ready |
| `work` | Active testnet execution staging |
| `claude/...` | Claude Code development sessions |
| `feature/...` | Feature development |

CI in all repos follows the same split: plan gate on PR/push to main (safe, no secrets),
execute gate on manual dispatch or push to `work` (secrets required).

---

## What to Build First

The correct order — nothing builds on something that doesn't exist yet:

```
Phase 4 (now, in pnw_mvp_v2):
  1. Verify Leo programs compile (leo build, all 3 Layer 2 programs)
  2. Deploy all programs to testnet
  3. Update manifest with real program IDs
  4. Run end-to-end happy path scenario
  5. Confirm Phase 4 exit criteria met

Phase 5 (pnw_mvp_v2):
  6. Testnet correctness validation
  7. Fix any bugs surfaced by real execution

Phase portal-MVP (new repos):
  8. Create pnw_employment_portal_v1
     - Start with worker onboarding + payroll run (minimum viable flow)
     - Then add credentials, PDF generation, QR codes
  9. Create pnw_auditing_portal_v1
     - Start with NFT view + disclosure receive flow
     - Then add report generation and printing
  10. Test end-to-end: employer onboards worker via portal →
      runs payroll → worker views paystub + prints → employer
      requests audit → worker consents → auditor views disclosure

Phase 6 (hardening):
  11. Replace manual view key share with encrypted delivery
  12. Scoped view key derivation (not full view key)
  13. Tax export modules (WA first, then other states)
  14. npm package for adapter types
  15. Mainnet manifest + rename
```

---

## Open Questions (Portal Repos — Resolve Before Building)

1. **Tech stack for portals** — React + Next.js? Svelte? Vue? Decision affects how wallet
   extensions are integrated and how client-side crypto runs.

2. **Aleo SDK for client-side decoding** — which SDK version handles view key record
   scanning in-browser? Need to verify browser WASM support for the target SDK.

3. **Scoped view key derivation** — full view key share works for MVP but is not ideal.
   Does the Aleo SDK support derivation of epoch-scoped view keys today, or is this a
   Phase 6 research item?

4. **QR code content schema** — what exactly goes in the onboarding QR payload? Needs
   a spec before the employer portal generates them and the worker portal reads them.

5. **Hosting** — where do the portals run? Vercel/Netlify for MVP? Self-hosted for
   mainnet? Affects how env vars and secrets are managed in production.
