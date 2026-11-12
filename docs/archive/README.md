# docs/archive

Retired documents and code are deleted, not kept (Hewn's OPS-09): git history is the archive. Each
row says what the thing was, when and why it went, and the commit that still holds it; nothing
else lives in this folder (`scripts/check_archive.py`). Read one with `git show 209a234:<path>`.

Superseded program versions are the exception: they stay in `src/layer1/archive/` and
`src/layer2/archive/`, unchanged, because they are on chain for good and their source is what
anyone checks the deployed program against.

| Path | Was | Retired | Why | Held by |
|---|---|---|---|---|
| `docs/archive/NOTES.md` | The issue tracker through April 2026 | 2026-11-04 | Every issue in it was fixed or overtaken (checked one by one on 2026-11-04); the E10 milestone's transactions are in `README.md`; its last open item, debug logging, is enforced in Hewn's CI | `209a234` |
| `docs/archive/DIRECTORY.md` | A file map as of 2026-04-10 | 2026-11-04 | Replaced by the READMEs in each folder and the root README | `209a234` |
| `docs/archive/MULTI_REPO_PLAN.md` | The three-repo plan (programs, employment portal, auditing portal) | 2026-11-04 | The portal became Hewn; the auditing portal was never built | `209a234` |
| `docs/archive/AUDITOR_PORTAL.md` | The design for that auditing portal (lived next to `audit_nft.aleo`) | 2026-11-04 | Superseded by Hewn's `docs/AUDIT_DESIGN.md`, which proves payroll without receipts | `209a234` |
| `docs/archive/IDEA_BOARD.md` | April 2026 brainstorming on payroll speed | 2026-11-04 | Answered by paying with one private transfer per worker | `209a234` |
| `docs/archive/LAYER1_INTERFACE.md` | The callable surface of the Layer 1 programs, March 2026 | 2026-11-04 | Each live program's README carries its own surface | `209a234` |
| `docs/operations/PHASE4_TESTNET_GAMEPLAN.md` | The February 2026 plan from the planner to testnet execution | 2026-11-04 | Done in April 2026 | `209a234` |
| `portal/` | The portal's planning layer in TypeScript (workflows, routers, the Layer 1 and 2 adapters, the CLI adapter, commitments, records), kept for its type checks and the adapter codec test | 2026-11-04 | Nothing called it: Hewn's packages took over in October 2026, and Hewn deleted its own copies of the routers and the CLI adapter the same day | `209a234` |
| `scripts/run_phase4_adapter_tests.sh` | Ran `portal/tests/phase4_adapter.test.ts` in the plan gate | 2026-11-04 | Went with `portal/` | `209a234` |
| `.github/workflows/execute_testnet.yml` | The execute gate: ran a scenario through the command-line harness inside GitHub, on a push to a branch named `work` or by hand | 2026-11-12 | Nothing has needed it since April 2026, and the harness runs from an operator's own machine, so no account's keys need to sit in GitHub for it | `4740c99` |
| `scripts/dispatch_phase4_execute.sh` | Started that workflow through the GitHub API | 2026-11-12 | Went with the workflow | `4740c99` |
