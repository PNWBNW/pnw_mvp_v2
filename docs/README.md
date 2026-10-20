# docs/

What's here, and how much to trust each file.

| File | Status | What it is |
|---|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Reference, April 2026 | The conceptual spec for the programs: layers, money flow, the trust model, workflows. Still right about the programs; where it says payroll runs through `payroll_core`, Hewn today pays with one private USDCx transfer per worker and sends the paystub as a letter (see the note at its top). |
| [`migrations/`](migrations/) | Live | One note per deployed change: what changed, the transactions, the checks that must fail and pass. `2026-10-14-open-registration.md` is the free-registration upgrade. |
| [`operations/PHASE4_CLI_SETUP.md`](operations/PHASE4_CLI_SETUP.md) | Legacy CLI path | Installing pinned Leo and snarkOS and running the command-line happy path. Hewn signs everything in the Shield wallet instead; the CLI gate in `.github/workflows/execute_testnet.yml` still uses this. |
| [`operations/PHASE4_TESTNET_GAMEPLAN.md`](operations/PHASE4_TESTNET_GAMEPLAN.md) | History | The February 2026 plan for getting from the planner to testnet execution. Done. |
| [`archive/`](archive/README.md) | History | Documents from the portal era that no longer describe the code. |

Design documents for what the programs are *for* live in the Hewn repo, next to the app that uses
them: `docs/LETTERS.md`, `docs/JOB_BOARD.md`, `docs/AUDIT_DESIGN.md`, `docs/NAME_REGISTRY_MAP.md`
and `docs/THREAT_MODEL.md` in [PNWBNW/hewn](https://github.com/PNWBNW/hewn/tree/main/docs).
