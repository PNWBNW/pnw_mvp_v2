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

export type Layer2TxMeta = {
  program: "payroll_nfts.aleo" | "credential_nft.aleo" | "audit_nft.aleo";
  transition: string;
  network: Network;
};

export interface Layer2Adapter {
  executePlan(network: Network, plan: Layer2CallPlanStep[]): Promise<Layer2CallPlanResult>;
}

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

  async execute(plan: Layer2CallPlanStep[]): Promise<Layer2CallPlanResult> {
    return this.adapter.executePlan(this.network, plan);
  }
}

export function resolveLayer2Endpoint(network: Network, step: Layer2CallPlanStep): Layer2TxMeta {
  switch (step.kind) {
    case "mint_cycle_nft":
      return { program: "payroll_nfts.aleo", transition: "mint_cycle_nft", network };
    case "mint_quarter_nft":
      return { program: "payroll_nfts.aleo", transition: "mint_quarter_nft", network };
    case "mint_ytd_nft":
      return { program: "payroll_nfts.aleo", transition: "mint_ytd_nft", network };
    case "mint_eoy_nft":
      return { program: "payroll_nfts.aleo", transition: "mint_eoy_nft", network };
    case "revoke_payroll_nft":
      return { program: "payroll_nfts.aleo", transition: "revoke_nft", network };
    case "mark_payroll_nft_superseded":
      return { program: "payroll_nfts.aleo", transition: "mark_superseded", network };
    case "assert_payroll_nft_exists":
      return { program: "payroll_nfts.aleo", transition: "assert_nft_exists", network };
    case "get_payroll_nft_anchor_height":
      return { program: "payroll_nfts.aleo", transition: "get_anchor_height", network };
    case "get_payroll_nft_status":
      return { program: "payroll_nfts.aleo", transition: "get_status", network };
    case "get_payroll_nft_superseded_by":
      return { program: "payroll_nfts.aleo", transition: "get_superseded_by", network };

    case "mint_credential_nft":
      return { program: "credential_nft.aleo", transition: "mint_credential_nft", network };
    case "revoke_credential_nft":
      return { program: "credential_nft.aleo", transition: "revoke_credential_nft", network };
    case "assert_credential_exists":
      return { program: "credential_nft.aleo", transition: "assert_credential_exists", network };
    case "get_credential_anchor_height":
      return { program: "credential_nft.aleo", transition: "get_credential_anchor_height", network };
    case "get_credential_status":
      return { program: "credential_nft.aleo", transition: "get_credential_status", network };
    case "get_credential_revoked_height":
      return { program: "credential_nft.aleo", transition: "get_credential_revoked_height", network };
    case "assert_scope_anchored":
      return { program: "credential_nft.aleo", transition: "assert_scope_anchored", network };
    case "get_scope_anchor_height":
      return { program: "credential_nft.aleo", transition: "get_scope_anchor_height", network };

    case "mint_authorization_nft":
      return { program: "audit_nft.aleo", transition: "mint_authorization_nft", network };
    case "revoke_authorization_nft":
      return { program: "audit_nft.aleo", transition: "revoke_authorization_nft", network };
    case "mark_authorization_expired":
      return { program: "audit_nft.aleo", transition: "mark_authorization_expired", network };
    case "anchor_audit_attestation":
      return { program: "audit_nft.aleo", transition: "anchor_audit_attestation", network };
    case "assert_authorization_exists":
      return { program: "audit_nft.aleo", transition: "assert_authorization_exists", network };
    case "assert_authorization_active":
      return { program: "audit_nft.aleo", transition: "assert_authorization_active", network };
    case "get_authorization_anchor_height":
      return { program: "audit_nft.aleo", transition: "get_authorization_anchor_height", network };
    case "get_authorization_status":
      return { program: "audit_nft.aleo", transition: "get_authorization_status", network };
    case "get_authorization_expiry":
      return { program: "audit_nft.aleo", transition: "get_authorization_expiry", network };
    case "get_authorization_revoked_height":
      return { program: "audit_nft.aleo", transition: "get_authorization_revoked_height", network };
    case "assert_attestation_anchored":
      return { program: "audit_nft.aleo", transition: "assert_attestation_anchored", network };
    case "get_attestation_anchor_height":
      return { program: "audit_nft.aleo", transition: "get_attestation_anchor_height", network };
    case "get_attestation_authorization":
      return { program: "audit_nft.aleo", transition: "get_attestation_authorization", network };
  }
}
