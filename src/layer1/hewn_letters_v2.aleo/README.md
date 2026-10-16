# hewn_letters_v2.aleo

Private letters as records: the chain is the mailbox. v1's two calls, unchanged, plus `send_many`
for announcements. Design and reasoning: `docs/LETTERS.md` in the app repo (PNWBNW/hewn).

| Call | Inputs (all private) | Outputs |
|---|---|---|
| `send` | `to: address`, `lookup: [u128; 2]`, `parcel: [field; 34]` | `Letter` (owner `to`), `SentLetter` (owner: the signer) |
| `send_page` | `to: address`, `lookup: [u128; 2]`, `page: [field; 256]` | `Page` (owner `to`) |
| `send_many` | `to: [address; 8]`, `lookup: [u128; 2]`, `parcel: [field; 34]` | 8 × `Letter` (owner `to[i]`), `SentLetter` (owner: the signer) |

- **The parcel:** sealed by the app and padded, so every letter is the same size. For
  `send_many` it is sealed under the channel's key (only its members hold it), and every copy
  carries the same parcel and `lookup` (the channel's slot).
- **`send_many` with fewer than eight people:** the app fills the unused places with the sender's
  own account. Those copies are the sender's own, like its `SentLetter`. Record owners are
  encrypted, so nothing on the chain shows how many of the eight are real. A team bigger than
  eight takes more than one call.
- **`lookup`:** must not be all zeros. **Addresses:** no place in `to` may be the zero address.
- **No public state:** no mappings and no finalize.
- **`@noupgrade`:** a change ships as `hewn_letters_v3`. v1 stays deployed, and the app still
  reads letters sent with it.

**Tests:** `leo test` runs 12: four that must work and eight that must fail. The must-fail cases
include the zero address in the first, middle and last place of `send_many`.

**Deploy:** Actions → deploy-new-program → `hewn_letters_v2.aleo`. Run it first with broadcast
off.
