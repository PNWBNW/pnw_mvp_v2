# PNW MVP v2
**Proven National Workers — Privacy-First Payroll and Compliance on Aleo**

---

## What This Is

PNW MVP v2 is a privacy-first payroll and compliance framework built natively on **Aleo**, using **USDCx** for stable-value settlement. It enables employers to execute payroll privately, workers to receive cryptographically verifiable paystub receipts, and auditors to verify compliance — all without exposing identities, wages, or business data on public chain state.

**The core promise:** USDCx proves the funds are clean. PNW proves the payroll relationship is legitimate. Neither requires the other to expose sensitive data to do its job.

This repository (`pnw_mvp_v2`) is the **foundation layer** — Leo programs, TypeScript adapters, CI/CD infrastructure, and manifests. The portal applications are built in separate repos that consume from this one.

---

## Architecture at a Glance

```
┌──────────────────────────────────────────────────────────────────┐
│                         Aleo Testnet                             │
│                                                                  │
│  Layer 1 (Canonical Logic)          Layer 2 (NFT Anchors)        │
│  ├─ pnw_name_registry               ├─ payroll_nfts              │
│  ├─ employer_license_registry       ├─ credential_nft            │
│  ├─ employer_profiles               └─ audit_nft                 │
│  ├─ worker_profiles                                              │
│  ├─ employer_agreement                                           │
│  ├─ payroll_core  ← USDCx settlement                             │      ← this repo
│  ├─ paystub_receipts                                             │
│  ├─ payroll_audit_log                                            │
│  └─ pnw_router                                                   │
└─────────────────────────────┬────────────────────────────────────┘
                              │ snarkos developer execute
                    ┌─────────┴─────────┐
                    │   pnw_mvp_v2      │     ← this repo
                    │  adapters + CI    │
                    └────────┬──────────┘
               exports manifest + adapter types
               ┌─────────────┴──────────────┐
               ▼                            ▼
  pnw_employment_portal_v1     pnw_auditing_portal_v1      ← future repos
  (employer + worker UI)       (auditor UI)
```

### Layer 1 — Canonical On-Chain Logic

Nine Leo programs forming the source of truth for all payroll and compliance state transitions. They handle identity commitments, employment agreements, USDCx payroll execution, private receipt issuance, and hash-only audit anchoring. They never expose identities, wages, or aggregated statistics.

| Program | Purpose |
|---|---|
| `pnw_name_registry.aleo` | Employer/worker name hash registry with suffix codes |
| `employer_license_registry.aleo` | License eligibility validation |
| `employer_profiles.aleo` | Employer profile commitment anchoring |
| `worker_profiles.aleo` | Worker profile commitment anchoring |
| `employer_agreement_v2.aleo` | Employment agreement creation, amendment, termination |
| `payroll_core.aleo` | USDCx payroll execution — consumes employer records, emits worker records |
| `paystub_receipts.aleo` | Private paystub receipt issuance |
| `payroll_audit_log.aleo` | Hash-only audit event anchoring |
| `pnw_router.aleo` | Multi-program orchestration entry point |

### Layer 2 — Commitment NFT Anchors

Three Leo programs providing on-chain commitment anchors for reporting and audit. They are **not** a ledger or custody mechanism — they anchor hashes only.

| Program | Purpose |
|---|---|
| `payroll_nfts.aleo` | Payroll cycle, quarter, YTD, and EOY commitment NFTs |
| `credential_nft.aleo` | Employment credential authorization NFTs |
| `audit_nft.aleo` | Audit authorization NFTs with block-height expiry |

### Privacy Rules (Non-Negotiable)

- No plaintext identities, wages, or addresses on public chain state
- Public mappings hold hashes and commitment anchors only
- No cumulative spend counters (salary leakage via delta inference)
- Layer 2 NFTs are commitment anchors — they never move funds
- No pooled custody — employer USDCx records are consumed → worker records emitted directly

