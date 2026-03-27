# NOTES.md — PNW MVP v2 Active Issue Tracker

> Living document. Update this in every PR that touches roadmap, execution, or bug status.
> See `CLAUDE.md` for project overview, architecture invariants, and file map.

---

## Fix Priority Order

```
1. Leo programs: async transition + caller fix + consume fix (Issues #3, #4, #4b, #4c, #4d)
2. Adapter CLI flags fix (Issue #1b)
3. Onboarding scenario invalid address (Issue #10)
4. Execute gate on-push trigger removed (Issue #7)
5. SNARKOS_ENDPOINT alignment (Issue #6) ✅ FIXED
6. Receipt verification order (Issue #8)
7. Deploy programs, update manifest with real IDs (Issue #5)
8. Step traces real execution wiring (Issue #9)
```

---

## Issue Tracker

### #1 — FIXED: Wrong CLI tool
**File:** `portal/src/adapters/aleo_cli_adapter.ts`
**Was:** `aleo execute <program>/<transition> <args> --network <network>`
**Fixed:** `snarkos developer execute <program> <transition> <args> --private-key ... --endpoint ... --broadcast`
**Status:** ✅ Fixed in commit `e281083` (branch `claude/project-review-Bjwsc`)

---

### #1b — FIXED: snarkos flags corrected
**File:** `portal/src/adapters/aleo_cli_adapter.ts` — `buildCliCommand`, lines ~389–404
**Problem:** Fix #1 used `--query <url>` and `--broadcast <url>` (with URL argument).
Per project docs (`docs/operations/PHASE4_CLI_SETUP.md` line 82 and line 121–124):
- Flag is `--endpoint`, NOT `--query`
- `--broadcast` takes NO URL argument — it's a standalone flag
- The node URL (including `/testnet` path segment) goes in `--endpoint` only

**Current wrong output:**
```
snarkos developer execute 'payroll_nfts.aleo' 'mint_cycle_nft' <args>
  --private-key '<KEY>' --query '<NODE_URL>' --broadcast '<NODE_URL>/testnet/transaction/broadcast'
```

**Correct output:**
```
snarkos developer execute 'payroll_nfts.aleo' 'mint_cycle_nft' <args>
  --private-key '<KEY>' --endpoint '<NODE_URL>' --broadcast
```

**Fix:** In `buildCliCommand`, change `"--query"` → `"--endpoint"` and remove `broadcast_url` / `shellQuote(broadcast_url)` → just `"--broadcast"`.
Also remove `SNARKOS_NETWORK_FLAG` and `broadcast_url` construction — not needed.

**Acceptance check:** Generated command string contains `--endpoint` and ends with `--broadcast` (no URL after it).

---

### #2 — FIXED: Wrong arg encoding
**File:** `portal/src/adapters/aleo_cli_adapter.ts` — `encodeBytes32`
**Was:** `0xdeadbeef...` (hex string)
**Fixed:** `[ 222u8, 173u8, 190u8, ... ]` (Leo `[u8; 32]` array literal)
**Status:** ✅ Fixed in commit `e281083`

---

### #3 — Leo mapping ops require `async function` (finalize)
**Files:** All 3 Layer 2 Leo programs
**Problem:** In Leo v2+, `Mapping::get_or_use` and `Mapping::set` can ONLY appear in `async function` (finalize) blocks. Regular `function` and `transition` bodies cannot do mapping operations. The current code puts all mapping ops in regular `function` bodies called directly from `transition` bodies.

**Affected functions that need to become finalize logic:**

`payroll_nfts.aleo`:
- `function anchor_unique(nft_id)` — reads + writes 3 mappings → move to finalize
- `function mint_common(...)` — calls `anchor_unique` + cross-program calls → restructure
- `transition revoke_nft` — reads `nft_status` + writes it → needs `async transition` + finalize
- `transition mark_superseded` — reads + writes mappings → needs `async transition` + finalize
- `transition assert_nft_exists` — reads mapping → needs `async transition` + finalize
- `transition get_anchor_height` — reads mapping → needs `async transition` + finalize
- `transition get_status` — reads mapping → needs `async transition` + finalize
- `transition get_superseded_by` — reads mapping → needs `async transition` + finalize
- All 4 mint transitions — calls `mint_common` which calls `anchor_unique` → needs `async transition` + finalize

