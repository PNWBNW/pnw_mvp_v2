# hewn_jobs_v1.aleo

The public job board. Postings are the one thing in Hewn meant for anyone to read, so they live
in public mappings, like `.hewn` names. Applications, replies, interview times and "not selected"
are sealed letters (`hewn_letters_v2`); this program never sees an applicant. Design and the
app's side: `docs/JOB_BOARD.md` in the app repo (PNWBNW/hewn).

| Call | Inputs (all public) | Does |
|---|---|---|
| `post` | `posting_id`, `employer_name_hash`, `suffix_code`, `pay_type`, `pay_min`, `pay_max`, `employment_type`, `hours_per_week`, `place`, `body` | Adds a posting under the business's name, at the next index |
| `update` | the same | Replaces an open posting's facts and body |
| `close` | `posting_id`, `employer_name_hash`, `suffix_code` | Closes it for good (post again to reopen) |

**Who may call:** each call runs `pnw_name_registry_v2.aleo/assert_employer_owner(employer_name_hash,
signer, suffix_code)` after checking `suffix_code` is 1 to 40, so only the business that owns the
`.hewn` name can post under it, update or close it. `suffix_code` is the industry code the name was
registered under (the registry's `employer_suffix_code`, which the app reads); a worker name has
none (0), so a worker can't post under their own name. A fork running its own registry holds no
`.hewn` names and can't post here. `update` and `close` also check the posting was made under that
name.

**What's stored** (`postings[id]`, a `Posting`): `employer_name_hash`, `posted_height`, `open`,
`pay_type` (0 not shown, 1 an hour, 2 a year; when 0 both amounts are 0), `pay_min` and `pay_max`
in cents, `employment_type` (0 not stated, 1 full-time, 2 part-time, 3 seasonal, 4 temporary,
5 contract), `hours_per_week` in tenths (375 = 37.5; at most 1,680), `place` (0 not stated,
1 on site, 2 remote, 3 hybrid). `posting_body[id]` holds the title, location and description as
40 fields (about 1.2 KB), packed and deflated by the app the way letters are.

**Listing without a server:** `posting_count[0u8]` is how many postings there have ever been and
`posting_at[i]` the id of the i-th, so a page can walk them straight from the chain.

**Checks:** a zero id or name hash, a pay range backwards, an amount with pay hidden, an unknown
employment type or place, or more than 168 hours a week are refused before Shield is asked.

**Tests:** `leo test` runs 19: three that must work and sixteen that must fail (an unowned name,
an unregistered one, a worker name with or without a made-up industry code, a business name under
the wrong code, a duplicate id, editing under another name, editing or closing after a close,
closing what doesn't exist, and each bad value). The registry is the local stub in
`src/stubs/pnw_name_registry_v2.aleo`, seeded with `register_test_employer` (a business name and
its code) or `register_test_name` (a worker name); `program.json` points at it. The deploy workflow switches the dependency to the real registry on testnet before compiling
the bytecode it deploys.

**Deploy:** Actions → deploy-new-program → `hewn_jobs_v1.aleo`, broadcast off first.

`@noupgrade`: a change ships as `hewn_jobs_v2`.
