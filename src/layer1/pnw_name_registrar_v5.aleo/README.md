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

Rules, the same in every path: one name per wallet, a wallet is a worker or an employer but
never both, worker names are soulbound. The free functions were appended in the upgrade; the paid
ones stay byte-for-byte as deployed, because an upgrade may not change what a finalize takes in.

The four earlier registrars (`pnw_name_registrar.aleo` to `_v4`) and the pre-upgrade snapshot of
this one are in `../archive/`.
