# employer_agreement_v4.aleo

Job offers and the agreements they become. An employer creates an offer: the worker receives a
private `PendingAgreement` record. The worker accepts: three `FinalAgreement` copies are minted,
one each for the worker, the employer and the DAO, and the agreement's anchor height, parties
commitment and status go into public mappings. Everything about the job (terms, pay, the parties'
names) stays inside the records; the chain sees a 32-byte id and a status code.

Upgrades: `@admin`. Deployed on testnet; **edition 2** since 2026-10-15
(`docs/migrations/2026-10-14-open-registration.md`), which appended the `_open` functions.

## Lifecycle

| Function | Who | Does |
|---|---|---|
| `create_offer_open(...)` | Employer | An offer, gated only by owning the employer name. **Hewn uses this.** |
| `accept_job_offer(...)` | Worker | Turns the pending offer into the three `FinalAgreement` records and anchors it. **Hewn uses this.** |
| `pause_employer_open`, `terminate_employer_open`, `resume_employer_open` | Employer | Pause, end or vote to resume, without the licence check |
| `pause_agreement_{employer,worker,dao}` | Each party | Pause (the employer path requires a verified licence) |
| `terminate_agreement_{employer,worker,dao}` | Each party | End |
| `approve_resume_{employer,worker,dao}` then `resume_agreement` | All three | Resuming a paused agreement takes every party's approval (bits in `resume_approvals`) |
| `supersede_agreement(...)` | Employer | Replaces an agreement with a revised one |
| `create_job_offer(...)` | Employer | The original offer path, licence required. On chain, unused by Hewn |

## For other programs

| Function | Checks |
|---|---|
| `assert_agreement_anchored(agreement_id)` | The agreement exists |
| `assert_agreement_active(agreement_id)` | It is active, not paused, ended or superseded |
| `assert_employer_authorized(agreement_id, parties_key, employer_name_hash, worker_name_hash)` | The caller can reproduce the private parties commitment, so they hold a copy of the agreement, and it is active. Credentials mint through this. |

Statuses: pending 0, active 1, paused 2, terminated 3, superseded 4. Pay frequencies: daily 1,
weekly 2, biweekly 3, monthly 4, quarterly 5.

## Public state

`agreement_anchor_height`, `agreement_parties_commitment`, `agreement_status`, `resume_approvals`,
all keyed by the agreement id. The terms themselves never appear: Hewn sends them to the worker as
a sealed letter and the record carries their hash (`terms_doc_hash`, `terms_root`).

v2 and v3, and the snapshot taken before edition 2, are in `../archive/`.

## Tests

`tests/test_employer_agreement_v4.leo`, run by the plan gate (`deploy.yml`): 31 tests, 23 of them
refusals. What must work: an open offer (minted to the worker, the employer as `employer_address`;
public only the anchor height, a commitment, status pending and no approvals), an open-ended offer
(no end date, review on the start), the licensed original with the licence flag, each pay
frequency, `assert_agreement_anchored`, and, from pending, terminate by the business (`_open`),
terminate by the worker, and supersede. What must fail: an offer for a name nobody owns, someone
else owns, or reused id; pay frequency 0 and 6; a zero revision, schema or policy; an end on or
before the start; a review before the start; the licensed original without the flag; pause and
resume from pending; terminate twice, with the wrong parties key, after the name changed hands, or
for an unknown id; supersede twice; `assert_agreement_active` and `assert_employer_authorized` on
a pending offer; the anchored check on an unknown id; and a DAO path from a caller that isn't the
DAO.

The deployed program is never edited. The gate tests a copy with `@noupgrade` in place of `@admin`
(the local ledger refuses an `@admin` program whose deployer isn't the admin) and its two network
dependencies pointed at the stubs in `src/stubs/`, whose `assert_is_owner` and `assert_verified`
are the deployed ones and whose test-only `register_test_name` and `set_test_verified` seed them;
the substitutions are asserted before `leo test`.

What the tests can't show: `accept_job_offer`. It consumes the `PendingAgreement` the offer minted
to the worker, and a record minted inside a test belongs to the test program, which no signer can
spend. So no test reaches ACTIVE, and the paths that need it (pause, approving and completing a
resume, the two active-state assertions) are shown refusing from pending, not succeeding.
`employer_agreement_v5`, the successor, has the full lifecycle under test (22 tests).
