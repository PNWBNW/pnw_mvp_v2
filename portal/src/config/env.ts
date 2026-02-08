// portal/src/config/env.ts
//
// Environment configuration for the PNW portal.
// - testnet-first
// - no network calls
// - strict parsing (inspection-style guardrails)
//
// NOTE: Do NOT commit real secrets. Use .env locally.

export type Network = "testnet" | "mainnet";

export type PortalEnv = {
  // Network selection
  PNW_NETWORK: Network;

  // Optional: RPC / API endpoints (only used later when wiring network execution)
  // Keep as strings here; transport adapters live elsewhere.
  ALEO_RPC_URL?: string;

  // Optional: portal operator keys (only used later for CLI / signing flows)
  // We keep them optional because many flows will be user-wallet driven.
  PORTAL_PRIVATE_KEY?: string;
  PORTAL_VIEW_KEY?: string;
  PORTAL_ADDRESS?: string;

  // Optional: feature gates for dev workflows (no effect unless wired)
  PNW_DEBUG?: boolean;
};

function readBool(v: string | undefined): boolean | undefined {
  if (v === undefined) return undefined;
  const s = v.trim().toLowerCase();
  if (s === "1" || s === "true" || s === "yes" || s === "on") return true;
  if (s === "0" || s === "false" || s === "no" || s === "off") return false;
  throw new Error(`Invalid boolean env value: ${v}`);
}

function readNetwork(v: string | undefined): Network {
  const s = (v ?? "testnet").trim().toLowerCase();
  if (s === "testnet") return "testnet";
  if (s === "mainnet") return "mainnet";
  throw new Error(`Invalid PNW_NETWORK: ${v} (expected "testnet" | "mainnet")`);
}

export function loadEnv(processEnv: NodeJS.ProcessEnv = process.env): PortalEnv {
  const PNW_NETWORK = readNetwork(processEnv.PNW_NETWORK);

  const ALEO_RPC_URL = processEnv.ALEO_RPC_URL?.trim() || undefined;

  const PORTAL_PRIVATE_KEY = processEnv.PORTAL_PRIVATE_KEY?.trim() || undefined;
  const PORTAL_VIEW_KEY = processEnv.PORTAL_VIEW_KEY?.trim() || undefined;
  const PORTAL_ADDRESS = processEnv.PORTAL_ADDRESS?.trim() || undefined;

  const PNW_DEBUG = readBool(processEnv.PNW_DEBUG);

  return {
    PNW_NETWORK,
    ALEO_RPC_URL,
    PORTAL_PRIVATE_KEY,
    PORTAL_VIEW_KEY,
    PORTAL_ADDRESS,
    PNW_DEBUG,
  };
}

// Convenience singleton (safe; no side effects)
export const ENV: PortalEnv = loadEnv();
