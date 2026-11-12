# 2026-11-11 — Two upgrades and one deployment found on chain, and the check that finds the next

A security review on 2026-11-11 read every program from the explorer and compared it with this
repository. The programs on chain match the source function for function. Three things the
record here didn't say:

| Program | What the chain shows | What the record said |
|---|---|---|
| `pnw_name_registry_v2.aleo` | Edition 1. Against edition 0 it adds the mapping `employer_primary_name_of`, the function `set_primary_employer_name`, and seven instructions inside the existing finalize of `register_employer_name` that set a first primary name | The manifest's note said "upgraded with resolver mappings". No migration note; edition 0 not archived |
| `payroll_core_v2.aleo` | Edition 1. Against edition 0 it changes one argument of the stablecoin's `transfer_private` call inside the existing `execute_payroll` and `execute_payroll_batch_2`: the recipient is `r3.worker_addr` (and `r4.worker_addr` for the second worker) where edition 0 passed `r1` | Nothing. No upgrade in the manifest, no migration note, edition 0 not archived |
| `credential_nft_v4.aleo` | Deployed at edition 0 | No manifest entry; `docs/PUBLIC_STATE.md` said "staged, never deployed" |

Neither upgrade looks like anything but a fix made at the time. They are written down here
because the second one shows what an upgrade is: a change to the logic inside functions people
already use, with the same name, inputs and outputs, which a wallet proves against without
saying that anything changed. When either upgrade was made, and its transaction, were not
recorded and are not reconstructed here.

## What an upgrade can do

From snarkVM 4.12.0, `check_upgrade_is_valid`: an upgrade can add imports, mappings, structs,
records, closures and functions, and it can change the logic of any existing function or
finalize. It can't delete anything, change a mapping, struct or record, change a function's
inputs or outputs, or touch the constructor. This file's neighbour of 2026-10-14 says an upgrade
"can append functions"; that was the part used then, not the whole of it.

One address is the `@admin` of ten live programs (the registry, the registrar, worker profiles,
employer profiles, `employer_agreement_v4`, `payroll_core_v2`, `paystub_receipts`,
`pnw_router_v4`, `credential_nft_v3`, `credential_nft_v4`) and of eleven archived ones that are
still deployed. The address is fixed in each constructor, so the key can't be replaced.

## The check

`config/testnet.manifest.json` now records, for all 35 of our programs on chain, the edition and
the SHA-256 of the program text there. `scripts/check_chain.py` reads the chain and fails on any
difference; the plan gate runs it on every pull request and `chain-watch` runs it every day. A
deliberate deploy or upgrade records itself with `--write` in its own pull request, with its
migration note.

Eleven archived programs that are still deployed had no manifest entry; they have one now, so
they are watched too.
