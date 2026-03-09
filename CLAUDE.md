# CLAUDE.md — PNW MVP v2 Session Context

> Read this file first at the start of every session. It survives context compression.
> The companion file `NOTES.md` has the full issue tracker and order of operations.

---

## What This Project Is

**PNW MVP v2** — Proven National Workers. A privacy-first payroll and compliance framework on Aleo using USDCx for settlement. Employers execute payroll privately; workers receive private paystub receipts; audits happen via scoped, time-limited disclosure. Nothing sensitive hits public on-chain state.

Full technical spec: `ARCHITECTURE.md`

---

## Active Branch

`claude/project-review-Bjwsc` — all development goes here.

---

## Toolchain Pins

| Tool | Version | Binary name |
|------|---------|-------------|
| Leo  | 3.4.0 | `leo` |
| snarkOS | v4.4.0 | `snarkos` |
| Node | 20 | `node` |

Download URLs are in `.github/workflows/deploy.yml` and `.github/workflows/execute_testnet.yml`.

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
| 4 | 🔧 In progress | Adapter execution boundary |
| 5 | ⏳ Pending | Testnet correctness validation |
| 6 | ⏳ Pending | Hardening and release |

### Phase 4 Exit Criteria
- [ ] Adapter generates correct `snarkos developer execute` commands per `step.kind`
- [ ] Leo programs compile (all 3 Layer 2 programs)
- [ ] One reproducible end-to-end testnet happy path runs
- [x] CI split: `plan_gate` (PR-safe) + `execute_gate` (protected, manual dispatch only)
- [x] Manifest validation wired before execute mode

---

## Known Bugs — Current Status

See `NOTES.md` for full details and fix priority. Summary:

### CRITICAL (block compilation / testnet execution)
| # | Bug | File | Status |
|---|-----|------|--------|
| 1 | Wrong CLI tool: `aleo execute` → `snarkos developer execute` | `aleo_cli_adapter.ts` | ✅ Fixed |
| 2 | Wrong arg encoding: `0xhex` → `[ 1u8, 2u8, ... ]` array literal | `aleo_cli_adapter.ts` | ✅ Fixed |
| 1b | NEW: Fixed #1 used wrong flags: `--query`/`--broadcast <url>` should be `--endpoint`/`--broadcast` (flag only) | `aleo_cli_adapter.ts` | ❌ Needs fix |
| 3 | All mapping ops in `function` bodies — must be `async function` (finalize) | All Layer 2 Leo programs | ❌ Needs fix |
| 4 | `caller.private` in assertions — should be just `caller` | `payroll_nfts`, `credential_nft`, `audit_nft` | ❌ Needs fix |
| 4b | `block.height` used in transition circuit — only valid in finalize | `payroll_nfts.aleo` L171, L190 | ❌ Needs fix |
| 4c | `consume nft;` — not valid Leo v3.x syntax | `payroll_nfts`, `credential_nft`, `audit_nft` | ❌ Needs fix |
| 4d | `_nonce: group.public` explicitly declared + `group::rand().public` set — VM-managed, not user-set in Leo | All Layer 2 records | ❌ Needs verify |

### HIGH
| # | Bug | File | Status |
|---|-----|------|--------|
| 5 | Programs not deployed — manifest IDs are file names, not verified testnet IDs | `testnet.manifest.json` | ⚠️ Pre-deploy |
| 6 | `SNARKOS_ENDPOINT` required by env script but actual commands use `RPC_URL`/`PHASE4_SUBMIT_ENDPOINT` | `require_phase4_execute_env.sh` | ❌ Needs fix |
| 7 | Execute gate fires on every push to `main` (not just manual dispatch) | `execute_testnet.yml` | ❌ Needs fix |
| 8 | Receipt verification tries JSON-RPC first; Aleo uses REST — should try REST first | `verify_phase4_receipts.py` | ❌ Needs fix |
| 9 | Step traces are hardcoded placeholders, not real execution output | `run_phase4_execute_scenario.sh` | ⚠️ Scaffold |

### MEDIUM
| # | Bug | File | Status |
|---|-----|------|--------|
| 10 | Invalid Aleo address (42 chars, needs 63): employer address in onboarding scenario | `min_spend.onboarding.json` | ❌ Needs fix |
| 11 | All-placeholder hashes (`0x1111...`) in sample mint args | `onboarding_mint_args.sample.json` | ⚠️ Sample file |
| 12 | Layer 2 `program.json` files may be incomplete (missing `program.toml` for Leo build) | `src/layer2/*/` | ❌ Needs verify |
| 13 | Bundle SHA check fails if artifacts re-generated in same run (SHA changes) | `verify_phase4_execute_artifacts.py` | ⚠️ Minor |

---

## File Map (What Does What)

### Layer 2 Leo Programs (on-chain)
- `src/layer2/payroll_nfts.aleo/main.leo` — payroll cycle/quarter/YTD/EOY NFT mint + revoke + supersede
- `src/layer2/credential_nft.aleo/main.leo` — credential NFT mint + revoke + scope anchoring
- `src/layer2/audit_nft.aleo/main.leo` — audit authorization NFT + expiry + attestation anchoring

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
- `ARCHITECTURE.md` — full technical spec
- `docs/operations/PHASE4_CLI_SETUP.md` — operator setup: install Leo/snarkOS, run happy path
- `docs/operations/PHASE4_TESTNET_GAMEPLAN.md` — PR sequence A→D and Phase 5/6 plan

---

## Correct `snarkos developer execute` Syntax

Per project docs (`docs/operations/PHASE4_CLI_SETUP.md`):

```bash
snarkos developer execute \
  <program_id> <function_name> <input1> <input2> ... \
  --private-key "<KEY>" \
  --endpoint "<NODE_URL_WITH_NETWORK_PATH>" \
  --broadcast
```

Key points:
- Flag is `--endpoint`, NOT `--query`
- `--broadcast` is a **standalone flag** — no URL argument
- The network path goes in `--endpoint` (e.g. `https://api.explorer.provable.com/v2/testnet`)

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
```

---

## Decisions (Durable)

- `2026-02-27` — Adapters are the only execution boundary
- `2026-03-01` — Canonical Phase A scenario contract as shared input surface for test + app dispatch
- `2026-03-02` — Accept raw-name inputs with deterministic local hash derivation in scenarios
- `2026-03-02` — No cumulative public spend counters (salary leakage risk); hash-only audit anchors only
- `2026-03-09` — Consolidate all working context into `CLAUDE.md` + `NOTES.md` to survive compression
