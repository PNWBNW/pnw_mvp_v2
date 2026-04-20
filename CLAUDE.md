# CLAUDE.md — PNW MVP v2 Session Context

> Read this file first at the start of every session. It survives context compression.
> The companion file `docs/NOTES.md` has the full issue tracker and order of operations.

---

## What This Project Is

**PNW MVP v2** — Proven National Workers. A privacy-first payroll and compliance framework on Aleo using USDCx for settlement. Employers execute payroll privately; workers receive private paystub receipts; audits happen via scoped, time-limited disclosure. Nothing sensitive hits public on-chain state.

Full technical spec: `docs/ARCHITECTURE.md`

---

## Active Branch

`main` is stable. Feature work on `feature/...` or `claude/...` branches.

---

## Commit Message Rules

- **Never** append a `https://claude.ai/...` session link to commit messages.
- Commit messages should be plain descriptive text only.

---

## Toolchain Pins

| Tool | Version | Binary name | SHA256 |
|------|---------|-------------|--------|
| Leo  | 4.0.0 | `leo` | set via `vars.LEO_SHA256` repo var |
| snarkOS | v4.6.0 | `snarkos` | update needed — ConsensusVersion::V14 required for v4 deploys |
| Node | 20 | `node` | managed by `actions/setup-node` |

> **Note (2026-04-01):** Leo v4.0.0 and snarkOS v4.6.0 are required for new deployments.
> The network enforces ConsensusVersion::V14 which rejects programs compiled with Leo <4.0.
> All PNW source files are now v4 syntax. Already-deployed programs retain v3 bytecode on-chain.

Download URLs are in `.github/workflows/deploy.yml` and `.github/workflows/execute_testnet.yml`.
The snarkOS SHA256 is hardcoded in `deploy.yml` and should also be set as the `SNARKOS_SHA256` GitHub repo variable for `execute_testnet.yml`.

---

## Architecture Invariants (Never Break These)

1. **Workflows/routers are planning-only.** No CLI calls, no network execution from workflows or routers ever.
2. **Adapters are the only execution boundary.** All program IDs and transition names live in `portal/src/adapters/`.
3. **No plaintext identity, wages, or business data on public-chain state.** Public mappings hold hashes and commitment anchors only.
4. **No cumulative spend counters in public mappings.** They leak salary via delta inference.
5. **Layer 2 does not move funds.** `payroll_nfts.aleo`, `credential_nft.aleo`, `audit_nft.aleo` are commitment anchors only.
6. **No pooled custody in MVP.** Employer USDCx records are consumed → worker records emitted. No protocol treasury.

---

## Phase Status

| Phase | Status | Notes |
|-------|--------|-------|
| 0 | ✅ Done | Layer 1 programs, Layer 1 interfaces |
| 1 | ✅ Done | Portal workflow definitions (planning-only) |
| 2 | ✅ Done | Layer 2 NFT programs (payroll, credential, audit) |
| 3 | ✅ Done | Layer 2 router, type contracts, compile gate |
| 4 | ✅ Done | End-to-end private payroll on testnet (2026-04-10) |
| 5 | ✅ Done | Multi-worker (3 workers), credential_nft_v3/v4, payroll_nfts_v2, generative art |
| 6 | 🔧 In progress | Mainnet preparation, security audit, state tax expansion |

### Phase 4 Progress — COMPLETE
- [x] Adapter generates correct `snarkos developer execute` commands per `step.kind`
- [x] Leo programs compile (all Layer 2 programs)
- [x] CI split: `plan_gate` (PR-safe) + `execute_gate` (protected, manual dispatch only)
- [x] Manifest validation wired before execute mode
- [x] All active programs deployed to testnet
- [x] Leo v4.0 migration — 3 new programs deployed, all source updated (2026-04-01)
- [x] Employer + worker onboarding via portal
- [x] Agreement creation + acceptance via portal
- [x] Encrypted terms vault (AES-256-GCM + Pinata IPFS)
- [x] **Payroll execution via portal — 4-step sequential flow (2026-04-10)**
  - Step 1: `employer_agreement_v4::assert_agreement_active`
  - Step 2: `test_usdcx_stablecoin::transfer_private` (Sealance Merkle proof, depth 16)
  - Step 3: `paystub_receipts::mint_paystub_receipts` (worker + employer records)
  - Step 4: `payroll_audit_log::anchor_event`
