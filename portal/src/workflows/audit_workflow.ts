// portal/src/workflows/audit_workflow.ts
//
// Phase 1 workflow definition (planning-only).
// - Defines canonical audit authorization intent and ordering.
// - Produces Layer 1 call plans.
// - Does NOT execute CLI/wallet/network calls.

import type { Bytes32, U32 } from "../types/aleo_types";
import type { CallPlanStep } from "../router/layer1_router";

export type AuditScope = {
  // Domain-separated scope commitment generated off-chain.
  scope_hash: Bytes32;

  // Optional references for operator traceability.
  agreement_id?: Bytes32;
  receipt_anchor?: Bytes32;

  // Human/audit process metadata is represented by hashes only.
  policy_hash?: Bytes32;
};

export type AuditAuthorizationRequest = {
  // Event hash anchored in payroll_audit_log.aleo (authorization-bound hash).
  authorization_event_hash: Bytes32;

  // Scope commitment for what can be disclosed.
  scope: AuditScope;

  // Optional expiry epoch (portal policy; u32 semantics).
  expires_epoch?: U32;

  // If true, include an assertion step after anchoring.
  include_post_anchor_assert?: boolean;
};

export type AuditWorkflowOutput = {
  plan: CallPlanStep[];
  outputs: {
    authorization_event_hash: Bytes32;
    scope_hash: Bytes32;
    expires_epoch: U32 | null;
  };
};

/**
 * Build canonical audit-authorization workflow plan.
 *
 * Order:
 * 1) Anchor authorization event hash.
 * 2) Optionally assert anchor existence in the same plan.
 *
 * Notes:
 * - Batched anchoring model: callers may submit multiple authorization requests
 *   and concatenate resulting `audit_anchor_event` steps before execution.
 * - Expiry handling is encoded in workflow outputs for policy enforcement in
 *   downstream layers (adapter/UI/off-chain checks).
 */
export function buildAuditWorkflow(input: AuditAuthorizationRequest): AuditWorkflowOutput {
  const plan: CallPlanStep[] = [
    {
      kind: "audit_anchor_event",
      event_hash: input.authorization_event_hash,
    },
  ];

  if (input.include_post_anchor_assert === true) {
    plan.push({
      kind: "audit_assert_event_anchored",
      event_hash: input.authorization_event_hash,
    });
  }

  return {
    plan,
    outputs: {
      authorization_event_hash: input.authorization_event_hash,
      scope_hash: input.scope.scope_hash,
      expires_epoch: input.expires_epoch ?? null,
    },
  };
}
