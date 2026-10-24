# hewn_cards_v1.aleo

The cards every account gets, **staged, not deployed** (2026-10-24): a business's card and a
worker's tenure card, each issued once per `.hewn` name by the account that owns it. Design and
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

## Checks after deploy (must fail / must pass)

With two fresh test wallets holding ALEO for fees, B (a business name, industry code `c`) and W
(a worker name):

- B: `issue_business_card(B, c)` → **accepted**; `cards[B]` is `{ issued_at: h, shown: true }` with `h` the transaction's block. B again → **rejected**.
- B: `issue_business_card(B, c + 1)` → **rejected**; `issue_worker_card(B, true)` → **rejected**; `hide_card(B)` → **rejected**.
- W: `issue_worker_card(W, false)` → **accepted**; `cards[W].shown` is false. W: `hide_card(W)` → **rejected** (already hidden); `show_card(W)` → **accepted**; `show_card(W)` again → **rejected**.
- W: `issue_business_card(W, c)` → **rejected**. A third wallet: `show_card(W)` → **rejected**.
- The explorer: each transaction's public inputs are the name hash, the code or the flag, and the signer (through the registry's finalize), nothing else.

Then the app (its own PR): a business's card issued in the same setup that registers its name,
a worker asked at setup whether theirs is shown, the switch in Settings with the honest note
above, existing accounts claiming their card once from Settings, and the public page that draws
a business's card from its name.
