// portal/src/payroll/mint_payroll_nft.ts
//
// This file prepares the payload to mint a payroll NFT (Layer 2) from a canonical doc.
// It does NOT perform network calls yet (framing stage).
//
// Later, you can wire this into:
// - leo run / snarkos execution wrappers
// - wallet signing + broadcast
// - or an SDK call path
//
// For now: build deterministic "mint request" objects.

import { buildCommitments, type CanonicalDoc } from "../commitments/canonical_encoder";
import { toHex } from "../commitments/hash";
import type { PayrollNftScope } from "../commitments/token_id";

export type PayrollNftMintRequest = {
  // For logging and deterministic identity
  token_id_hex: string;

  // Commitment payloads (bytes32 hex for transport)
  token_id: string;     // hex
  doc_hash: string;     // hex
  inputs_hash: string;  // hex
  root: string;         // hex

  // Metadata (u32/u16)
  scope: PayrollNftScope;
  period_id: number; // u32
  schema_v: number;  // u16
  calc_v: number;    // u16
  policy_v: number;  // u16

  // Agreement reference (optional but useful)
  agreement_id: string; // hex
};

/**
 * Deterministically creates a mint request for Layer2 payroll_nfts.aleo.
 * Network execution is intentionally deferred.
 */
export function createPayrollNftMintRequest(doc: CanonicalDoc): PayrollNftMintRequest {
  const out = buildCommitments(doc);

  const schema_v = doc.header.versions.schema_v;
  const calc_v = doc.header.versions.calc_v;
  const policy_v = doc.header.versions.policy_v;

  const token_id_hex = toHex(out.token_id);

  return {
    token_id_hex,

    token_id: token_id_hex,
    doc_hash: toHex(out.doc_hash),
    inputs_hash: toHex(out.inputs_hash),
    root: toHex(out.root),

    scope: doc.scope,
    period_id: doc.period_id,
    schema_v,
    calc_v,
    policy_v,

    agreement_id: toHex(doc.agreement_id),
  };
}