---

## Three-Repo Structure

This project is built across three repositories designed to stay independent with clean interoperability contracts.

| Repo | Contents | Status |
|---|---|---|
| `pnw_mvp_v2` | Leo programs, adapters, CI, manifests | Active — this repo |
| `pnw_employment_portal_v1` | Employer + Worker two-sided portal | Planned — post Phase 5 |
| `pnw_auditing_portal_v1` | Auditor portal | Planned — post Phase 5 |

The portal repos consume `config/testnet.manifest.json` from this repo as their canonical program ID source. No portal ever hardcodes a program ID. See [`docs/MULTI_REPO_PLAN.md`](./docs/MULTI_REPO_PLAN.md) for the full interoperability plan.

---

## Phase Status

| Phase | Description | Status |
|---|---|---|
| 0 | Layer 1 Leo programs + interfaces | ✅ Done |
| 1 | Portal workflow definitions (planning layer) | ✅ Done |
| 2 | Layer 2 NFT programs | ✅ Done |
| 3 | Layer 2 router, type contracts, compile gate | ✅ Done |
| 4 | Adapter execution boundary + CI split | 🔧 In progress |
| 5 | Testnet correctness validation | ⏳ Pending |
| 6 | Hardening, tax exports, release | ⏳ Pending |

**Phase 4 exit criteria:**
- [x] Adapter generates correct `snarkos developer execute` commands per step kind
- [ ] Leo programs compile (`leo build`) — fixes applied, needs Codespace verification
- [ ] One reproducible end-to-end testnet happy path run
- [x] CI split: `plan_gate` (PR-safe, no secrets) + `execute_gate` (protected, manual dispatch)
- [x] Manifest validation wired before execute mode

---

## Repository Navigation

| Where to start | File |
|---|---|
| Session context + bug list + phase status | [`CLAUDE.md`](./CLAUDE.md) |
| Full issue tracker + fix order | [`NOTES.md`](./NOTES.md) |
| Technical architecture spec | [`ARCHITECTURE.md`](./ARCHITECTURE.md) |
| Complete file directory | [`DIRECTORY.md`](./DIRECTORY.md) |
| Employment portal product spec | [`docs/EMPLOYMENT_PORTAL.md`](./docs/EMPLOYMENT_PORTAL.md) |
| Three-repo interoperability plan | [`docs/MULTI_REPO_PLAN.md`](./docs/MULTI_REPO_PLAN.md) |
| Phase 4 CLI setup (local + Codespace) | [`docs/operations/PHASE4_CLI_SETUP.md`](./docs/operations/PHASE4_CLI_SETUP.md) |
| Testnet deployment gameplan | [`docs/operations/PHASE4_TESTNET_GAMEPLAN.md`](./docs/operations/PHASE4_TESTNET_GAMEPLAN.md) |

---

## Toolchain

| Tool | Pinned Version |
|---|---|
| Leo | 3.5.0 |
| snarkOS | v4.5.5 |
| Node.js | 20 |

---

## CI / CD

**`deploy.yml` (plan gate)** — runs on every PR and push to `main`. No secrets required. Typechecks the TypeScript adapter and router layers, runs codec tests, validates the testnet manifest schema, and enforces Layer 1 public-state leakage guards.

**`execute_testnet.yml` (execute gate)** — manual dispatch only (or push to `work` branch). Requires secrets. Runs a full testnet scenario against real deployed programs with broadcast enabled and receipt verification required.

---

## USDCx Note

USDCx is treated as a native Aleo asset (`test_usdcx_stablecoin.aleo` on testnet). The protocol never wraps, mirrors, or custodies USDCx — employer records are consumed and worker records are emitted directly in the same payroll transaction. Token program ID is configurable via `config/testnet.manifest.json`.

---

## License

**PROPRIETARY.** No rights granted for reuse, redistribution, or deployment without explicit written authorization.
