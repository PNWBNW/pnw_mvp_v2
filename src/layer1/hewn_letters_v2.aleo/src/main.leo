// ---------------------------------------------------------------------------
// hewn_letters_v2 — private letters as records, now with announcements
// (Joshua, 2026-10-16; design in the app repo, docs/LETTERS.md).
//
// v1 (deployed, immutable) carried one letter to one person. v2 keeps both of
// its calls exactly and adds `send_many`, so a business can post one
// announcement to its team with one approval instead of one per person:
//
//   send       a letter (34 fields, 1,054 bytes) to `to`, and the same letter
//              back to the sender, so their history is on every device
//   send_page  a long document (256 fields, 7,936 bytes: an offer's terms) to
//              `to` only; the sender keeps its own copy in its books
//   send_many  one letter to each of eight accounts, and one copy back to the
//              sender. The app fills unused places with the sender's own
//              account (those copies are the sender's, like its SentLetter);
//              a team of more than eight takes more than one call.
//
// What an announcement carries is sealed by the app under the channel's own
// key, which only its members hold, so every copy is the same parcel under
// the same `lookup` (the channel's slot). Each copy is still a record owned
// by its member, so only that member's view key opens it, and nobody can tell
// from the chain who the eight are, or how many of them are real.
//
// `lookup` is the app's id for the slot (BLAKE3 of a key, the kind of
// document and its number), so each side finds the next letter of a
// conversation without opening the others.
//
// No mapping, no finalize, no public state: a transaction shows that one of
// these ran, its fixed sizes, and its fee. Record owners are encrypted; the
// recipient learns the sender from the record's sender ciphertext.
//
// Immutable (@noupgrade): a change ships as hewn_letters_v3.
// ---------------------------------------------------------------------------

program hewn_letters_v2.aleo {
    // The zero address: nobody holds its key, so a letter to it is lost.
    const NOBODY: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    // A letter, as its recipient holds it.
    record Letter {
        owner: address,
        lookup: [u128; 2],
        parcel: [field; 34],
    }

    // The same letter, as its sender keeps it.
    record SentLetter {
        owner: address,
        lookup: [u128; 2],
        parcel: [field; 34],
    }

    // A long document, as its recipient holds it.
    record Page {
        owner: address,
        lookup: [u128; 2],
        page: [field; 256],
    }

    fn send(to: address, lookup: [u128; 2], parcel: [field; 34]) -> (Letter, SentLetter) {
        assert_neq(to, NOBODY);
        assert(lookup[0u32] != 0u128 || lookup[1u32] != 0u128);
        return (
            Letter { owner: to, lookup: lookup, parcel: parcel },
            SentLetter { owner: self.signer, lookup: lookup, parcel: parcel },
        );
    }

    fn send_page(to: address, lookup: [u128; 2], page: [field; 256]) -> Page {
        assert_neq(to, NOBODY);
        assert(lookup[0u32] != 0u128 || lookup[1u32] != 0u128);
        return Page { owner: to, lookup: lookup, page: page };
    }

    fn send_many(to: [address; 8], lookup: [u128; 2], parcel: [field; 34]) -> (Letter, Letter, Letter, Letter, Letter, Letter, Letter, Letter, SentLetter) {
        for i: u32 in 0u32..8u32 {
            assert_neq(to[i], NOBODY);
        }
        assert(lookup[0u32] != 0u128 || lookup[1u32] != 0u128);
        return (
            Letter { owner: to[0u32], lookup: lookup, parcel: parcel },
            Letter { owner: to[1u32], lookup: lookup, parcel: parcel },
            Letter { owner: to[2u32], lookup: lookup, parcel: parcel },
            Letter { owner: to[3u32], lookup: lookup, parcel: parcel },
            Letter { owner: to[4u32], lookup: lookup, parcel: parcel },
            Letter { owner: to[5u32], lookup: lookup, parcel: parcel },
            Letter { owner: to[6u32], lookup: lookup, parcel: parcel },
            Letter { owner: to[7u32], lookup: lookup, parcel: parcel },
            SentLetter { owner: self.signer, lookup: lookup, parcel: parcel },
        );
    }

    @noupgrade
    constructor() {}
}
