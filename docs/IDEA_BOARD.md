# Idea Board — Payroll Speedup & Future Improvements

> Scratchpad for ideas, not a design spec. Nothing here is committed work
> until it lands in `NOTES.md` with an owner and acceptance criteria.

---

## Current Baseline (2026-04-11)

| Scenario | Wall time | Dominant cost |
|---|---|---|
| 1 worker (monolithic `execute_payroll`) | ~170s | Shield WASM prover (ZK proof gen) |
| 3 workers (sequential, current) | ~510s (8.5 min) | 3 × 170s + ~30s inter-worker prep |
| 10 workers (projected) | ~1700s (28 min) | Linear in N — unworkable for demo |

**Goal** — bring 3-worker runs below 4 minutes and 10-worker runs below 6 minutes.

---

## The Speedup Space (4 Axes)

1. **Reduce proof count** — fewer wallet signatures per run.
2. **Reduce per-proof cost** — shrink the circuit, cache the proving key.
3. **Overlap work** — pipeline prep steps while the wallet is still proving.
4. **Move the prover** — off the browser WASM and onto something faster.

---

## Ideas

### A. Pipeline prep across workers *(easy, ~60-120s savings on 3-worker run)*

**Impact:** Low-medium. **Effort:** ~2 hours. **Risk:** Low.

While Shield is building worker N's proof (~150-170s blocking), the
coordinator is currently *idle*. We could use that time to do worker N+1's
prep work concurrently:
- Fetch + filter USDCx records
- Build the Sealance Merkle exclusion proof (~5-10s)
- Serialize `WorkerPayArgs` struct
- Warm any cached state

Then the instant worker N hits `confirmed`, the wallet popup for worker N+1
fires immediately with zero prep delay. Saves the ~30s inter-worker gap ×
(N-1) workers.

**3 workers:** 510s → ~450s. Not game-changing but free.

**Where to build:** `src/coordinator/settlement_coordinator.ts` —
kick off `prepareChunk(N+1)` as a background promise the moment worker N
enters the `proving` stage.

---

### B. Cache Sealance Merkle tree across workers in a run *(easy, ~15-30s savings)*

**Impact:** Low. **Effort:** ~30 min. **Risk:** Zero.

Right now we rebuild the Sealance freeze-list Merkle tree for every worker:
```ts
const tree = sealance.buildTree(leaves)
const proofLeft = sealance.getSiblingPath(tree, leftIdx, 16)
// ...
```

The employer address doesn't change mid-run, and the freeze-list root is
stable within a testnet block (several seconds). Cache the computed
`formattedProof` once per run and reuse it for all N workers. Saves
~5-10s per worker × (N-1) workers.

**Where to build:** `src/coordinator/settlement_coordinator.ts` top-level
closure inside `executeSettlement` — compute once, pass into each
`executeChunkViaWallet` call.

---

### C. Pre-warm the WASM prover *(easy, ~5-20s savings first worker only)*

**Impact:** Very low. **Effort:** ~1 hour. **Risk:** Low.

Shield's WASM prover has a cold-start cost the first time it builds a proof
in a session. If we could call a dummy `executeTransaction` the instant the
user opens the payroll page (or better, the instant they connect wallet),
the prover runtime would be "hot" by the time they click Sign.

Unknown: whether Shield exposes a way to warm its prover without actually
broadcasting a tx. Might be a Shield-team feature request.

---

### D. `execute_payroll_batch_N` — one signature, one proof, N workers *(medium-hard, 30-50% savings)*

**Impact:** **HIGH.** **Effort:** 4-8 hours (includes Leo redesign, redeploy,
retest). **Risk:** Medium — we've hit AVM constraints here before.

The existing `execute_payroll_batch_2` failed because it tried to consume
the chained `remainder1` Token record as input to the second `transfer_private`
call within the same transition. AVM rejects: "input record must belong to
the signer" (i.e. can't consume a record created mid-transition).

**The fix:** don't chain `transfer_private` calls. Instead, add a new
transition to `test_usdcx_stablecoin.aleo`:

```leo
transition transfer_private_batch_N(
    input: Token,
    recipients: [address; N],
    amounts: [u128; N],
    merkle_proofs: [MerkleProof; 2]   // one exclusion proof for sender
) -> ([Token; N], Token)               // N recipient records + 1 remainder
```

This consumes `input` ONCE and emits `N+1` output records in a single
transition. Then `payroll_core_v2::execute_payroll_batch_N` calls this
once and loops through paystub receipt minting for each worker.

**Projection:** a single proof covering 2-3 workers is probably ~200-250s
total (sublinear in N because much of the circuit is per-transition
overhead, not per-worker). 3 workers in one proof ≈ 3 min vs. 8.5 min
sequential. **~65% savings.**

**Caveats:**
- Fixed array size baked into the transition — need `batch_2`, `batch_3`,
  `batch_5`, `batch_10` variants, or dynamic batching via smart chunking
- `test_usdcx_stablecoin.aleo` redeploy required
- Sealance Merkle exclusion proof only needs to verify the SENDER once
  (saves per-worker verification cost)

**Where to build:**
- `pnw_mvp_v2/src/layer1/test_usdcx_stablecoin.aleo/main.leo` — new batch transition
- `pnw_mvp_v2/src/layer1/payroll_core_v2.aleo/main.leo` — new `execute_payroll_batch_N` that calls the batch transfer
- `pnw_employment_portal_v1/src/coordinator/settlement_coordinator.ts` — chunk planner selects batch variant based on row count
- `pnw_employment_portal_v1/src/lib/pnw-adapter/layer1_*.ts` — type-level plumbing

---

### E. Parallel browser tabs for parallel proofs *(easy-medium, up to N× speedup — but fragile)*

