// ---------------------------------------------------------------------------
// hewn_cards_v1 — the cards every account gets (Joshua, 2026-10-24; design in
// the app repo, docs/HEWN_ART.md).
//
// A business's card and a worker's tenure card are drawn from the account's
// .hewn name and from one number on chain: the block height the card was
// issued at, where the account's time on Hewn counts from. The picture itself
// is never stored; anyone with the name and the height draws the same card.
// Everything else on a card (the land, the constellation, the pine) comes
// from the name, which is public already on the registry.
//
//   issue_business_card   once per business name, by its owner. Public from
//                         the start: a business's card is always shown.
//   issue_worker_card     once per worker name, by its owner, shown or hidden
//                         as the worker chooses at setup.
//   show_card, hide_card  a worker's switch, any time. Hiding tells every app
//                         not to draw the card; it can't erase that the card
//                         was issued (the issue is a public transaction, and
//                         the chain keeps its history), and the app says so.
//
// Every call runs the registry's `assert_employer_owner` against the signer:
// with the name's industry code (1 to 40) for a business name, with 0 for a
// worker name (the registry stores no code for those), so each kind of card
// goes only to its kind of name, and only to the account that owns it. A card
// is bound to its name: there is no transfer. If a name ever changes hands
// through the registry, the card goes with it. A fork running its own
// registry holds no .hewn names and can't issue cards here.
//
// Public state: cards[name_hash] = { issued_at, shown }. No counters, no
// amounts, nothing about a person beyond what the registry shows already.
//
// Immutable (@noupgrade): a change ships as hewn_cards_v2.
// ---------------------------------------------------------------------------

import pnw_name_registry_v2.aleo;

program hewn_cards_v1.aleo {
    // The one entry a card has: when it was issued, and whether it is shown.
    struct Card {
        issued_at: u32, // block height
        shown: bool,    // always true for a business; the worker's choice
    }

    mapping cards: field => Card;

    // A business's card. `suffix_code` is the industry code the name was
    // registered under (the registry's `employer_suffix_code`, which the app
    // reads); the registry checks it against the name.
    fn issue_business_card(public name_hash: field, public suffix_code: u8) -> Final {
        assert_neq(name_hash, 0field);
        assert(suffix_code >= 1u8 && suffix_code <= 40u8);
        let owner: Final = pnw_name_registry_v2.aleo::assert_employer_owner(name_hash, self.signer, suffix_code);
        return final {
            owner.run();
            assert(!cards.contains(name_hash));
            cards.set(name_hash, Card { issued_at: block.height, shown: true });
        };
    }

    // A worker's card, shown or hidden as they choose. A worker name has no
    // industry code, so the registry check is against 0: a business name
    // (code 1 to 40) can't take a worker's card.
    fn issue_worker_card(public name_hash: field, public shown: bool) -> Final {
        assert_neq(name_hash, 0field);
        let owner: Final = pnw_name_registry_v2.aleo::assert_employer_owner(name_hash, self.signer, 0u8);
        return final {
            owner.run();
            assert(!cards.contains(name_hash));
            cards.set(name_hash, Card { issued_at: block.height, shown: shown });
        };
    }

    // The worker's switch. Only a worker name (code 0) passes the registry
    // check, so a business can't hide its card. Switching to the state the
    // card is already in is refused, so a stale app can't pay for nothing.
    fn show_card(public name_hash: field) -> Final {
        let owner: Final = pnw_name_registry_v2.aleo::assert_employer_owner(name_hash, self.signer, 0u8);
        return final {
            owner.run();
            let card: Card = cards.get(name_hash);
            assert(!card.shown);
            cards.set(name_hash, Card { issued_at: card.issued_at, shown: true });
        };
    }

    fn hide_card(public name_hash: field) -> Final {
        let owner: Final = pnw_name_registry_v2.aleo::assert_employer_owner(name_hash, self.signer, 0u8);
        return final {
            owner.run();
            let card: Card = cards.get(name_hash);
            assert(card.shown);
            cards.set(name_hash, Card { issued_at: card.issued_at, shown: false });
        };
    }

    @noupgrade
    constructor() {}
}
