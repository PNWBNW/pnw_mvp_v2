// portal/src/router/layer2_router.ts
//
// Layer 2 Router (Portal)
// - Builds deterministic call plans for Layer 2 NFT programs.
// - Does not execute by itself.
// - Keeps planner logic free of program/transition strings.

import type { Network } from "../config/env";
import type { Bytes32, U16, U32 } from "../types/aleo_types";
import type {
  AuditAuthorizationNftRecord,
  CredentialNftRecord,
  PayrollNftRecord,
} from "../types/aleo_records";
import type { Layer2Adapter } from "../adapters/layer2_adapter";

export type Layer2CallPlanStep =
  // payroll_nfts.aleo
  | {
      kind: "mint_cycle_nft";
      args: {
        nft_id: Bytes32;
        agreement_id: Bytes32;
        period_start: U32;
        period_end: U32;
        doc_hash: Bytes32;
        root: Bytes32;
        inputs_hash: Bytes32;
        schema_v: U16;
        calc_v: U16;
        policy_v: U16;
      };
    }
  | {
      kind: "mint_quarter_nft";
      args: {
        nft_id: Bytes32;
        agreement_id: Bytes32;
        period_start: U32;
        period_end: U32;
        doc_hash: Bytes32;
        root: Bytes32;
        inputs_hash: Bytes32;
        schema_v: U16;
        calc_v: U16;
        policy_v: U16;
      };
    }
  | {
      kind: "mint_ytd_nft";
      args: {
        nft_id: Bytes32;
        agreement_id: Bytes32;
        period_start: U32;
        period_end: U32;
        doc_hash: Bytes32;
        root: Bytes32;
        inputs_hash: Bytes32;
        schema_v: U16;
        calc_v: U16;
        policy_v: U16;
      };
    }
  | {
      kind: "mint_eoy_nft";
      args: {
        nft_id: Bytes32;
        agreement_id: Bytes32;
        period_start: U32;
        period_end: U32;
        doc_hash: Bytes32;
        root: Bytes32;
        inputs_hash: Bytes32;
        schema_v: U16;
        calc_v: U16;
        policy_v: U16;
      };
    }
  | {
      kind: "revoke_payroll_nft";
      nft: PayrollNftRecord;
    }
  | {
      kind: "mark_payroll_nft_superseded";
      old_nft: PayrollNftRecord;
      new_nft_id: Bytes32;
    }
  | {
      kind: "assert_payroll_nft_exists";
      nft_id: Bytes32;
    }
  | {
      kind: "get_payroll_nft_anchor_height";
      nft_id: Bytes32;
    }
  | {
      kind: "get_payroll_nft_status";
      nft_id: Bytes32;
    }
  | {
      kind: "get_payroll_nft_superseded_by";
      nft_id: Bytes32;
    }

  // credential_nft.aleo
  | {
      kind: "mint_credential_nft";
      args: {
        credential_id: Bytes32;
        subject_hash: Bytes32;
        issuer_hash: Bytes32;
        scope_hash: Bytes32;
        doc_hash: Bytes32;
        root: Bytes32;
        schema_v: U16;
        policy_v: U16;
      };
    }
  | {
      kind: "revoke_credential_nft";
      nft: CredentialNftRecord;
    }
  | {
      kind: "assert_credential_exists";
      credential_id: Bytes32;
    }
  | {
      kind: "get_credential_anchor_height";
      credential_id: Bytes32;
    }
  | {
      kind: "get_credential_status";
      credential_id: Bytes32;
    }
  | {
      kind: "get_credential_revoked_height";
      credential_id: Bytes32;
    }
  | {
      kind: "assert_scope_anchored";
      scope_hash: Bytes32;
    }
  | {
      kind: "get_scope_anchor_height";
      scope_hash: Bytes32;
    }

  // audit_nft.aleo
  | {
      kind: "mint_authorization_nft";
      args: {
        auth_id: Bytes32;
        scope_hash: Bytes32;
        authorization_event_hash: Bytes32;
        policy_hash: Bytes32;
        issued_epoch: U32;
        expires_epoch: U32;
        schema_v: U16;
        policy_v: U16;
      };
    }
  | {
      kind: "revoke_authorization_nft";
      nft: AuditAuthorizationNftRecord;
    }
  | {
      kind: "mark_authorization_expired";
      auth_id: Bytes32;
      current_epoch: U32;
    }
  | {
      kind: "anchor_audit_attestation";
      auth_id: Bytes32;
      attestation_hash: Bytes32;
      current_epoch: U32;
    }
  | {
      kind: "assert_authorization_exists";
      auth_id: Bytes32;
    }
  | {
      kind: "assert_authorization_active";
      auth_id: Bytes32;
      current_epoch: U32;
    }
  | {
      kind: "get_authorization_anchor_height";
      auth_id: Bytes32;
    }
  | {
      kind: "get_authorization_status";
      auth_id: Bytes32;
    }
  | {
      kind: "get_authorization_expiry";
      auth_id: Bytes32;
    }
  | {
      kind: "get_authorization_revoked_height";
      auth_id: Bytes32;
    }
  | {
      kind: "assert_attestation_anchored";
      attestation_hash: Bytes32;
    }
  | {
      kind: "get_attestation_anchor_height";
      attestation_hash: Bytes32;
    }
  | {
      kind: "get_attestation_authorization";
      attestation_hash: Bytes32;
    };