`credential_nft.aleo`:
- `function anchor_credential_once(credential_id)` → move to finalize
- `function anchor_scope_if_first(scope_hash)` → move to finalize
- All transitions that call these → `async transition`

`audit_nft.aleo`:
- `function anchor_auth_once(auth_id, expires_epoch)` → move to finalize
- `function assert_auth_active_and_not_expired(auth_id, current_epoch)` → move to finalize
- `function anchor_attestation_once(auth_id, attestation_hash)` → move to finalize
- All transitions that call these → `async transition`

**Pattern to apply:**
```leo
// Before (broken):
function anchor_unique(nft_id: [u8; 32]) {
    let existing: u32 = Mapping::get_or_use(nft_anchor_height, nft_id, 0u32);
    Mapping::set(nft_anchor_height, nft_id, block.height);
}
transition mint_cycle_nft(...) -> PayrollNFT {
    anchor_unique(nft_id);
    return PayrollNFT { ... };
}

// After (correct):
async transition mint_cycle_nft(
    nft_id: [u8; 32],
    ...
) -> (PayrollNFT, Future) {
    // ZK circuit: validate inputs, build record
    assert(period_start != 0u32);
    // ... other asserts
    let nft: PayrollNFT = PayrollNFT {
        nft_id: nft_id,
        owner: caller,   // NOT caller.private in literals either — see #4
        ...
    };
    // Cross-program async calls
    let f1: Future = employer_agreement_v2.aleo/assert_agreement_active(agreement_id);
    let f2: Future = payroll_audit_log.aleo/assert_event_anchored(inputs_hash);
    return (nft, finalize_mint_cycle_nft(f1, f2, nft_id));
}

async function finalize_mint_cycle_nft(f1: Future, f2: Future, nft_id: [u8; 32]) {
    await(f1);
    await(f2);
    // anchor_unique logic here:
    let existing: u32 = Mapping::get_or_use(nft_anchor_height, nft_id, 0u32);
    assert(existing == 0u32);
    let h: u32 = block.height;
    Mapping::set(nft_anchor_height, nft_id, h);
    Mapping::set(nft_status, nft_id, STATUS_ACTIVE);
    Mapping::set(superseded_by, nft_id, [0u8; 32]);
}
```

**Acceptance check:** `leo build` succeeds for all 3 Layer 2 programs.

---

### #4 — `caller.private` invalid in assertions
**Files:**
- `payroll_nfts.aleo` line 336: `assert(nft.owner == caller.private)`
- `payroll_nfts.aleo` line 352: `assert(old_nft.owner == caller.private)`
- `credential_nft.aleo` line 127: `assert(nft.owner == caller.private)`
- `audit_nft.aleo` line 150: `assert(nft.owner == caller.private)`

**Problem:** `caller` is an `address` value — it has no `.private` field. In assertions you're doing a value comparison, not a field declaration.

**Note:** `owner: caller.private` in record literals (e.g. `payroll_nfts.aleo` L192) is VALID Leo syntax — it assigns the field `owner` the value `caller` with visibility `.private`.

**Fix:** `assert(nft.owner == caller.private)` → `assert(nft.owner == caller)`

**Acceptance check:** `leo build` passes. All 4 assertion sites updated.

---

### #4b — `block.height` in transition circuit context
**File:** `payroll_nfts.aleo/main.leo`
- Line 171: `let h: u32 = block.height;` (inside `function mint_common`)
- Line 190: `minted_height: h.private,` (sets record field from `h`)

**Problem:** `block.height` is only accessible in `async function` (finalize) context. It cannot be read in the ZK circuit (transition/function) context.

