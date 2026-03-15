// portal/src/workflows/payroll_workflow.ts
//
// Phase 1 workflow definition (planning-only).
// - Defines canonical payroll intent and ordering.
// - Produces Layer 1 call plans.
// - Does NOT execute CLI/wallet/network calls.

import type { CallPlanStep, BatchPayrollWorker } from "../router/layer1_router";
import type { UsdcxRecord } from "../types/aleo_records";
import type { Field, Address } from "../types/aleo_types";

export type PayrollWorkflowInput = {
  // Canonical execute_payroll arguments prepared by portal normalization + commitments.
  payroll: Extract<CallPlanStep, { kind: "execute_payroll" }>["args"];

  // Optional guard rails to include explicit precondition assertions in the plan.
  include_prechecks?: boolean;
};

export type PayrollWorkflowOutput = {
  // Ordered Layer 1 plan (adapter executes later).
  plan: CallPlanStep[];

  // Workflow-level outputs that downstream stages can reuse for tracing and L2 commitments.
  outputs: {
    agreement_id: Extract<CallPlanStep, { kind: "execute_payroll" }>["args"]["agreement_id"];
    epoch_id: Extract<CallPlanStep, { kind: "execute_payroll" }>["args"]["epoch_id"];
    receipt_anchor: Extract<CallPlanStep, { kind: "execute_payroll" }>["args"]["receipt_anchor"];
    receipt_pair_hash: Extract<CallPlanStep, { kind: "execute_payroll" }>["args"]["receipt_pair_hash"];
    payroll_inputs_hash: Extract<CallPlanStep, { kind: "execute_payroll" }>["args"]["payroll_inputs_hash"];
    audit_event_hash: Extract<CallPlanStep, { kind: "execute_payroll" }>["args"]["audit_event_hash"];
    /** Manifest linkage: passed through for Settlement Coordinator reconciliation. */
    batch_id: Extract<CallPlanStep, { kind: "execute_payroll" }>["args"]["batch_id"];
    row_hash: Extract<CallPlanStep, { kind: "execute_payroll" }>["args"]["row_hash"];
  };
};

/**
 * Build canonical payroll workflow plan.
 *
 * Order:
 * 1) Optional agreement assertion precheck.
 * 2) Execute payroll settlement + receipt mint + audit anchor in payroll_core.
 *
 * Notes:
 * - No execution happens here.
 * - Hash/anchor generation is supplied by commitments modules upstream.
 */
export function buildPayrollWorkflow(input: PayrollWorkflowInput): PayrollWorkflowOutput {
  const plan: CallPlanStep[] = [];

  if (input.include_prechecks !== false) {
    plan.push({
      kind: "assert_agreement_active",
      agreement_id: input.payroll.agreement_id,
    });
  }

  plan.push({ kind: "execute_payroll", args: input.payroll });

  return {
    plan,
    outputs: {
      agreement_id: input.payroll.agreement_id,
      epoch_id: input.payroll.epoch_id,
      receipt_anchor: input.payroll.receipt_anchor,
      receipt_pair_hash: input.payroll.receipt_pair_hash,
      payroll_inputs_hash: input.payroll.payroll_inputs_hash,
      audit_event_hash: input.payroll.audit_event_hash,
      batch_id: input.payroll.batch_id,
      row_hash: input.payroll.row_hash,
    },
  };
}

// ---------------------------------------------------------
// Batch payroll workflow (2 workers, 1 transaction)
// ---------------------------------------------------------

export type BatchPayrollWorkflowInput = {
  /**
   * A single USDCx Token record with amount >= worker1.net_amount + worker2.net_amount.
   * Obtain via portal/src/records/usdcx_fetcher.ts or scripts/scan_usdcx_records.sh.
   *
   * IMPORTANT: The program ID encoded in this record must match the deployed
   * USDCx program on testnet. Check config/testnet.manifest.json -> external.usdcx.
   * The actual testnet deployment may use a different name than "test_usdcx_stablecoin.aleo".
   */
  employer_usdcx: UsdcxRecord;
  employer_addr: Address;
  employer_name_hash: Field;
  worker1: BatchPayrollWorker;
  worker2: BatchPayrollWorker;
  include_prechecks?: boolean;
};

export type BatchPayrollWorkflowOutput = {
  plan: CallPlanStep[];
  outputs: {
    worker1: Pick<BatchPayrollWorker, "agreement_id" | "epoch_id" | "receipt_anchor" | "audit_event_hash" | "batch_id" | "row_hash">;
    worker2: Pick<BatchPayrollWorker, "agreement_id" | "epoch_id" | "receipt_anchor" | "audit_event_hash" | "batch_id" | "row_hash">;
    /** Total net USDCx that will leave the employer record (minor units) */
    total_net_amount: bigint;
  };
};

/**
 * Build a batch payroll plan for two workers in a single on-chain transaction.
 *
 * The plan produces one execute_payroll_batch_2 step. The circuit:
 * - Takes the single employer_usdcx record
 * - Chains two transfer_private calls internally (no wallet record juggling)
 * - Atomically guards both (agreement_id, epoch_id) pairs against double-pay
 * - Emits two WorkerPaystubReceipt + two EmployerPaystubReceipt records
 *
 * Pre-conditions (caller must satisfy before building this plan):
 * - employer_usdcx.amount >= worker1.net_amount + worker2.net_amount
 * - Both worker1.agreement_id and worker2.agreement_id map to ACTIVE agreements
 * - All receipt_anchor, audit_event_hash, payroll_inputs_hash values are
 *   pre-computed canonical hashes (use commitments/canonical_encoder.ts)
 */
export function buildBatchPayrollWorkflow(
  input: BatchPayrollWorkflowInput,
): BatchPayrollWorkflowOutput {
  const plan: CallPlanStep[] = [];

  if (input.include_prechecks !== false) {
    plan.push(
      { kind: "assert_agreement_active", agreement_id: input.worker1.agreement_id },
      { kind: "assert_agreement_active", agreement_id: input.worker2.agreement_id },
    );
  }

  plan.push({
    kind: "execute_payroll_batch_2",
    args: {
      employer_usdcx: input.employer_usdcx,
      employer_addr: input.employer_addr,
      employer_name_hash: input.employer_name_hash,
      worker1: input.worker1,
      worker2: input.worker2,
    },
  });

  return {
    plan,
    outputs: {
      worker1: {
        agreement_id: input.worker1.agreement_id,
        epoch_id: input.worker1.epoch_id,
        receipt_anchor: input.worker1.receipt_anchor,
        audit_event_hash: input.worker1.audit_event_hash,
        batch_id: input.worker1.batch_id,
        row_hash: input.worker1.row_hash,
      },
      worker2: {
        agreement_id: input.worker2.agreement_id,
        epoch_id: input.worker2.epoch_id,
        receipt_anchor: input.worker2.receipt_anchor,
        audit_event_hash: input.worker2.audit_event_hash,
        batch_id: input.worker2.batch_id,
        row_hash: input.worker2.row_hash,
      },
      total_net_amount: input.worker1.net_amount + input.worker2.net_amount,
    },
  };
}
