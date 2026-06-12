program payroll_guard.aleo {

    // ---------------------------------------------------------
    // Payroll Guard (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Purpose:
    // - Trustless double-pay protection for the sequential payroll flow.
    // - The monolithic payroll_core_v2::execute_payroll carried a
    //   paid_epoch[(agreement_id, epoch_id)] guard in its finalize, but the
    //   4-step sequential flow (required for Shield wallet's in-browser
    //   prover) bypasses payroll_core entirely. This standalone program
    //   restores the guard as step 0 of that flow: a single-program proof
    //   the wallet can always build.
    //
    // Key design:
    // - payment_key is the portal-computed payroll_inputs_hash
    //   (BLAKE3, schema_v >= 2), which commits to the agreement, epoch,
    //   amounts, run_kind, and run_memo. An intentional repeat payment
    //   (different amount, kind, or memo) derives a new key and claims a
    //   new slot; only a byte-identical resubmission collides and reverts.
    //
    // Privacy:
    // - Only key existence and first-claimed block height are public.
    //   No identities, wages, or counters (invariants #3 and #4).

    // ---------------------------------------------------------
    // payment_key => first-claimed block height
    // ---------------------------------------------------------
    mapping claimed_payment_height: [u8; 32] => u32;

    // ---------------------------------------------------------
    // Claim a payment slot (step 0 of the sequential payroll flow).
    // Reverts if the slot was already claimed.
    // ---------------------------------------------------------
    fn claim_payment_slot(payment_key: [u8; 32]) -> Final {
        return final {
            let existing: u32 = claimed_payment_height.get_or_use(payment_key, 0u32);
            assert(existing == 0u32);
            claimed_payment_height.set(payment_key, block.height);
        };
    }

    // ---------------------------------------------------------
    // Cross-program assertion: ensure a payment slot was claimed.
    // Lets downstream programs require that step 0 ran.
    // ---------------------------------------------------------
    fn assert_payment_claimed(payment_key: [u8; 32]) -> Final {
        return final {
            let h: u32 = claimed_payment_height.get_or_use(payment_key, 0u32);
            assert(h != 0u32);
        };
    }

    @noupgrade constructor() {}
}
