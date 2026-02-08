// portal/src/payroll/paystub_builder.ts
//
// Builds a canonical paystub document (off-chain) suitable for commitments + optional Layer2 mint.
// This outputs a CanonicalDoc consumed by commitments/buildCommitments().

import type { CanonicalDoc } from "../commitments/canonical_encoder";
import { PayrollNftScope } from "../commitments/token_id";
import type { PaystubBuildInput } from "./types";

export function buildPaystubCanonicalDoc(input: PaystubBuildInput): CanonicalDoc {
  const e = input.event;

  // Canonical doc_type namespace (stable string)
  const doc_type = "PNW::PAYROLL::PAYSTUB";

  // Fields are normalized and deterministic; we only map into CanonicalValue.
  return {
    header: {
      doc_type,
      versions: {
        schema_v: 1,
        calc_v: 1,
        policy_v: 1,
      },
    },

    agreement_id: e.agreement_id,
    period_id: e.epoch_id,          // for cycle paystub, period_id == epoch_id
    scope: PayrollNftScope.CYCLE,

    // Bind the document to the underlying receipt(s)
    input_anchors: [e.receipt_anchor],

    fields: {
      currency: { t: "utf8", v: e.currency },

      employer_id: { t: "bytes32", v: e.employer_id },
      worker_id: { t: "bytes32", v: e.worker_id },

      pay_frequency: { t: "u8", v: e.pay_frequency },

      gross_ledger_units: { t: "ledger_units", v: e.gross_ledger_units },
      net_ledger_units: { t: "ledger_units", v: e.net_ledger_units },
      tax_withheld_ledger_units: { t: "ledger_units", v: e.tax_withheld_ledger_units },
      fee_amount_ledger_units: { t: "ledger_units", v: e.fee_amount_ledger_units },

      anchor_height: { t: "u32", v: e.anchor_height },

      is_void: { t: "u8", v: e.is_void ? 1 : 0 },

      // Optional linkage fields
      ...(e.revision_of_anchor ? { revision_of_anchor: { t: "bytes32", v: e.revision_of_anchor } } : {}),
      ...(e.memo_hash ? { memo_hash: { t: "bytes32", v: e.memo_hash } } : {}),
    },
  };
}
