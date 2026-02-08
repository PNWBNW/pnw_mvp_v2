// portal/src/payroll/indexer.ts
//
// Index normalized payroll events into deterministic groupings used by builders:
// - (agreement_id, epoch_id) buckets
// - stable ordering
// - precomputed aggregates

import type { IndexedAgreementEpoch, NormalizedPayrollEvent } from "./types";
import { toHex } from "../commitments/hash";

export function indexByAgreementAndEpoch(events: NormalizedPayrollEvent[]): IndexedAgreementEpoch[] {
  // Stable sort first (so outputs are deterministic regardless of input order).
  const sorted = events.slice().sort((a, b) => {
    const ag = cmpHex(toHex(a.agreement_id), toHex(b.agreement_id));
    if (ag !== 0) return ag;
    if (a.epoch_id !== b.epoch_id) return a.epoch_id < b.epoch_id ? -1 : 1;
    // tie-break on anchor height, then anchor bytes
    if (a.anchor_height !== b.anchor_height) return a.anchor_height < b.anchor_height ? -1 : 1;
    return cmpHex(toHex(a.receipt_anchor), toHex(b.receipt_anchor));
  });

  const buckets = new Map<string, IndexedAgreementEpoch>();

  for (const ev of sorted) {
    const key = `${toHex(ev.agreement_id)}::${ev.epoch_id}`;
    const existing = buckets.get(key);

    if (!existing) {
      buckets.set(key, {
        agreement_id: ev.agreement_id,
        epoch_id: ev.epoch_id,
        events: [ev],

        gross_total: ev.is_void ? 0n : ev.gross_ledger_units,
        net_total: ev.is_void ? 0n : ev.net_ledger_units,
        tax_total: ev.is_void ? 0n : ev.tax_withheld_ledger_units,
        fee_total: ev.is_void ? 0n : ev.fee_amount_ledger_units,

        min_anchor_height: ev.anchor_height,
        max_anchor_height: ev.anchor_height,
      });
    } else {
      existing.events.push(ev);

      if (!ev.is_void) {
        existing.gross_total += ev.gross_ledger_units;
        existing.net_total += ev.net_ledger_units;
        existing.tax_total += ev.tax_withheld_ledger_units;
        existing.fee_total += ev.fee_amount_ledger_units;
      }

      if (ev.anchor_height < existing.min_anchor_height) existing.min_anchor_height = ev.anchor_height;
      if (ev.anchor_height > existing.max_anchor_height) existing.max_anchor_height = ev.anchor_height;
    }
  }

  // Return in deterministic insertion order based on sorted traversal.
  return Array.from(buckets.values());
}

function cmpHex(a: string, b: string): number {
  if (a === b) return 0;
  return a < b ? -1 : 1;
}
