# hewn_credentials_v1.aleo

A worker's credentials, **deployed 2026-10-25** (transaction
`at1fndzrvr79edftn7a8k5shvqcp5ygj4jw4q9qndmwdpu3fa7vluzqu4hauy`, block 20806575, 9.08 credits;
staged the same day): a business vouching for a person it has an agreement with: employment
verified, a skill, a clearance, or something custom. Design and the art: `docs/HEWN_ART.md` in the
app repo (PNWBNW/hewn), "A worker's land and its
landmarks". The worker's app draws each live credential as a landmark on their land (a cabin, a
bridge, a fire lookout, a cairn): built and lit while active, a bare frame while offered, a ghost
once revoked. The business's app keeps its copy.

A credential lives in two private records that differ only in owner and role: the issuer's copy
and the subject's. What it says (the title, the dates, the details) stays in the two vaults; the
record carries a hash of it (`scope`). The only public thing about a credential is its
**commitment**, one hash over the kind, the two accounts, the scope and a random nonce, with a
status and the block it was issued at. Nothing on chain links the business and the person.

| Call | Inputs | Who | Does |
|---|---|---|---|
| `issue` | `parties_key`, `subject`, `kind`, `scope`, `nonce` (all private) | The employer of an agreement with the subject | Two copies, offered. Refused unless `employer_agreement_v5` says the pair did agree (active, paused or ended), the kind is 1 to 4, the nonce isn't zero, and no credential has that commitment yet |
| `accept` | The subject's copy | The subject | Offered → active. The copy comes back to them unchanged |
| `decline` | The subject's copy | The subject | Offered → declined. The copy is spent; nothing is drawn |
| `revoke` | The issuer's copy | The issuer | Offered or active → revoked. The copy is spent; the subject's stays and draws as a ghost |
| `assert_active` | `commitment` | Any program | Passes only while the credential is active |

Kinds: 1 employment verified, 2 skills, 3 clearance, 4 custom. Statuses: 1 offered, 2 active,
3 revoked, 4 declined (0: none). No fee beyond the network's.

**Who may issue.** The signer passes the agreement's parties key and the worker's account
privately, and the program calls `employer_agreement_v5.aleo/assert_pair_agreed(key, signer,
worker)`: the pair tag only matches when the signer is that agreement's employer and the subject
its worker, and the status is active, paused or ended (a past employer may still vouch for work
that was done; a pending or withdrawn offer doesn't count). No registry call: the app checks names
off chain, as `employer_agreement_v5` does. A credential to oneself can't happen: v5 refuses an
offer to yourself, so no agreed pair has one account on both sides.

**Who may move it.** A record is spent only by its owner, so the subject's copy can only be
accepted or declined by the subject and the issuer's only revoked by the issuer; the role byte in
each copy refuses the other move. A stranger holds nothing to call with.

**What is public.** A transaction's public finalize inputs are the pair tag (from
`assert_pair_agreed`, as for every program that checks an agreement) and the commitment; later
moves name only the commitment. Both are pseudonyms: a watcher can count the credentials issued
under one tag, and the moves on one commitment, without learning who or which. A commitment can't
be worked out from public data: the nonce is random and private, and so are the two accounts.

**Bound to the pair.** There is no transfer: a credential can't be sold, moved or re-issued by
anyone but the employer of the agreement it came from. Two credentials of the same kind to the
same person are two credentials (two jobs, two cabins), each with its own nonce.

## Public state

`credential_status[commitment] = u8` and `credential_anchor[commitment] = u32` (the block the
credential was issued at). No name, no account, no counter.

## Tests

`tests/test_hewn_credentials_v1.leo`, run by the plan gate: 28 tests, 20 of them refusals (a
pending offer, a withdrawn one, no agreement at all, the worker issuing to themself, a subject the
agreement isn't with, the wrong key, kind 0 and 5, a zero nonce, the same commitment twice,
accepting twice, accepting or declining with the issuer's copy, declining after accepting,
revoking with the subject's copy, revoking a declined one, accepting a revoked one, and
`assert_active` on an offered, a revoked and an unknown commitment). The agreement program is the
local stub (`src/stubs/employer_agreement_v5.aleo`, the pair tag as deployed), seeded with
`set_test_pair`. One signer throughout: where a test has to spend the subject's copy, the stub
seeds the signer on both sides, which the live program never allows.

## Checked on the network (2026-10-25)

