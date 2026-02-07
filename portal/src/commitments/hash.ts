// portal/src/commitments/hash.ts
//
// Dependencies (recommended):
//   npm i @noble/hashes
//
// This module is the single entry-point for all hashing and domain separation.
// Everything that becomes a commitment should flow through this file.

import { blake3 } from "@noble/hashes/blake3";
import { concatBytes } from "@noble/hashes/utils";

export type Bytes32 = Uint8Array;

export const HASH_LEN = 32;

export const HASH_DOMAINS = {
  DOC: "PNW::DOC",
  INPUTS: "PNW::INPUTS",
  LEAF: "PNW::LEAF",
  MERKLE_NODE: "PNW::MERKLE_NODE",
  TOKEN_ID: "PNW::TOKEN_ID",
} as const;

const te = new TextEncoder();

export function assertBytes32(x: Uint8Array, label = "bytes32"): asserts x is Bytes32 {
  if (!(x instanceof Uint8Array)) throw new Error(`${label} must be Uint8Array`);
  if (x.length !== HASH_LEN) throw new Error(`${label} must be 32 bytes (got ${x.length})`);
}

export function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}

export function utf8(s: string): Uint8Array {
  return te.encode(s);
}

export function blake3_256(data: Uint8Array): Bytes32 {
  const out = blake3(data, { dkLen: HASH_LEN });
  // noble returns Uint8Array
  return out;
}

/**
 * Domain-separated hash:
 * H(domain || 0x00 || payload)
 *
 * 0x00 is an unambiguous delimiter between the domain label and payload.
 */
export function hashDomain(domain: string, payload: Uint8Array): Bytes32 {
  const dom = utf8(domain);
  const sep = new Uint8Array([0x00]);
  return blake3_256(concatBytes(dom, sep, payload));
}

/**
 * Convenience: hash of concatenated parts with domain separation.
 */
export function hashDomainParts(domain: string, ...parts: Uint8Array[]): Bytes32 {
  const payload = concatBytes(...parts);
  return hashDomain(domain, payload);
}

/**
 * Hex helpers for test vectors / logs.
 */
export function toHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function fromHex(hex: string): Uint8Array {
  const clean = hex.startsWith("0x") ? hex.slice(2) : hex;
  if (clean.length % 2 !== 0) throw new Error("hex length must be even");
  const out = new Uint8Array(clean.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}
