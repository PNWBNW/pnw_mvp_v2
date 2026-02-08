// portal/src/router/layer1_router.ts
//
// Layer 1 Router (Portal)
// - Builds deterministic call-plans for Layer 1 on-chain actions.
// - DOES NOT embed transition strings. Those live only in the adapter.
// - DOES NOT compute canonical hashes. Those come from canonical_encoder.ts.
// - Treats Leo records as opaque objects returned by execution adapters.

import type { Network } from "../config/env";
import type { Field, U8, U16, U32, U128, Address, Bytes32 } from "../types/aleo_types";

import type {
  PendingAgreementRecord, // opaque, returned by employer_agreement create_job_offer
  FinalAgreementRecord,   // opaque, returned by employer_agreement accept_job_offer
  EmployerProfileRecord,  // opaque
  WorkerProfileRecord,    // opaque
  WorkerPaystubReceiptRecord,   // opaque
  EmployerPaystubReceiptRecord, // opaque
  UsdcxRecord,            // opaque: test_usdcx_stablecoin.Record
} from "../types/aleo_records";

import type { CanonicalHashes } from "../commitments/canonical_types";

// Adapter interface (implemented by aleo_cli.ts, aleo_wallet.ts, etc.)
import type { Layer1Adapter } from "../adapters/layer1_adapter";

/**
 * A single planned action. The adapter is responsible for converting this into
 * a concrete transaction (CLI/wallet) and returning outputs.
 */
export type CallPlanStep =
  | {
      kind: "register_worker_name";
      name_hash: Field;
      fee_amount: U128; // portal-supplied
    }
  | {
      kind: "release_worker_name";
    }
  | {
      kind: "register_employer_name";
      name_hash: Field;
      suffix_code: U8;
      fee_amount: U128; // portal-supplied
    }
  | {
      kind: "request_employer_sellback";
      name_hash: Field;
    }
  | {
      kind: "fulfill_employer_sellback";
      name_hash: Field;
    }
  | {
      kind: "assert_name_owner";
      name_hash: Field;
      owner: Address;
    }
  | {
      kind: "create_worker_profile";
      args: {
        worker_name_hash: Field;
        first_name_u128: U128;
        middle_name_u128: U128;
        last_name_u128: U128;
        age: U8;
        gender: U8;
        residency_state_code: U16;
        country_code: U16;
        state_issue_id_u128: U128;
        industry_code: U8;
        citizenship_flag: U8;
        schema_v: U16;
        policy_v: U16;
        profile_rev: U16;
        profile_anchor: Bytes32;
      };
    }
  | {
      kind: "update_worker_profile";
      args: {
        old_profile: WorkerProfileRecord;
        first_name_u128: U128;
        middle_name_u128: U128;
        last_name_u128: U128;
        age: U8;
        gender: U8;
        residency_state_code: U16;
        country_code: U16;
        state_issue_id_u128: U128;
        industry_code: U8;
        citizenship_flag: U8;
        schema_v: U16;
        policy_v: U16;
        new_profile_rev: U16;
        new_profile_anchor: Bytes32;
      };
    }
  | {
      kind: "assert_worker_profile_anchored";
      profile_anchor: Bytes32;
    }
  | {
      kind: "get_worker_profile_anchor_height";
      profile_anchor: Bytes32;
    }
  | {
      kind: "create_employer_profile";
      args: {
        employer_name_hash: Field;
        suffix_code: U8;
        legal_name_u128: U128;
        registration_id_u128: U128;
        registration_state_code: U16;
        country_code: U16;
        formation_year: U16;
        entity_type_code: U8;
        industry_code: U8;
        employer_size_code: U8;
        operating_region_code: U16;
        schema_v: U16;
        policy_v: U16;
        profile_rev: U16;
        profile_anchor: Bytes32;
      };
    }
  | {
      kind: "update_employer_profile";
      args: {
        old_profile: EmployerProfileRecord;
        legal_name_u128: U128;
        registration_id_u128: U128;
        registration_state_code: U16;
        country_code: U16;
        formation_year: U16;
        entity_type_code: U8;
        industry_code: U8;
        employer_size_code: U8;
        operating_region_code: U16;
        schema_v: U16;
        policy_v: U16;
        new_profile_rev: U16;
        new_profile_anchor: Bytes32;
      };
    }
  | {
      kind: "assert_employer_profile_anchored";
      profile_anchor: Bytes32;
    }
  | {
      kind: "get_employer_profile_anchor_height";
      profile_anchor: Bytes32;
    }
  | {
      kind: "license_set_verified";
      wallet: Address;
      license_hash: Bytes32;
      verified: boolean;
    }
  | {
      kind: "license_assert_verified";
      wallet: Address;
    }
  | {
      kind: "license_get_license_hash";
      wallet: Address;
    }
  | {
      kind: "create_job_offer";
      args: {
        agreement_id: Bytes32;
        parties_key: Bytes32;
        employer_name_hash: Field;
        worker_name_hash: Field;
        worker_address: Address;
        industry_code: U8;
        pay_frequency_code: U8;
        start_epoch: U32;
        end_epoch: U32;
        review_epoch: U32;
        agreement_rev: U16;
        schema_v: U16;
        policy_v: U16;
        terms_doc_hash: Bytes32;
        terms_root: Bytes32;
        offer_time_hash: Bytes32;
      };
    }
  | {
      kind: "accept_job_offer";
      args: {
        offer: PendingAgreementRecord;
        accept_time_hash: Bytes32;
      };
    }
  | {
      kind: "pause_agreement";
      agreement_id: Bytes32;
      parties_key: Bytes32;
    }
  | {
      kind: "terminate_agreement";
      agreement_id: Bytes32;
      parties_key: Bytes32;
    }
  | {
      kind: "resume_agreement_employer";
      agreement_id: Bytes32;
      parties_key: Bytes32;
    }
  | {
      kind: "resume_agreement_worker";
      agreement_id: Bytes32;
      parties_key: Bytes32;
    }
  | {
      kind: "resume_agreement_dao";
      agreement_id: Bytes32;
      parties_key: Bytes32;
    }
  | {
      kind: "finalize_resume";
      agreement_id: Bytes32;
      parties_key: Bytes32;
    }
  | {
      kind: "supersede_agreement";
      agreement_id: Bytes32;
      parties_key: Bytes32;
    }
  | {
      kind: "assert_agreement_active";
      agreement_id: Bytes32;
    }
  | {
      kind: "get_agreement_anchor_height";
      agreement_id: Bytes32;
    }
  | {
      kind: "mint_paystub_receipts";
      args: {
        worker_owner: Address;
        employer_owner: Address;
        worker_name_hash: Field;
        employer_name_hash: Field;
        agreement_id: Bytes32;
        epoch_id: U32;
        gross_amount: U128;
        net_amount: U128;
        tax_withheld: U128;
        fee_amount: U128;
        payroll_inputs_hash: Bytes32;
        receipt_anchor: Bytes32;
        pair_hash: Bytes32;
        utc_time_hash: Bytes32;
      };
    }
  | {
      kind: "mint_reversal_receipts";
      args: {
        worker_owner: Address;
        employer_owner: Address;
        worker_name_hash: Field;
        employer_name_hash: Field;
        agreement_id: Bytes32;
        epoch_id: U32;
        gross_amount: U128;
        net_amount: U128;
        tax_withheld: U128;
        fee_amount: U128;
        payroll_inputs_hash: Bytes32;
        reversal_anchor: Bytes32;
        pair_hash: Bytes32;
        utc_time_hash: Bytes32;
      };
    }
  | {
      kind: "assert_receipt_anchored";
      receipt_anchor: Bytes32;
    }
  | {
      kind: "get_receipt_anchor_height";
      receipt_anchor: Bytes32;
    }
  | {
      kind: "audit_anchor_event";
      event_hash: Bytes32;
    }
  | {
      kind: "audit_assert_event_anchored";
      event_hash: Bytes32;
    }
  | {
      kind: "audit_get_event_height";
      event_hash: Bytes32;
    }
  | {
      kind: "execute_payroll";
      args: {
        employer_usdcx: UsdcxRecord;
        employer_addr: Address;
        worker_addr: Address;
        employer_name_hash: Field;
        worker_name_hash: Field;
        agreement_id: Bytes32;
        epoch_id: U32;
        gross_amount: U128;
        net_amount: U128;
        tax_withheld: U128;
        fee_amount: U128;
        receipt_anchor: Bytes32;
        receipt_pair_hash: Bytes32;
        payroll_inputs_hash: Bytes32;
        utc_time_hash: Bytes32;
        audit_event_hash: Bytes32;
      };
    };

