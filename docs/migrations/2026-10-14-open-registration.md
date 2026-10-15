# Open registration (2026-10-14, deployed 2026-10-15)

**Live on testnet.**

| Program | Edition | Upgrade tx | Fee tx |
|---|---|---|---|
| `pnw_name_registrar_v5.aleo` | 1 | `at1m77eapnjtp4wxk0lf5y9dyp3j0glxm2umsv8rk0j8nt2ny96xg9q6cgtx6` | `at1vyv2fpc0eanxdcwmqqyhh7r27dfuqjylcptcszlpmh5f0d4ghq9scz3f0e` |
| `employer_agreement_v4.aleo` | 2 | `at17d0f4a442msg92tzgem7s65346s2eway3auvpwalzmnyhngtgqqqe62yjc` | `at1y57hyvancr67dm49jq7fyvqxmc6yc8p8jsswcf50gdg4mt2ng5qs4t3g7y` |

Toolchain that worked: bytecode compiled with Leo 4.0.0, upgrade built and sent by Leo 4.4.5
(crates.io build) with `--consensus-heights` set to snarkVM 4.12.0's testnet table (V21 at
20,234,000, V22 at 20,415,000; Leo 4.4.5's snarkVM 4.11 has both as placeholders, and fee proofs
built for consensus 20 are rejected with "verify_batch failed"). Endpoint `/v2`.

Two `@admin` programs upgraded in place (edition bump, same program ids, same admin
`aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx`). Previous editions are in
`src/layer1/archive/`, unchanged.

## What changes

An upgrade can change what a function does but not what its finalize takes in, so the gated
functions can't simply lose their approval and payment calls (the second check run failed with
"the finalize inputs to the function 'register_worker_name' do not match"). Instead every existing
function stays byte-for-byte as deployed and open copies are appended:

| Program | New function | Same as | Without |
|---|---|---|---|
| `pnw_name_registrar_v5.aleo` | `register_worker_free` | `register_worker_name` | the 1 USDCx transfer |
| | `register_employer_free` | `register_employer_name` | the 1 USDCx transfer and `assert_verified`; `base_price` 0 |
| `employer_agreement_v4.aleo` | `create_offer_open` | `create_job_offer` | `assert_verified` |
| | `pause_employer_open` | `pause_agreement_employer` | `assert_verified` |
| | `terminate_employer_open` | `terminate_agreement_employer` | `assert_verified` |
| | `resume_employer_open` | `approve_resume_employer` | `assert_verified` |

Each agreement copy keeps `pnw_name_registry_v2::assert_is_owner(employer_name_hash, caller)`.
Helpers the copies need (`assert_pay_frequency`, `is_valid_suffix`) are inlined in the copies:
calling a helper twice makes Leo emit it as a closure, which would change the deployed bytecode.

Checked offline with Leo 4.0.0 against the repo's own dependency sources: the new bytecode is the
deployed bytecode with only the new functions appended (no existing line changed), the imports are
unchanged, and the new functions contain no `assert_verified` and no USDCx call. Hewn calls the new
names; the old gated functions stay on chain unused.

## Deploy (Joshua, admin key) — from the phone

Workflow `.github/workflows/upgrade_program.yml` (runs `leo upgrade` with the latest Leo; it
bootstraps 4.0.0 and runs `leo update`). Leo 4.0.0 alone builds and passes the upgrade checks but
only knows consensus up to version 14, so the network rejects its fee proof ("Fee verification
failed … verify_batch"). The check run's "Consensus Version" line should show the network's current
version before broadcasting.

1. Once: GitHub → repo Settings → Environments → `testnet-staging` → add secret
   `ADMIN_PRIVATE_KEY` = the private key of `aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx`.
   (If the existing `ALEO_PRIVATE_KEY` there already is that key, this step can be skipped; the run
   checks and stops if the key belongs to anyone else.)
2. Actions → upgrade-admin-program → Run workflow → program `pnw_name_registrar_v5.aleo`,
   broadcast **off**. Green = it builds against the live network and the key is right.
3. Same again with broadcast **on**.
4. Repeat 2–3 for `employer_agreement_v4.aleo`.

From a laptop instead: `cd src/layer1/<program> && leo upgrade --network testnet --endpoint
https://api.explorer.provable.com/v2 --broadcast` with `PRIVATE_KEY` in `.env`.

Imports: the first check run failed with "Cannot add program … because its import
'employer_license_registry.aleo' must be added first"; both programs keep every import they had.

## Checks after deploy (must fail / must pass)

Run with a fresh test wallet holding only ALEO for fees:

- `register_employer_free(hash("newco"), u128("newco"), 9u8)` from an **unapproved** wallet with no USDCx → **accepted**.
- The old `register_employer_name` from the same kind of wallet → still **rejected** (unchanged).
- Same wallet, `register_worker_free(...)` → **rejected** (one name per wallet).
- Any wallet, `register_employer_free(hash("newco"), …)` again → **rejected** (name taken).
- `register_employer_free(…, 0u8)` or `41u8` → **rejected** (suffix).
- A wallet with **no** name calling `create_offer_open(…)` → **rejected** (`assert_is_owner`).
- "newco" wallet calling `create_offer_open` with its own name hash, unapproved, zero USDCx → **accepted**.

Then: `config/testnet.manifest.json` notes, and in Hewn drop the "needs approval" branch and the
1 USDCx note (`apps/business/src/chain/business_registry.ts`, `RegisterBusiness.tsx`).
