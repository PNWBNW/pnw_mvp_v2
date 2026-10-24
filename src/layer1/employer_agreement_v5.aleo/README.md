# employer_agreement_v5.aleo

Job offers and the agreements they become, between two parties. **Deployed 2026-10-24**
(transaction `at1pvypp6lknqz7u7rs8af2qc8r5k2wgds7x3sct6xtdjs0t70feu9ssx6j3k`, block 20793785;
staged 2026-10-23 and locked in before the deploy, `docs/migrations/2026-10-23-agreement-v5.md`).
`employer_agreement_v4.aleo` stays live: it holds the agreements already made, and Hewn sends new
offers to it until it switches.

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
- **Two parties.** No DAO copy, no DAO powers. Resuming takes both approvals, and so does ending
  by mutual agreement. The employer gets a `SentOffer` record with the offer, to withdraw it and
  to rebuild its books on any device.
- **The pair tag** (2026-10-24). One BHP1024 hash over the agreement's random `parties_key` and
  the two accounts. The status is kept under it as well as under the id, so another program
  (paystubs, reviews) proves "the caller holds an agreement with this person, and it is active"
  from private inputs: `assert_pair_active`, `assert_pair_agreed`. v4's `assert_agreement_*`
  helpers, which took the agreement id as a public input, are gone.
- **Packed bytes** (2026-10-24). Every 32-byte value is `[u128; 2]`, the high half first (as
  `hewn_letters_v2`'s `lookup`); every 64-byte half is `[u128; 4]`. Twenty words in the records
  instead of three hundred and twenty bytes.
- **A reason when an agreement ends** (Joshua, 2026-10-24), private: in the ending party's own
  copy (`end_reason`) and in an `AgreementEnd` record minted to the other party. Each party has
  its own reasons (below). Nothing about the reason reaches public state.
- **Immutable** (`@noupgrade`): no admin key can change what an agreement means. A change ships
  as `employer_agreement_v6`.

`parties_key` stays: random, chosen by the employer's app, it seals the offer's terms and the
negotiation before acceptance, names the conversation in both vaults, and now makes the pair tag.
A zero key is refused, and a key can't be used for two offers (its tag would already exist).

## Records

| Record | Owner | Carries |
|---|---|---|
| `PendingAgreement` | the worker | the offer: ids, both name hashes, terms, `employer_half` |
| `SentOffer` | the employer | the same offer, shorter: ids, name hashes, `terms_doc_hash`, `offer_time_hash`, `employer_half` |
| `FinalAgreement` | one copy each | the agreement, with `accept_time_hash`, `employer_half`, `worker_half`, `end_reason` (0 while it runs; set only in the copy of the party that ended it) |
| `AgreementEnd` | the party that did not end it | `agreement_id`, `parties_key`, `ended_by`, `reason` |

`owner` is the first field of each record. The other fields keep v4's names; their byte arrays
became `[u128; 2]` (`agreement_id`, `parties_key`, the hashes) and `[u128; 4]` (the halves), so
Hewn's readers tell a v4 record from a v5 one by the element type.

## Functions

| Function | Who | Does |
|---|---|---|
| `create_offer(agreement_id, parties_key, employer_name_hash, worker_name_hash, worker_address, terms: OfferTerms, hashes: OfferHashes, employer_half)` | Employer | Mints the `PendingAgreement` to the worker and a `SentOffer` to itself; anchors the id and the pair tag. An offer to yourself, a zero key or a used key is refused. |
| `accept_offer(offer: PendingAgreement, accept_time_hash, worker_half)` | Worker | Mints the two `FinalAgreement` copies; pending → active |
| `withdraw_offer(sent: SentOffer)` | Employer | An offer not yet accepted: pending → withdrawn |
| `pause_employer(a)`, `pause_worker(a)` | Each party, with its copy | active → paused; the copy comes back |
| `approve_resume_employer(a)`, `approve_resume_worker(a)`, then `resume(a)` | Both, then either | paused → active once both approved |
| `terminate_employer(a, reason)`, `terminate_worker(a, reason)` | Each party | active or paused → ended; the copy comes back with the reason, an `AgreementEnd` goes to the other party |
| `approve_end_employer(a)`, `approve_end_worker(a)`, then `end_mutual(a)` | Both, then either | → ended with reason 5, the `AgreementEnd` to the other party |
| `assert_pair_active(parties_key, employer, worker)`, `assert_pair_agreed(parties_key, employer, worker)` | Other programs | The tag's status is active; or the two did agree at some point (active, paused or ended: not pending, not withdrawn) |

`OfferTerms { industry_code, pay_frequency_code, start_epoch, end_epoch, review_epoch,
agreement_rev, schema_v, policy_v }` and `OfferHashes { terms_doc_hash, terms_root,
offer_time_hash }` group the offer's inputs: a transition takes 16 at most.

Statuses: pending 0, active 1, paused 2, ended 3, withdrawn 4. Pay frequencies: daily 1, weekly
2, biweekly 3, monthly 4, quarterly 5.

End reasons, and who may give each: resigned 1 (the worker), laid off 2 (the employer), contract
finished 3 (either), let go 4 (the employer), mutual 5 (only through `end_mutual`, after both
approved). A reason outside a party's own list is refused in the transition.

## Public state

By agreement id (`[u128; 2]`): `agreement_anchor_height`, `agreement_status`, `resume_approvals`,
`end_approvals`. By pair tag (`field`): `pair_status`. Nothing public names a person, a business
or an account.

**The tag is a pseudonym.** It never reveals who the parties are or which agreement it is, but it
is the same value every time a program checks it, so a watcher can count how often an agreement
is checked (a paystub a week, say) without learning anything else. Each agreement has its own
tag: a rehire gets a new key and a new tag.

## Tests

`tests/test_employer_agreement_v5.leo`, run by the plan gate: 22 tests, 18 of them refusals (an
offer to yourself, acceptance by someone the offer didn't go to, the same id twice, the same key
twice, a zero key, withdrawing twice, a withdrawn offer taken for agreed or active, a bad pay
frequency, an end before the start, a review before the start, a zero revision, an unknown pair
taken for active or agreed, a pending offer taken for active or agreed, the wrong key, the wrong
worker). Every test runs as one signer, who can't be both parties, so acceptance and the
lifecycle after it (pause, resume, the three ways of ending and their reasons) are checked on the
network with two test wallets (the migration note has the list; not run yet).
