// Tests for the USDCx stand-in: it must move value the way the deployed program
// does (who ends up owning which record, in which output position, with which
// amounts), and refuse what the deployed program refuses. Each test runs every
// call's finalize in order, so a failed public check fails the test.
import test_usdcx_stablecoin.aleo;
program test_test_usdcx_stablecoin.aleo {
    // Two people who are not the test signer (the runner signs as aleo1rhgd…, so a test that paid
    // that address would pass even if the change and the payment were swapped).
    const ANA: address = aleo1s3ws5tra87fjycnjrwsjcrnw2qxr8jfqqdugnf0xzqqw29q9m5pqem2u4t;
    const BEA: address = aleo1ncruukxn5w0rk5hk657y8pheajyhzz2e757p08sc9cn2ygts0yzqjzs37e;
    const COMPLIANCE: address = aleo1mnldqsfrwayzfep3t9zusu4y7yknsdhfwx76v5pajla35mrqn5xsvvurhy;
    const NOBODY: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;
    const FUNDS: u128 = 1_000_000_000u128; // $1,000 in minor units

    // Every private transfer carries a freeze-list proof; the stand-in takes it and doesn't
    // check it, so the tests pass two empty ones (NO_PROOFS below, written out in each test).

    // ---- What must work ----

    @test
    fn test_mint_private_owner() -> Final {
        let (c, t, f) = test_usdcx_stablecoin.aleo::mint_private(self.signer, FUNDS);
        assert_eq(t.owner, self.signer);
        assert_eq(t.amount, FUNDS);
        assert_eq(c.owner, COMPLIANCE);
        assert_eq(c.amount, FUNDS);
        assert_eq(c.sender, NOBODY);
        assert_eq(c.recipient, self.signer);
        return final { f.run(); };
    }

    @test
    fn test_pay_worker_and_change() -> Final {
        let (c0, employer, f0) = test_usdcx_stablecoin.aleo::mint_private(self.signer, FUNDS);
        // 234.56 USDCx to Ana: the change comes back first, Ana's token second, as deployed.
        let (c, change, paid, f) = test_usdcx_stablecoin.aleo::transfer_private(ANA, 234_560_000u128, employer, [test_usdcx_stablecoin.aleo::MerkleProof { siblings: [0field; 16], leaf_index: 0u32 }; 2]);
        assert_neq(ANA, self.signer);
        assert_eq(paid.owner, ANA);
        assert_eq(paid.amount, 234_560_000u128);
        assert_eq(change.owner, self.signer);
        assert_eq(change.amount, FUNDS - 234_560_000u128);
        assert_eq(c.owner, COMPLIANCE);
        assert_eq(c.amount, 234_560_000u128);
        assert_eq(c.sender, self.signer);
        assert_eq(c.recipient, ANA);
        return final { f0.run(); f.run(); };
    }

    @test
    fn test_three_workers_one_token() -> Final {
        // A pay run: three transfers in a row from one token, the change feeding the next.
        let (c0, t0, f0) = test_usdcx_stablecoin.aleo::mint_private(self.signer, FUNDS);
        let (c1, t1, p1, f1) = test_usdcx_stablecoin.aleo::transfer_private(ANA, 300_000_000u128, t0, [test_usdcx_stablecoin.aleo::MerkleProof { siblings: [0field; 16], leaf_index: 0u32 }; 2]);
        let (c2, t2, p2, f2) = test_usdcx_stablecoin.aleo::transfer_private(BEA, 200_000_000u128, t1, [test_usdcx_stablecoin.aleo::MerkleProof { siblings: [0field; 16], leaf_index: 0u32 }; 2]);
        let (c3, t3, p3, f3) = test_usdcx_stablecoin.aleo::transfer_private(ANA, 100_000_000u128, t2, [test_usdcx_stablecoin.aleo::MerkleProof { siblings: [0field; 16], leaf_index: 0u32 }; 2]);
        assert_eq(p1.owner, ANA);
        assert_eq(p2.owner, BEA);
        assert_eq(p3.owner, ANA);
        assert_eq(p1.amount + p2.amount + p3.amount + t3.amount, FUNDS);
        assert_eq(t3.owner, self.signer);
        assert_eq(t3.amount, 400_000_000u128);
        return final { f0.run(); f1.run(); f2.run(); f3.run(); };
    }

    @test
    fn test_whole_token_zero_change() -> Final {
        let (c0, t, f0) = test_usdcx_stablecoin.aleo::mint_private(self.signer, 50u128);
        let (c, change, paid, f) = test_usdcx_stablecoin.aleo::transfer_private(BEA, 50u128, t, [test_usdcx_stablecoin.aleo::MerkleProof { siblings: [0field; 16], leaf_index: 0u32 }; 2]);
        assert_eq(paid.amount, 50u128);
        assert_eq(change.amount, 0u128);
        assert_eq(change.owner, self.signer);
        return final { f0.run(); f.run(); };
    }

    @test
    fn test_split_and_join() -> Final {
        let (c0, t, f0) = test_usdcx_stablecoin.aleo::mint_private(self.signer, 1_000u128);
        let (piece, rest) = test_usdcx_stablecoin.aleo::split(t, 250u128);
        assert_eq(piece.owner, self.signer);
        assert_eq(piece.amount, 250u128);
        assert_eq(rest.owner, self.signer);
        assert_eq(rest.amount, 750u128);
        let whole = test_usdcx_stablecoin.aleo::join(piece, rest);
        assert_eq(whole.owner, self.signer);
        assert_eq(whole.amount, 1_000u128);
        return final { f0.run(); };
    }

    @test
    fn test_public_to_private_debits() -> Final {
        // The caller of the stand-in is whoever called it: from a wallet that is the person,
        // from this test it is the test program itself (self.address), so that is who holds the
        // public balance and shows as the sender.
        let caller: address = self.address;
        let f0 = test_usdcx_stablecoin.aleo::mint_test(caller, FUNDS);
        let (c, t, f1) = test_usdcx_stablecoin.aleo::transfer_public_to_private(self.signer, 400_000_000u128);
        assert_eq(t.owner, self.signer);
        assert_eq(t.amount, 400_000_000u128);
        assert_eq(c.owner, COMPLIANCE);
        assert_eq(c.sender, caller);
        assert_eq(c.recipient, self.signer);
        return final {
            f0.run();
            f1.run();
            assert_eq(test_usdcx_stablecoin.aleo::balances.get(caller), FUNDS - 400_000_000u128);
        };
    }

    @test
    fn test_public_transfers_move() -> Final {
        // transfer_public debits the caller (here the test program); transfer_public_as_signer
        // debits the signer (the person), whichever program they went through.
        let caller: address = self.address;
        let me: address = self.signer;
        let f0 = test_usdcx_stablecoin.aleo::mint_test(caller, 300u128);
        let f1 = test_usdcx_stablecoin.aleo::mint_test(me, 60u128);
        let f2 = test_usdcx_stablecoin.aleo::transfer_public(ANA, 100u128);
        let f3 = test_usdcx_stablecoin.aleo::transfer_public_as_signer(BEA, 50u128);
        return final {
            f0.run();
            f1.run();
            f2.run();
            f3.run();
            assert_eq(test_usdcx_stablecoin.aleo::balances.get(caller), 200u128);
            assert_eq(test_usdcx_stablecoin.aleo::balances.get(me), 10u128);
            assert_eq(test_usdcx_stablecoin.aleo::balances.get(ANA), 100u128);
            assert_eq(test_usdcx_stablecoin.aleo::balances.get(BEA), 50u128);
        };
    }

    // ---- What must fail ----

    @test
    @should_fail
    fn test_pay_over_token_fails() -> Final {
        let (c0, t, f0) = test_usdcx_stablecoin.aleo::mint_private(self.signer, 100u128);
        let (c, change, paid, f) = test_usdcx_stablecoin.aleo::transfer_private(ANA, 101u128, t, [test_usdcx_stablecoin.aleo::MerkleProof { siblings: [0field; 16], leaf_index: 0u32 }; 2]);
        return final { f0.run(); f.run(); };
    }

    @test
    @should_fail
    fn test_split_over_token_fails() -> Final {
        let (c0, t, f0) = test_usdcx_stablecoin.aleo::mint_private(self.signer, 100u128);
        let (piece, rest) = test_usdcx_stablecoin.aleo::split(t, 101u128);
        return final { f0.run(); };
    }

    // Not tested here: spending a Token the signer doesn't own. The Leo test runner lets it
    // through (tried 2026-11-07); the real VM refuses it, on the devnode and on chain, and
    // Hewn's devnode rehearsal runs against that VM.

    @test
    @should_fail
    fn test_private_no_balance_fails() -> Final {
        let (c, t, f) = test_usdcx_stablecoin.aleo::transfer_public_to_private(self.signer, 1u128);
        return final { f.run(); };
    }

    @test
    @should_fail
    fn test_public_no_balance_fails() -> Final {
        let f = test_usdcx_stablecoin.aleo::transfer_public_as_signer(ANA, 1u128);
        return final { f.run(); };
    }

    @noupgrade constructor() {}
}
