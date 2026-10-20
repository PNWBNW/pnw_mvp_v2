# Layer 1 archive

Programs that are no longer the live version, kept exactly as they were. Nothing here is built,
tested or deployed by CI, and nothing live depends on it. It stays because a deployed Aleo program
can't be taken off the chain, only left unused, and because the history of how each one changed is
worth keeping next to its successor.

Two kinds of folder live here:

| Pattern | What it is | Example |
|---|---|---|
| `<program>.aleo/` | A whole version that was superseded by a later one. The live version is in `src/layer1/`. | `pnw_name_registrar_v4.aleo/` → superseded by `pnw_name_registrar_v5.aleo` |
| `<program>.aleo-<date>/` | A snapshot of a still-live `@admin` program, taken just before it was upgraded in place on that date. | `employer_agreement_v4.aleo-2026-04-12/` |

What's here, and what replaced it:

| Archived | Replaced by | Why |
|---|---|---|
| `pnw_name_registry.aleo` (v1, `@noupgrade`) | `pnw_name_registry_v2.aleo` | v1 mixed payments into the registry; v2 is pure name storage behind an authorised registrar |
| `pnw_name_registrar.aleo`, `_v2`, `_v3`, `_v4` | `pnw_name_registrar_v5.aleo` | one name per wallet, reverse resolver, then free registration (v5 edition 1) |
| `employer_agreement_v2.aleo`, `_v3` | `employer_agreement_v4.aleo` | three-party `FinalAgreement` records; v4 added `assert_employer_authorized` and the open offer paths |
| `employer_profiles.aleo` | `employer_profiles_v2.aleo` | re-pointed at the v2 registry |
| `pnw_worker_profiles.aleo` | `pnw_worker_profiles_v2.aleo` | re-pointed at the v2 registry |
| `pnw_router_v2.aleo`, `_v3` | `pnw_router_v4.aleo` | re-pointed at `employer_agreement_v4` |
| `payroll_core.aleo` | `payroll_core_v2.aleo` | the Leo v4 rebuild; Hewn pays with a plain private transfer today, so neither is called by the app |
| `hewn_letters_v1.aleo-2026-10-18` | `hewn_letters_v2.aleo` | v2 added `send_many`; v1 is still deployed and Hewn still reads letters sent with it |
| `employer_agreement_v4.aleo-2026-04-12` | the live `employer_agreement_v4.aleo` (edition 2) | pre-upgrade snapshot |
| `pnw_name_registrar_v5.aleo-2026-03-28` | the live `pnw_name_registrar_v5.aleo` (edition 1) | pre-upgrade snapshot |

A note on `program.json`: some of these point at sibling programs by relative path
(`"path": "../employer_profiles_v2.aleo"`). Those paths assume the folder's old place in
`src/layer1/`. To build one again, move it back up a level first; don't edit the archived copy.

Which program is live is decided by one file: `config/testnet.manifest.json`.
