// Tests for hewn_letters_v2: what a letter and an announcement must carry, and what must fail.
import hewn_letters_v2.aleo;
program test_hewn_letters_v2.aleo {
    const ANA: address = aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;
    const BEA: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;
    const NOBODY: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    // ---- What must work ----

    @test
    fn test_send_both_copies() {
        let (letter, sent) = hewn_letters_v2.aleo::send(ANA, [1u128, 2u128], [7field; 34]);
        assert_eq(letter.owner, ANA);
        assert_eq(letter.lookup[0u32], 1u128);
        assert_eq(letter.lookup[1u32], 2u128);
        assert_eq(letter.parcel[33u32], 7field);
        assert_eq(sent.owner, self.signer);
        assert_eq(sent.parcel[0u32], 7field);
    }

    @test
    fn test_send_page() {
        let page = hewn_letters_v2.aleo::send_page(ANA, [3u128, 4u128], [9field; 256]);
        assert_eq(page.owner, ANA);
        assert_eq(page.lookup[0u32], 3u128);
        assert_eq(page.page[255u32], 9field);
    }

    @test
    fn test_many_each_in_place() {
        let to: [address; 8] = [ANA, BEA, ANA, BEA, ANA, BEA, ANA, BEA];
        let (a, b, c, d, e, f, g, h, sent) = hewn_letters_v2.aleo::send_many(to, [5u128, 6u128], [3field; 34]);
        assert_eq(a.owner, ANA);
        assert_eq(b.owner, BEA);
        assert_eq(c.owner, ANA);
        assert_eq(h.owner, BEA);
        assert_eq(a.lookup[0u32], 5u128);
        assert_eq(h.lookup[1u32], 6u128);
        assert_eq(d.parcel[0u32], 3field);
        assert_eq(g.parcel[33u32], 3field);
        assert_eq(sent.owner, self.signer);
        assert_eq(sent.lookup[0u32], 5u128);
        assert_eq(sent.parcel[33u32], 3field);
    }

    @test
    fn test_many_padded_with_sender() {
        // Two members; the other six places are the sender's own account.
        let me: address = self.signer;
        let to: [address; 8] = [ANA, BEA, me, me, me, me, me, me];
        let (a, b, c, d, e, f, g, h, sent) = hewn_letters_v2.aleo::send_many(to, [0u128, 1u128], [0field; 34]);
        assert_eq(a.owner, ANA);
        assert_eq(b.owner, BEA);
        assert_eq(c.owner, me);
        assert_eq(h.owner, me);
        assert_eq(sent.owner, me);
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_send_to_nobody_fails() {
        let (letter, sent) = hewn_letters_v2.aleo::send(NOBODY, [1u128, 2u128], [0field; 34]);
    }

    @test
    @should_fail
    fn test_send_no_lookup_fails() {
        let (letter, sent) = hewn_letters_v2.aleo::send(ANA, [0u128, 0u128], [0field; 34]);
    }

    @test
    @should_fail
    fn test_page_to_nobody_fails() {
        let page = hewn_letters_v2.aleo::send_page(NOBODY, [1u128, 2u128], [0field; 256]);
    }

    @test
    @should_fail
    fn test_page_no_lookup_fails() {
        let page = hewn_letters_v2.aleo::send_page(ANA, [0u128, 0u128], [0field; 256]);
    }

    @test
    @should_fail
    fn test_many_nobody_first_fails() {
        let to: [address; 8] = [NOBODY, BEA, ANA, BEA, ANA, BEA, ANA, BEA];
        let (a, b, c, d, e, f, g, h, sent) = hewn_letters_v2.aleo::send_many(to, [1u128, 2u128], [0field; 34]);
    }

    @test
    @should_fail
    fn test_many_nobody_last_fails() {
        let to: [address; 8] = [ANA, BEA, ANA, BEA, ANA, BEA, ANA, NOBODY];
        let (a, b, c, d, e, f, g, h, sent) = hewn_letters_v2.aleo::send_many(to, [1u128, 2u128], [0field; 34]);
    }

    @test
    @should_fail
    fn test_many_nobody_middle_fails() {
        let to: [address; 8] = [ANA, BEA, ANA, BEA, NOBODY, BEA, ANA, BEA];
        let (a, b, c, d, e, f, g, h, sent) = hewn_letters_v2.aleo::send_many(to, [1u128, 2u128], [0field; 34]);
    }

    @test
    @should_fail
    fn test_many_no_lookup_fails() {
        let to: [address; 8] = [ANA, BEA, ANA, BEA, ANA, BEA, ANA, BEA];
        let (a, b, c, d, e, f, g, h, sent) = hewn_letters_v2.aleo::send_many(to, [0u128, 0u128], [0field; 34]);
    }

    @noupgrade
    constructor() {}
}
