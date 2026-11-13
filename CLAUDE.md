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
  `src/layer1/archive/` or `src/layer2/archive/`, with a row in that folder's README and its
  hashes in that folder's `SHA256SUMS` (`scripts/check_archive.py --write`; CI fails on an edit).
- An `@admin` program may be upgraded in place (`upgrade_program.yml`) only when the migration
  note explains why that is safe and Joshua has said go. An upgrade can add functions, mappings,
  records and imports, and it can change the logic inside any existing function or finalize; it
  can't remove anything, change a function's inputs or outputs, or change what an existing
  finalize takes in (snarkVM `check_upgrade_is_valid`;
  `docs/migrations/2026-10-14-open-registration.md`). So whoever holds the admin key decides what
  every `@admin` program does next.
- `config/testnet.manifest.json` is the single source of truth for what is live. It changes in
  the same pull request as the deploy or upgrade it records, and it records each program's
  edition and the hash of its text on chain (`scripts/check_chain.py --write`). The plan gate and
  the daily `chain-watch` run compare it with the chain, so an upgrade nobody recorded fails.
  Under `watched` it records the same for programs Hewn relies on and doesn't own (the
  stablecoin and what it imports), so their owners' upgrades fail it too.

**Privacy**
- No plaintext identity, wage, address or business data in public state. Mappings hold hashes,
  commitment anchors, statuses and block heights.
- No cumulative counters in public mappings (they leak wages by difference). CI enforces this
  (`scripts/check_layer1_public_leakage_guards.py`).
- Layer 2 never moves funds (`scripts/check_layer2_moves_no_funds.py` in CI). No pooled custody: an employer's USDCx records are consumed and the
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
  a key into a chat. Keys never go in URLs; logs never print accounts. The plan gate's secrets
  scan (`scripts/check_secrets.py`) is the backstop.

**Working here**
- Hewn's app is the caller. Every transaction is signed in the user's Shield wallet; the
  command-line path (`scripts/`) is a test harness run from your own machine, not a
  product path.
- Commit messages are plain descriptive text, `<scope>: <what changed>`. Never append a
  `https://claude.ai/...` session link.
