// portal/src/commitments/token_id.ts
//
// Deterministic token_id derivation.
// Token IDs must not depend on mint order or wall-clock time.
// This is used to derive stable IDs for Layer 2 payroll NFTs.

import { concatBytes } from "@noble/hashes/utils";
import { Bytes32, HASH_DOMAINS, assertBytes32, hashDomain } from "./hash";

/**
 * Scope describes what the NFT represents.
 * Keep it minimal and stable. Add new values only by appending.
 */
export enum PayrollNftScope {
  CYCLE = 1,     // per payroll cycle
  QUARTERLY = 2, // Q1-Q4 summary
  YTD = 3,       // year-to-date
  EOY = 4,       // end-of-year
}

/**
 * Spec version for token_id derivation.
 * Increment ONLY for breaking changes.
 */
export const TOKEN_ID_SPEC_V: number = 1;

/**
 * Deterministic period encoding for token_id.
 * - For CYCLE: portal-defined epoch_id (u32)
 * - For QUARTERLY: YYYYQ encoded as (year * 10 + quarter) in u32 (example)
 * - For YTD/EOY: year as u32
 *
 * This file does not dictate the meaning; it enforces stable byte encoding.
 */
export type PeriodId = number;

/**
 * Produces a Bytes32 token_id:
 * H(PNW::TOKEN_ID, spec_v || scope || period_id || agreement_id || inputs_hash)
 */
export function deriveTokenId(params: {
  scope: PayrollNftScope;
  period_id: PeriodId;         // u32
  agreement_id: Bytes32;       // bytes32
  inputs_hash: Bytes32;        // bytes32 (binds to underlying receipts set)
}): Bytes32 {
  const { scope, period_id, agreement_id, inputs_hash } = params;

  assertBytes32(agreement_id, "agreement_id");
  assertBytes32(inputs_hash, "inputs_hash");

  const specV = u16be(TOKEN_ID_SPEC_V);
  const scopeB = u8(scope);
  const periodB = u32be(period_id);

  const payload = concatBytes(specV, scopeB, periodB, agreement_id, inputs_hash);
  return hashDomain(HASH_DOMAINS.TOKEN_ID, payload);
}

function u8(n: number): Uint8Array {
  if (!Number.isInteger(n) || n < 0 || n > 255) throw new Error(`u8 out of range: ${n}`);
  return Uint8Array.from([n]);
}

function u16be(n: number): Uint8Array {
  if (!Number.isInteger(n) || n < 0 || n > 0xffff) throw new Error(`u16 out of range: ${n}`);
  return Uint8Array.from([(n >> 8) & 0xff, n & 0xff]);
}

function u32be(n: number): Uint8Array {
  if (!Number.isInteger(n) || n < 0 || n > 0xffffffff) throw new Error(`u32 out of range: ${n}`);
  return Uint8Array.from([
    (n >>> 24) & 0xff,
    (n >>> 16) & 0xff,
    (n >>> 8) & 0xff,
    n & 0xff,
  ]);
}
