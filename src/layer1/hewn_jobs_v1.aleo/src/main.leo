// ---------------------------------------------------------------------------
// hewn_jobs_v1 — the public job board (Joshua, 2026-10-19; design in the app
// repo, docs/JOB_BOARD.md).
//
// Postings are the one thing in Hewn meant to be read by anyone, so they live
// in public mappings, like .hewn names. Everything around them stays private:
// an application is a sealed letter to the business (hewn_letters), and so is
// every reply, interview time and "not selected". This program never sees an
// applicant.
//
//   post    a new posting: the facts anyone can filter on (pay, type, hours,
//           where) and its body (title, location and description, packed and
//           deflated by the app into 40 fields, about 1.2 KB)
//   update  the same, replacing a posting that is still open
//   close   closes it for good (post again to reopen)
//
// Only the business that owns the posting's .hewn name can post under it,
// update it or close it: each call runs the registry's `assert_employer_owner`
// against the signer and the name's industry code (1 to 40 for a business
// name; a worker name has none, so it can't post), and a fork running its own
// registry can't post here.
// The board lists postings by index: `posting_count[0]` is how many were ever
// posted and `posting_at[i]` the id of the i-th, so any app can walk them
// without a server or an indexer.
//
// Immutable (@noupgrade): a change ships as hewn_jobs_v2.
// ---------------------------------------------------------------------------

import pnw_name_registry_v2.aleo;

// The checks every posting passes, before Shield is asked.
fn check_facts(employer_name_hash: field, pay_type: u8, pay_min: u64, pay_max: u64, employment_type: u8, hours_per_week: u16, place: u8) {
    assert_neq(employer_name_hash, 0field);
    assert(pay_type <= 2u8);
    assert(pay_max >= pay_min);
    if pay_type == 0u8 {
        assert_eq(pay_min, 0u64);
        assert_eq(pay_max, 0u64);
    }
    assert(employment_type <= 5u8);
    assert(hours_per_week <= 1680u16); // 168 hours a week, in tenths
    assert(place <= 3u8);
}

program hewn_jobs_v1.aleo {
    // What anyone can filter on. Pay is in cents; `pay_type` 0 means the
    // posting shows no pay (then both amounts are 0).
    struct Posting {
        employer_name_hash: field,
        posted_height: u32,
        open: bool,
        pay_type: u8,        // 0 not shown, 1 an hour, 2 a year
        pay_min: u64,
        pay_max: u64,
        employment_type: u8, // 0 not stated, 1 full-time, 2 part-time, 3 seasonal, 4 temporary, 5 contract
        hours_per_week: u16, // tenths of an hour: 375 is 37.5
        place: u8,           // 0 not stated, 1 on site, 2 remote, 3 hybrid
    }

    // The posting's text, packed by the app (title, location, description).
    struct Body {
        words: [field; 40],
    }

    // How many postings there have ever been, under key 0.
    mapping posting_count: u8 => u32;
    // The i-th posting's id, so the board can walk them.
    mapping posting_at: u32 => field;
    mapping postings: field => Posting;
    mapping posting_body: field => Body;


    fn post(
        public posting_id: field,
        public employer_name_hash: field,
        public suffix_code: u8,
        public pay_type: u8,
        public pay_min: u64,
        public pay_max: u64,
        public employment_type: u8,
        public hours_per_week: u16,
        public place: u8,
        public body: Body,
    ) -> Final {
        assert_neq(posting_id, 0field);
        check_facts(employer_name_hash, pay_type, pay_min, pay_max, employment_type, hours_per_week, place);
        // A business name's industry code is 1 to 40; a worker name's is 0.
        assert(suffix_code >= 1u8 && suffix_code <= 40u8);
        let owner: Final = pnw_name_registry_v2.aleo::assert_employer_owner(employer_name_hash, self.signer, suffix_code);
        let facts: Posting = Posting {
            employer_name_hash: employer_name_hash,
            posted_height: 0u32,
            open: true,
            pay_type: pay_type,
            pay_min: pay_min,
            pay_max: pay_max,
            employment_type: employment_type,
            hours_per_week: hours_per_week,
            place: place,
        };
        return final {
            owner.run();
            assert(!postings.contains(posting_id));
            let n: u32 = posting_count.get_or_use(0u8, 0u32);
            posting_at.set(n, posting_id);
            posting_count.set(0u8, n + 1u32);
            postings.set(posting_id, Posting {
                employer_name_hash: facts.employer_name_hash,
                posted_height: block.height,
                open: true,
                pay_type: facts.pay_type,
                pay_min: facts.pay_min,
                pay_max: facts.pay_max,
                employment_type: facts.employment_type,
                hours_per_week: facts.hours_per_week,
                place: facts.place,
            });
            posting_body.set(posting_id, body);
        };
    }

    fn update(
        public posting_id: field,
        public employer_name_hash: field,
        public suffix_code: u8,
        public pay_type: u8,
        public pay_min: u64,
        public pay_max: u64,
        public employment_type: u8,
        public hours_per_week: u16,
        public place: u8,
        public body: Body,
    ) -> Final {
        check_facts(employer_name_hash, pay_type, pay_min, pay_max, employment_type, hours_per_week, place);
        // A business name's industry code is 1 to 40; a worker name's is 0.
        assert(suffix_code >= 1u8 && suffix_code <= 40u8);
        let owner: Final = pnw_name_registry_v2.aleo::assert_employer_owner(employer_name_hash, self.signer, suffix_code);
        return final {
            owner.run();
            let current: Posting = postings.get(posting_id);
            assert_eq(current.employer_name_hash, employer_name_hash);
            assert(current.open);
            postings.set(posting_id, Posting {
                employer_name_hash: employer_name_hash,
                posted_height: current.posted_height,
                open: true,
                pay_type: pay_type,
                pay_min: pay_min,
                pay_max: pay_max,
                employment_type: employment_type,
                hours_per_week: hours_per_week,
                place: place,
            });
            posting_body.set(posting_id, body);
        };
    }

    fn close(public posting_id: field, public employer_name_hash: field, public suffix_code: u8) -> Final {
        // A business name's industry code is 1 to 40; a worker name's is 0.
        assert(suffix_code >= 1u8 && suffix_code <= 40u8);
        let owner: Final = pnw_name_registry_v2.aleo::assert_employer_owner(employer_name_hash, self.signer, suffix_code);
        return final {
            owner.run();
            let current: Posting = postings.get(posting_id);
            assert_eq(current.employer_name_hash, employer_name_hash);
            assert(current.open);
            postings.set(posting_id, Posting {
                employer_name_hash: current.employer_name_hash,
                posted_height: current.posted_height,
                open: false,
                pay_type: current.pay_type,
                pay_min: current.pay_min,
                pay_max: current.pay_max,
                employment_type: current.employment_type,
                hours_per_week: current.hours_per_week,
                place: current.place,
            });
        };
    }

    @noupgrade
    constructor() {}
}
