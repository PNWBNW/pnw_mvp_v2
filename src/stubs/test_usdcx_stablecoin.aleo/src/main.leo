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
//   - pnw_name_registrar: transfer_public_as_signer
//   - payroll_core:       transfer_private, Token, MerkleProof, ComplianceRecord
// ---------------------------------------------------------

// MerkleProof struct — used by transfer_private for freeze-list verification
struct MerkleProof {
    siblings: [field; 16],
    leaf_index: u32,
}

program test_usdcx_stablecoin.aleo {

    // Token record (private ownership, private balance).
    record Token {
        owner: address,
        amount: u128,
    }

    // Compliance audit record emitted on every private transfer.
    // Field names match the on-chain program (sender/recipient, not from_addr/to_addr).
    record ComplianceRecord {
        owner: address,
        amount: u128,
        sender: address,
        recipient: address,
    }

    // Credentials record — reusable freeze-list proof
    record Credentials {
        owner: address,
        freeze_list_root: field,
    }

    // Public balance mapping (address -> balance in micro-USDCx).
    mapping account: address => u128;

    // ---------------------------------------------------------
    // transfer_public — debit caller's public balance, credit `to`.
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

    // ---------------------------------------------------------
    // transfer_private — split a Token record, verify freeze-list.
    // Signature matches the on-chain program exactly:
    //   transfer_private(from: address, amount: u128, token: Token, proofs: [MerkleProof; 2])
    //   -> (ComplianceRecord, Token, Token, Final)
    // ---------------------------------------------------------
    fn transfer_private(from: address, amount: u128, token: Token, proofs: [MerkleProof; 2]) -> (ComplianceRecord, Token, Token, Final) {
        assert(token.amount >= amount);
        let compliance: ComplianceRecord = ComplianceRecord {
            owner: from,
            amount: amount,
            sender: from,
            recipient: token.owner,
        };
        let recipient_token: Token = Token {
            owner: token.owner,
            amount: amount,
        };
        let change: Token = Token {
            owner: token.owner,
            amount: token.amount - amount,
        };
        return (compliance, recipient_token, change, final {
            // Stub: on-chain program verifies freeze-list Merkle proofs here
        });
    }

    @noupgrade constructor() {}
}