**Fix options:**
1. Remove `minted_height` from the `PayrollNFT` record entirely (since it can't be set from circuit context anyway)
2. Pass `0u32` as placeholder (worst option — misleading)
3. Set it in finalize via a separate mapping (overengineered for MVP)

**Recommended fix:** Remove `minted_height: u32.private` from the record struct and remove `minted_height: h.private` from the record literal. Same for `issued_height` in `AuditAuthorizationNFT` and `minted_height` in `CredentialNFT`.

**Acceptance check:** No `block.height` references in non-finalize context.

---

### #4c — `consume nft;` not valid Leo v3.x syntax
**Files:** `payroll_nfts.aleo` line 343, line 359; `credential_nft.aleo` line 134; `audit_nft.aleo` line 157

**Problem:** In Leo v3.x, there is no `consume` keyword. Record consumption happens implicitly at the Aleo VM level when a record is passed as input to a transition — it gets "spent" and cannot be reused.

**Fix:** Simply remove the `consume nft;` statement. The record is already consumed by being an input to the transition.

**Acceptance check:** `leo build` passes. No `consume` keyword in any Leo file.

---

### #4d — FIXED: `_nonce: group.public` in record definitions
**All 3 Layer 2 programs** — removed `_nonce: group.public` from record struct definitions and `_nonce: group::GEN` from all record literal constructions.

**Acceptance check:** Run `leo build` in Codespace for each of the 3 Layer 2 programs to confirm no `_nonce` errors.

---

### #5 — Programs not deployed; manifest IDs unverified
**File:** `config/testnet.manifest.json`
**Problem:** The manifest uses local file-name IDs (`payroll_nfts.aleo`, etc.). Actual testnet deployed program IDs are assigned at deploy time by the Aleo network and may include version suffixes or differ from local names. Until programs are deployed, we can't verify these.

**Blocked by:** Leo compilation fixes (#3, #4, #4b, #4c, #4d) must happen first, then deploy.

**Action when unblocked:**
1. Run `leo deploy` for each Layer 2 program on testnet
2. Capture the confirmed deployed program ID from the transaction
3. Update `config/testnet.manifest.json` with actual deployed IDs

**Acceptance check:** Manifest IDs match deployed program IDs queryable on Aleo explorer.

---

### #6 — SNARKOS_ENDPOINT required but commands use different env var ✅ FIXED
**Fix applied:** Consolidated three endpoint vars (`RPC_URL`, `SNARKOS_ENDPOINT`, `PHASE4_SUBMIT_ENDPOINT`) into a single canonical `ENDPOINT` var. Updated `require_phase4_execute_env.sh`, `execute_testnet.yml`, `run_phase4_execute_scenario.sh`, and `check_phase4_negative_path_guards.sh`. Also bumped snarkOS from v4.4.0 to v4.5.5 and added `.env.example` with canonical endpoint value.

**Set secret:** Replace old `RPC_URL`/`SNARKOS_ENDPOINT` GitHub secrets with a single `ENDPOINT` secret: `https://api.explorer.provable.com/v1/testnet`

---

### #7 — FIXED: execute gate no longer runs on `main` pushes
**File:** `.github/workflows/execute_testnet.yml`
**Problem:** The `on.push.branches` trigger includes `main` (and `work`). This means every merge to main triggers a real testnet execution with real secrets and potential real transaction broadcast. This is dangerous and unintentional — the execute gate should only run on `work` pushes (staging) and explicit manual dispatch.

**Fix:** Remove `main` from the `on.push.branches` list. Keep `work` for staging auto-runs and `workflow_dispatch` for manual control.

```yaml
on:
  push:
    branches:
      - work        # staging auto-run only
  workflow_dispatch:
    inputs:
      scenario: ...
```

**Acceptance check:** Pushing to main does not trigger `execute_testnet.yml`. Only `work` branch pushes and `workflow_dispatch` trigger it.

---

### #8 — FIXED: receipt verification tries REST before JSON-RPC
**File:** `scripts/verify_phase4_receipts.py` — `verify_with_retries` function
**Problem:** First attempt is `post_json(rpc_url, {"jsonrpc": "2.0", "method": "getTransaction", ...})` — but Aleo does not expose a JSON-RPC interface. This call will always fail. The REST fallback `get_url(f"{rpc_url}/transaction/{tx_id}")` is the correct protocol and should be tried first.

**Fix:** Swap the order — try REST GET first, fall back to JSON-RPC (or remove JSON-RPC entirely since Aleo doesn't support it).

```python
# Correct order:
ok, detail = get_url(f"{rpc_url.rstrip('/')}/transaction/{tx_id}")
if ok:
    return True, detail, "rest:GET /transaction/{id}"
# Only then try other methods
```

**Acceptance check:** Receipt verification correctly uses the Aleo REST API as primary protocol.

---

### #9 — Step traces are fake/placeholder in scenario runner
**File:** `scripts/run_phase4_execute_scenario.sh`
**Problem:** The step traces emitted in `step_traces.json` are hardcoded arrays of step names with status `"planned"` — no actual `snarkos` CLI calls happen. When `EXECUTE_BROADCAST=true`, only the pre-built `broadcast_commands_file` commands run (bypassing the adapter). The traces don't reflect real execution.

**Context:** This was scaffolded intentionally during Phase 4 build-up. The script runs pre-built commands from `PHASE4_BROADCAST_COMMANDS_FILE` rather than generating them from the TypeScript adapter.

**Fix:** Wire the adapter's `executePlan` output into the scenario runner, or generate the snarkos commands via the TS adapter then execute them in the bash script. This is Phase 4 completion work — requires Leo compilation (#3/#4) and CLI fix (#1b) to be done first.

**Acceptance check:** `step_traces.json` contains real execution status for each step kind, populated from actual `snarkos developer execute` calls.

---

### #10 — Invalid Aleo address in onboarding scenario
**File:** `config/scenarios/testnet/min_spend.onboarding.json`
**Problem:** `participants.employer.address` is `"aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqm3k3f"` — 42 characters. A valid Aleo address is 63 characters (`aleo1` + 58 bech32 chars). This will fail any address validation.

The correct Aleo zero address (all zeros) would be `aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq8rxyt` (verify this against real Aleo tooling; the exact checksum matters).

**Fix:** Replace the employer address with a real testnet address for the operator/test account, or if using a placeholder, use the correctly checksummed zero address.

**Acceptance check:** `python3 scripts/validate_phaseA_scenario.py config/scenarios/testnet/min_spend.onboarding.json` passes if the schema validates address length. Both addresses in the scenario are valid 63-character Aleo addresses.

---

### #11 — All-placeholder hashes in sample mint args
**File:** `config/scenarios/testnet/onboarding_mint_args.sample.json`
**Problem:** All hash fields are obvious placeholders (`0x1111...1111`, `0x2222...2222`, etc.). These will never match real on-chain state.

**Context:** This is a sample/template file. It's expected to contain placeholders — operators replace with real values before running. The issue is that CI uses this file for the `onboarding_smoke` scenario, which means CI runs will always produce unverifiable tx IDs.

**Fix:** Either:
1. Mark more clearly as a template (rename to `onboarding_mint_args.template.json`) and provide a real sample populated from a known test deployment, OR
2. Accept this as a known gap until first real testnet deploy (#5)

**Status:** Acceptable for now as long as real values are substituted before any broadcast execution.

---

### #12 — Layer 2 `program.json` / `program.toml` completeness
**Files:** `src/layer2/*/program.json`
**Problem:** The Leo build system may require `program.toml` (not just `program.json`) depending on the Leo version. Verify that `leo build` runs correctly with the existing `program.json` files for Leo v3.5.0.

**Also fixed:** `payroll_nfts.aleo/program.json` listed `paystub_receipts.aleo` as a dependency (wrong) — corrected to `employer_agreement_v2.aleo` to match the actual `import` in `main.leo`.

**Check:** Run `leo build` in each `src/layer2/*.aleo/` directory after fixing compilation bugs (#3/#4/#4b/#4c/#4d).

**Acceptance check:** `leo build` succeeds in all 3 Layer 2 program directories.

---

### #13 — Bundle SHA check fragile on re-runs
**File:** `scripts/verify_phase4_execute_artifacts.py`
**Problem:** The verifier reads SHA256 hashes from `bundle_manifest.json` and compares against actual file content. If the bundle generator (`run_phase4_execute_scenario.sh`) is re-run in the same directory without clearing artifacts first, the manifest may contain the SHA of the previous run's files while the actual files have been updated — causing SHA mismatches and false failures.

**Fix:** In `run_phase4_execute_scenario.sh`, clear the artifact directory before writing new files, or ensure the manifest is always written AFTER all other files are finalized (it already is — the manifest SHA is computed at write time, so this is only an issue if the verifier is run against stale artifacts). Add a `--clean` flag or auto-clean on each run.

**Status:** Minor; only affects re-runs in the same dir. Acceptable for MVP.

---

## Order of Operations (Remaining PRs)

### PR A-fix — Fix `buildCliCommand` flags (Issue #1b)
**Scope:** `portal/src/adapters/aleo_cli_adapter.ts`
- Change `"--query"` → `"--endpoint"`
- Remove `broadcast_url` construction and `SNARKOS_NETWORK_FLAG`
- Change `shellQuote(broadcast_url)` → just `"--broadcast"` (no arg)

### PR Leo-1 — Fix `caller.private`, `consume`, `_nonce`, `block.height` (Issues #4, #4b, #4c, #4d)
**Scope:** All 3 `src/layer2/*/main.leo` files
**These are pure substitution fixes; do them before the async restructure.**
- `assert(... == caller.private)` → `assert(... == caller)` (4 sites)
- `consume nft;` → remove (4 sites)
- `_nonce: group.public` → remove from record defs (3 records)
- `_nonce: group::rand().public` → remove from record literals (3 records)
- `minted_height: u32.private` → remove from record defs + literals (in mint_common, CredentialNFT, AuditAuthorizationNFT)
- `issued_height: u32.private` → remove from `AuditAuthorizationNFT` def + literal
- `let h: u32 = block.height;` → remove from non-finalize contexts

### PR Leo-2 — Async transition + finalize restructure (Issue #3)
**Scope:** All 3 `src/layer2/*/main.leo` files
**This is the major restructure. Do after Leo-1.**
- All mapping-reading/writing `function` bodies → become `async function finalize_*` bodies
- All `transition` bodies that called those functions → become `async transition` bodies
- Update return signatures: `-> T` → `-> (T, Future)` for mint transitions; `-> Future` for void async transitions
- Wire cross-program calls as `Future`-returning and `await()` them in finalize
- Run `leo build` in each program directory

### PR Fix-7 — Remove main-branch execute trigger (Issue #7)
**Scope:** `.github/workflows/execute_testnet.yml`
- Remove `main` from `on.push.branches`

### PR Fix-6-8 — SNARKOS_ENDPOINT alignment + receipt verification order (Issues #6, #8)
**Scope:** `scripts/require_phase4_execute_env.sh`, `scripts/verify_phase4_receipts.py`
- #6: Remove `SNARKOS_ENDPOINT` from required list (or wire it to actual command generation)
- #8: Swap REST and JSON-RPC verification order in `verify_with_retries`

### PR Fix-10 — Fix invalid employer address (Issue #10)
**Scope:** `config/scenarios/testnet/min_spend.onboarding.json`
- Replace 42-char employer address with valid 63-char address

### PR Deploy — Deploy Layer 2 programs, update manifest (Issue #5)
**Blocked by:** PR Leo-1 + PR Leo-2 (must compile first)
- `leo deploy` for each Layer 2 program
- Update `config/testnet.manifest.json` with actual deployed program IDs

---

## Acceptance Criteria for Phase 4 Exit

1. `leo build` succeeds in all 3 `src/layer2/` program directories
2. `npx tsc -p portal/tsconfig.phase4.json` passes
3. `scripts/run_phase4_adapter_tests.sh` passes
4. Generated adapter commands match correct `snarkos developer execute` syntax
5. `execute_testnet.yml` only fires on `work` branch + manual dispatch (not `main`)
6. One reproducible testnet run emits real tx IDs and receipt verification passes
