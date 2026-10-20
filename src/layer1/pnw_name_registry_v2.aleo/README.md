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
move under the Aleo Name Service as the `hewn` TLD (Hewn's `BUILD_PLAN.md`, "Mainnet names").