- [x] **End-to-end testnet happy path runs** ✅ First successful run: 2026-04-10
  - Verify agreement: `at1mydsktdsr8pk7d4utzrp6n2rvtgkkpavthukyt4kpdadgyx5lg8sgljea3`
  - USDCx transfer: `at1yphn8n9zejqnnsktuev7rl9vkv8styq00rjpffa0h7rxnccssyyqdk9ltw`
  - Mint receipts: `at1w86wy80c9sgv0e2ukwlzja4r4km0vkld2tna586t9447q6pjvvrqhuvnw4`
  - Anchor event: `at1jp6mertn92hpn79uak8vdy9t4ha2t0f4fwq877uy6rmjl20g0syqdzygp3`
- [x] **Payroll anchor NFT mint** ✅ First successful mint: 2026-04-10
  - `at1d8ht598hqqjgmqfxjwvt0cf47aqafgynzjhazhtreze6j22hzcrq5992r5` (`payroll_nfts_v2::mint_cycle_nft`)
- [x] **`payroll_nfts_v2.aleo` deployed** (replaces legacy `payroll_nfts.aleo` which was stuck on `employer_agreement_v2`)
  - Deploy tx: `at14yh96gmylgched07c756y5y230wj0x8wrnk4q7r3g85etsmuzqysm3fmqq`
- [x] **On-chain payroll history scanner** — portal reconstructs run history from `EmployerPaystubReceipt` records via wallet's `requestRecords`, no localStorage dependency

### Phase 5 — COMPLETE (2026-04-12)
- [x] Multi-worker payroll — 3 workers sequential with USDCx remainder-record handling ✅
- [x] `payroll_nfts_v2.aleo` deployed (replaces v1 stuck on agreement_v2) ✅
- [x] `credential_nft_v3.aleo` deployed with 3 cross-program auth checks ✅
- [x] `credential_nft_v4.aleo` deployed with employer license check (staged) ✅
- [x] `employer_agreement_v4.aleo` upgraded with `assert_employer_authorized` ✅
- [x] Worker portal: paystub viewer, credential gallery, W-4 form, timesheet ✅
- [x] Client-side federal tax engine (IRS annualization method) ✅
- [x] Generative topographic credential art (BLAKE3-seeded, 4 palettes) ✅

### Phase 6 — Mainnet Preparation (In Progress)
- [ ] Double-pay protection — `paid_epoch` guard lost in 4-step split. Portal-side or standalone transition
- [ ] Step failure recovery — resume from step N instead of restarting
- [ ] External security audit of all Leo programs
- [ ] State tax engine expansion
- [ ] Mobile responsive polish

---

## Known Bugs — Current Status

See `docs/NOTES.md` for full details and fix priority. Summary:

### CRITICAL (block compilation / testnet execution)
| # | Bug | File | Status |
|---|-----|------|--------|
| 1 | Wrong CLI tool: `aleo execute` → `snarkos developer execute` | `aleo_cli_adapter.ts` | ✅ Fixed |
| 2 | Wrong arg encoding: `0xhex` → `[ 1u8, 2u8, ... ]` array literal | `aleo_cli_adapter.ts` | ✅ Fixed |
| 1b | Fixed flags to `--endpoint` + `--broadcast` (no URL arg) | `aleo_cli_adapter.ts` | ✅ Fixed |
| 3 | All mapping ops in `function` bodies — must be `async function` (finalize) | All Layer 2 Leo programs | ✅ Fixed |
| 4 | `caller.private` in assertions — should be just `caller` | `payroll_nfts`, `credential_nft`, `audit_nft` | ✅ Fixed |
| 4b | `block.height` used in transition circuit — only valid in finalize | `payroll_nfts.aleo` L171, L190 | ✅ Fixed |
| 4c | `consume nft;` — not valid Leo v3.x syntax | `payroll_nfts`, `credential_nft`, `audit_nft` | ✅ Fixed |
| 4d | `_nonce: group.public` explicitly declared + `group::GEN` set — VM-managed, not user-set in Leo | All Layer 2 records | ✅ Fixed |

