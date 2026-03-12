// portal/src/workflows/audit_workflow.ts
//
// Phase 1 workflow definition (planning-only).
// - Defines the canonical audit authorization flow with dual-consent enforcement.
// - Produces Layer 1 call plans and derives all commitment hashes.
// - Does NOT execute CLI/wallet/network calls.
//
// Flow overview:
//   Phase 1 — Employer anchors their consent hash in Layer 1
//   Phase 2 — Worker anchors their consent hash in Layer 1
//   Phase 3 — Portal anchors the combined authorization_event_hash in Layer 1
//   Phase 4 — mint_authorization_nft is called (verifies all 3 anchors on-chain)
//             The resulting AuditAuthorizationNFT is owned by the auditor.
//
// The scope_hash (inside the NFT) commits to exactly what the auditor requested.
// The auditor must reveal the AuditScopeRequest pre-image to the portal to receive data.
// The portal serves ONLY records matching the declared scope — nothing else.

import type { Bytes32, U32 } from "../types/aleo_types";
import type { CallPlanStep } from "../router/layer1_router";
import {
  type AuditScopeRequest,
  type DerivedAuditHashes,
  deriveAuditHashes,
  describeDataCategories,
} from "../commitments/audit_scope_encoder";

// ---------------------------------------------------------
// Re-export scope types for consumers (adapter, tests, future audit_repo SDK)
// ---------------------------------------------------------
export type { AuditScopeRequest } from "../commitments/audit_scope_encoder";
export {
  DATA_CAT_PAYROLL_CYCLE,
  DATA_CAT_QUARTERLY_SUMMARY,
  DATA_CAT_YTD_SUMMARY,
  DATA_CAT_EOY_SUMMARY,
  DATA_CAT_CREDENTIALS,
  DATA_CAT_AUDIT_EVENTS,
  PURPOSE_REGULATORY_AUDIT,
  PURPOSE_COMPLIANCE_REVIEW,
  PURPOSE_DISPUTE_RESOLUTION,
  PURPOSE_TAX_REVIEW,
  PURPOSE_WORKER_REQUEST,
} from "../commitments/audit_scope_encoder";

// ---------------------------------------------------------
// Workflow input — what the auditor submits to initiate the flow
// ---------------------------------------------------------

export type AuditRequestInput = {
  // Unique identifier for this request (portal-generated, hex32)
  request_id: Bytes32;

  // Auditor's Aleo address (becomes NFT owner; BLAKE3 hash stored in consent hashes)
  auditor_address: string;

  // BLAKE3 of the auditor's Aleo address (pre-computed for consent hash derivation)
  auditor_addr_hash: Bytes32;

  // Exactly what the auditor is requesting — this is all they can ever access
  scope: AuditScopeRequest;

  // Current epoch at time of request (used to derive expires_epoch)
  issued_epoch: U32;

  // Policy document hash (operator-defined; versioned by policy_v)
  policy_hash: Bytes32;

  // Schema and policy versions
  schema_v: number;
  policy_v: number;
};

// ---------------------------------------------------------
// Consent context — derived from the request, shared with both consenting parties
// ---------------------------------------------------------
//
// Both Worker and Employer receive this context before signing.
// They see: what data is being requested, for which worker/employer,
// what the purpose is, and exactly how long access is requested.
// Their consent hashes commit to all of these fields.

export type AuditConsentContext = {
  request_id: Bytes32;
  scope_hash: Bytes32;
  expires_epoch: U32;
  access_duration_epochs: U32;
  data_categories_description: string[];   // human-readable for UI review
  employer_consent_hash: Bytes32;
  worker_consent_hash: Bytes32;
  authorization_event_hash: Bytes32;
};

// ---------------------------------------------------------
// Workflow output — the full call plan + derived hashes
// ---------------------------------------------------------

export type AuditWorkflowOutput = {
  // Four-phase call plan (planning only — no execution here)
  phases: {
    phase1_employer: CallPlanStep[];   // employer anchors consent
    phase2_worker: CallPlanStep[];     // worker anchors consent
    phase3_combined: CallPlanStep[];   // portal anchors authorization event
    phase4_mint: CallPlanStep[];       // mint the NFT
  };

  // Consent context — shared with both parties before they sign
  consent_context: AuditConsentContext;

  // All derived hashes — for adapter consumption and test assertions
  hashes: DerivedAuditHashes;

  // Mint inputs — passed to the adapter when executing Phase 4
  mint_inputs: AuditMintInputs;
};