Run from a script with the two test accounts of the cards check, B (business, `hewncards_b1`) and
W (worker, `hewncards_w1`), who hold an active `employer_agreement_v5` agreement since the
OFFER-4 run (`at1f96vhyq…`) and a withdrawn offer beside it. Every call went to the network; a
refusal is a transaction the network rejected in finalize (the explorer files it under its fee
transaction), judged by the mapping it had to leave untouched a minute later.

| Call | Expected | Result |
|---|---|---|
| B: `issue` employment to W under the active pair | accepted, offered | ✅ `at12ssfs79zqhvfnqgr57utcnsy79xqldkcrpj2z6rfsllgynqdacxqvlv6cq`; status 1, anchor 20806613 |
| W: `accept` with the subject's copy | active | ✅ `at1rpd3ry53el4dqdzapyapetlkydlc7dtpwkjg4aqa5qyvg5vztcrqgjfepv`; status 2 |
| B: `assert_active` on it | accepted | ✅ `at1ul0vx3ck52vn6er0an0vkzl06ucnmg3gec6sswwjk4dw5ru33vzqslyewt` |
| B: `revoke` the active one with the issuer's copy | revoked | ✅ `at1acf2eccds3tla36mdufmyvyzge8enpknd76hjql3azh2jkhqdqqsyraacn`; status 3 |
| B: `issue` skills to W | offered | ✅ `at1t2u6j5fkcmjp0pz87thqrsrtgqjn5ncq7rfdl6d4japzfjcvv5rqnlypah`; status 1, anchor 20806629 |
| W: `decline` it | declined | ✅ `at1nh0fay297segm6kpakk4memuvqpecusxhw8wmktpcehaz4yrcs9sxzleda`; status 4 |
| B: `issue` clearance to W | offered | ✅ `at132an3nrmmz0ffkcjmz8ar8ta5j48e32fh224465wsd2z2ql4wqyqe75j6g`; status 1, anchor 20806636 |
| B: `revoke` it while offered | revoked | ✅ `at1vxve7cq29calj7882l0s5kte0fggaceg7a28k8ptnwp5c7nt9v8sxauwcc`; status 3 |
| W: `issue` to B (the worker is not the employer) | rejected | ✅ `at1zfe6eg3v9nssz959323kl7xyam2e9qgwfqf0907e69anzdmh9ygqy0ame3`; no status written |
| B: `issue` under the withdrawn pair | rejected | ✅ `at1fqfkzmp83lafsnhq7nes9p02eewlnywasl85ajfeu8jzvm4ua5pqusdgyl`; no status written |
| B: `issue` the same scope and nonce again (the same commitment) | rejected | ✅ `at1anvtdze3twfkq2c27w3eex7mjgra08m5vu2dudjukvhzyvq635pqnh7pnh`; status stays 3 |
| W: `accept` the revoked clearance | rejected | ✅ `at12qj849t9wc3mlrem78qmvepmm39flnfs7e3rq39sl57lvzuvagzq8d2csg`; status stays 3 |
| B: `revoke` the declined skills | rejected | ✅ `at1gw3hqrqde2ns3l84zru80arsv3selq9nw0av3x2t83ekkfskzuzst9dd9s`; status stays 4 |
| B: `assert_active` on the revoked employment | rejected | ✅ `at1aq09sae3qwwwlzst99h290nate333t63anmktmkwh7fqpxnwgvgs9w5c3u` |

Fourteen of fourteen. What the explorer shows of an `issue`: five private inputs, two records,
and a finalize future whose arguments are the pair tag (from `assert_pair_agreed`) and the
commitment, nothing else; `accept`, `decline` and `revoke` take one record and name only the
commitment. Each copy decrypts only with its owner's view key and carries the kind, both
accounts, the scope, the nonce and the commitment.

## Deployed

`deploy-new-program` run 16 (2026-10-25 03:37 UTC) swapped the stub for the live `employer_agreement_v5.aleo`,
compiled with Leo 4.0.0, ran the 28 tests and deployed the bytecode: transaction
`at1fndzrvr79edftn7a8k5shvqcp5ygj4jw4q9qndmwdpu3fa7vluzqu4hauy`, fee `at1ya905q5kgwh5djv6kdpqglrwfkraz62fa0406yugl3tnn7vv0yxsfsq2zj`, block 20806575,
9.083442 credits (storage 6.423, synthesis 1.658442, namespace 1, constructor 0.002). Execution costs:
`issue` 0.005567, `accept` 0.003091, `decline` 0.002459, `revoke` 0.002497, `assert_active`
0.001486. The program on chain matches main bcf2f38 instruction for instruction; recorded in
`config/testnet.manifest.json` as `program_ids.credentials.hewn_credentials`.
