# employer_agreement_v5 (2026-10-23, staged; locked in and deployed 2026-10-24)

**Deployed 2026-10-24** (below). `employer_agreement_v4.aleo` stays live; Hewn keeps reading v4
records for the agreements already made, and sends new offers to v5 once it switches.

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
   offer and application. The only public finalize inputs are the agreement id and the pair tag.
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

## Locked in before the deploy (2026-10-24)

The staged program was held back when the faucet failed, and Joshua used the pause to settle
everything a later program would need from the agreement (one rebuild, since anything left out
would mean a v6). Decided 2026-10-24:

4. **The pair tag.** Every agreement gets `BHP1024::hash_to_field({ parties_key, employer, worker })`:
   a hash over its random key and the two accounts. The status is kept under the tag
   (`pair_status`) as well as under the id, and two transitions serve other programs:
   `assert_pair_active(parties_key, employer, worker)` and `assert_pair_agreed(...)` (active, paused
   or ended: the two did agree; not a pending or withdrawn offer). A paystub program passes the
   key and both accounts privately, checks the signer against them itself, and calls one of these;
   nothing public names the agreement id. v4's `assert_agreement_anchored`, `assert_agreement_active`
   and `assert_employer_authorized`, which took the id as a public finalize input, are gone, and
   so is the `agreement_parties_commitment` mapping they served. The tag is a pseudonym: the same
   value every time it is checked, so a watcher can count checks against an agreement without
   learning who or which. A zero key is refused; a key can't start two offers.
5. **Packed bytes.** `[u8; 32]` became `[u128; 2]` (the high half first, as `hewn_letters_v2`'s
   `lookup`) and `[u8; 64]` became `[u128; 4]`: the records carry twenty words instead of three
   hundred and twenty bytes, so proofs on a phone and the deployment are both smaller. Mapping
   keys follow (`[u128; 2]`).
6. **A reason when an agreement ends** (Joshua: yes). `terminate_employer(a, reason)` and
   `terminate_worker(a, reason)` take it; the caller's copy comes back with `end_reason` set and
   the other party receives an `AgreementEnd { agreement_id, parties_key, ended_by, reason }`, so
   both hold the statement on chain, authored by the party that ended it. Reasons and who may give
   them: 1 resigned (worker), 2 laid off (employer), 3 contract finished (either), 4 let go
   (employer), 5 mutual, reached only through `approve_end_employer` + `approve_end_worker` then
   `end_mutual` by either. Withdrawn is now its own status (4), so a withdrawn offer never counts
   as an agreement that was. Nothing about a reason reaches public state.
7. **No role or title in the agreement** (Joshua: no). Certifications stand on their own, apart
   from any agreement, so the credential program will check its issuer against the name registry,
   not against an agreement. The pair tag is for paystubs, employment verification and reviews.

## Checked offline

Leo 4.0.0 (the release zip, SHA-256 `95bcda063c8f0abad5f7484f5f6dbf9e5608bf0e5ce78082e2da8469366df705`,
the SHA this note recorded on 2026-10-23; CI pins the same release): the program compiles to valid bytecode
(20.3 KB, 15 entry points), and `leo test` passes 22 of 22
(`src/layer1/employer_agreement_v5.aleo/tests/`), 18 of them refusals. Every test runs as one
signer, who can't be both parties (an offer to yourself is refused; Leo's `@test(private_key)`
changes the signer for a whole test, not within one), so the tests cover the offer, withdrawing,
the pair tag's public state and the refusals; acceptance and the lifecycle after it are checked on
the network below.

## Deploy (Joshua, admin key as the deployer, 2026-10-24)

Workflow `.github/workflows/deploy_program.yml` (deploy-new-program) from `main` at `633e45e`:
broadcast off (run 10), then on (run 12). Compiled and tested with Leo 4.0.0 (22 of 22), deployed
from that bytecode at consensus version 22.

| | |
|---|---|
| Transaction | `at1pvypp6lknqz7u7rs8af2qc8r5k2wgds7x3sct6xtdjs0t70feu9ssx6j3k`, accepted |
| Fee transaction | `at1476zzxqz9rw9ylmcyveux660y43qqfm3yu2k7965wdaggsg6surszw4z7k` |
| Block | 20793785 |
| Cost | 40.764508 credits: storage 28.516, synthesis 11.246508, namespace 1, constructor 0.002 (public fee, no priority fee) |
| Size | 20.27 KB; 2,401,604 variables, 1,933,558 constraints |

The program the explorer serves (`/v2/testnet/program/employer_agreement_v5.aleo`) matches what
Leo 4.0.0 builds from `main` byte for byte.

What one call costs, in credits: `create_offer` 0.007735, `accept_offer` 0.007279, `withdraw_offer`
0.003059, `pause_*` 0.00527, each `approve_resume_*` 0.00428, `resume` 0.005369, `terminate_*`
0.00637, each `approve_end_*` 0.00431, `end_mutual` 0.006401, `assert_pair_active` 0.0017,
`assert_pair_agreed` 0.00178.

The manifest records it (`config/testnet.manifest.json`, status active). `program_ids.layer1`
keeps `employer_agreement` on v4, which holds the agreements already made, and adds
`employer_agreement_v5` beside it, as Hewn's `packages/config/src/programs.ts` already has it.
`employer_agreement_v4.aleo` stays in `src/layer1`, not `archive/`: four deployed programs import
it (`payroll_core_v2`, `pnw_router_v4`, `payroll_nfts_v2`, `credential_nft_v3`), and so does the
staged `credential_nft_v4`.

