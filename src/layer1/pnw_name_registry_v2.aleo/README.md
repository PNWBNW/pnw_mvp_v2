# pnw_name_registry_v2.aleo

The registry of names: which wallet owns which name hash, whether it is a worker's or an
employer's, and an employer's industry suffix (codes 1 to 40). It stores names and nothing else;
paying for one is the registrar's job (`pnw_name_registrar_v5.aleo`), which is the only program
allowed to write here.

Upgrades: `@admin`. Deployed on testnet (`config/testnet.manifest.json`).

## What other programs call

| Function | Checks |
|---|---|
| `assert_is_owner(name_hash, owner)` | `owner` holds that name |
| `assert_employer_owner(name_hash, owner, suffix_code)` | `owner` holds that employer name with that suffix |

Every program that needs to know who someone is calls one of these: offers and agreements, the job
board, credentials. Hewn reads the mappings directly for name lookups.

## What the registrar calls

| Function | Does |
|---|---|
| `register_worker_name(name_hash, owner)` | One worker name per wallet, soulbound |
| `register_employer_name(...)` | An employer name with its suffix; records the base price paid |
| `release_worker_name()` | Gives a worker name up |
| `request_empl_sellback(name_hash)` / `fulfill_empl_sellback(...)` | An employer name sold back, with its refund |
| `set_primary_employer_name(name_hash)` | Which of an employer's names is primary |
| `set_authorized_caller(registrar_addr)` | Admin only: which registrar may write |

## Public state

`name_owner`, `name_kind`, `employer_suffix_code`, `worker_primary_name_of`,
`employer_primary_name_of`, `employer_name_count`, `employer_base_paid`, `sellback_seller`,
`sellback_refund_amount`, `authorized_caller`. A name hash is public, as a domain name is; the
plaintext behind it lives in the registrar's reverse resolver.

Superseded v1 (`pnw_name_registry.aleo`, `@noupgrade`) is in `../archive/`. On mainnet, names
move under the Aleo Name Service as the `hewn` TLD (Hewn's `docs/MAINNET_NAMES.md`).

## Tests

`tests/test_pnw_name_registry_v2.leo`, run by the plan gate (2026-10-25): 30 tests, 20 of them
refusals. What must work: the admin naming the registrar and a worker registration; three business
names with the count the app passes matching the chain's; a worker name passing the employer check
with code 0 (what `hewn_cards_v1` passes for a worker card); a free name selling back for 0 and a
paid one for three quarters; a sold-back name free again and the count dropping; a released worker
name free again and the worker able to take another; setting the primary name. What must fail: a
second worker name, a taken name (worker or business, or a worker taking a business's), suffix 0
and 41, a count that doesn't match, a fourth name, release with no name or of someone else's,
sellback by a non-owner or of a worker name, fulfilment with no request or the wrong refund or
seller, setting primary on a name not owned or a worker name, and the two guards with the wrong
owner, the wrong code, or after a sellback.

The deployed program is never edited. The copy the tests run against differs on two marked
lines, so they can run offline: `ADMIN` is the test program's own address (the registry gates its
writes on the caller being the registrar or ADMIN, and a program's caller inside a test is the
test program, `aleo1lmfa…` for `test_pnw_name_registry_v2.aleo`), and the constructor is
`@noupgrade` (the local test ledger refuses to deploy an `@admin` program for a deployer who isn't
the admin). The gate checks both substitutions took. What this can't show: a stranger program
being refused as registrar, since the one caller in a test is the admin.
