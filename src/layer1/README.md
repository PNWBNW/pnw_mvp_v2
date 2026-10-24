# src/layer1 — the canonical programs

Layer 1 is where the rules live: who owns a name, which agreement is active, how money moves.
Every program keeps identifying data in private records and puts only hashes, commitments and
block heights in public mappings. The versions in this folder are the live ones; superseded
versions are in [`archive/`](archive/README.md), and `config/testnet.manifest.json` is the one
list of what is deployed.

"Hewn today" says how the app uses each program right now. Several are deployed and sound but not
called, because Hewn's payroll settled on one private USDCx transfer per worker with the paystub
sent as a letter (see Hewn's `docs/AUDIT_DESIGN.md`); they wait for the audit design and for
credentials.

| Program | Upgrades | What it does | Hewn today |
|---|---|---|---|
| [`pnw_name_registry_v2.aleo`](pnw_name_registry_v2.aleo/README.md) | `@admin` | Who owns which name hash, worker or employer, with the industry suffix. `assert_is_owner` and `assert_employer_owner` are the guards every other program calls. | Read for every name lookup; checked by every program the app calls |
| [`pnw_name_registrar_v5.aleo`](pnw_name_registrar_v5.aleo/README.md) | `@admin`, edition 1 | Registers names: the paid path (1 USDCx) and, since 2026-10-15, the free path. Keeps the readable name for reverse lookup. | `register_worker_free` / `register_employer_free` at setup |
| [`employer_license_registry.aleo`](employer_license_registry.aleo/README.md) | `@noupgrade` | A verified flag per employer wallet, set by the authority. | Not used: the free paths don't require it |
| [`employer_profiles_v2.aleo`](employer_profiles_v2.aleo/README.md) | `@admin` | A private `EmployerProfile` record and its anchor. | Deployed, not called |
| [`pnw_worker_profiles_v2.aleo`](pnw_worker_profiles_v2.aleo/README.md) | `@admin` | A private `WorkerProfile` record and its anchor. | `create_worker_profile` at worker setup |
| [`employer_agreement_v4.aleo`](employer_agreement_v4.aleo/README.md) | `@admin`, edition 2 | Job offers and agreements: a `PendingAgreement` to the worker, three `FinalAgreement` copies on acceptance, pause / terminate / resume, and `assert_employer_authorized` for other programs. | Offers (`create_offer_open`) and acceptance (`accept_job_offer`) |
| [`employer_agreement_v5.aleo`](employer_agreement_v5.aleo/README.md) | `@noupgrade` | The two-party rebuild, **staged, not deployed** (2026-10-23, locked in 2026-10-24): the P-256 public halves ride in the records, no registry call in any public input, a `SentOffer` to the employer, no DAO copy; a pair tag carries the status for other programs, bytes packed as `u128`, a private reason when an agreement ends. | Nothing yet: Hewn switches once it is deployed (`docs/migrations/2026-10-23-agreement-v5.md`) |
| [`payroll_core_v2.aleo`](payroll_core_v2.aleo/README.md) | `@admin` | One-proof payroll: verify the agreement, move USDCx, mint receipts, anchor the event, guard against double pay. | Deployed, not called: the app pays with `transfer_private` directly |
| [`paystub_receipts.aleo`](paystub_receipts.aleo/README.md) | `@admin` | Private paystub receipts for worker and employer, with reversals. | Deployed, not called: paystubs travel as letters |
| [`payroll_audit_log.aleo`](payroll_audit_log.aleo/README.md) | `@noupgrade` | Hash-only event anchors with block heights. | Deployed, not called |
| [`pnw_router_v4.aleo`](pnw_router_v4.aleo/README.md) | `@admin` | One entry surface over agreements, profiles and names. | Deployed, not called |
| [`hewn_letters_v2.aleo`](hewn_letters_v2.aleo/README.md) | `@noupgrade` | Sealed letters as records: `send`, `send_page`, `send_many` (eight at once). | Every offer, message, timecard, schedule and paystub |
| [`hewn_jobs_v1.aleo`](hewn_jobs_v1.aleo/README.md) | `@noupgrade` | The public job board: `post` ($1 USDCx), `update`, `feature` ($5 a day), `close`. | Jobs and Find work |

Two programs these import are not ours: `test_usdcx_stablecoin.aleo` (the testnet stablecoin) and
`credits.aleo`. Local stand-ins for building and testing offline are in [`../stubs/`](../stubs/README.md).

## Working on a program

- Build or test from a copy whose folder name has no `.aleo` suffix (Leo treats a path ending in
  `.aleo` as bytecode): `cp -r src/layer1/hewn_jobs_v1.aleo /tmp/hewn_jobs_v1 && cd /tmp/hewn_jobs_v1 && leo test`.
  The CI job in `.github/workflows/deploy.yml` does exactly this for the programs with tests.
- A deployed program is never edited in place. A change is a new version (`_v3`), deployed with
  `.github/workflows/deploy_program.yml`, with a migration note under `docs/migrations/`; the old
  version moves to `archive/`. An `@admin` program may be upgraded in place with
  `upgrade_program.yml` only when the migration note says why that is safe.
- New or changed Leo comes with negative tests: inputs that must fail.
