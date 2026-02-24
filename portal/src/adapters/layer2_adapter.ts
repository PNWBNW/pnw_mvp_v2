// portal/src/adapters/layer2_adapter.ts
//
// Layer 2 Adapter interface + endpoint mapping.
// - Router builds deterministic call plans.
// - Adapter resolves program/transition strings and executes.

import type { Network } from "../config/env";
import type { Layer2CallPlanResult, Layer2CallPlanStep } from "../router/layer2_router";

export type Layer2TxMeta = {
  program: "payroll_nfts.aleo" | "credential_nft.aleo" | "audit_nft.aleo";
  transition: string;
  network: Network;
};

export interface Layer2Adapter {
  executePlan(network: Network, plan: Layer2CallPlanStep[]): Promise<Layer2CallPlanResult>;
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
