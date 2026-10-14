# Open registration (2026-10-14)

Two `@admin` programs upgraded in place (edition bump, same program ids, same admin
`aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx`). Previous editions are in
`src/layer1/archive/`, unchanged.

## What changes

| Program | Before | After |
|---|---|---|
| `pnw_name_registrar_v5.aleo` | `register_worker_name` / `register_employer_name` took 1 USDCx (`transfer_public_as_signer`) and the employer one asserted `employer_license_registry::assert_verified(signer)` | Both free, no approval. `base_price` recorded as 0, so a sellback refunds nothing (`fulfill_empl_sellback` asserts `refund == 0`). Imports: only `pnw_name_registry_v2`. |
| `employer_agreement_v4.aleo` | `create_job_offer`, `pause_agreement_employer`, `terminate_agreement_employer`, `approve_resume_employer` asserted `assert_verified(caller)` | Only `pnw_name_registry_v2::assert_is_owner(employer_name_hash, caller)` remains: the caller must own the business name on the agreement. Import of `employer_license_registry` dropped. |

Unchanged: `pnw_name_registry_v2` (still authorizes the registrar as caller), `employer_license_registry`
(`@noupgrade`; simply no longer called by these two), one-name-per-wallet, suffix 1..40, every record
and mapping. A price can come back later by reintroducing the transfer in the registrar.

## Deploy (Joshua, admin key) — from the phone

Workflow `.github/workflows/upgrade_program.yml` (runs `leo upgrade`, Leo 4.0.0, the same toolchain
that upgraded `employer_agreement_v4` in April):

1. Once: GitHub → repo Settings → Environments → `testnet-staging` → add secret
   `ADMIN_PRIVATE_KEY` = the private key of `aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx`.
   (If the existing `ALEO_PRIVATE_KEY` there already is that key, this step can be skipped; the run
   checks and stops if the key belongs to anyone else.)
2. Actions → upgrade-admin-program → Run workflow → program `pnw_name_registrar_v5.aleo`,
   broadcast **off**. Green = it builds against the live network and the key is right.
3. Same again with broadcast **on**.
4. Repeat 2–3 for `employer_agreement_v4.aleo`.

From a laptop instead: `cd src/layer1/<program> && leo upgrade --network testnet --endpoint
https://api.explorer.provable.com/v1 --broadcast` with `PRIVATE_KEY` in `.env`.

If the network rejects an edition because the import list changed, restore the removed import lines
(unused) and run again.

## Checks after deploy (must fail / must pass)

Run with a fresh test wallet holding only ALEO for fees:

- `register_employer_name(hash("newco"), u128("newco"), 9u8)` from an **unapproved** wallet → **accepted** (was rejected).
- Same wallet, `register_worker_name(...)` → **rejected** (one name per wallet).
- Any wallet, `register_employer_name(hash("newco"), …)` again → **rejected** (name taken).
- `register_employer_name(…, 0u8)` or `41u8` → **rejected** (suffix).
- A wallet with **no** name calling `create_job_offer(…)` → **rejected** (`assert_is_owner`).
- "newco" wallet calling `create_job_offer` with its own name hash, unapproved, zero USDCx → **accepted**.
- `fulfill_empl_sellback` with `refund != 0` → **rejected**.

Then: `config/testnet.manifest.json` notes, and in Hewn drop the "needs approval" branch and the
1 USDCx note (`apps/business/src/chain/business_registry.ts`, `RegisterBusiness.tsx`).
