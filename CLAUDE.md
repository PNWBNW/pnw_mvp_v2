# CLAUDE.md — PNW MVP v2

> Read this first, every session. It is the project context for the Leo programs that
> [Hewn](https://github.com/PNWBNW/hewn) runs on. The app, the build plan and the progress log live
> in that repo; this one holds what is on chain.

## What this is

The on-chain side of Hewn: Leo programs on Aleo testnet for names, agreements, sealed letters, the
public job board, payroll settlement and commitment anchors. PNW (Proven National Workers) is the
protocol and company namespace; Hewn is the product. The programs keep anything about a person
in private records and put only hashes, commitments and block heights in public state.

Read in this order: this file, `README.md`, `config/testnet.manifest.json` (what is deployed),
the README in `src/layer1/`, `src/layer2/` and `src/stubs/`, then Hewn's `CLAUDE.md` and
`BUILD_PLAN.md` for what to build next.

## Rules (non-negotiable)

**Immutability**
- A deployed program is never edited in place. A change ships as a new version (`hewn_jobs_v2`)
  with a migration note under `docs/migrations/`; the old version moves, unchanged, to
  `src/layer1/archive/` or `src/layer2/archive/`.
- An `@admin` program may be upgraded in place (`upgrade_program.yml`) only when the migration
  note explains why that is safe and Joshua has said go. An upgrade can append functions but can't
  change what an existing finalize takes in (`docs/migrations/2026-10-14-open-registration.md`).
- `config/testnet.manifest.json` is the single source of truth for what is live. It changes in
  the same pull request as the deploy or upgrade it records.

**Privacy**
- No plaintext identity, wage, address or business data in public state. Mappings hold hashes,
  commitment anchors, statuses and block heights.
- No cumulative counters in public mappings (they leak wages by difference). CI enforces this
  (`scripts/check_layer1_public_leakage_guards.py`).
- Layer 2 never moves funds. No pooled custody: an employer's USDCx records are consumed and the
  worker's emitted in the same transition, or Hewn pays with a plain `transfer_private`.

**Writing Leo**
- Say so before starting any new or changed program, so Joshua can switch the session to Fable
  5.1 at high effort. Every program ships with Leo tests, including negative ones (inputs that
  must fail), run in CI (`deploy.yml`).
- Leo v4 syntax: transitions are `fn`, finalize is `async fn`, `@admin(address = …)` or
  `@noupgrade` on the constructor. Build and test from a copy whose folder has no `.aleo` suffix.
- Programs we don't own are imported from the network at deploy time; `src/stubs/` stand in
  for them offline.

**Keys and secrets**
- Never commit or print a private key, view key, `.env` or seed phrase. The admin key lives only in
  the GitHub secret `ADMIN_PRIVATE_KEY` (environment `testnet-staging`). Never ask anyone to paste
  a key into a chat. Keys never go in URLs; logs never print accounts.

**Working here**
- Hewn's app is the caller. Every transaction is signed in the user's Shield wallet; the
  command-line path (`portal/`, `scripts/`, `execute_testnet.yml`) is a test harness, not a
  product path.
- Commit messages are plain descriptive text, `<scope>: <what changed>`. Never append a
  `https://claude.ai/...` session link.
- `main` is stable; work on a branch and open a pull request; merge after the plan gate is green.

## What is live (testnet)

The full table, with each program's README, is in `src/layer1/README.md` and `src/layer2/README.md`.
In short:

| Program | Role | Hewn today |
|---|---|---|
| `pnw_name_registry_v2.aleo` | Who owns which name | Read; every other program checks names through it |
| `pnw_name_registrar_v5.aleo` (edition 1) | Registering names, free since 2026-10-15 | Setup |
| `pnw_worker_profiles_v2.aleo` | A worker's private profile | Worker setup |
| `employer_agreement_v4.aleo` (edition 2) | Offers and agreements | Offers and acceptance |
| `employer_agreement_v5.aleo` | Two-party offers and agreements, deployed 2026-10-24 | Not yet: Hewn switches next, and keeps reading v4 |
| `hewn_letters_v2.aleo` | Sealed letters (`send`, `send_page`, `send_many`) | Everything between people |
| `hewn_jobs_v1.aleo` | The public job board | Jobs, Find work |
| `hewn_cards_v1.aleo` | The cards every account gets: issue height and shown, by name | Not yet: the app issues cards at setup next |
| `employer_license_registry.aleo`, `employer_profiles_v2.aleo`, `pnw_router_v4.aleo`, `payroll_core_v2.aleo`, `paystub_receipts.aleo`, `payroll_audit_log.aleo` | Licences, employer profiles, routing, one-proof payroll, receipts, audit anchors | Deployed, not called |
| `payroll_nfts_v2.aleo`, `credential_nft_v3.aleo`, `credential_nft_v4.aleo` (staged), `audit_nft.aleo` | Layer 2 anchors | Deployed, not called: waiting on the audit design and credentials |

`hewn_letters_v1.aleo` is archived and still deployed; Hewn still reads letters sent with it.

## Where things are

| Path | What |
|---|---|
| `src/layer1/` | The canonical programs, one folder each (`program.json`, `src/main.leo`, `tests/`, `README.md`) |
| `src/layer2/` | The commitment-anchor programs |
| `src/stubs/` | Local stand-ins for the stablecoin and the registry, for offline builds and tests |
| `src/layer1/archive/`, `src/layer2/archive/` | Superseded versions and pre-upgrade snapshots, unchanged |
| `config/testnet.manifest.json` | What is deployed: ids, transactions, notes |
| `config/scenarios/` | Fixtures for the command-line execute gate |
| `docs/` | `ARCHITECTURE.md` (the spec), `migrations/` (every deployed change), `operations/` (the CLI path), `archive/` |
| `portal/` | The original planning-layer TypeScript, kept for its CI type gates; the live copy is Hewn's `packages/` |
| `scripts/` | CI checks and the execute harness; see its README |
| `.github/workflows/` | See below |

## Workflows

| Workflow | Trigger | Does |
|---|---|---|
| `deploy.yml` (the plan gate) | Every push and pull request | Pinned CLI check, portal typechecks, adapter codec test, manifest schema, the leakage guard, Leo tests for `hewn_letters_v2`, `hewn_jobs_v1`, `employer_agreement_v5` and `hewn_cards_v1` |
| `deploy_program.yml` (deploy-new-program) | Manual | Deploys one program from `src/layer1/` with the admin key, swapping stubs for the deployed dependencies first |
| `upgrade_program.yml` (upgrade-admin-program) | Manual | Upgrades an `@admin` program in place; run once with broadcast off, then on |
| `execute_testnet.yml` (the execute gate) | Manual, or the `work` branch | Runs a scenario through the CLI harness and verifies receipts |
| `generate_sha256.yml` | Manual | Checksums for new Leo and snarkOS artifacts when the pins move |

## Toolchain

| Tool | Version | Note |
|---|---|---|
| Leo | 4.0.0 | What CI builds and tests with (`vars.LEO_SHA256`); the upgrade workflow bootstraps 4.0.0 then runs `leo update` because only a newer Leo knows the current consensus version |
| snarkOS | v4.6.0 | The network enforces ConsensusVersion V14 and later; programs compiled with Leo before 4.0 are rejected |
| Node | 20 | `actions/setup-node` |

Endpoint: `https://api.explorer.provable.com/v2` as the base for `snarkos` and `leo`
(they add the network: `--network 1` is testnet), `https://api.explorer.provable.com/v2/testnet/...`
for REST reads. `.env.example` has every variable; `leo` reads `PRIVATE_KEY`.

## Validation commands

```bash
npx --yes --package typescript tsc -p portal/tsconfig.phase3.json
npx --yes --package typescript tsc -p portal/tsconfig.phase4.json
scripts/run_phase4_adapter_tests.sh
python3 scripts/validate_testnet_manifest.py config/testnet.manifest.json
python3 scripts/check_layer1_public_leakage_guards.py
cp -r src/layer1/hewn_jobs_v1.aleo /tmp/hewn_jobs_v1 && cp -r src/stubs /tmp/stubs && (cd /tmp/hewn_jobs_v1 && leo test)
```

## Decisions (durable)

- 2026-02-27 — Adapters are the only execution boundary; workflows and routers only plan.
- 2026-03-02 — No cumulative public spend counters; hash-only audit anchors.
- 2026-04-10 — First end-to-end private payroll on testnet (the five transactions are in `README.md`).
- 2026-10-13 — The portal became Hewn; this repo is the chain side of it. Licence AGPL-3.0-only (2026-10-15).
- 2026-10-14 — Hewn pays with one private USDCx transfer per worker and sends the paystub as a letter; `payroll_core_v2`, the receipts and the per-payment anchors stay deployed, unused.
- 2026-10-15 — Open registration: `pnw_name_registrar_v5` edition 1 and `employer_agreement_v4` edition 2 add free, licence-free paths; the gated originals stay on chain unchanged.
- 2026-10-16/18 — Letters are records on chain (`hewn_letters_v1`, then `v2` with `send_many`); the chain is the mailbox.
- 2026-10-19 — The public job board (`hewn_jobs_v1`): $1 USDCx to post, $5 a day to feature, 30 days at most, employer names only.
- 2026-10-20 — Superseded versions live in `src/<layer>/archive/`, unchanged; every live program carries a README.
- 2026-10-24 — `employer_agreement_v5` deployed: two parties, the halves in the records, no public link between the parties, a pair tag for other programs, a private end reason. v4 stays live for the agreements already made and the programs that import it.
- 2026-10-25 — `hewn_cards_v1` deployed: a business's card and a worker's tenure card, one public entry per name (issue height, shown), bound to the name, no fee of its own. Time on Hewn counts from the card's issue; the registry check runs at issue, so hiding is the app's permission to draw, not an erasure.

## What's next

Mainnet. `.hewn` names move under the Aleo Name Service as a TLD (Hewn's `BUILD_PLAN.md`,
"Mainnet names"), which needs a registrar program for it and a conversation with the ANS team.
The audit design (Hewn's `docs/AUDIT_DESIGN.md`) decides what Layer 2 anchors become. Every program
that will hold real money gets a third-party audit first.
