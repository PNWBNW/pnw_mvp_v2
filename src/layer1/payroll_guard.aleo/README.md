# payroll_guard.aleo

## Purpose

`payroll_guard.aleo` is a **standalone double-pay guard** for the sequential payroll flow.

The monolithic `payroll_core_v2::execute_payroll` enforced a
`paid_epoch[(agreement_id, epoch_id)]` guard in its finalize, but the portal's
4-step sequential payroll flow (required because Shield wallet's in-browser
prover silently drops multi-program proofs) bypasses `payroll_core` entirely —
leaving no on-chain double-pay protection.

This program restores that protection as **step 0** of the sequential flow:

```
Step 0: payroll_guard::claim_payment_slot(payment_key)   ← this program
Step 1: employer_agreement_v4::assert_agreement_active
Step 2: test_usdcx_stablecoin::transfer_private
Step 3: paystub_receipts::mint_paystub_receipts
Step 4: payroll_audit_log::anchor_event
```

`claim_payment_slot` is a single-program transition, so the wallet prover can
always build it.

## Key design — what blocks and what passes

`payment_key` is the portal-computed `payroll_inputs_hash` (BLAKE3,
manifest `schema_v >= 2`), which commits to:

- `agreement_id` + `epoch_id` (who and which pay period)
- gross / net / tax / fee amounts
- `run_kind` (`regular` / `bonus` / `correction` / `off_cycle`)
- `run_memo` (free-text reason)

So:

| Scenario | Result |
|---|---|
| Accidental resubmission of an identical payment | **Reverts** — slot already claimed |
| Second same-day payment with a different amount | Passes — new key |
| Second same-day payment, same amount, declared as `bonus` or with a memo | Passes — new key, intent on record |

Only a byte-identical payment can ever collide. The companion portal-side
guard (`pnw_employment_portal_v1/src/coordinator/double_pay_guard.ts`) catches
the same collision before any wallet signature is requested; this program
makes the protection trustless.

## Transitions

| Transition | Inputs | Behavior |
|---|---|---|
| `claim_payment_slot` | `payment_key: [u8; 32]` | Asserts the key is unclaimed, then records `block.height`. Reverts on replay. |
| `assert_payment_claimed` | `payment_key: [u8; 32]` | Cross-program assertion that step 0 ran for this key. |

## Privacy

Public state is `payment_key => first-claimed block height` only — an opaque,
domain-separated hash. No identities, wages, cumulative counters, or
per-actor balances (architecture invariants #3 and #4).

## Deployment status

**Not yet deployed.** Deploy with Leo 4.0.0 / snarkOS v4.6.0 per
`docs/operations/PHASE4_CLI_SETUP.md`, then:

1. Update `config/testnet.manifest.json` (`deployments` entry → `active`).
2. Wire step 0 into `executeSequentialPayroll` in
   `pnw_employment_portal_v1/src/coordinator/settlement_coordinator.ts`
   (the per-worker `payroll_inputs_hash` is already available there).