### HIGH
| # | Bug | File | Status |
|---|-----|------|--------|
| 5 | Programs not deployed — manifest IDs are file names, not verified testnet IDs | `testnet.manifest.json` | ✅ All L2 programs deployed (payroll_nfts, credential_nft, audit_nft + deps) — L1 pending |
| 6 | `SNARKOS_ENDPOINT` required by env script but actual commands use `RPC_URL`/`PHASE4_SUBMIT_ENDPOINT` | `require_phase4_execute_env.sh` | ✅ Fixed — consolidated to single `ENDPOINT` var |
| 7 | Execute gate fires on every push to `main` (not just manual dispatch) | `execute_testnet.yml` | ✅ Fixed |
| 8 | Receipt verification tries JSON-RPC first; Aleo uses REST — should try REST first | `verify_phase4_receipts.py` | ✅ Fixed |
| 9 | Step traces are hardcoded placeholders, not real execution output | `run_phase4_execute_scenario.sh` | ⚠️ Scaffold |

### MEDIUM
| # | Bug | File | Status |
|---|-----|------|--------|
| 10 | Valid-length Aleo employer addresses in onboarding/payroll testnet scenarios | `min_spend.onboarding.json`, `min_spend.payroll.json` | ✅ Fixed |
| 11 | All-placeholder hashes (`0x1111...`) in sample mint args | `onboarding_mint_args.sample.json` | ⚠️ Sample file |
| 12 | Layer 2 `program.json` files may be incomplete (missing `program.toml` for Leo build) | `src/layer2/*/` | ✅ Verified — all 3 compile and deploy successfully |
| 13 | Bundle SHA check fails if artifacts re-generated in same run (SHA changes) | `verify_phase4_execute_artifacts.py` | ⚠️ Minor |

---

## File Map (What Does What)

### Layer 2 Leo Programs (on-chain)
- `src/layer2/payroll_nfts_v2.aleo/main.leo` — payroll cycle NFT (imports employer_agreement_v4)
- `src/layer2/credential_nft_v3.aleo/main.leo` — dual-record credential mint + 3 cross-program auth checks
- `src/layer2/credential_nft_v4.aleo/main.leo` — adds employer license verification (staged)
- `src/layer2/audit_nft.aleo/main.leo` — audit authorization NFT + expiry + attestation anchoring
- `src/layer2/payroll_nfts.aleo/main.leo` — LEGACY (v1, superseded by v2)
- `src/layer2/credential_nft.aleo/main.leo` — LEGACY (v1, superseded by v3)

### Portal TypeScript (off-chain)
- `portal/src/adapters/aleo_cli_adapter.ts` — **THE execution boundary**; builds `snarkos` commands
- `portal/src/adapters/layer2_adapter.ts` — program/transition name mapping (no execution)
- `portal/src/adapters/layer1_adapter.ts` — Layer 1 endpoint mapping
- `portal/src/router/layer2_router.ts` — Layer 2 call plan builder (planning only)
- `portal/src/router/layer1_router.ts` — Layer 1 call plan builder (planning only)
- `portal/src/workflows/` — intent definitions (planning only, never execute)
- `portal/src/commitments/` — TLV encoding, BLAKE3 hashing, Merkle trees
- `portal/src/config/env.ts` — env var loading (`PORTAL_PRIVATE_KEY`, `ALEO_RPC_URL`, etc.)
- `portal/src/config/programs.ts` — program registry
- `portal/tests/phase4_adapter.test.ts` — adapter codec tests

