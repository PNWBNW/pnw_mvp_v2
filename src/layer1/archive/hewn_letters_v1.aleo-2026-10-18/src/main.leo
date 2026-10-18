// ---------------------------------------------------------------------------
// hewn_letters_v1 — private letters as records (Joshua, 2026-10-16; design in
// the app repo, docs/LETTERS.md).
//
// The chain is the mailbox: a letter is a record owned by its recipient, so
// only their view key opens it and their wallet finds it like any other
// record. What it carries is already sealed by the app (AES-256-GCM under the
// key only the two parties hold), padded to a fixed size so nothing shows how
// long a message is. A view key shown to an auditor reveals that letters
// exist, never what they say.
//
//   send       a letter (34 fields, 1,054 bytes) to `to`, and the same letter
//              back to the sender, so their history is on every device
//   send_page  a long document (256 fields, 7,936 bytes: an offer's terms) to
//              `to` only; the sender keeps its own copy in its books
//
// `lookup` is the app's id for the slot (BLAKE3 of the parties key, the kind
// of document and its number), so each side finds the next letter of a
// conversation without opening the others.
//
// No mapping, no finalize, no public state: a transaction shows that one of
// these ran, its fixed sizes, and its fee. With a private fee, not who sent
// it; the recipient is never shown (record owners are encrypted). The
// recipient learns the sender from the record's sender ciphertext.
//
// Immutable (@noupgrade): a change ships as hewn_letters_v2.
// ---------------------------------------------------------------------------

program hewn_letters_v1.aleo {
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

    @noupgrade
    constructor() {}
}
