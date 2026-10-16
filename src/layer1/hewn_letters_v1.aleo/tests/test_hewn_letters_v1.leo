// Tests for hewn_letters_v1: what a letter must carry, and what must fail.
import hewn_letters_v1.aleo;
program test_hewn_letters_v1.aleo {
    const ANA: address = aleo1rhgdu77hgyqd3xjj8ucu3jj9r2krwz6mnzyd80gncr5fxcwlh5rsvzp9px;

    // ---- What must work ----

    @test
    fn test_send_both_copies() {
        let parcel: [field; 34] = [7field; 34];
        let (letter, sent) = hewn_letters_v1.aleo::send(ANA, [1u128, 2u128], parcel);
        assert_eq(letter.owner, ANA);
        assert_eq(letter.lookup[0u32], 1u128);
        assert_eq(letter.lookup[1u32], 2u128);
        assert_eq(letter.parcel[0u32], 7field);
        assert_eq(letter.parcel[33u32], 7field);
        assert_eq(sent.owner, self.signer);
        assert_eq(sent.lookup[1u32], 2u128);
        assert_eq(sent.parcel[33u32], 7field);
    }

    @test
    fn test_half_zero_lookup_ok() {
        let (letter, sent) = hewn_letters_v1.aleo::send(ANA, [0u128, 5u128], [0field; 34]);
        assert_eq(letter.lookup[1u32], 5u128);
        let (other, mine) = hewn_letters_v1.aleo::send(ANA, [5u128, 0u128], [0field; 34]);
        assert_eq(other.lookup[0u32], 5u128);
    }

    @test
    fn test_send_page() {
        let page = hewn_letters_v1.aleo::send_page(ANA, [3u128, 4u128], [9field; 256]);
        assert_eq(page.owner, ANA);
        assert_eq(page.lookup[0u32], 3u128);
        assert_eq(page.page[255u32], 9field);
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_send_to_nobody_fails() {
        let (letter, sent) = hewn_letters_v1.aleo::send(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, [1u128, 2u128], [0field; 34]);
    }

    @test
    @should_fail
    fn test_send_no_lookup_fails() {
        let (letter, sent) = hewn_letters_v1.aleo::send(ANA, [0u128, 0u128], [0field; 34]);
    }

    @test
    @should_fail
    fn test_page_to_nobody_fails() {
        let page = hewn_letters_v1.aleo::send_page(aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc, [1u128, 2u128], [0field; 256]);
    }

    @test
    @should_fail
    fn test_page_no_lookup_fails() {
        let page = hewn_letters_v1.aleo::send_page(ANA, [0u128, 0u128], [0field; 256]);
    }

    @noupgrade
    constructor() {}
}