export type Layer2CallPlanResult = Record<string, unknown>;

export class Layer2Router {
  private readonly adapter: Layer2Adapter;
  private readonly network: Network;

  constructor(adapter: Layer2Adapter, network: Network) {
    this.adapter = adapter;
    this.network = network;
  }

  plan(step: Layer2CallPlanStep): Layer2CallPlanStep[] {
    return [step];
  }

  planMany(steps: Layer2CallPlanStep[]): Layer2CallPlanStep[] {
    return [...steps];
  }

  /**
   * Stable helper APIs (Phase 3 freeze):
   * - Keep raw plan/planMany for advanced composition.
   * - Provide intent helpers for common UI opportunities.
   */
  planMintCycleNft(args: Extract<Layer2CallPlanStep, { kind: "mint_cycle_nft" }>['args']): Layer2CallPlanStep[] {
    return [{ kind: "mint_cycle_nft", args }];
  }

  planMintQuarterNft(args: Extract<Layer2CallPlanStep, { kind: "mint_quarter_nft" }>['args']): Layer2CallPlanStep[] {
    return [{ kind: "mint_quarter_nft", args }];
  }

  planMintYtdNft(args: Extract<Layer2CallPlanStep, { kind: "mint_ytd_nft" }>['args']): Layer2CallPlanStep[] {
    return [{ kind: "mint_ytd_nft", args }];
  }

  planMintEoyNft(args: Extract<Layer2CallPlanStep, { kind: "mint_eoy_nft" }>['args']): Layer2CallPlanStep[] {
    return [{ kind: "mint_eoy_nft", args }];
  }

  planVerifyPayrollNft(nft_id: Bytes32): Layer2CallPlanStep[] {
    return [
      { kind: "assert_payroll_nft_exists", nft_id },
      { kind: "get_payroll_nft_status", nft_id },
      { kind: "get_payroll_nft_anchor_height", nft_id },
    ];
  }

  planVerifyCredential(credential_id: Bytes32, scope_hash?: Bytes32): Layer2CallPlanStep[] {
    const plan: Layer2CallPlanStep[] = [
      { kind: "assert_credential_exists", credential_id },
      { kind: "get_credential_status", credential_id },
      { kind: "get_credential_anchor_height", credential_id },
    ];

    if (scope_hash !== undefined) {
      plan.push(
        { kind: "assert_scope_anchored", scope_hash },
        { kind: "get_scope_anchor_height", scope_hash },
      );
    }

    return plan;
  }

  planVerifyAuthorization(auth_id: Bytes32, current_epoch: U32): Layer2CallPlanStep[] {
    return [
      { kind: "assert_authorization_exists", auth_id },
      { kind: "assert_authorization_active", auth_id, current_epoch },
      { kind: "get_authorization_status", auth_id },
      { kind: "get_authorization_anchor_height", auth_id },
      { kind: "get_authorization_expiry", auth_id },
    ];
  }

  async execute(plan: Layer2CallPlanStep[]): Promise<Layer2CallPlanResult> {
    return this.adapter.executePlan(this.network, plan);
  }
}