export type AuditMintInputs = {
  auth_id: Bytes32;
  request_id: Bytes32;
  scope_hash: Bytes32;
  authorization_event_hash: Bytes32;
  employer_consent_hash: Bytes32;
  worker_consent_hash: Bytes32;
  policy_hash: Bytes32;
  issued_epoch: U32;
  expires_epoch: U32;
  access_duration_epochs: U32;
  schema_v: number;
  policy_v: number;
};

// ---------------------------------------------------------
// Consent state machine
// ---------------------------------------------------------
//
// Tracks the authorization lifecycle from request to active NFT.
// The portal state machine transitions through these states.
// Each state transition requires an on-chain confirmation of the anchor.
//
// PENDING_EMPLOYER  → employer receives consent_context, reviews, signs
// EMPLOYER_CONSENTED → employer_consent_hash confirmed anchored in Layer 1
// PENDING_WORKER    → worker receives consent_context, reviews, signs
// DUAL_CONSENTED    → worker_consent_hash confirmed anchored in Layer 1
// ACTIVE            → authorization_event_hash anchored + NFT minted
// REVOKED           → revoke_authorization_nft called on-chain
// EXPIRED           → mark_authorization_expired called on-chain (or expires_epoch passed)

export type AuditConsentState =
  | "PENDING_EMPLOYER"
  | "EMPLOYER_CONSENTED"
  | "PENDING_WORKER"
  | "DUAL_CONSENTED"
  | "ACTIVE"
  | "REVOKED"
  | "EXPIRED";

// ---------------------------------------------------------
// buildAuditWorkflow — generate full call plan from auditor's request
// ---------------------------------------------------------
//
// This is the main entry point. It:
//   1. Validates the scope request
//   2. Derives all commitment hashes
//   3. Builds the four-phase call plan
//   4. Returns the consent context for distribution to both parties
//
// The call plan steps are planning-only. Execution happens in the adapter layer.

export function buildAuditWorkflow(
  input: AuditRequestInput,
  auth_id: Bytes32
): AuditWorkflowOutput {
  if (input.scope.access_duration_epochs === 0) {
    throw new Error("access_duration_epochs must not be zero");
  }
  if (input.scope.data_categories === 0) {
    throw new Error("data_categories must not be zero — auditor must specify at least one category");
  }
  if (input.scope.period_end_epoch < input.scope.period_start_epoch) {
    throw new Error("period_end_epoch must be >= period_start_epoch");
  }
  if (input.issued_epoch === 0) {
    throw new Error("issued_epoch must not be zero");
  }

  const hashes = deriveAuditHashes({
    request_id: input.request_id,
    scope: input.scope,
    issued_epoch: input.issued_epoch,
    auditor_addr_hash: input.auditor_addr_hash,
    employer_id_hash: input.scope.employer_id_hash,
    worker_id_hash: input.scope.worker_id_hash,
  });

  const consent_context: AuditConsentContext = {
    request_id: input.request_id,
    scope_hash: hashes.scope_hash,
    expires_epoch: hashes.expires_epoch,
    access_duration_epochs: input.scope.access_duration_epochs,
    data_categories_description: describeDataCategories(input.scope.data_categories),
    employer_consent_hash: hashes.employer_consent_hash,
    worker_consent_hash: hashes.worker_consent_hash,
    authorization_event_hash: hashes.authorization_event_hash,
  };

  const mint_inputs: AuditMintInputs = {
    auth_id,
    request_id: input.request_id,
    scope_hash: hashes.scope_hash,
    authorization_event_hash: hashes.authorization_event_hash,
    employer_consent_hash: hashes.employer_consent_hash,
    worker_consent_hash: hashes.worker_consent_hash,
    policy_hash: input.policy_hash,
    issued_epoch: input.issued_epoch,
    expires_epoch: hashes.expires_epoch,
    access_duration_epochs: input.scope.access_duration_epochs,
    schema_v: input.schema_v,
    policy_v: input.policy_v,
  };

  return {
    phases: {
      // Phase 1: Employer reviews consent_context and anchors their consent hash
      phase1_employer: [
        {
          kind: "audit_anchor_event",
          event_hash: hashes.employer_consent_hash,
        },
      ],

      // Phase 2: Worker reviews consent_context and anchors their consent hash
      phase2_worker: [
        {
          kind: "audit_anchor_event",
          event_hash: hashes.worker_consent_hash,
        },
      ],

      // Phase 3: Portal anchors the combined authorization event (both consents required first)
      phase3_combined: [
        {
          kind: "audit_anchor_event",
          event_hash: hashes.authorization_event_hash,
        },
      ],

      // Phase 4: Mint the NFT (verifies all 3 hashes anchored on-chain)
      phase4_mint: [
        {
          kind: "audit_mint_authorization_nft",
          ...mint_inputs,
        },
      ],
    },

    consent_context,
    hashes,
    mint_inputs,
  };
}
