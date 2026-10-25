# Public state on chain

Every public mapping in the programs under `src/layer1/` and `src/layer2/`: what it holds, what a
watcher learns from it, whether Hewn calls the program, and whether the program has Leo tests in
the plan gate. This is the page an auditor starts from; each program's README says more. A
mapping's keys and values are readable by anyone, and so are a transaction's public inputs and
finalize arguments (each program README's "What is public" covers those).

CI keeps this page complete (`scripts/check_public_state.py`, in the plan gate): it fails when a
mapping in a program's source is missing here, when a row names one that doesn't exist, when an
active program in `config/testnet.manifest.json` isn't listed, or when the "Tests" column doesn't
match the Leo tests `deploy.yml` runs.

Rules this page answers to (`CLAUDE.md`, Privacy): no plaintext identity, wage, address or
business data in public state; no cumulative counters (they leak wages by difference); mappings
hold hashes, commitments, statuses and block heights. Where a row departs from that, the reason
is in the row.

**Hewn calls:** *yes* (the app calls it today), *read* (the app only reads it), *planned* (named
in Hewn's plans), *no* (deployed, not called). **Tests:** *yes* when the plan gate runs the
program's Leo tests.

## Layer 1

| Program | Mapping | Key → value | What a watcher learns | Hewn calls | Tests |
|---|---|---|---|---|---|
| `pnw_name_registry_v2.aleo` | `name_owner` | `field` → `address` | Which account owns a name hash. Public by design, as a domain's owner is | read | yes |
| `pnw_name_registry_v2.aleo` | `name_kind` | `field` → `u8` | Whether a name is a person's or a business's | read | yes |
| `pnw_name_registry_v2.aleo` | `employer_suffix_code` | `field` → `u8` | A business name's industry code | read | yes |
| `pnw_name_registry_v2.aleo` | `worker_primary_name_of` | `address` → `field` | An account's person name hash (the reverse of `name_owner`) | read | yes |
| `pnw_name_registry_v2.aleo` | `employer_primary_name_of` | `address` → `field` | An account's business name hash | read | yes |
| `pnw_name_registry_v2.aleo` | `employer_name_count` | `address` → `u8` | How many business names an account holds. A count of names, not of money | read | yes |
| `pnw_name_registry_v2.aleo` | `employer_base_paid` | `field` → `u128` | The price paid to the registry for a business name: a business-level fee, never a wage. Free since 2026-10-15, so 0 for new names | read | yes |
| `pnw_name_registry_v2.aleo` | `sellback_seller` | `field` → `address` | Which account sold a name back to the registry | no | yes |
| `pnw_name_registry_v2.aleo` | `sellback_refund_amount` | `field` → `u128` | The refund for a name sold back: a registry fee, never a wage | no | yes |
| `pnw_name_registry_v2.aleo` | `authorized_caller` | `u8` → `address` | Which registrar program may write names | no | yes |
| `pnw_name_registrar_v5.aleo` | `name_plaintext` | `field` → `u128` | The name itself, encoded (the reverse resolver). Public by design, like the name | read | yes |
| `pnw_worker_profiles_v2.aleo` | `profile_anchor_height` | `[u8; 32]` → `u32` | That a profile with this hash exists, and the block it was anchored at. The profile stays in a private record | yes | yes |
| `employer_profiles_v2.aleo` | `profile_anchor_height` | `[u8; 32]` → `u32` | That an employer profile hash exists, and when | no | no |
| `employer_license_registry.aleo` | `is_verified` | `address` → `bool` | Which accounts the licence authority verified. Unused since open registration (2026-10-15) | no | no |
| `employer_license_registry.aleo` | `license_hash_of` | `address` → `field` | A hash of an account's licence documents. Unused since open registration | no | no |
| `employer_agreement_v4.aleo` | `agreement_anchor_height` | `[u8; 32]` → `u32` | That an agreement id exists, and when it was made | read | yes |
| `employer_agreement_v4.aleo` | `agreement_parties_commitment` | `[u8; 32]` → `field` | A hash over the parties, not who they are. v4's transactions do put both name hashes and accounts in their public finalize arguments, which is why v5 exists | read | yes |
| `employer_agreement_v4.aleo` | `agreement_status` | `[u8; 32]` → `u8` | An agreement's status (pending, active, paused, ended) | read | yes |
| `employer_agreement_v4.aleo` | `resume_approvals` | `[u8; 32]` → `u8` | Which side has approved resuming a paused agreement | read | yes |
| `employer_agreement_v5.aleo` | `agreement_anchor_height` | `[u128; 2]` → `u32` | That an agreement id exists, and when. Nothing public names either party | yes | yes |
| `employer_agreement_v5.aleo` | `agreement_status` | `[u128; 2]` → `u8` | An agreement's status (0 pending, 1 active, 2 paused, 3 ended, 4 withdrawn) | yes | yes |
| `employer_agreement_v5.aleo` | `resume_approvals` | `[u128; 2]` → `u8` | Which side has approved resuming | yes | yes |
| `employer_agreement_v5.aleo` | `end_approvals` | `[u128; 2]` → `u8` | Which side has approved ending by agreement. The reason stays private | yes | yes |
| `employer_agreement_v5.aleo` | `pair_status` | `field` → `u8` | A pair tag's status. The tag is a pseudonym: a watcher can count how often one agreement is checked, never who it is | yes | yes |
| `hewn_jobs_v1.aleo` | `posting_count` | `u8` → `u32` | How many job posts there have ever been (key 0). Counts ads, not money | yes | yes |
| `hewn_jobs_v1.aleo` | `posting_at` | `u32` → `field` | The i-th post's id, so the board can be walked | yes | yes |
| `hewn_jobs_v1.aleo` | `postings` | `field` → `Posting` | A job ad: the employer's name hash, when posted, open, featured until, the advertised pay range, type, hours, place. Public by design: an ad is for anyone to read, and its pay range is an offer, not anyone's wage | yes | yes |
| `hewn_jobs_v1.aleo` | `posting_body` | `field` → `Body` | The ad's text | yes | yes |
| `hewn_cards_v1.aleo` | `cards` | `field` → `Card` | A name's card: the block it was issued at (time on Hewn) and whether a worker shows it | yes | yes |
| `hewn_credentials_v1.aleo` | `credential_status` | `field` → `u8` | A credential commitment's status (offered, active, revoked, declined). No name, no account | yes | yes |
| `hewn_credentials_v1.aleo` | `credential_anchor` | `field` → `u32` | The block a credential was issued at | yes | yes |
| `payroll_audit_log.aleo` | `audit_event_height` | `[u8; 32]` → `u32` | That a 32-byte hash was anchored, and when. The monthly seal will use it (Hewn's `docs/AUDIT_DESIGN.md`) | planned | no |
| `payroll_core_v2.aleo` | `paid_epoch` | `PaidEpochKey` → `bool` | That an agreement id was paid in an epoch, never how much. Unused since 2026-10-14 | no | no |
| `paystub_receipts.aleo` | `receipt_anchor_height` | `[u8; 32]` → `u32` | That a receipt hash was anchored, and when. Unused since 2026-10-14 | no | no |

No public mappings: `hewn_letters_v2.aleo` (letters are private records; the chain is the
mailbox) and `pnw_router_v4.aleo` (routes calls, keeps nothing).

## Layer 2

None of these is called by Hewn today; they wait on the audit design.

| Program | Mapping | Key → value | What a watcher learns | Hewn calls | Tests |
|---|---|---|---|---|---|
| `audit_nft.aleo` | `auth_anchor_height` | `[u8; 32]` → `u32` | That an audit authorization exists, and when | no | no |
| `audit_nft.aleo` | `auth_status` | `[u8; 32]` → `u8` | An authorization's status | no | no |
| `audit_nft.aleo` | `auth_expires_epoch` | `[u8; 32]` → `u32` | When an authorization expires | no | no |
| `audit_nft.aleo` | `auth_revoked_height` | `[u8; 32]` → `u32` | When an authorization was revoked | no | no |
| `audit_nft.aleo` | `attestation_anchor_height` | `[u8; 32]` → `u32` | That an attestation exists, and when | no | no |
| `audit_nft.aleo` | `attestation_auth_id` | `[u8; 32]` → `[u8; 32]` | Which authorization an attestation was made under | no | no |
| `credential_nft_v3.aleo` | `credential_anchor_height` | `[u8; 32]` → `u32` | That a credential exists, and when | no | no |
| `credential_nft_v3.aleo` | `credential_status` | `[u8; 32]` → `u8` | A credential's status | no | no |
| `credential_nft_v3.aleo` | `credential_revoked_height` | `[u8; 32]` → `u32` | When it was revoked | no | no |
| `credential_nft_v3.aleo` | `credential_issuer` | `[u8; 32]` → `address` | The issuing account, in public. One reason `hewn_credentials_v1` replaced it | no | no |
| `credential_nft_v3.aleo` | `scope_anchor_height` | `[u8; 32]` → `u32` | That a scope hash was anchored, and when | no | no |
| `credential_nft_v4.aleo` | `credential_anchor_height` | `[u8; 32]` → `u32` | Staged, never deployed. As v3 | no | no |
| `credential_nft_v4.aleo` | `credential_status` | `[u8; 32]` → `u8` | Staged. As v3 | no | no |
| `credential_nft_v4.aleo` | `credential_revoked_height` | `[u8; 32]` → `u32` | Staged. As v3 | no | no |
| `credential_nft_v4.aleo` | `credential_issuer` | `[u8; 32]` → `address` | Staged. As v3: the issuing account in public | no | no |
| `credential_nft_v4.aleo` | `scope_anchor_height` | `[u8; 32]` → `u32` | Staged. As v3 | no | no |
| `payroll_nfts_v2.aleo` | `nft_anchor_height` | `[u8; 32]` → `u32` | That a payroll-cycle anchor exists, and when | no | no |
| `payroll_nfts_v2.aleo` | `nft_status` | `[u8; 32]` → `u8` | Its status | no | no |
| `payroll_nfts_v2.aleo` | `superseded_by` | `[u8; 32]` → `[u8; 32]` | Which anchor replaced it | no | no |

## What this page shows today

- **Counters:** two, neither about money: `employer_name_count` (names an account holds) and
  `posting_count` (job ads ever posted). No mapping adds up a payment.
- **Amounts:** `employer_base_paid` and `sellback_refund_amount` hold registry fees for business
  names, never a person's pay; `postings` holds an ad's advertised range. No wage appears anywhere.
- **Accounts in public:** the registry's own job (who owns a name), the licence registry (unused),
  and the issuer in `credential_nft_v3`/`v4` (unused, and replaced by `hewn_credentials_v1`).
- **Tests:** 9 of the 19 programs listed have Leo tests in the plan gate. `pnw_name_registry_v2`,
  `pnw_name_registrar_v5`, `pnw_worker_profiles_v2` and `employer_agreement_v4` since 2026-10-25,
  by Joshua's decision (2026-10-25): every deployed program Hewn calls; the rest later if needed.
  Tests only: deployed programs are never edited.