## Checks after deploy (must fail / must pass)

**Run 2026-10-25**, from a script with two funded test wallets (B holding the business name
`hewncards_b1`, W the worker name `hewncards_w1`), inputs built as Hewn's app builds them (the
halves random bytes, not real P-256 points; the program doesn't check them). Six of six: every
pass accepted, every refusal rejected in finalize, the public inputs as designed.

| Step | Expect | Got | Transaction |
|---|---|---|---|
| B `create_offer` to W | accepted | accepted; all 8 transition inputs private; the finalize's arguments the agreement id (`[u128; 2]`) and the pair tag (`field`), nothing else; `agreement_status` 0 | `at1qx9q5qlv6vfyyj56k6azc36v0uaagyeqf7jjkjq5z2kyfzuahupqgmulc2` |
| W `accept_offer` (the PendingAgreement decrypted with W's view key, the accept-time hash packed, W's half) | accepted | accepted; inputs a record and two private values; the same two public arguments; status 1. The first v5 acceptance on testnet | `at1f96vhyqufqpjw8336l5zmpwydde9eg4vdsgh39jz59cnkt4v8u9qfy4dgj` |
| B a second `create_offer` to W (new id, new key) | accepted | accepted; status 0 | `at1m7c8dk9853fqryw057nxhayv2f900rcaknx0tmw9x0sahnuewc9q7umjau` |
| B `withdraw_offer` with the SentOffer alone | accepted | accepted; the one input a record; status 4 (withdrawn) | `at1tmjtj4dt78tf3rav86yungp64fwx8rmf2k8zs0wgn4l30ja3scfq32qh8d` |
| B `create_offer` with offer 1's agreement id again | rejected | rejected (status still 1) | `at16mt8xlwfa0gph9kksmruan8h92fes45fyqgnrs5p56enf58lwvgsyupjjt` |
| B `withdraw_offer` on the accepted offer | rejected | rejected (status still 1) | `at1e5kuj8cpxyyftze3l0tvcvdset56h06pyayhk4ptlq5qr25q7qzsjauzpz` |

Not run yet: the pauses and resume, the three endings and their reasons, `end_mutual`, and
`assert_pair_active` / `assert_pair_agreed` from a third wallet (the credentials program's
network check, which calls `assert_pair_agreed` on this pair, covers the last). The list as
planned, for those:

With two fresh test wallets holding only ALEO for fees, B (a business name) and W (a worker name):

- B: `create_offer(..., worker_address = W, ...)` → **accepted**; B holds a `SentOffer`, W a `PendingAgreement`; the transaction's public inputs show two `u128` (the id) and a `field` (the tag), nothing else.
- B: `create_offer` with the same agreement id again → **rejected** (anchored twice); with a new id and the same `parties_key` → **rejected** (the tag exists).
- A third wallet calling `accept_offer` with W's record → **rejected** (not the owner; even with the plaintext, `worker_address != signer`).
- W: `accept_offer(pending, ..., worker_half)` → **accepted**; B and W each hold a `FinalAgreement` with both halves and `end_reason` 0; `agreement_status` is 1 and `pair_status[tag]` is 1.
- Any wallet: `assert_pair_active(key, B, W)` → **accepted**; with W's and B's addresses swapped → **rejected**.
- B: `withdraw_offer(sent)` now → **rejected** (not pending).
- W: `pause_worker(a)` → **accepted** (status 2; `assert_pair_active` → **rejected**, `assert_pair_agreed` → **accepted**); W: `pause_worker` again → **rejected**.
- B: `resume(a)` → **rejected** (no approvals); B: `approve_resume_employer(a)`, W: `approve_resume_worker(a)`, then either: `resume(a)` → **accepted** (status 1).
- W: `terminate_worker(a, 2)` → **rejected** (laid off is the employer's reason); B: `terminate_employer(a, 1)` → **rejected** (resigned is the worker's).
- B: `end_mutual(a)` → **rejected** (no approvals).
- W: `terminate_worker(a, 1)` → **accepted** (status 3): W's copy says `end_reason` 1, B holds an `AgreementEnd` with `ended_by` W and reason 1; B: `terminate_employer(a, 2)` now → **rejected** (ended already). `assert_pair_agreed` → **accepted**, `assert_pair_active` → **rejected**.
- B: a second offer to W (new id, new key), W accepts, B: `approve_end_employer(a)`, W: `approve_end_worker(a)`, W: `end_mutual(a)` → **accepted**: W's copy `end_reason` 5, B holds an `AgreementEnd` with reason 5.
- B: a third offer to W, then B: `withdraw_offer(sent)` → **accepted** (status 4); `assert_pair_agreed(key, B, W)` → **rejected**.

Then Hewn switches (its own PR, prepared alongside this one): new offers go to v5 with the
employer's half and the packed inputs, acceptances pass the worker's half, both apps seed the
conversation's key ring from the halves in the record, the status reader knows "withdrawn", ending
an agreement asks for the reason and shows the other side's `AgreementEnd`, and v4 records keep
being read for the agreements already made.
