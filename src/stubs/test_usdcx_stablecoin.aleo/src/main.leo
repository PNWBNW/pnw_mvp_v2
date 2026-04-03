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
//   - pnw_name_registrar: transfer_public_as_signer
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
    fn transfer_public(to: address, amount: u128) -> Final {
        let from: address = self.caller;
        return final {
            let from_bal: u128 = account.get_or_use(from, 0u128);
            assert(from_bal >= amount);
            account.set(from, from_bal - amount);
            let to_bal: u128 = account.get_or_use(to, 0u128);
            account.set(to, to_bal + amount);
        };
    }

    // ---------------------------------------------------------
    // transfer_public_as_signer — debit SIGNER's public balance, credit `to`.
    // Used by pnw_name_registrar for name registration fees.
    // Unlike transfer_public, this uses self.signer (the original tx signer)
    // so cross-program calls deduct from the user, not the calling program.
    // ---------------------------------------------------------
    fn transfer_public_as_signer(to: address, amount: u128) -> Final {
        let from: address = self.signer;
        return final {
            let from_bal: u128 = account.get_or_use(from, 0u128);
            assert(from_bal >= amount);
            account.set(from, from_bal - amount);
            let to_bal: u128 = account.get_or_use(to, 0u128);
            account.set(to, to_bal + amount);
        };
    }

    // Compliance audit record emitted on every private transfer.
    record ComplianceRecord {
        owner: address,
        from_addr: address,
        to_addr: address,
        amount: u128,
    }

    // ---------------------------------------------------------
    // transfer_private — split a Token record into two records.
    // Used by payroll_core for employer → worker private payroll.
    // Actual on-chain signature (as observed from Leo type errors):
    //   transfer_private(from: address, amount: u128, token: Token, to: address)
    //   -> (ComplianceRecord, Token, Token, Final)
    // NOTE: if the 4th arg type or return shape differs from the
    // deployed program, Leo will report a type error — update to match.
    // ---------------------------------------------------------
    fn transfer_private(from: address, amount: u128, token: Token, to: address) -> (ComplianceRecord, Token, Token, Final) {
        assert(token.amount >= amount);
        let compliance: ComplianceRecord = ComplianceRecord {
            owner: from,
            from_addr: from,
            to_addr: to,
            amount: amount,
        };
        let recipient: Token = Token {
            owner: to,
            amount: amount,
        };
        let change: Token = Token {
            owner: token.owner,
            amount: token.amount - amount,
        };
        return (compliance, recipient, change, final {
            // compliance/audit hook — actual finalize logic determined by on-chain program
        });
    }

    @noupgrade constructor() {}
}
