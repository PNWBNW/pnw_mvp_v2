# hewn_cards_v1.aleo

The cards every account gets, **deployed 2026-10-25** (transaction
`at1wcl4ymh20vhmq3td6jt4meknl5u8uclptc2ktl5r2jk2eh6jtcyqmakzeq`, block 20801930, 6.12 credits;
staged 2026-10-24): a business's card and a worker's tenure card, each issued once per `.hewn`
name by the account that owns it. Design and
the art: `docs/HEWN_ART.md` in the app repo (PNWBNW/hewn).

A card is drawn from two things: the account's name (public already on the registry: it gives
the land, the constellation, the map) and one number this program keeps, the block height the
card was issued at, where the account's **time on Hewn** counts from. The picture is never stored;
anyone with the name and the height draws the same card, and the app's renderer is versioned so a
card issued under one version is always drawn with it.

| Call | Inputs (all public) | Who | Does |
|---|---|---|---|
| `issue_business_card` | `name_hash`, `suffix_code` | The business that owns the name | Issues its card, shown from the start. Once per name. |
| `issue_worker_card` | `name_hash`, `shown` | The worker who owns the name | Issues their card, shown or hidden as they choose at setup. Once per name. |
| `show_card`, `hide_card` | `name_hash` | The worker who owns the name | The switch, any time. Switching to the state the card is already in is refused. A business's card can't be hidden. |

No fee beyond the network's. Nothing is charged by this program.

**Who may call.** Every call runs `pnw_name_registry_v2.aleo/assert_employer_owner(name_hash,
signer, code)`: with the name's industry code (1 to 40, checked before the registry is asked) for a
business's card, with 0 for a worker's card and the switch. The registry stores `0` as a worker
name's code and 1 to 40 as a business name's, so each kind of card goes only to its kind of name,
and only to the account the registry says owns it. A fork running its own registry holds no
`.hewn` names and can't issue cards here.

**Bound to the name.** There is no transfer: a card can't be sold or traded apart from its name.
If a name ever changes hands through the registry, its card goes with it to the new owner, since
the registry decides who may call. A public "under new ownership since" mark, for a business that
changes hands, is not in this version.

## Public state

`cards[name_hash] = Card { issued_at: u32, shown: bool }`. One entry per card. `issued_at` is the
block height of the issue; `shown` is `true` for every business and the worker's choice for a
worker. A page that draws a worker's public card reads the entry and draws only while `shown` is
true. No counters, no amounts, nothing about a person beyond what the registry shows already.

**What a worker's switch can and can't do** (Joshua, 2026-10-24: the registry check runs at
issue, so issuing leaves a public trace). Hiding tells every app not to draw the card from then
on. It can't erase that the card was issued: the issue is a public transaction naming the name's
hash and the account (as every registry check does), and the chain keeps its history. What being
shown adds, then, is only the app's permission to draw the card where the name appears. The app
says so when the worker switches.

## Tests

`tests/test_hewn_cards_v1.leo`, run by the plan gate: 22 tests, 18 of them refusals (a name the
signer doesn't own, a name not registered, the wrong industry code, code 0 or 41 for a business,
a business's card on a worker name, a worker's card on a business name, a second card for a
name, a zero name, the switch before a card exists, switching to the state the card is in, hiding
a business's card, switching someone else's card). The registry is the local stub (`src/stubs`),
seeded with a worker name or a business name with its code.

## Checked on the network (2026-10-25)

Run from a script with two fresh test wallets funded with 4 credits each: B, holding the
business name `hewncards_b1` (industry code 7, registered through `register_employer_free`,
`at1s74j6crsnnym46gnjpmwgky5d3h0jgcw5lhvuspp2ztj9gxwuy9se0wvxy`), and W, holding the worker name
`hewncards_w1` (`register_worker_free`, `at10fatwulnsztk8lz3ghqazcqnar8y2526xdfyuevyvjgr9wzpxc8q2mpj96`).
Every call below went to the network; a refusal is a transaction the network rejected in finalize
(the explorer files it under its fee transaction), and the mapping was read after each one.

| Call | Expected | Result |
|---|---|---|
| B: `issue_business_card(B, 7)` | accepted | ✅ `at1zcm4m62h9nd0etutrd93rrg6wwkpcm9ugknrgus9ytxs7y9kdyzs07sugg`; `cards[B] = { issued_at: 20802629, shown: true }` |
| B: the same again | rejected | ✅ block 20802632 |
| B: `issue_business_card(B, 8)` (wrong code) | rejected | ✅ block 20802635 |
| B: `issue_worker_card(B, true)` | rejected | ✅ block 20802641 |
| B: `hide_card(B)` | rejected | ✅ block 20802646 |
| W: `issue_worker_card(W, false)` | accepted | ✅ `at12tx6z58er24la7pvh5ydelvulupth07hmr6d0kzk36u2swqef58q4mpgwq`; `cards[W] = { issued_at: 20802650, shown: false }` |
| W: `hide_card(W)` (already hidden) | rejected | ✅ block 20802654 |
| W: `show_card(W)` | accepted | ✅ `at1enccrrafr2yfyjya6tmupjrqdpjldkfvusgu0slx9c4yl9tc8yrquy8wlp`; `shown: true` |
| W: `show_card(W)` again | rejected | ✅ block 20802662 |
| W: `issue_business_card(W, 7)` | rejected | ✅ block 20802665 |
| W: `hide_card(W)` | accepted | ✅ `at159rm248e3p8ltmwvpzap5m6l8sd0tkfw02rrmnvx28udc8yukg9spxf9gt`; `shown: false` |

13 of 13 as expected (the two registrations included), the issue heights unchanged throughout. A
third wallet switching W's card, and the two refusals the transition itself makes (code 0 or 41,
a zero name), are covered by the Leo tests and weren't sent. Each refused call cost its signer
the network fee, as any rejected execution does.

Then the app (its own PR): a business's card issued in the same setup that registers its name,
a worker asked at setup whether theirs is shown, the switch in Settings with the honest note
above, existing accounts claiming their card once from Settings, and the public page that draws
a business's card from its name.
