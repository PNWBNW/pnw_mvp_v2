# employer_agreement_v5 (2026-10-23, staged)

**Not deployed yet.** `employer_agreement_v4.aleo` stays live; Hewn keeps reading v4 records for
the agreements already made.

## Why a new version

Three decisions in Hewn's `BUILD_PLAN.md` land on the agreement program at once, and a deployed
program can't change, so they ship together:

1. **Twin-curve from the first letter** (step 4 of the twin-curve order, 2026-10-23). Hewn's
   conversations between a business and a person it hired now move to a key made by P-256 key
   exchange, with the public halves riding on letters. v5 carries the halves in the records
   instead: the employer's in the offer, the worker's in the acceptance, both in every
   `FinalAgreement` copy. Each side's app makes the pair's key from its own private half (kept in
   its vault at offer or acceptance time), so the very first letter after acceptance is sealed
   under a key no view key can reach.
2. **Who works for whom stays off the public chain** (the security review, 2026-10-22). v4's
   `create_offer_open` and `accept_job_offer` call `pnw_name_registry_v2::assert_is_owner(name_hash,
   address)`, whose finalize inputs are public: both names' hashes and both accounts show in the
   transaction. v5 calls nothing. The offer binds the signer as the employer inside the private
   record; accepting takes the worker's own `PendingAgreement` and checks `worker_address ==
   self.signer`; pause, terminate and resume take the holder's own `FinalAgreement` and check the
   caller's role inside it. The app checks name ownership off chain, as it already does for every
   offer and application. The only public finalize inputs are the agreement id and the parties
   commitment.
3. **Two parties** (2026-10-20: on mainnet, agreements carry no DAO copy and no DAO powers). No
   third copy, no DAO functions; resuming takes both parties' approval. The employer gets a
   `SentOffer` record with the offer, so it can withdraw privately (v4's withdraw took the name
   hashes as public inputs) and rebuild its books on any device.

Also: `@noupgrade`, in line with "no program can be upgraded on mainnet"; the licence-gated
originals (`create_job_offer` and the `_employer` variants that called
`employer_license_registry`) are gone, Hewn never used them; and the offer's 16 inputs became 17
with the half, over the limit, so the eight numeric terms travel as one `OfferTerms` struct and
the three hashes as one `OfferHashes`.

No imports, so the program builds and tests offline with no stubs.

## Checked offline

Leo 4.0.0 (the release zip, SHA-256 `95bcda063c8f0abad5f7484f5f6dbf9e5608bf0e5ce78082e2da8469366df705`;
compare with the repository variable `LEO_SHA256`, which this session couldn't read): the program
compiles to valid bytecode (15.7 KB), and `leo test` passes 15 of 15
(`src/layer1/employer_agreement_v5.aleo/tests/`). Every test runs as one signer, who can't be both
parties (an offer to yourself is refused), so the tests cover the offer, withdrawing, the public
state and eleven refusals; acceptance and the lifecycle after it are checked on the network below.

## Deploy (Joshua, admin key as the deployer) — from the phone

Workflow `.github/workflows/deploy_program.yml`: Actions → deploy-new-program → Run workflow →
program `employer_agreement_v5.aleo`, broadcast **off** (green = it builds against the live network
and the key can pay). Then again with broadcast **on**. Expect a deployment in the range of
`hewn_letters_v2` (21.6 credits): the acceptance mints two large records.

Then, in this repository, one PR: `config/testnet.manifest.json` (`program_ids.layer1.employer_agreement`
→ v5, the deployment entry with its transaction ids, v4 marked legacy), `employer_agreement_v4.aleo`
moved to `src/layer1/archive/` unchanged with a row in its README, and the live table in
`src/layer1/README.md` and `CLAUDE.md`.

## Checks after deploy (must fail / must pass)

With two fresh test wallets holding only ALEO for fees, B (a business name) and W (a worker name):

- B: `create_offer(..., worker_address = W, ...)` → **accepted**; B holds a `SentOffer`, W a `PendingAgreement`; the transaction's public inputs show the agreement id and a field, nothing else.
- B: `create_offer` with the same agreement id again → **rejected** (anchored twice).
- A third wallet calling `accept_offer` with W's record → **rejected** (not the owner; even with the plaintext, `worker_address != signer`).
- W: `accept_offer(pending, ..., worker_half)` → **accepted**; B and W each hold a `FinalAgreement` with both halves; `agreement_status` is 1.
- B: `withdraw_offer(sent)` now → **rejected** (not pending).
- W: `pause_worker(a)` → **accepted** (status 2); W: `pause_worker` again → **rejected**.
- B: `resume(a)` → **rejected** (no approvals); B: `approve_resume_employer(a)`, W: `approve_resume_worker(a)`, then either: `resume(a)` → **accepted** (status 1).
- B: `terminate_employer(a)` → **accepted** (status 3); W: `terminate_worker(a)` → **rejected**.
- B: a second offer to W, then B: `withdraw_offer(sent)` → **accepted** (status 3).

Then Hewn switches (its own PR, prepared alongside this one): new offers go to v5 with the
employer's half, acceptances pass the worker's half, both apps seed the conversation's key ring
from the halves in the record, and v4 records keep being read for the agreements already made.