- `main` is stable; work on a branch and open a pull request; merge after the plan gate is green.
- Retired documents and code are deleted, not archived (Hewn's OPS-09): git history is the
  archive, and `docs/archive/README.md` keeps one row each with the commit that holds it
  (`scripts/check_archive.py`). Superseded program versions are the exception: they stay in
  `src/<layer>/archive/`, unchanged.

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
| `hewn_credentials_v1.aleo` | A worker's credentials, deployed 2026-10-25: a business vouching for a person it has an agreement with, two private records, a public commitment with its status | Team page (issue, revoke) and a worker's Profile (accept, decline); drawn as landmarks |
| `employer_license_registry.aleo`, `employer_profiles_v2.aleo`, `pnw_router_v4.aleo`, `payroll_core_v2.aleo`, `paystub_receipts.aleo`, `payroll_audit_log.aleo` | Licences, employer profiles, routing, one-proof payroll, receipts, audit anchors | Deployed, not called |
| `payroll_nfts_v2.aleo`, `credential_nft_v3.aleo`, `credential_nft_v4.aleo`, `audit_nft.aleo` | Layer 2 anchors | Deployed, not called: waiting on the audit design and credentials |

`hewn_letters_v1.aleo` is archived and still deployed; Hewn still reads letters sent with it.

## Where things are

| Path | What |
|---|---|
| `src/layer1/` | The canonical programs, one folder each (`program.json`, `src/main.leo`, `tests/`, `README.md`) |
| `src/layer2/` | The commitment-anchor programs |
| `src/stubs/` | Local stand-ins for the stablecoin and the registry, for offline builds and tests |
| `src/layer1/archive/`, `src/layer2/archive/` | Superseded versions and pre-upgrade snapshots, unchanged |
| `config/testnet.manifest.json` | What is deployed: ids, transactions, notes |
| `config/scenarios/` | Fixtures for the command-line harness |
| `docs/` | `ARCHITECTURE.md` (the spec), `PUBLIC_STATE.md` (every public mapping, what it reveals, Hewn's use, tests), `migrations/` (every deployed change), `operations/` (the CLI path), `archive/` (the record of what was retired) |
| `scripts/` | CI checks and the execute harness; see its README |
| `.github/workflows/` | See below |

## Workflows

| Workflow | Trigger | Does |
|---|---|---|
| `deploy.yml` (the plan gate) | Every push and pull request | The secrets scan, pinned CLI check, manifest schema, the chain check (`scripts/check_chain.py`), the leakage guard, the public-state map check (`docs/PUBLIC_STATE.md`), the archive check, the link check, the Layer 2 funds check, Leo tests for `hewn_letters_v2`, `hewn_jobs_v1`, `employer_agreement_v5`, `hewn_cards_v1`, `hewn_credentials_v1`, `pnw_name_registry_v2`, `pnw_name_registrar_v5`, `pnw_worker_profiles_v2` and `employer_agreement_v4` |
| `deploy_program.yml` (deploy-new-program) | Manual, from `main` only | Deploys one program from `src/layer1/` with the admin key, swapping stubs for the deployed dependencies first. Same two jobs and two runs as the upgrade: the build job's summary shows the program's text and SHA-256 |
| `upgrade_program.yml` (upgrade-admin-program) | Manual, from `main` only | Upgrades an `@admin` program in place. A build job with no key compiles it and writes a summary (the bytecode's SHA-256 and its difference from the edition on chain); the sign job gets the key after approval. Run once with broadcast off, then on with that SHA-256 in `expected_sha256` |
| `chain_watch.yml` (chain-watch) | Daily, or by hand | Reads every program from the explorer, ours and the `watched` ones (the stablecoin and its imports), and fails if its edition or text differs from the manifest (`scripts/check_chain.py`); no secret |
| `generate_sha256.yml` | Manual | Checksums for new Leo and snarkOS release assets when the pins move (release URLs on github.com only, passed as variables); compare with a second download before pinning |

## Toolchain

| Tool | Version | Note |
|---|---|---|
| Leo | 4.0.0 to compile and test; 4.4.6 to sign and send | 4.0.0 (release `v4.0.0` from `aleo-labs-protocol/leo`, checksum pinned) is the language our programs are written in: Leo 4.4 refuses their source (a `const` inside `program { }`, `self.signer`, now `std::ctx::signer()`), so moving it is a Leo change of its own (say so first, INV-22). The deploy and upgrade workflows sign and send with the 4.4.6 release, downloaded and checked against the SHA-256 written in the workflow (never a cache or a build), because only a newer Leo knows today's consensus; 4.4.6 removed self-update and `--disable-update-check`, prints `N tests run: N passed, 0 failed` and writes `build/<name>/<name>.aleo` |
| snarkOS | v4.12.0 | The pair Leo 4.4.6's release names; from `aleo-labs-protocol/snarkOS`, checksum pinned. Leo and snarkOS moved there from ProvableHQ in late October 2026 (the old addresses redirect) |
| Node | 20 | `actions/setup-node` |

Endpoint: `https://api.explorer.provable.com/v2` as the base for `snarkos` and `leo`
(they add the network: `--network 1` is testnet), `https://api.explorer.provable.com/v2/testnet/...`
for REST reads. `.env.example` has every variable; `leo` reads `PRIVATE_KEY`.

## Validation commands

```bash
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
- 2026-10-25 — `hewn_credentials_v1` deployed: a business vouches for a person it has an agreement with, in two private records; public only a commitment with its status and issue height. Issuing checks the pair through `employer_agreement_v5`, so nothing public names the two; no transfer, no fee of its own.
- 2026-10-25 — `hewn_cards_v1` deployed: a business's card and a worker's tenure card, one public entry per name (issue height, shown), bound to the name, no fee of its own. Time on Hewn counts from the card's issue; the registry check runs at issue, so hiding is the app's permission to draw, not an erasure.

## What's next

Mainnet. `.hewn` names move under the Aleo Name Service as a TLD (Hewn's `docs/MAINNET_NAMES.md`),
which needs a registrar program for it (one that keeps a wallet to one kind of name, which v5
doesn't) and a conversation with the ANS team.
The audit design (Hewn's `docs/AUDIT_DESIGN.md`) decides what Layer 2 anchors become. Every program
that will hold real money gets a third-party audit first.