**Impact:** High (in theory). **Effort:** ~2-3 hours. **Risk:** HIGH.

Shield's WASM prover is per-tab. In theory, opening 3 tabs simultaneously
could run 3 proofs in parallel, completing ~170s total instead of ~510s.

**Reality checks:**
- CPU contention — 3 concurrent WASM provers compete for cores; total time
  may be closer to 1.5-2×, not 3×
- Each tab needs its own wallet session state (cookies, localStorage)
- User experience is weird: 3 popup windows, 3 signatures to approve in
  different tabs, 3 different transaction views
- Shield may rate-limit / refuse concurrent prover instances
- Race conditions on USDCx record selection — tab 2 might pick the same
  record as tab 1 before tab 1 commits

**Verdict:** Only worth exploring AFTER we understand whether tabs are
isolated from each other's proof state. Probably not a clean win.

---

### F. Server-side prover (offload WASM to a backend) *(hard, >50% savings)*

**Impact:** **Very high** (~30s per proof vs. 170s). **Effort:** 1-2 weeks.
**Risk:** High — changes the trust/privacy model.

Run the ZK prover on a server with 16+ cores instead of the browser. Proofs
that take 170s in WASM take 20-30s on a proper CPU with Rust-native snarkVM.

**Privacy problem:** the prover sees plaintext inputs. For PNW this is
unacceptable without mitigation. Options:
- **Self-hosted prover per employer** — user runs their own prover node.
  Removes multi-tenant privacy risk but adds ops burden.
- **Commit-reveal ceremony** — client commits to inputs on-chain, server
  produces a proof that only it can complete, client decrypts final artifact.
  Technically possible but complex.
- **Confidential compute** — prover inside Intel SGX / AWS Nitro / TDX
  enclave with attestation. Judges may find this suspicious for a
  privacy-first pitch.

**Verdict:** Not for the 40-hour window. Great post-buildathon roadmap item.

---

### G. Shrink the `execute_payroll` circuit *(medium, 20-40% savings)*

**Impact:** Medium. **Effort:** 3-6 hours of Leo-level optimization. **Risk:** Medium.

Audit `payroll_core_v2::execute_payroll` for:
- Redundant hash rounds (are we hashing things that don't need hashing?)
- Unnecessary field element conversions
- Assertion that could be client-side pre-checks instead of in-circuit
- Tighter input types (e.g. `u64` instead of `u128` where amounts allow)
- Whether the 4 sub-calls could share work via helper functions

Leo compiler optimizations have matured in v4 — a clean rebuild might be
15-25% faster just from the compiler, with no source changes. Worth
measuring before hand-optimizing.

---

### H. Skip redundant on-chain verification for same-employer runs *(medium, 10-20% savings)*

**Impact:** Low-medium. **Effort:** 2-4 hours. **Risk:** Low.

`employer_agreement_v4::assert_agreement_active` is called for every worker
in a run. For a multi-worker run, all workers share the same employer —
the license + employer identity checks could happen once at the start of
the run instead of once per worker.

**How:** introduce a session-scoped "run_token" — a private record the
employer mints at the start of a run via a lightweight transition, which
later `execute_payroll_*` calls consume as proof that prechecks already
happened. Saves ~5-10s per worker.

**Caveat:** breaks strict per-worker atomicity; a mid-run failure leaves
workers in an "already prechecked" state. Audit story must handle this.

---

### I. Progressive proving — queue all signatures upfront *(UX, not speedup)*

**Impact:** Zero on wall time. **Effort:** ~1 hour. **Risk:** None.

Currently the user signs worker 1, waits 170s, then signs worker 2, waits
170s, etc. What if the portal queues all N signature requests upfront at
the start of the run, so the user clicks sign 3 times in the first
20 seconds and then walks away?

**Limitation:** Shield won't let you queue multiple popups. Would need to
check whether the wallet adapter supports this or not.

**Even if it doesn't reduce wall time, it FEELS faster** — user attention
is only needed during a short cluster at the start, not sprinkled across
8 minutes. Very worth exploring for the demo UX.

---

### J. Pre-commit manifest off-chain, settle async *(architectural, post-MVP)*

**Impact:** Decouples UX latency from proof time. **Effort:** 10+ hours.
**Risk:** Architectural.

Post-buildathon idea: employer clicks "Run Payroll" → portal generates
manifest → commits manifest hash on-chain via a lightweight anchor transition
(~5s) → UI shows "Payroll queued!" → workers see pending paystubs → actual
ZK proofs are generated in the background over the next 20 minutes → each
settles on-chain as its proof completes.

User never waits. Workers see "pending → settled" transitions. Great UX
but a big redesign of the state machine.

---

## Ranked Recommendation for the 40-Hour Window

If we get to pick 1-2 items to land before submission:

1. **Ship B (Sealance cache) immediately** — 30 min, zero risk, ~15-30s savings.
2. **Ship A (pipeline prep)** — 2 hours, ~60s savings, makes the 3-worker run feel tighter.
3. **If time allows, attempt D (batch_N with fixed transfer)** — 4-8 hours of
   focused work. If it lands, the demo jumps to 3-5× faster for multi-worker
   runs. If it doesn't land, we still have the current sequential path as fallback.

**Not doing now:** E (parallel tabs — fragile), F (server prover — trust story),
G (circuit shrink — needs measurement first), H (precheck skip — audit complexity),
J (async settle — too big).

---

## Workers Not In This Doc

Ideas for future scratchpads:
- Worker portal paystub viewer (reads `WorkerPaystubReceipt` records)
- Mobile-responsive employer portal
- Audit authorization flow polish
- NFT visual art + metadata for payroll/credential/audit NFTs
