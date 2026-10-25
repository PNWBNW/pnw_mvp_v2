# pnw_worker_profiles_v2.aleo

A worker's profile: name, age, gender, residency and country codes, a state-issued id, an industry
code and policy flags, all in a private `WorkerProfile` record the worker owns. Public state holds
one thing, `profile_anchor_height`: the block at which a profile's commitment (`profile_anchor`, a
32-byte hash the app computes) was first seen. Nothing about the person reaches a mapping.

Upgrades: `@admin`. Deployed on testnet 2026-03-26; imports `pnw_name_registry_v2.aleo`.

| Function | Does | Hewn |
|---|---|---|
| `create_worker_profile(...)` | Mints the record to the caller, who must own the worker name it binds to; anchors the commitment (first height wins) | Worker setup |
| `update_worker_profile(old, ...)` | Consumes the caller's record and mints the next revision (strictly higher `profile_rev`), still bound to the name, with a new anchor | Profile edits |
| `assert_profile_anchored(anchor)` | Refuses unless the anchor has a height | Other programs |
| `assert_worker_exists(anchor)` | The same check, under the name other programs call it by | Other programs |

Checks in every path: gender is 1, 2 or 3 (male, female, prefer not to say), age at most 120, the
residency state, country and industry codes and the schema and policy versions are non-zero, and
the revision is non-zero (and climbs on update). Ownership of the name is checked through the
registry's `assert_is_owner` at create and again at update, so a name that changed hands takes the
right to update the profile with it. The record's `issued_height` is a sentinel (0); the height
lives in the mapping.

Not enforced on chain: that the name is a worker's rather than a business's (the registry has no
`assert_worker_owner`; the app only offers this to worker accounts), and that a name has one
profile (the tests record that two can be created).

## Tests

`tests/test_pnw_worker_profiles_v2.leo`, run by the plan gate (`deploy.yml`): 19 tests, 14 of them
refusals. What must work: create (the record is the caller's, bound to the name, at revision 1,
and the anchor gets a height), the edge values (age 120, each gender code), the two public
assertions, and the recorded fact that a name can carry two profiles. What must fail: create for
a name nobody owns, someone else owns, or another name than the one owned; gender 0 and 4; age
121; a zero state, country, industry, schema, policy or revision; and either assertion on an
unknown anchor.

The deployed program is never edited. The gate tests a copy with `@noupgrade` in place of
`@admin` (the local ledger refuses an `@admin` program whose deployer isn't the admin) and its
registry dependency pointed at the stub in `src/stubs/`, whose `assert_is_owner` is the deployed
one and whose test-only `register_test_name` seeds the owner; both changes are asserted before
`leo test`.

What the tests can't show: `update_worker_profile`. It consumes the record `create` minted to the
caller, and inside a test the caller is the test program, whose records no signer can spend, so
every update call is refused before the program's own checks run. Its field guards are the same
asserts as create's; the revision-must-climb and owner checks are read, not run. Hewn's caller is
the worker's wallet, where the record is spendable.
