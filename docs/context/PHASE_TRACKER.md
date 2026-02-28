# Phase Tracker

_Last updated: 2026-02-28_

## Snapshot

- **Phase 0:** Completed
- **Phase 1:** Completed
- **Phase 2:** Completed
- **Phase 3:** Completed (signoff committed)
- **Phase 4:** In progress (execution boundary implementation)
- **Phase 5:** Pending (testnet correctness validation)
- **Phase 6:** Pending (hardening)

## Phase 4 Exit Criteria

- [ ] Adapter executes real Aleo CLI commands via typed step->endpoint->codec mapping
- [ ] Structured execution trace artifacts are emitted for every run
- [x] GitHub Actions split into:
  - [x] plan gate (PR-safe, no secrets)
  - [x] execute gate (manual + environment protected + secrets)
- [x] Environment/program manifest validation added before execute mode

## Phase 5 Entry Requirements

- [ ] Leo/snarkOS pins verified in operator and CI environments
- [ ] Testnet program IDs are versioned and resolved deterministically
- [ ] One end-to-end happy path is scriptable/reproducible


## Current Phase 4 progress notes

- PR A started: deterministic Layer 2 CLI command generation and typed execution traces/errors are now implemented in adapter scaffold.
- Remaining to exit Phase 4: adapter codec integration tests + real execute smoke run with protected environment.

## Known Blockers / Risks

- CLI arg codec mismatches are the most likely early execution failure mode.
- Secret handling and environment protections must be complete before execute automation.
