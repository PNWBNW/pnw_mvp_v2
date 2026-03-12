// ---------------------------------------------------------
// test_usdcx_stablecoin.aleo — LOCAL STUB
// ---------------------------------------------------------
// This file is a minimal local stub matching the deployed
// test_usdcx_stablecoin.aleo interface on Aleo testnet.
//
// Purpose: allow `leo build` to resolve the stablecoin
// dependency without a live network fetch.
//
// Interface surface used by PNW programs:
//   - pnw_name_registry: transfer_public
//   - payroll_core:      transfer_private, Token record
// ---------------------------------------------------------

program test_usdcx_stablecoin.aleo {

    // Token record (private ownership, private balance).
    record Token {
        owner: address,
        amount: u128,
    }

    // Public balance mapping (address -> balance in micro-USDCx).
    mapping account: address => u128;

    // ---------------------------------------------------------
    // transfer_public — debit caller's public balance, credit `to`.
    // Used by pnw_name_registry for name registration fees.
    // ---------------------------------------------------------
    async transition transfer_public(to: address, amount: u128) -> Future {
        return finalize_transfer_public(self.caller, to, amount);
    }

    async function finalize_transfer_public(from: address, to: address, amount: u128) {
        let from_bal: u128 = account.get_or_use(from, 0u128);
        assert(from_bal >= amount);
        account.set(from, from_bal - amount);
        let to_bal: u128 = account.get_or_use(to, 0u128);
        account.set(to, to_bal + amount);
    }

    // ---------------------------------------------------------
    // transfer_private — split a Token record into two records.
    // Used by payroll_core for employer → worker private payroll.
    // Input token is consumed implicitly as a transition input.
    // ---------------------------------------------------------
    transition transfer_private(token: Token, to: address, amount: u128) -> (Token, Token) {
        assert(token.amount >= amount);
        let recipient: Token = Token {
            owner: to,
            amount: amount,
        };
        let change: Token = Token {
            owner: token.owner,
            amount: token.amount - amount,
        };
        return (recipient, change);
    }

    @noupgrade async constructor() {}
}