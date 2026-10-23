# employer_agreement_v5.aleo

Job offers and the agreements they become, between two parties. **Staged, not deployed**
(2026-10-23, `docs/migrations/2026-10-23-agreement-v5.md`); `employer_agreement_v4.aleo` stays live
until Hewn switches.

What changed from v4, in one line each:

- **Twin-curve from the first letter.** The offer carries the employer's P-256 public half, the
  acceptance the worker's; both ride in every `FinalAgreement` copy. Each side's app makes the
  pair's key from its own private half, which never leaves its vault (Hewn's
  `docs/TWIN_CURVE_CONVERSATIONS.md`). A view key opens the records and sees two public halves,
  not the key.
- **Who works for whom stays off the public chain.** No registry call: nothing names a hash or an
  account in public finalize inputs. The offer binds the signer as the employer inside the record;
  accepting takes the worker's own `PendingAgreement`; every later step takes the holder's own
  `FinalAgreement` and checks the caller's role inside it.
- **Two parties.** No DAO copy, no DAO powers. Resuming takes both approvals. The employer gets a
  `SentOffer` record with the offer, to withdraw it and to rebuild its books on any device.
- **Immutable** (`@noupgrade`): no admin key can change what an agreement means. A change ships
  as `employer_agreement_v6`.

`parties_key` stays: random, chosen by the employer's app, it seals the offer's terms and the
negotiation before acceptance, and names the conversation in both vaults.

## Records

| Record | Owner | Carries |
|---|---|---|
| `PendingAgreement` | the worker | the offer: ids, both name hashes, terms, `employer_half` |
| `SentOffer` | the employer | the same offer, shorter: ids, name hashes, `terms_doc_hash`, `offer_time_hash`, `employer_half` |
| `FinalAgreement` | one copy each | the agreement, with `accept_time_hash`, `employer_half` and `worker_half` |

`owner` is the first field of each record. The other fields keep v4's names, so Hewn's record
readers (`parties_key`, `agreement_id`, `employer_address`, `worker_address`, the name hashes,
`terms_doc_hash`) read v4 and v5 records alike.

## Functions

| Function | Who | Does |
|---|---|---|
| `create_offer(agreement_id, parties_key, employer_name_hash, worker_name_hash, worker_address, terms: OfferTerms, hashes: OfferHashes, employer_half)` | Employer | Mints the `PendingAgreement` to the worker and a `SentOffer` to itself; anchors the id. An offer to yourself is refused. |
| `accept_offer(offer: PendingAgreement, accept_time_hash, worker_half)` | Worker | Mints the two `FinalAgreement` copies; pending → active |
| `withdraw_offer(sent: SentOffer)` | Employer | An offer not yet accepted: pending → terminated |
| `pause_employer(a)`, `pause_worker(a)` | Each party, with its copy | active → paused; the copy comes back |
| `terminate_employer(a)`, `terminate_worker(a)` | Each party | → terminated |
| `approve_resume_employer(a)`, `approve_resume_worker(a)`, then `resume(a)` | Both, then either | paused → active once both approved |
| `assert_agreement_anchored(id)`, `assert_agreement_active(id)`, `assert_employer_authorized(id, parties_key, employer_name_hash, worker_name_hash)` | Other programs | As v4: exists; is active; the caller can reproduce the parties commitment and it is active |

`OfferTerms { industry_code, pay_frequency_code, start_epoch, end_epoch, review_epoch,
agreement_rev, schema_v, policy_v }` and `OfferHashes { terms_doc_hash, terms_root,
offer_time_hash }` group the offer's inputs: a transition takes 16 at most, and the offer has 17.

Statuses: pending 0, active 1, paused 2, terminated 3. Pay frequencies: daily 1, weekly 2,
biweekly 3, monthly 4, quarterly 5.

## Public state

`agreement_anchor_height`, `agreement_parties_commitment`, `agreement_status`, `resume_approvals`,
keyed by the agreement id (32 random bytes). The commitment is the same BHP1024 hash as v4 over
(`parties_key`, both name hashes), so a credential program written against v4's
`assert_employer_authorized` carries over. Nothing public names a person, a business or an account.

## Tests

`tests/test_employer_agreement_v5.leo`, run by the plan gate: what an offer mints, withdrawing,
the public state, and eleven refusals (an offer to yourself, acceptance by someone the offer
didn't go to, the same id twice, a withdrawn offer taken for active, a bad pay frequency, an end
before the start, a review before the start, a zero revision, an unknown id, a pending offer taken
for active, the wrong parties key). Every test runs as one signer, who can't be both parties, so
acceptance and the lifecycle after it are checked on the network at deploy time (the migration
note has the list).
