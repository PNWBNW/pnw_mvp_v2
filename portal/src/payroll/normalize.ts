// portal/src/payroll/normalize.ts
//
// Deterministic normalization of decrypted Layer 1 receipts into base payroll events.
// Keep this pure (no I/O). This is the "inspection step" in the portal pipeline.

import type { DecryptedPaystubReceipt, NormalizedPayrollEvent } from "./types";
import { assertBytes32 } from "../commitments/hash";

export function normalizePaystubReceipt(r: DecryptedPaystubReceipt): NormalizedPayrollEvent {
  // Basic structural assertions (cheap and catches drift early).
  assertBytes32(r.agreement_id, "agreement_id");
  assertBytes32(r.employer_id, "employer_id");
  assertBytes32(r.worker_id, "worker_id");
  assertBytes32(r.receipt_anchor, "receipt_anchor");
  if (r.revision_of_anchor) assertBytes32(r.revision_of_anchor, "revision_of_anchor");
  if (r.memo_hash) assertBytes32(r.memo_hash, "memo_hash");

  // Determinism rules:
  // - epoch_id must be u32
  // - heights must be u32
  // - currency must be fixed string (USDCX)
  // - monetary fields are bigint (ledger_units)
  assertU32(r.epoch_id, "epoch_id");
  assertU32(r.anchor_height, "anchor_height");
  assertU32(r.issued_height, "issued_height");
  if (r.currency !== "USDCX") throw new Error(`Unsupported currency: ${r.currency}`);

  // Default flags
  const is_void = Boolean(r.is_void);

  return {
    agreement_id: r.agreement_id,
    employer_id: r.employer_id,
    worker_id: r.worker_id,

    epoch_id: r.epoch_id,
    pay_frequency: r.pay_frequency,

    currency: r.currency,

    gross_ledger_units: assertLedger(r.gross_ledger_units, "gross_ledger_units"),
    net_ledger_units: assertLedger(r.net_ledger_units, "net_ledger_units"),
    tax_withheld_ledger_units: assertLedger(r.tax_withheld_ledger_units, "tax_withheld_ledger_units"),
    fee_amount_ledger_units: assertLedger(r.fee_amount_ledger_units, "fee_amount_ledger_units"),

    receipt_anchor: r.receipt_anchor,
    anchor_height: r.anchor_height,

    revision_of_anchor: r.revision_of_anchor,
    is_void,
    memo_hash: r.memo_hash,
  };
}

export function normalizeMany(receipts: DecryptedPaystubReceipt[]): NormalizedPayrollEvent[] {
  return receipts.map(normalizePaystubReceipt);
}

function assertU32(n: number, label: string): void {
  if (!Number.isInteger(n) || n < 0 || n > 0xffffffff) throw new Error(`${label} must be u32`);
}

function assertLedger(x: bigint, label: string): bigint {
  if (typeof x !== "bigint") throw new Error(`${label} must be bigint`);
  // ledger_units should be non-negative; reversals happen as separate receipts (your model)
  if (x < 0n) throw new Error(`${label} must be non-negative`);
  return x;
}
