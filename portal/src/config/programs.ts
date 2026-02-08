// portal/src/config/programs.ts
//
// Program name registry for the portal.
// - single source of truth for program identifiers
// - supports testnet/mainnet selection
// - includes USDCx program names provided by Aleo dev guidance
//
// NOTE: These are program *names* (e.g., "payroll_core.aleo").
// If later you need transition names, keep them centralized here too.

import { ENV, type Network } from "./env";

export type ProgramGroup = "layer1" | "layer2" | "external";

export type ProgramRef = {
  group: ProgramGroup;
  name: string; // e.g., "payroll_core.aleo"
};

export type ProgramRegistry = {
  // External programs
  USDCX_STABLECOIN: ProgramRef;

  // Layer 1 (canonical)
  PNW_ROUTER: ProgramRef;
  PNW_NAME_REGISTRY: ProgramRef;
  WORKER_PROFILES: ProgramRef;
  EMPLOYER_PROFILES: ProgramRef;
  EMPLOYER_LICENSE_REGISTRY: ProgramRef;
  EMPLOYER_AGREEMENT: ProgramRef;
  PAYROLL_CORE: ProgramRef;
  PAYSTUB_RECEIPTS: ProgramRef;
  PAYROLL_AUDIT_LOG: ProgramRef;

  // Layer 2 (commitment NFTs)
  PAYROLL_NFTS: ProgramRef;
  CREDENTIAL_NFT: ProgramRef; // planned / pending build
  AUDIT_NFT: ProgramRef;      // planned / pending build
};

function usdcxProgramName(net: Network): string {
  // From Aleo guidance:
  // Mainnet: usdcx_stablecoin.aleo
  // Testnet: test_usdcx_stablecoin.aleo
  return net === "mainnet" ? "usdcx_stablecoin.aleo" : "test_usdcx_stablecoin.aleo";
}

export function programsForNetwork(net: Network): ProgramRegistry {
  return {
    // External
    USDCX_STABLECOIN: { group: "external", name: usdcxProgramName(net) },

    // Layer 1
    PNW_ROUTER: { group: "layer1", name: "pnw_router.aleo" },
    PNW_NAME_REGISTRY: { group: "layer1", name: "pnw_name_registry.aleo" },
    WORKER_PROFILES: { group: "layer1", name: "worker_profiles.aleo" },
    EMPLOYER_PROFILES: { group: "layer1", name: "employer_profiles.aleo" },
    EMPLOYER_LICENSE_REGISTRY: { group: "layer1", name: "employer_license_registry.aleo" },
    EMPLOYER_AGREEMENT: { group: "layer1", name: "employer_agreement.aleo" },
    PAYROLL_CORE: { group: "layer1", name: "payroll_core.aleo" },
    PAYSTUB_RECEIPTS: { group: "layer1", name: "paystub_receipts.aleo" },
    PAYROLL_AUDIT_LOG: { group: "layer1", name: "payroll_audit_log.aleo" },

    // Layer 2
    PAYROLL_NFTS: { group: "layer2", name: "payroll_nfts.aleo" },
    CREDENTIAL_NFT: { group: "layer2", name: "credential_nft.aleo" },
    AUDIT_NFT: { group: "layer2", name: "audit_nft.aleo" },
  };
}

// Convenience singleton based on ENV
export const PROGRAMS: ProgramRegistry = programsForNetwork(ENV.PNW_NETWORK);

/**
 * Helper: get program name string quickly.
 * Example: programName("PAYROLL_CORE") => "payroll_core.aleo"
 */
export function programName(key: keyof ProgramRegistry): string {
  return PROGRAMS[key].name;
}
