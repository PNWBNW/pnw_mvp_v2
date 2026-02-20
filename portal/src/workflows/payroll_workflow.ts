// portal/src/workflows/payroll_workflow.ts
//
// Phase 1 workflow definition (planning-only).
// - Defines canonical payroll intent and ordering.
// - Produces Layer 1 call plans.
// - Does NOT execute CLI/wallet/network calls.

import type { CallPlanStep } from "../router/layer1_router";

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
    },
  };
}
