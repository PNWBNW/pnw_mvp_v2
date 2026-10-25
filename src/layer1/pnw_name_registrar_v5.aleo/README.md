# pnw_name_registrar_v5.aleo

How a name is registered. The registrar takes the payment, checks what needs checking, and writes
the name into `pnw_name_registry_v2.aleo`. It also keeps the readable name (`name_plaintext`,
up to 16 characters packed into a `u128`) so a hash can be turned back into a name: names are
public identities, like domain names.

Upgrades: `@admin`. Deployed on testnet; **edition 1** since the open-registration upgrade of
2026-10-15 (`docs/migrations/2026-10-14-open-registration.md`).

| Function | Does | Hewn |
|---|---|---|
| `register_worker_free(...)` | A worker name, no payment | Used at setup |
| `register_employer_free(...)` | An employer name with its suffix, no payment, no licence check | Used at setup |
| `register_worker_name(...)` | A worker name for 1 USDCx to the foundation treasury | On chain, unused |
| `register_employer_name(...)` | An employer name for 1 USDCx, licence required (`employer_license_registry`) | On chain, unused |
| `fulfill_empl_sellback(...)` | Completes an employer's sellback | On chain, unused |

Rules, the same in every path: one name per wallet, worker names are soulbound. A wallet is meant
to be a worker or an employer but never both; the chain doesn't hold that line yet (the registry
counts the two kinds apart, and the tests record it), Hewn's app does
(`apps/business/src/chain/account_kind.ts`), and the mainnet registrar will (Joshua confirmed the
rule on 2026-10-25; a worker's account can still be a business's customer). The free functions
were appended in the upgrade; the paid ones stay byte-for-byte as deployed, because an upgrade may
not change what a finalize takes in.

The four earlier registrars (`pnw_name_registrar.aleo` to `_v4`) and the pre-upgrade snapshot of
this one are in `../archive/`.

## Tests

`tests/test_pnw_name_registrar_v5.leo`, run by the plan gate (`deploy.yml`): 24 tests, 15 of them
refusals. What must work: a free worker name and a free employer name (suffix 1, 7 and 40) land in
the registry under the signer with the readable name kept beside the hash; the paid paths move
1 USDCx from the signer to the treasury, keep the change, and the employer one needs the licence
registry's flag. What must fail: a second worker name, a second employer name (the registrar always
passes count 0), a free name after a paid one and the reverse, suffix 0 and 41 on both paths, a
paid name with no funds or one micro-USDCx short, an employer name unlicensed, revoked or
unfunded, and a sellback completed by anyone but the treasury. Two tests record that one wallet
can hold both kinds today (above).

The deployed program is never edited. The gate tests a copy with its three network dependencies
pointed at local ones: the stablecoin and licence-registry stubs in `src/stubs/` (seeded with their
test-only `mint_test` and `set_test_verified`), and the real `pnw_name_registry_v2` with its ADMIN
constant set to the registrar's own program address, since the registry gates writes on the
caller being the registrar or ADMIN and the caller of a program the registrar calls is the
registrar. Both copies get `@noupgrade` in place of `@admin` (the local ledger refuses an `@admin`
program whose deployer isn't the admin). Each substitution is asserted before `leo test` runs.
What the tests can't show: a completed sellback (the request must come from the name's owner and
the refund from the treasury, neither of which a test can be) and a name taken by another wallet
(the registry's own tests cover it).