/**
 * Result outputs from executing call plans.
 * NOTE: each adapter may return richer metadata, but this is the stable router shape.
 */
export type CallPlanResult = Record<string, unknown>;

export class Layer1Router {
  private readonly adapter: Layer1Adapter;
  private readonly network: Network;

  constructor(adapter: Layer1Adapter, network: Network) {
    this.adapter = adapter;
    this.network = network;
  }

  /**
   * Build a call plan for registering a worker name.
   * fee_amount must be supplied by the portal (pricing policy).
   */
  planRegisterWorkerName(name_hash: Field, fee_amount: U128): CallPlanStep[] {
    return [{ kind: "register_worker_name", name_hash, fee_amount }];
  }

  planRegisterEmployerName(name_hash: Field, suffix_code: U8, fee_amount: U128): CallPlanStep[] {
    return [{ kind: "register_employer_name", name_hash, suffix_code, fee_amount }];
  }

  planCreateJobOffer(args: CallPlanStep & { kind: "create_job_offer" }["args"]): CallPlanStep[] {
    return [{ kind: "create_job_offer", args }];
  }

  planAcceptJobOffer(offer: PendingAgreementRecord, accept_time_hash: Bytes32): CallPlanStep[] {
    return [{ kind: "accept_job_offer", args: { offer, accept_time_hash } }];
  }

  /**
   * Payroll plan assumes all canonical hashes were computed off-chain:
   * - payroll_inputs_hash
   * - receipt_anchor
   * - receipt_pair_hash
   * - audit_event_hash
   * - utc_time_hash
   */
  planExecutePayroll(args: CallPlanStep & { kind: "execute_payroll" }["args"]): CallPlanStep[] {
    return [{ kind: "execute_payroll", args }];
  }

  /**
   * Mint Layer1 receipts directly (rare; usually done inside payroll_core).
   * Included because it’s part of the Layer1 surface and may be used for reversals.
   */
  planMintPaystubReceipts(args: CallPlanStep & { kind: "mint_paystub_receipts" }["args"]): CallPlanStep[] {
    return [{ kind: "mint_paystub_receipts", args }];
  }

  planMintReversalReceipts(args: CallPlanStep & { kind: "mint_reversal_receipts" }["args"]): CallPlanStep[] {
    return [{ kind: "mint_reversal_receipts", args }];
  }

  /**
   * Execute a call plan using the configured adapter.
   * The adapter is responsible for:
   * - mapping each step.kind to program/transition
   * - constructing transactions
   * - signing (wallet/cli)
   * - returning outputs/records
   */
  async execute(plan: CallPlanStep[]): Promise<CallPlanResult> {
    return this.adapter.executePlan(this.network, plan);
  }
}
