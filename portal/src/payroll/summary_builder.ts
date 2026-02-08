// portal/src/payroll/summary_builder.ts
//
// Builds canonical summary documents for:
// - QUARTERLY
// - YTD
// - EOY
//
// The portal decides the scope + period_id meaning.
// The commitments layer only requires period_id is u32 and deterministic.

import type { CanonicalDoc } from "../commitments/canonical_encoder";
import { PayrollNftScope } from "../commitments/token_id";
import type { SummaryBuildInput } from "./types";

export function buildPayrollSummaryCanonicalDoc(input: SummaryBuildInput): CanonicalDoc {
  const { agreement_id, period_id, scope, events } = input;

  const doc_type = docTypeForScope(scope);

  // Deterministic input anchors set:
  // - include all receipt_anchor values
  // - commitments/buildCommitments() will sort defensively
  const anchors = events.map((e) => e.receipt_anchor);

  // Deterministic aggregates (ignore void events)
  let gross_total = 0n;
  let net_total = 0n;
  let tax_total = 0n;
  let fee_total = 0n;

  let min_height = 0xffffffff;
  let max_height = 0;

  // We assume all events are same agreement; portal should enforce upstream.
  for (const e of events) {
    if (!e.is_void) {
      gross_total += e.gross_ledger_units;
      net_total += e.net_ledger_units;
      tax_total += e.tax_withheld_ledger_units;
      fee_total += e.fee_amount_ledger_units;
    }

    if (e.anchor_height < min_height) min_height = e.anchor_height;
    if (e.anchor_height > max_height) max_height = e.anchor_height;
  }

  // If empty, upstream should have rejected; but keep deterministic behavior.
  if (events.length === 0) {
    min_height = 0;
    max_height = 0;
  }

  // Currency is fixed to USDCX for now; enforce by taking the first if present.
  const currency = events[0]?.currency ?? "USDCX";

  return {
    header: {
      doc_type,
      versions: {
        schema_v: 1,
        calc_v: 1,
        policy_v: 1,
      },
    },

    agreement_id,
    period_id,
    scope,

    input_anchors: anchors,

    fields: {
      currency: { t: "utf8", v: currency },

      // Aggregate totals in ledger_units
      gross_total_ledger_units: { t: "ledger_units", v: gross_total },
      net_total_ledger_units: { t: "ledger_units", v: net_total },
      tax_total_ledger_units: { t: "ledger_units", v: tax_total },
      fee_total_ledger_units: { t: "ledger_units", v: fee_total },

      // Provenance window
      min_anchor_height: { t: "u32", v: min_height },
      max_anchor_height: { t: "u32", v: max_height },

      // Event count (including voids, so audits can see corrections occurred)
      event_count: { t: "u32", v: events.length },
    },
  };
}

function docTypeForScope(scope: PayrollNftScope): string {
  switch (scope) {
    case PayrollNftScope.QUARTERLY:
      return "PNW::PAYROLL::SUMMARY::QUARTERLY";
    case PayrollNftScope.YTD:
      return "PNW::PAYROLL::SUMMARY::YTD";
    case PayrollNftScope.EOY:
      return "PNW::PAYROLL::SUMMARY::EOY";
    case PayrollNftScope.CYCLE:
      // Not used for summary_builder; cycle uses paystub_builder.
      return "PNW::PAYROLL::PAYSTUB";
    default:
      return "PNW::PAYROLL::SUMMARY";
  }
}
