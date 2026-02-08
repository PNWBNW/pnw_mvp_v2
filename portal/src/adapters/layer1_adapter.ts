// portal/src/adapters/layer1_adapter.ts
//
// Layer 1 Adapter interface + shared types.
// The router builds a call plan (kinds + typed args).
// The adapter maps kinds -> (program, transition) and executes via a backend (CLI, wallet, SDK).
//
// IMPORTANT:
// - Keep program/transition strings here (single source of truth for execution).
// - Router must remain free of program/transition strings.

import type { Network } from "../config/env";
import type { CallPlanStep, CallPlanResult } from "../router/layer1_router";

// Minimal execution metadata (extend later if needed)
export type TxMeta = {
  program: string;
  transition: string;
  network: Network;
};

export type StepExecutionResult = {
  meta: TxMeta;
  // Adapter-specific raw output (CLI JSON, wallet response, etc.)
  raw: unknown;
  // Parsed outputs (records, fields) if the adapter supports it.
  outputs?: unknown;
};

export interface Layer1Adapter {
  /**
   * Execute a plan in-order. The adapter is responsible for:
   * - selecting the correct program + transition for each step.kind
   * - building the transaction request
   * - signing (wallet/cli)
   * - broadcasting
   * - returning outputs (records) when applicable
   */
  executePlan(network: Network, plan: CallPlanStep[]): Promise<CallPlanResult>;
}

/**
 * Map each CallPlanStep kind to the exact on-chain program + transition.
 * This is the canonical execution mapping and must match LAYER1_INTERFACE.md.
 */
export function resolveLayer1Endpoint(network: Network, step: CallPlanStep): TxMeta {
  // USDCx program differs per network.
  // Testnet: test_usdcx_stablecoin.aleo
  // Mainnet: usdcx_stablecoin.aleo
  const USDCX_PROGRAM = network === "testnet" ? "test_usdcx_stablecoin.aleo" : "usdcx_stablecoin.aleo";

  switch (step.kind) {
    // -----------------------------
    // pnw_name_registry.aleo
    // -----------------------------
    case "register_worker_name":
      return { program: "pnw_name_registry.aleo", transition: "register_worker_name", network };
    case "release_worker_name":
      return { program: "pnw_name_registry.aleo", transition: "release_worker_name", network };
    case "register_employer_name":
      return { program: "pnw_name_registry.aleo", transition: "register_employer_name", network };
    case "request_employer_sellback":
      return { program: "pnw_name_registry.aleo", transition: "request_employer_sellback", network };
    case "fulfill_employer_sellback":
      return { program: "pnw_name_registry.aleo", transition: "fulfill_employer_sellback", network };
    case "assert_name_owner":
      return { program: "pnw_name_registry.aleo", transition: "assert_is_owner", network };

    // -----------------------------
    // worker_profiles.aleo
    // -----------------------------
    case "create_worker_profile":
      return { program: "worker_profiles.aleo", transition: "create_worker_profile", network };
    case "update_worker_profile":
      return { program: "worker_profiles.aleo", transition: "update_worker_profile", network };
    case "assert_worker_profile_anchored":
      return { program: "worker_profiles.aleo", transition: "assert_profile_anchored", network };
    case "get_worker_profile_anchor_height":
      return { program: "worker_profiles.aleo", transition: "get_anchor_height", network };

    // -----------------------------
    // employer_profiles.aleo
    // -----------------------------
    case "create_employer_profile":
      return { program: "employer_profiles.aleo", transition: "create_employer_profile", network };
    case "update_employer_profile":
      return { program: "employer_profiles.aleo", transition: "update_employer_profile", network };
    case "assert_employer_profile_anchored":
      return { program: "employer_profiles.aleo", transition: "assert_profile_anchored", network };
    case "get_employer_profile_anchor_height":
      return { program: "employer_profiles.aleo", transition: "get_anchor_height", network };

    // -----------------------------
    // employer_license_registry.aleo
    // -----------------------------
    case "license_set_verified":
      return { program: "employer_license_registry.aleo", transition: "set_verified", network };
    case "license_assert_verified":
      return { program: "employer_license_registry.aleo", transition: "assert_verified", network };
    case "license_get_license_hash":
      return { program: "employer_license_registry.aleo", transition: "get_license_hash", network };

    // -----------------------------
    // employer_agreement.aleo
    // -----------------------------
    case "create_job_offer":
      return { program: "employer_agreement.aleo", transition: "create_job_offer", network };
    case "accept_job_offer":
      return { program: "employer_agreement.aleo", transition: "accept_job_offer", network };
    case "pause_agreement":
      return { program: "employer_agreement.aleo", transition: "pause_agreement", network };
    case "terminate_agreement":
      return { program: "employer_agreement.aleo", transition: "terminate_agreement", network };
    case "resume_agreement_employer":
      return { program: "employer_agreement.aleo", transition: "resume_agreement_employer", network };
    case "resume_agreement_worker":
      return { program: "employer_agreement.aleo", transition: "resume_agreement_worker", network };
    case "resume_agreement_dao":
      return { program: "employer_agreement.aleo", transition: "resume_agreement_dao", network };
    case "finalize_resume":
      return { program: "employer_agreement.aleo", transition: "finalize_resume", network };
    case "supersede_agreement":
      return { program: "employer_agreement.aleo", transition: "supersede_agreement", network };
    case "assert_agreement_active":
      return { program: "employer_agreement.aleo", transition: "assert_agreement_active", network };
    case "get_agreement_anchor_height":
      return { program: "employer_agreement.aleo", transition: "get_anchor_height", network };

    // -----------------------------
    // paystub_receipts.aleo
    // -----------------------------
    case "mint_paystub_receipts":
      return { program: "paystub_receipts.aleo", transition: "mint_paystub_receipts", network };
    case "mint_reversal_receipts":
      return { program: "paystub_receipts.aleo", transition: "mint_reversal_receipts", network };
    case "assert_receipt_anchored":
      return { program: "paystub_receipts.aleo", transition: "assert_receipt_anchored", network };
    case "get_receipt_anchor_height":
      return { program: "paystub_receipts.aleo", transition: "get_anchor_height", network };

    // -----------------------------
    // payroll_audit_log.aleo
    // -----------------------------
    case "audit_anchor_event":
      return { program: "payroll_audit_log.aleo", transition: "anchor_event", network };
    case "audit_assert_event_anchored":
      return { program: "payroll_audit_log.aleo", transition: "assert_event_anchored", network };
    case "audit_get_event_height":
      return { program: "payroll_audit_log.aleo", transition: "get_event_height", network };

    // -----------------------------
    // payroll_core.aleo
    // -----------------------------
    case "execute_payroll":
      return { program: "payroll_core.aleo", transition: "execute_payroll", network };

    default: {
      // Exhaustiveness check
      const _exhaustive: never = step;
      throw new Error(`Unhandled CallPlanStep kind: ${(step as any).kind}`);
    }
  }
}
