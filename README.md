# PNW MVP v2 — the Leo programs behind Hewn

The on-chain side of [**Hewn**](https://github.com/PNWBNW/hewn), free, open-source bookkeeping and
payroll on Aleo. These programs register names, hold job agreements, carry sealed letters, run the
public job board and settle private payroll in USDCx. Anything about a person stays in private
records; public state holds hashes, commitments, statuses and block heights, nothing that reads
as a wage or a name.

> **Status:** deployed on Aleo testnet and in daily use by the Hewn app. Mainnet comes after a
> third-party audit. Nothing here is tax, legal or accounting advice.

## How it fits together

```
 Hewn (the app, PNWBNW/hewn)                      Aleo testnet
┌───────────────────────────────┐   signed in   ┌─────────────────────────────────────┐
│ books · payroll · schedule ·  │   Shield      │ Layer 1: names, agreements, letters, │
│ hours · hiring · messages     ├──────────────▶│ the job board, payroll settlement    │
│ (encrypted vault, no server)  │               │ Layer 2: commitment anchors          │
│                               │◀──────────────┤ public state: hashes and heights only│
└───────────────────────────────┘    reads      └─────────────────────────────────────┘
```

Every transaction is signed in the user's Shield wallet. Hewn's `packages/config` takes program
ids from `config/testnet.manifest.json`; nothing hard-codes one.

## What's on chain

| Program | What it does | Hewn today |
|---|---|---|
| **`pnw_name_registry_v2.aleo`** | Who owns which `name.hewn` (worker or employer, with the industry suffix); the ownership checks every other program calls | Read on every lookup |
| **`pnw_name_registrar_v5.aleo`** | Registers names, free since 2026-10-15, and keeps the readable name for reverse lookup | Setup |
| **`pnw_worker_profiles_v2.aleo`** | A worker's private profile record and its anchor | Worker setup |
| **`employer_agreement_v4.aleo`** | Job offers and agreements: a private offer to the worker, three agreement copies on acceptance, pause / end / resume | Offers and acceptance |
| `employer_agreement_v5.aleo` | The two-party rebuild (2026-10-24): the conversation key's public halves in the records, nothing public about who works for whom, a private reason when an agreement ends, a pair tag other programs check | Deployed; Hewn switches next |
| **`hewn_letters_v2.aleo`** | Sealed letters as private records: one, a long page, or one to eight people at once | Every offer, message, timecard, schedule and paystub |
| **`hewn_jobs_v1.aleo`** | The public job board: post ($1 USDCx), update, feature ($5 a day), close | Jobs and Find work |
| **`hewn_cards_v1.aleo`** | The cards every account gets: a business's card and a worker's tenure card, issued once per name; on chain only the issue height and whether it is shown | Issued at setup, next |
| `hewn_credentials_v1.aleo` | A worker's credentials (staged 2026-10-25): a business vouching for a person it has an agreement with, in two private records; public only a commitment, its status and its issue block | Not yet: deploy, then the app draws them as landmarks |
| `employer_license_registry.aleo` | A verified flag per employer, set by the authority | Not required by the free paths |
| `employer_profiles_v2.aleo` | An employer's private profile record | Deployed, not called |
| `pnw_router_v4.aleo` | One entry surface over agreements, profiles and names | Deployed, not called |
| `payroll_core_v2.aleo`, `paystub_receipts.aleo`, `payroll_audit_log.aleo` | One-proof payroll with receipts and audit anchors | Deployed, not called: Hewn pays with one private transfer per worker |
| `payroll_nfts_v2.aleo`, `credential_nft_v3.aleo`, `credential_nft_v4.aleo` (staged), `audit_nft.aleo` | Layer 2 anchors for payroll cycles, credentials and audits | Deployed, waiting on the audit design and credentials |

Each program's folder has a README with its functions and public state; the layer READMEs
([`src/layer1`](src/layer1/README.md), [`src/layer2`](src/layer2/README.md)) have the overview.
`config/testnet.manifest.json` records every deployment with its transaction.

## Privacy rules

- No plaintext identities, wages or addresses in public state. Mappings hold hashes, commitment
  anchors, statuses and block heights.
- No cumulative counters in public mappings: they would leak wages by difference. CI fails on one.
- Layer 2 never moves funds.
- No pooled custody. Money goes from the employer's private records to the worker's, directly.
- A deployed program is never edited. Changes ship as a new version with a migration note; the
  old one is kept in `archive/`, unchanged.

## Finding your way around

| Path | What's there |
|---|---|
| [`src/layer1/`](src/layer1/README.md) | The canonical programs, one folder each with `program.json`, `src/main.leo`, tests and a README |
| [`src/layer2/`](src/layer2/README.md) | The commitment-anchor programs |
| [`src/stubs/`](src/stubs/README.md) | Local stand-ins for the stablecoin and the registry, so programs build and test offline |
| `src/layer1/archive/`, `src/layer2/archive/` | Superseded versions and pre-upgrade snapshots, kept as they were |
| [`config/`](config/README.md) | `testnet.manifest.json`, the source of truth for what is deployed; scenario fixtures |
| [`docs/`](docs/README.md) | The architecture spec, a migration note per deployed change, the CLI operations guide, the archive |
| [`scripts/`](scripts/README.md) | CI checks and the command-line test harness |
| [`portal/`](portal/README.md) | The original planning-layer TypeScript, kept for its type gates; the live copy is in Hewn |
| `.github/workflows/` | The plan gate (every PR), deploy and upgrade (manual, admin key), the execute gate |
| [`CLAUDE.md`](CLAUDE.md) | The rules and context for anyone, person or agent, working here |

## Working here

Toolchain: Leo 4.0.0, snarkOS v4.6.0, Node 20 (pinned in `.github/workflows/deploy.yml`;
`.devcontainer/` installs them). The network enforces ConsensusVersion V14, so programs compiled
with an older Leo are rejected.

```bash
# Test a program (Leo reads a path ending in .aleo as bytecode, so test from a copy without it)
cp -r src/layer1/hewn_jobs_v1.aleo /tmp/hewn_jobs_v1 && cp -r src/stubs /tmp/stubs
cd /tmp/hewn_jobs_v1 && leo test

# The plan-gate checks CI runs on every pull request
python3 scripts/validate_testnet_manifest.py config/testnet.manifest.json
python3 scripts/check_layer1_public_leakage_guards.py
```

Deploying is a workflow, not a laptop: Actions → **deploy-new-program** (a new program) or
**upgrade-admin-program** (an `@admin` program, in place) with the admin key from the repository's
`testnet-staging` secrets. Both are run once with broadcast off, then on. Every deploy gets a note
in `docs/migrations/` and a line in the manifest. Copy `.env.example` to `.env` for local work and
never commit it.

## The first private payroll on testnet (2026-04-10)

| Step | Program | Transaction |
|---|---|---|
| Verify agreement | `employer_agreement_v4` | `at1mydsktdsr8pk7d4utzrp6n2rvtgkkpavthukyt4kpdadgyx5lg8sgljea3` |
| Transfer USDCx | `test_usdcx_stablecoin` | `at1yphn8n9zejqnnsktuev7rl9vkv8styq00rjpffa0h7rxnccssyyqdk9ltw` |
| Mint receipts | `paystub_receipts` | `at1w86wy80c9sgv0e2ukwlzja4r4km0vkld2tna586t9447q6pjvvrqhuvnw4` |
| Anchor event | `payroll_audit_log` | `at1jp6mertn92hpn79uak8vdy9t4ha2t0f4fwq877uy6rmjl20g0syqdzygp3` |
| Mint cycle NFT | `payroll_nfts_v2` | `at1d8ht598hqqjgmqfxjwvt0cf47aqafgynzjhazhtreze6j22hzcrq5992r5` |

How the project got from there to Hewn is told in
[Hewn's README](https://github.com/PNWBNW/hewn#where-it-came-from).

## License

Copyright (C) 2025-2026 Joshua Daniel Day.

Free software under the **GNU Affero General Public License, version 3** (`AGPL-3.0-only`); see
[`LICENSE`](LICENSE). Distributed WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. The Hewn name and logo are not covered.