### CI / Scripts
- `.github/workflows/deploy.yml` — `plan_gate`: runs on PR + push to main, no secrets
- `.github/workflows/execute_testnet.yml` — `execute_gate`: manual dispatch + `work` branch, uses secrets
- `scripts/require_phase4_execute_env.sh` — validates env vars before execute runs
- `scripts/run_phase4_execute_scenario.sh` — runs a scenario and emits artifact bundle
- `scripts/verify_phase4_receipts.py` — verifies tx IDs against RPC
- `scripts/verify_phase4_execute_artifacts.py` — checks bundle SHA integrity
- `scripts/run_phase4_adapter_tests.sh` — runs adapter codec tests

### Config
- `config/testnet.manifest.json` — canonical program ID registry (must match deployed IDs)
- `config/scenarios/testnet/min_spend.payroll.json` — payroll test scenario
- `config/scenarios/testnet/min_spend.onboarding.json` — onboarding test scenario (**has invalid employer address**)
- `config/scenarios/testnet/onboarding_mint_args.sample.json` — sample args (**all placeholders**)

### Reference Docs (keep, don't merge)
- `docs/ARCHITECTURE.md` — full technical spec
- `docs/operations/PHASE4_CLI_SETUP.md` — operator setup: install Leo/snarkOS, run happy path
- `docs/operations/PHASE4_TESTNET_GAMEPLAN.md` — PR sequence A→D and Phase 5/6 plan

---

## Correct `snarkos developer execute` Syntax

Per project docs (`docs/operations/PHASE4_CLI_SETUP.md`):

```bash
snarkos developer execute \
  <program_id> <function_name> <input1> <input2> ... \
  --private-key "<KEY>" \
  --endpoint "<BASE_URL>" \
  --network <N> \
  --broadcast
```

Key points:
- Flag is `--endpoint`, NOT `--query`
- `--endpoint` takes a **base URL** only (e.g. `https://api.explorer.provable.com/v2`) — snarkOS appends the network path
- `--network` selects the network: `0` = mainnet, `1` = testnet
- `--broadcast` is a **standalone flag** — no URL argument

---

## Validation Commands

```bash
# TypeScript compile gates
npx --yes --package typescript tsc -p portal/tsconfig.phase3.json
npx --yes --package typescript tsc -p portal/tsconfig.phase4.json

# Adapter codec tests
scripts/run_phase4_adapter_tests.sh

# Manifest validation
python3 scripts/validate_testnet_manifest.py config/testnet.manifest.json

# Scenario validation
python3 scripts/validate_phaseA_scenario.py config/scenarios/testnet/min_spend.payroll.json
python3 scripts/validate_phaseA_scenario.py config/scenarios/testnet/min_spend.onboarding.json

# CLI version check
scripts/verify_provable_cli.sh

# Execute env check (requires ENDPOINT set):
# ENDPOINT=https://api.explorer.provable.com/v2 ... scripts/require_phase4_execute_env.sh
```

> **Canonical endpoint** (Provable Explorer v2, base URL):
> `ENDPOINT=https://api.explorer.provable.com/v2`
> snarkOS CLI appends the network path via `--network 1` (testnet) or `--network 0` (mainnet).
> REST API queries use the full path: `https://api.explorer.provable.com/v2/testnet/...`
> Copy `.env.example` to `.env` and fill in credentials. Never commit `.env`.
>
> **For `leo deploy` / `leo execute`:** Leo CLI reads `PRIVATE_KEY` (not `ALEO_PRIVATE_KEY`).
> Your `.env` must contain `PRIVATE_KEY=APrivateKey1...` for deploy to work.
> `ALEO_PRIVATE_KEY` is used only by the portal TypeScript adapter (`snarkos developer execute`).

---

## Decisions (Durable)

- `2026-02-27` — Adapters are the only execution boundary
- `2026-03-01` — Canonical Phase A scenario contract as shared input surface for test + app dispatch
- `2026-03-02` — Accept raw-name inputs with deterministic local hash derivation in scenarios
- `2026-03-02` — No cumulative public spend counters (salary leakage risk); hash-only audit anchors only
- `2026-03-09` — Consolidate all working context into `CLAUDE.md` + `docs/NOTES.md` to survive compression
- `2026-04-10` — Move ARCHITECTURE/DIRECTORY/NOTES into `docs/`; delete stale `employer_portal/` mirror and v1 program READMEs superseded by v2/v4 versions
