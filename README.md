# PNW MVP v2

**Proven National Workers — Privacy-First Payroll and Compliance on Aleo**

---

## What This Is

PNW MVP v2 is the on-chain foundation for a privacy-first payroll, credential, and employment infrastructure framework built on Aleo. It contains all Leo programs, TypeScript adapters, deployment manifests, and CI/CD infrastructure. The portal applications that consume this layer live in [`pnw_employment_portal_v1`](https://github.com/PNWBNW/pnw_employment_portal_v1). The master project repo is [`pnw`](https://github.com/PNWBNW/pnw).

**The core promise:** USDCx proves the funds are clean. PNW proves the payroll relationship is legitimate. Neither requires the other to expose sensitive data.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                         Aleo Testnet                             │
│                                                                  │
│  Layer 1 (Canonical Logic)          Layer 2 (NFT Anchors)        │
│  ├─ pnw_name_registry_v2            ├─ payroll_nfts_v2           │
│  ├─ pnw_name_registrar_v5          ├─ credential_nft_v3         │
│  ├─ employer_license_registry       ├─ credential_nft_v4 (staged)│
│  ├─ employer_agreement_v4           └─ audit_nft                 │
│  ├─ payroll_core_v2  ← USDCx settlement                         │
│  ├─ paystub_receipts                                             │
│  ├─ payroll_audit_log                                            │
│  └─ pnw_router_v4                                                │
└─────────────────────────────┬────────────────────────────────────┘
                              │ wallet executeTransaction
                    ┌─────────┴─────────┐
                    │  Portal adapter   │
                    │  layer (synced    │
                    │  from this repo)  │
                    └────────┬──────────┘
                             ▼
                pnw_employment_portal_v1
                (employer + worker dApp)
```

### Layer 1 — Canonical On-Chain Logic

Leo programs forming the source of truth for all payroll and compliance state transitions.

| Program | Purpose | Constructor |
|---|---|---|
| `pnw_name_registry_v2.aleo` | Name hash registry with ownership assertions + reverse resolver | @admin |
| `pnw_name_registrar_v5.aleo` | Registration orchestrator (USDCx payment, plaintext storage) | @admin |
| `employer_license_registry.aleo` | License eligibility gate (AUTHORITY-controlled) | @noupgrade |
| `employer_profiles_v2.aleo` | Employer profile commitment anchoring (license-gated, suffix-bound) | @admin |
| `pnw_worker_profiles_v2.aleo` | Worker profile commitment anchoring with hash-only anchor index | @admin |
| `employer_agreement_v4.aleo` | Agreement lifecycle (offer → accept → pause/terminate/resume) + `assert_employer_authorized` for credential auth | @admin |
| `payroll_core_v2.aleo` | Monolithic payroll execution — agreement verification, USDCx transfer, receipt mint, audit anchor in one ZK proof. `paid_epoch` double-pay guard. | @admin |
| `paystub_receipts.aleo` | Dual private receipt issuance (WorkerPaystubReceipt + EmployerPaystubReceipt) | @admin |
| `payroll_audit_log.aleo` | Hash-only audit event anchoring with block-height timestamps | @noupgrade |
| `pnw_router_v4.aleo` | Multi-program orchestration entry point | @admin |

### Layer 2 — Commitment NFT Anchors

On-chain commitment anchors for reporting, credentials, and audit. They anchor hashes only — they never move funds.

| Program | Purpose |
|---|---|
| `payroll_nfts_v2.aleo` | Payroll cycle NFT batch anchor (imports employer_agreement_v4) |
| `credential_nft_v3.aleo` | Dual-record credential mint with 3 cross-program authorization checks (employer name ownership, worker name ownership, parties_key commitment + ACTIVE status). Unauthorized mints revert on-chain. |
| `credential_nft_v4.aleo` | Adds employer license verification to v3's checks. Staged for post-buildathon activation. |
| `audit_nft.aleo` | Dual-consent audit authorization with block-height expiry + attestation anchoring |

### Privacy Rules (Non-Negotiable)

- No plaintext identities, wages, or addresses on public chain state
- Public mappings hold hashes and commitment anchors only
- No cumulative spend counters (salary leakage via delta inference)
- Layer 2 NFTs are commitment anchors — they never move funds
- No pooled custody — employer USDCx records consumed → worker records emitted directly

---

## How The Repos Connect

This repo exports to the portal:

| Export | Consumed by portal at |
|---|---|
| `config/testnet.manifest.json` | `src/config/programs.ts` — canonical program ID registry |
| `portal/src/adapters/*.ts` | `src/lib/pnw-adapter/*.ts` — execution boundary, program/transition mapping |
| `portal/src/router/*.ts` | `src/lib/pnw-adapter/layer1_router.ts`, `layer2_router.ts` — call plan types |
| `portal/src/commitments/*.ts` | `src/lib/pnw-adapter/canonical_encoder.ts`, `hash.ts`, `merkle.ts` — deterministic hashing |

The portal copies these files with sync headers. No portal ever hardcodes a program ID — all IDs flow from `testnet.manifest.json`. See [`docs/MULTI_REPO_PLAN.md`](./docs/MULTI_REPO_PLAN.md) for the full interoperability plan.

---

## Phase Status

| Phase | Description | Status |
|---|---|---|
| 0 | Layer 1 Leo programs + interfaces | ✅ Done |
| 1 | Portal workflow definitions (planning layer) | ✅ Done |
| 2 | Layer 2 NFT programs | ✅ Done |
| 3 | Layer 2 router, type contracts, compile gate | ✅ Done |
| 4 | End-to-end testnet execution (E10) | ✅ Done (2026-04-10) |
| 5 | Hardening: multi-worker, credentials, paystubs | ✅ Done (2026-04-12) |
| 6 | Mainnet preparation | ⏳ Pending |

### Key Milestones

- **E10 (2026-04-10):** First end-to-end private payroll + anchor on testnet — 5 transactions confirmed
- **E11 (2026-04-11):** Multi-worker payroll (3 workers), USDCx double-spend fix, filling progress bar
- **Credentials (2026-04-12):** `credential_nft_v3` deployed with hard on-chain authorization, dual-record mint, generative topographic art. `employer_agreement_v4` upgraded with `assert_employer_authorized`.
- **`credential_nft_v4` (2026-04-12):** Deployed with additional employer license check, staged for post-buildathon
- **Worker Features (2026-04-15):** Client-side federal tax engine, W-4 form with parties_key encryption, timesheet, paystub viewer, pay rates in agreements
- **Inline W-4 (2026-04-20):** Removed PDF upload friction — W-4 fillable directly in portal for zero-friction mobile experience

---

## Toolchain

| Tool | Pinned Version |
|---|---|
| Leo | 4.0.0 |
| snarkOS | v4.6.0 |
| Node.js | 20 |

> Leo v4.0.0 and snarkOS v4.6.0 are required. The network enforces ConsensusVersion::V14 which rejects programs compiled with Leo <4.0.

---

## USDCx Note

USDCx is treated as a native Aleo asset (`test_usdcx_stablecoin.aleo` on testnet). The protocol never wraps, mirrors, or custodies USDCx — employer records are consumed and worker records are emitted directly in the same payroll transition. Token program ID is configurable via `config/testnet.manifest.json`.

---

## Documentation

| Document | Purpose |
|---|---|
| [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) | Deep technical architecture and trust model |
| [`docs/NOTES.md`](./docs/NOTES.md) | Issue tracker and fix priority |
| [`docs/DIRECTORY.md`](./docs/DIRECTORY.md) | Repo file map with per-file descriptions |
| [`docs/MULTI_REPO_PLAN.md`](./docs/MULTI_REPO_PLAN.md) | Three-repo interoperability plan |
| [`docs/IDEA_BOARD.md`](./docs/IDEA_BOARD.md) | Payroll speedup brainstorming |
| [`docs/operations/PHASE4_CLI_SETUP.md`](./docs/operations/PHASE4_CLI_SETUP.md) | Leo v4 / snarkOS v4.6 setup |
| [`docs/operations/PHASE4_TESTNET_GAMEPLAN.md`](./docs/operations/PHASE4_TESTNET_GAMEPLAN.md) | Deployment roadmap |

---

## License

Proprietary — PNW Smart Contract License v1.7. See the master repo [`LICENSE.md`](https://github.com/PNWBNW/pnw/blob/main/LICENSE.md).
