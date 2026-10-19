# hewn_jobs_v1.aleo

The public job board. Postings are the one thing in Hewn meant for anyone to read, so they live
in public mappings, like `.hewn` names. Applications, replies, interview times and "not selected"
are sealed letters (`hewn_letters_v2`); this program never sees an applicant. Design and the
app's side: `docs/JOB_BOARD.md` in the app repo (PNWBNW/hewn).

| Call | Inputs (all public) | Does | Costs (USDCx, plus the network fee) |
|---|---|---|---|
| `post` | `posting_id`, `employer_name_hash`, `suffix_code`, `pay_type`, `pay_min`, `pay_max`, `employment_type`, `hours_per_week`, `place`, `body` | Adds a posting under the business's name, at the next index | $1 |
| `update` | the same | Replaces an open posting's facts and body | free |
| `feature` | `posting_id`, `employer_name_hash`, `suffix_code`, `days` | Keeps an open posting near the top for `days` more days (1 to 30; stacks on what's left, never more than 30 days ahead) | $5 a day |
| `close` | `posting_id`, `employer_name_hash`, `suffix_code` | Closes it for good (post again to reopen) | free |

**Fees** are public `transfer_public_as_signer` calls on `test_usdcx_stablecoin.aleo` from the
signer to the Hewn foundation treasury (`aleo1s8t86…amdd`, the account the name registrar pays).
If any check in the call fails, nothing is charged. A posting is public anyway, so a public fee
gives nothing away.

**Who may call:** each call runs `pnw_name_registry_v2.aleo/assert_employer_owner(employer_name_hash,
signer, suffix_code)` after checking `suffix_code` is 1 to 40, so only the business that owns the
`.hewn` name can post under it, update, feature or close it. `suffix_code` is the industry code the
name was registered under (the registry's `employer_suffix_code`, which the app reads); a worker
name has none (0), so a worker can't post under their own name. A fork running its own registry
holds no `.hewn` names and can't post here. `update`, `feature` and `close` also check the posting
was made under that name and is still open.

**What's stored** (`postings[id]`, a `Posting`): `employer_name_hash`, `posted_height`, `open`,
`featured_until` (a block height; 0 or past means not featured), `pay_type` (0 not shown, 1 an
hour, 2 a year; when 0 both amounts are 0), `pay_min` and `pay_max` in cents, `employment_type`
(0 not stated, 1 full-time, 2 part-time, 3 seasonal, 4 temporary, 5 contract), `hours_per_week`
in tenths (375 = 37.5; at most 1,680), `place` (0 not stated, 1 on site, 2 remote, 3 hybrid).
`posting_body[id]` holds the title, location and description as 40 fields (about 1.2 KB), packed
and deflated by the app the way letters are.

**Listing without a server:** `posting_count[0u8]` is how many postings there have ever been and
`posting_at[i]` the id of the i-th, so a page can walk them straight from the chain. The board
shows postings whose `featured_until` is still ahead first (latest window first), then the rest
newest first. A day is 28,800 blocks (about one block every 3 seconds, as the app assumes).

**Checks:** a zero id or name hash, a pay range backwards, an amount with pay hidden, an unknown
employment type or place, more than 168 hours a week, an industry code outside 1 to 40, or 0 or
more than 30 days are refused before Shield is asked.

**Tests:** `leo test` runs 31: five that must work and twenty-six that must fail (an unowned name,
an unregistered one, a worker name with or without a made-up industry code, a business name under
the wrong code, a duplicate id, editing under another name, editing or closing after a close,
closing what doesn't exist, each bad value, a posting or a feature without the USDCx or a cent
short, 0 or 31 days, 20 days twice, featuring a closed, unknown or someone else's posting). The
registry and USDCx are the local stubs in `src/stubs/`, seeded with `register_test_employer` (a
business name and its code), `register_test_name` (a worker name) and `mint_test` (a balance);
`program.json` points at them. The deploy workflow switches both dependencies to the real programs
on testnet before compiling the bytecode it deploys.

**Deployed 2026-10-19** (Actions → deploy-new-program): `at1354m4j9wxc9st3ukwcl2082s6429ddgx27kfekz500rpzcne4qqse80q4n`,
fee transaction `at1m7ngn79cd0kpuj92zkkv05lx7aq0wwgzh0sdc9df6dmc6ghvmgpse2cz0s`; 8.924390 credits (storage
6.628, synthesis 1.294, namespace 1, constructor 0.002). Per call, in ALEO on top of the USDCx fee:
`post` 0.020269, `update` 0.014193, `feature` 0.006927, `close` 0.003964.

`@noupgrade`: a change ships as `hewn_jobs_v2`.
