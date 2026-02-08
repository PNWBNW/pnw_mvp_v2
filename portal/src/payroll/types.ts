// portal/src/payroll/types.ts
//
// Canonical payroll portal types (off-chain).
// This file is the vocabulary lock for all payroll aggregation + builders.

import type { Bytes32 } from "../commitments/hash";
import type { PayrollNftScope, PeriodId } from "../commitments/token_id";

export type CurrencyCode = "USDCX";

// Store monetary values as integer base units (deterministic).
export type LedgerUnits = bigint;

export enum PayFrequency {
  DAILY = 1,
  WEEKLY = 2,
  BIWEEKLY = 3,
  MONTHLY = 4,
  QUARTERLY = 5,
}

// Layer2 mint scopes (cycle, quarterly, YTD, EOY)
export type PayrollScope = PayrollNftScope;

// What the portal needs from Layer 1 after decrypt / view authorization.
// This is intentionally minimal and can evolve with schema_v bumps.
export type DecryptedPaystubReceipt = {
  // Canonical anchors/ids
  agreement_id: Bytes32;
  employer_id: Bytes32;
  worker_id: Bytes32;

  // Period identification (portal-defined meaning; still encoded as u32)
  epoch_id: number; // u32
  pay_frequency: PayFrequency;

  // Monetary fields (ledger_units)
  currency: CurrencyCode; // "USDCX"
  gross_ledger_units: LedgerUnits;
  net_ledger_units: LedgerUnits;
  tax_withheld_ledger_units: LedgerUnits;
  fee_amount_ledger_units: LedgerUnits;

  // Receipt linkage
  receipt_anchor: Bytes32; // hash anchor for this receipt event
  anchor_height: number;   // u32 block height when anchored (or issuance height)
  issued_height: number;   // u32 block height when receipt record created (if different)

  // Optional revision/void linkage (portal can interpret)
  revision_of_anchor?: Bytes32; // points to prior anchor being revised
  is_void?: boolean;

  // Optional metadata commitments
  memo_hash?: Bytes32; // commitment to plaintext memo stored off-chain
};

export type NormalizedPayrollEvent = {
  agreement_id: Bytes32;
  employer_id: Bytes32;
  worker_id: Bytes32;

  epoch_id: number; // u32
  pay_frequency: PayFrequency;

  currency: CurrencyCode;

  gross_ledger_units: LedgerUnits;
  net_ledger_units: LedgerUnits;
  tax_withheld_ledger_units: LedgerUnits;
  fee_amount_ledger_units: LedgerUnits;

  receipt_anchor: Bytes32;
  anchor_height: number; // u32

  revision_of_anchor?: Bytes32;
  is_void: boolean;
  memo_hash?: Bytes32;
};

export type IndexedAgreementEpoch = {
  agreement_id: Bytes32;
  epoch_id: number; // u32
  events: NormalizedPayrollEvent[];

  // Deterministic aggregates for summaries
  gross_total: LedgerUnits;
  net_total: LedgerUnits;
  tax_total: LedgerUnits;
  fee_total: LedgerUnits;

  // Anchor heights can be used for audit reference
  min_anchor_height: number; // u32
  max_anchor_height: number; // u32
};

export type PaystubBuildInput = {
  event: NormalizedPayrollEvent;
};

export type SummaryBuildInput = {
  agreement_id: Bytes32;
  period_id: PeriodId; // u32 (portal-defined encoding)
  scope: PayrollScope;
  events: NormalizedPayrollEvent[];
};
