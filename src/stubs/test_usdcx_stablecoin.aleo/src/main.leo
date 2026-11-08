// ---------------------------------------------------------
// test_usdcx_stablecoin.aleo — LOCAL STAND-IN, never deployed
// ---------------------------------------------------------
// Stands in for the testnet USDCx stablecoin so our programs build and
// test offline, and so a local devnode can rehearse a payroll run
// (Hewn, docs/VEIL.md). The deploy workflow swaps it for the deployed
// program before anything reaches the chain; the real program already
// owns this name on testnet.
//
// Every transition here has the same name, inputs (in the same order)
// and outputs (in the same order) as the deployed program, read from its
// bytecode on 2026-11-07:
//
//   transfer_private(recipient, amount, token, proofs)
//     -> (ComplianceRecord, change to the sender, the recipient's Token, Final)
//   transfer_public_to_private(to, amount) -> (ComplianceRecord, Token, Final)
//   mint_private(to, amount)               -> (ComplianceRecord, Token, Final)
//   split(token, amount)                   -> (Token of `amount`, Token of the rest)
//   join(a, b)                             -> Token
//   transfer_public(to, amount), transfer_public_as_signer(to, amount) -> Final
//
// What differs from the deployed program, on purpose:
//   - mint_private is open to anyone (on chain only a minter role may call it)
//     and mint_test credits a public balance out of nothing: both exist so a
//     test or a devnode can hold USDCx at all.
//   - The freeze-list proofs are taken but not checked, and there is no pause,
//     role or supply bookkeeping: the freeze list lives in another program
//     that a devnode doesn't have. The record flow is what is rehearsed.
//
// Who calls what:
//   - pnw_name_registrar_v5: transfer_public_as_signer (the name price)
//   - hewn_jobs_v1:          transfer_public_as_signer (+ mint_test in tests)
//   - payroll_core_v2:       transfer_private, Token, MerkleProof, ComplianceRecord
//   - Hewn's pay queue (apps/business, packages/rail): transfer_private and split
// ---------------------------------------------------------

// The freeze-list exclusion proof a private transfer carries (two leaves that
// bracket the sender in the sorted freeze list; depth 16), as deployed.
struct MerkleProof {
    siblings: [field; 16],
    leaf_index: u32,
}

program test_usdcx_stablecoin.aleo {

    // The deployed program's compliance officer: every ComplianceRecord is
    // owned by this address. A public constant from the bytecode, not a key.
    const COMPLIANCE: address = aleo1mnldqsfrwayzfep3t9zusu4y7yknsdhfwx76v5pajla35mrqn5xsvvurhy;
    // "Minted" shows as a transfer from the zero address, as deployed.
    const NOBODY: address = aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq3ljyzc;

    // A private USDCx balance: amount in minor units (10^6 per dollar).
    record Token {
        owner: address,
        amount: u128,
    }

    // The audit copy of every private movement, owned by the compliance officer.
    record ComplianceRecord {
        owner: address,
        amount: u128,
        sender: address,
        recipient: address,
    }

    // A reusable freeze-list proof (transfer_private_with_creds on chain; not carried here).
    record Credentials {
        owner: address,
        freeze_list_root: field,
    }

    // Public balances, by address, as deployed (`balances`).
    mapping balances: address => u128;

    // ---------------------------------------------------------
    // Public balances
    // ---------------------------------------------------------

    // Move a public balance from the caller to `to`.
    fn transfer_public(to: address, amount: u128) -> Final {
        let from: address = self.caller;
        return final {
            let from_bal: u128 = balances.get_or_use(from, 0u128);
            assert(from_bal >= amount);
            balances.set(from, from_bal - amount);
            let to_bal: u128 = balances.get_or_use(to, 0u128);
            balances.set(to, to_bal + amount);
        };
    }

    // Move a public balance from the signer (the person, through whichever
    // program called this) to `to`. What the registrar and the job board use for fees.
    fn transfer_public_as_signer(to: address, amount: u128) -> Final {
        let from: address = self.signer;
        return final {
            let from_bal: u128 = balances.get_or_use(from, 0u128);
            assert(from_bal >= amount);
            balances.set(from, from_bal - amount);
            let to_bal: u128 = balances.get_or_use(to, 0u128);
            balances.set(to, to_bal + amount);
        };
    }

    // TEST ONLY, not on the deployed program: credit `to` a public balance out
    // of nothing, so a test or a devnode account can pay a fee or go private.
    fn mint_test(to: address, amount: u128) -> Final {
        return final {
            let bal: u128 = balances.get_or_use(to, 0u128);
            balances.set(to, bal + amount);
        };
    }

    // Turn `amount` of the caller's public balance into a private Token for `to`.
    // The route by which a business's USDCx goes private before payroll.
    fn transfer_public_to_private(to: address, amount: u128) -> (ComplianceRecord, Token, Final) {
        let from: address = self.caller;
        let token: Token = Token { owner: to, amount: amount };
        let compliance: ComplianceRecord = ComplianceRecord {
            owner: COMPLIANCE,
            amount: amount,
            sender: from,
            recipient: to,
        };
        return (compliance, token, final {
            let from_bal: u128 = balances.get_or_use(from, 0u128);
            assert(from_bal >= amount);
            balances.set(from, from_bal - amount);
        });
    }

    // ---------------------------------------------------------
    // Private balances
    // ---------------------------------------------------------

    // Mint a private Token for `to`. On chain only a minter may; here anyone may,
    // which is the point of a stand-in: a devnode business needs USDCx to pay with.
    fn mint_private(to: address, amount: u128) -> (ComplianceRecord, Token, Final) {
        let token: Token = Token { owner: to, amount: amount };
        let compliance: ComplianceRecord = ComplianceRecord {
            owner: COMPLIANCE,
            amount: amount,
            sender: NOBODY,
            recipient: to,
        };
        return (compliance, token, final {
            // On chain: the minter role, the pause flag and the supply cap are checked here.
        });
    }

    // Pay `amount` of `token` to `recipient`. The sender's change comes back
    // first, the recipient's Token second, as deployed. Paying more than the
    // token holds fails (the subtraction underflows), and the VM refuses a token
    // the signer doesn't own.
    fn transfer_private(recipient: address, amount: u128, token: Token, proofs: [MerkleProof; 2]) -> (ComplianceRecord, Token, Token, Final) {
        let change: Token = Token {
            owner: token.owner,
            amount: token.amount - amount,
        };
        let paid: Token = Token {
            owner: recipient,
            amount: amount,
        };
        let compliance: ComplianceRecord = ComplianceRecord {
            owner: COMPLIANCE,
            amount: amount,
            sender: token.owner,
            recipient: recipient,
        };
        return (compliance, change, paid, final {
            // On chain: the proofs are checked against the freeze list's root here,
            // and the pause flag. A devnode has neither; the record flow is what is rehearsed.
        });
    }

    // Cut `amount` off a Token: the piece first, the rest second, both the owner's.
    fn split(token: Token, amount: u128) -> (Token, Token) {
        let piece: Token = Token { owner: token.owner, amount: amount };
        let rest: Token = Token { owner: token.owner, amount: token.amount - amount };
        return (piece, rest);
    }

    // Merge two Tokens of one owner.
    fn join(a: Token, b: Token) -> Token {
        return Token { owner: a.owner, amount: a.amount + b.amount };
    }

    @noupgrade constructor() {}
}
