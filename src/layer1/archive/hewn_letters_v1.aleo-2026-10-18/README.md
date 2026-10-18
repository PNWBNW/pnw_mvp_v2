# hewn_letters_v1.aleo

Private letters as records: the chain is the mailbox. Design and reasoning: `docs/LETTERS.md` in
the app repo (PNWBNW/hewn).

| Call | Inputs (all private) | Outputs |
|---|---|---|
| `send` | `to: address`, `lookup: [u128; 2]`, `parcel: [field; 34]` | `Letter` (owner `to`), `SentLetter` (owner: the signer) |
| `send_page` | `to: address`, `lookup: [u128; 2]`, `page: [field; 256]` | `Page` (owner `to`) |

- The parcel is already sealed by the app (AES-256-GCM under the pair's parties key) and padded,
  so every letter is the same size.
- `lookup` is the app's slot id (BLAKE3 of parties key, kind and sequence). It must not be all
  zeros.
- `to` must not be the zero address.
- No mappings, no finalize, no public state. With a private fee, a transaction shows only that
  one of these calls ran.
- `@noupgrade`: a change ships as `hewn_letters_v2`.

Tests: `leo test` (7: three that must work, four that must fail). Deploy: Actions →
deploy-new-program.
