// canonical_encoder.ts
// PNW MVP v2 – Canonical Encoding + Hashing + Merkle (Encoding Spec v1)
//
// Implements sections 2.1–2.7 of the portal canonical encoding rules:
// - TLV primitives (type + length + value)
// - Object framing (OBJ_TAG + ENC_V + TLVs in fixed order)
// - BLAKE3-256 hashing for doc_hash / inputs_hash / leaf hashes
// - Merkle root construction from leaf hashes (BLAKE3-256)
//
// Notes:
// - No JSON stringification is used for hashing.
// - No floats. Monetary values are bigint "ledger_units" encoded as bigint_dec ASCII.
// - All hashes/ids are bytes32 values, supplied as lowercase 64-hex strings.
//
// Dependency:
//   npm i @noble/hashes
//   (or replace blake3_256() with your preferred blake3 implementation)

import { blake3 } from "@noble/hashes/blake3";
import { utf8ToBytes } from "@noble/hashes/utils";

/* -----------------------------
 * Types
 * ----------------------------- */

export type Hex32 = string; // 64 hex chars, lowercase, no 0x
export type U32 = number;
export type U16 = number;
export type U8 = number;
export type MoneyLedger = bigint;

export type PayrollNftType = "CYCLE" | "QUARTER" | "YTD" | "EOY";
export type ReceiptKind = "PAYSTUB" | "REVERSAL";

export interface VersionTriplet {
  schema_v: U16;
  calc_v: U16;
  policy_v: U16;
}

export interface AnchorRef {
  anchor: Hex32;
  anchor_height: U32;
}

export interface PeriodRange {
  period_type: PayrollNftType;
  period_start: U32;
  period_end: U32;
}

export interface PaystubDocument {
  doc_type: "PAYSTUB";
  versions: VersionTriplet;

  agreement_id: Hex32;
  epoch_id: U32;

  worker_name_hash: string;   // Aleo field string, canonical decimal
  employer_name_hash: string; // Aleo field string, canonical decimal

  currency_code: U8; // USDCX=1

  gross_ledger: MoneyLedger;
  net_ledger: MoneyLedger;
  tax_withheld_ledger: MoneyLedger;
  fee_ledger: MoneyLedger;

  payroll_inputs_hash: Hex32;
  receipt_anchor: Hex32;
  receipt_height: U32;

  audit_anchor?: Hex32;        // optional (monthly batch)
  audit_anchor_height?: U32;   // optional (0 if absent)

  utc_time_hash: Hex32;
}

export interface PayrollSummaryDocument {
  doc_type: "SUMMARY";
  summary_type: PayrollNftType;
  versions: VersionTriplet;

  agreement_id: Hex32;
  period: PeriodRange;

  worker_name_hash: string;
  employer_name_hash: string;

  currency_code: U8; // USDCX=1

  gross_total_ledger: MoneyLedger;
  net_total_ledger: MoneyLedger;
  tax_total_ledger: MoneyLedger;
  fee_total_ledger: MoneyLedger;

  inputs_hash: Hex32;

  audit_anchor?: Hex32;
  audit_anchor_height?: U32;
}

export interface InputsItem {
  receipt_anchor: Hex32;
  receipt_height: U32;
  payroll_inputs_hash: Hex32;
  kind: ReceiptKind; // PAYSTUB=1 REVERSAL=2
}

export interface InputsSet {
  versions: VersionTriplet;
  agreement_id: Hex32;

  period: PeriodRange;
  currency_code: U8;

  items: InputsItem[];
}

/* -----------------------------
 * Constants (Spec v1)
 * ----------------------------- */

export const ENC_V: U16 = 1;

// Object tags
export const OBJ_PAYSTUB_DOC: U16 = 0x1001;
export const OBJ_SUMMARY_DOC: U16 = 0x1002;
export const OBJ_INPUTS_SET: U16 = 0x2001;

export const OBJ_LEAF_PAYSTUB: U16 = 0x3001;
export const OBJ_LEAF_SUMMARY: U16 = 0x3002;

// TLV primitive type codes (1 byte)
export const TLV_U8: U8 = 0x01;
export const TLV_U16: U8 = 0x02;
export const TLV_U32: U8 = 0x03;
export const TLV_BYTES32: U8 = 0x04;
export const TLV_FIELD_STR: U8 = 0x05;
export const TLV_UTF8_STR: U8 = 0x07;
export const TLV_BIGINT_DEC: U8 = 0x08;

// Currency code mapping (2.7)
export const CURRENCY_USDCX: U8 = 1;

// PayrollNftType mapping (mirrors payroll_nfts.aleo)
export const TYPE_CYCLE: U8 = 1;
export const TYPE_QUARTER: U8 = 2;
export const TYPE_YTD: U8 = 3;
export const TYPE_EOY: U8 = 4;

// ReceiptKind mapping
export const KIND_PAYSTUB: U8 = 1;
export const KIND_REVERSAL: U8 = 2;

// Merkle leaf ids (2.6 draft)
export const LEAF_IDENTITY_BINDING: U8 = 1;
export const LEAF_AMOUNTS: U8 = 2;
export const LEAF_PROVENANCE: U8 = 3;

export const LEAF_PERIOD_BINDING: U8 = 1;
export const LEAF_TOTALS: U8 = 2;
export const LEAF_SUM_PROVENANCE: U8 = 3;

/* -----------------------------
 * Errors / validation helpers
 * ----------------------------- */

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

function isLowerHex(s: string): boolean {
  return /^[0-9a-f]+$/.test(s);
}

function strip0x(h: string): string {
  return h.startsWith("0x") ? h.slice(2) : h;
}

function validateHex32(h: string): string {
  const x = strip0x(h);
  assert(x.length === 64, `bytes32 must be 64 hex chars (got ${x.length})`);
  assert(isLowerHex(x), "bytes32 must be lowercase hex");
  return x;
}

function hexToBytes(h: string): Uint8Array {
  const x = validateHex32(h);
  const out = new Uint8Array(32);
  for (let i = 0; i < 32; i++) {
    const byte = x.slice(i * 2, i * 2 + 2);
    out[i] = Number.parseInt(byte, 16);
  }
  return out;
}

function validateDecString(s: string, label: string): string {
  const t = s.trim();
  assert(/^[0-9]+$/.test(t), `${label} must be canonical decimal (digits only)`);
  if (t.length > 1) assert(t[0] !== "0", `${label} must not have leading zeros`);
  return t;
}

function bigintToDecCanonical(x: bigint, label: string): string {
  assert(x >= 0n, `${label} must be non-negative`);
  return validateDecString(x.toString(10), label);
}

/* -----------------------------
 * Byte concat utilities
 * ----------------------------- */

function concatBytes(chunks: Uint8Array[]): Uint8Array {
  const total = chunks.reduce((n, c) => n + c.length, 0);
  const out = new Uint8Array(total);
  let off = 0;
  for (const c of chunks) {
    out.set(c, off);
    off += c.length;
  }
  return out;
}

/* -----------------------------
 * Fixed-width integer encoders (big-endian)
 * ----------------------------- */

export function u8ToBytes(x: U8): Uint8Array {
  assert(Number.isInteger(x) && x >= 0 && x <= 0xff, "u8 out of range");
  return Uint8Array.of(x);
}

export function u16ToBytes(x: U16): Uint8Array {
  assert(Number.isInteger(x) && x >= 0 && x <= 0xffff, "u16 out of range");
  return Uint8Array.of((x >>> 8) & 0xff, x & 0xff);
}

export function u32ToBytes(x: U32): Uint8Array {
  assert(Number.isInteger(x) && x >= 0 && x <= 0xffffffff, "u32 out of range");
  return Uint8Array.of(
    (x >>> 24) & 0xff,
    (x >>> 16) & 0xff,
    (x >>> 8) & 0xff,
    x & 0xff
  );
}

/* -----------------------------
 * TLV encoding (2.1–2.2)
 * TLV = type(1) + len(u16) + value(bytes)
 * ----------------------------- */

export function tlv(t: U8, value: Uint8Array): Uint8Array {
  const typeB = u8ToBytes(t);
  const lenB = u16ToBytes(value.length);
  return concatBytes([typeB, lenB, value]);
}

export function tlvU8(x: U8): Uint8Array {
  return tlv(TLV_U8, u8ToBytes(x));
}

export function tlvU16(x: U16): Uint8Array {
  return tlv(TLV_U16, u16ToBytes(x));
}

export function tlvU32(x: U32): Uint8Array {
  return tlv(TLV_U32, u32ToBytes(x));
}

export function tlvBytes32(h: Hex32): Uint8Array {
  return tlv(TLV_BYTES32, hexToBytes(h));
}

export function tlvFieldStr(fieldDec: string): Uint8Array {
  const canon = validateDecString(fieldDec, "field_str");
  return tlv(TLV_FIELD_STR, utf8ToBytes(canon));
}

export function tlvBigintDec(x: bigint): Uint8Array {
  const canon = bigintToDecCanonical(x, "bigint_dec");
  return tlv(TLV_BIGINT_DEC, utf8ToBytes(canon));
}

export function tlvUtf8Str(s: string): Uint8Array {
  // MVP: do not trim; do not case-fold.
  // If you later add NFC normalization, do it here consistently for all platforms.
  return tlv(TLV_UTF8_STR, utf8ToBytes(s));
}

/* -----------------------------
 * Object framing (2.3)
 * obj = OBJ_TAG(u16) + ENC_V(u16) + TLVs...
 * ----------------------------- */

export function encodeObject(tag: U16, tlvs: Uint8Array[]): Uint8Array {
  const header = concatBytes([u16ToBytes(tag), u16ToBytes(ENC_V)]);
  return concatBytes([header, ...tlvs]);
}

/* -----------------------------
 * Hashing (BLAKE3-256)
 * ----------------------------- */

export function blake3_256(bytes: Uint8Array): Uint8Array {
  // noble blake3 returns Uint8Array; set dkLen=32 to force 256-bit
  return blake3(bytes, { dkLen: 32 });
}

export function bytesToHexLower(b: Uint8Array): string {
  let s = "";
  for (const x of b) s += x.toString(16).padStart(2, "0");
  return s;
}

export function hashHex32(bytes: Uint8Array): Hex32 {
  return bytesToHexLower(blake3_256(bytes));
}

/* -----------------------------
 * Mappings (2.7)
 * ----------------------------- */

export function payrollTypeToU8(t: PayrollNftType): U8 {
  switch (t) {
    case "CYCLE": return TYPE_CYCLE;
    case "QUARTER": return TYPE_QUARTER;
    case "YTD": return TYPE_YTD;
    case "EOY": return TYPE_EOY;
  }
}

export function receiptKindToU8(k: ReceiptKind): U8 {
  return k === "PAYSTUB" ? KIND_PAYSTUB : KIND_REVERSAL;
}

/* -----------------------------
 * Canonical sorting (2.5)
 * Sort by (receipt_height asc, receipt_anchor lex asc)
 * ----------------------------- */

export function sortInputs(items: InputsItem[]): InputsItem[] {
  return [...items].sort((a, b) => {
    if (a.receipt_height !== b.receipt_height) return a.receipt_height - b.receipt_height;
    // lex compare anchors
    const ax = validateHex32(a.receipt_anchor);
    const bx = validateHex32(b.receipt_anchor);
    return ax < bx ? -1 : ax > bx ? 1 : 0;
  });
}

/* -----------------------------
 * Encoders for doc_hash (2.4)
 * ----------------------------- */

export function encodePaystubDocument(doc: PaystubDocument): Uint8Array {
  const auditAnchor = doc.audit_anchor ?? "0".repeat(64);
  const auditHeight = doc.audit_anchor_height ?? 0;

  const tlvs: Uint8Array[] = [
    tlvU16(doc.versions.schema_v),
    tlvU16(doc.versions.calc_v),
    tlvU16(doc.versions.policy_v),

    tlvBytes32(doc.agreement_id),
    tlvU32(doc.epoch_id),

    tlvFieldStr(doc.worker_name_hash),
    tlvFieldStr(doc.employer_name_hash),

    tlvU8(doc.currency_code),

    tlvBigintDec(doc.gross_ledger),
    tlvBigintDec(doc.net_ledger),
    tlvBigintDec(doc.tax_withheld_ledger),
    tlvBigintDec(doc.fee_ledger),

    tlvBytes32(doc.payroll_inputs_hash),
    tlvBytes32(doc.receipt_anchor),
    tlvU32(doc.receipt_height),

    tlvBytes32(auditAnchor),
    tlvU32(auditHeight),

    tlvBytes32(doc.utc_time_hash),
  ];

  return encodeObject(OBJ_PAYSTUB_DOC, tlvs);
}

export function encodePayrollSummaryDocument(doc: PayrollSummaryDocument): Uint8Array {
  const auditAnchor = doc.audit_anchor ?? "0".repeat(64);
  const auditHeight = doc.audit_anchor_height ?? 0;

  const tlvs: Uint8Array[] = [
    tlvU16(doc.versions.schema_v),
    tlvU16(doc.versions.calc_v),
    tlvU16(doc.versions.policy_v),

    tlvU8(payrollTypeToU8(doc.summary_type)),
    tlvBytes32(doc.agreement_id),

    tlvU32(doc.period.period_start),
    tlvU32(doc.period.period_end),

    tlvFieldStr(doc.worker_name_hash),
    tlvFieldStr(doc.employer_name_hash),

    tlvU8(doc.currency_code),

    tlvBigintDec(doc.gross_total_ledger),
    tlvBigintDec(doc.net_total_ledger),
    tlvBigintDec(doc.tax_total_ledger),
    tlvBigintDec(doc.fee_total_ledger),

    tlvBytes32(doc.inputs_hash),

    tlvBytes32(auditAnchor),
    tlvU32(auditHeight),
  ];

  return encodeObject(OBJ_SUMMARY_DOC, tlvs);
}

/* -----------------------------
 * Encoder for inputs_hash (2.5)
 * ----------------------------- */

export function encodeInputsSet(set: InputsSet): Uint8Array {
  const items = sortInputs(set.items);
  const count = items.length;

  const tlvs: Uint8Array[] = [
    tlvU16(set.versions.schema_v),
    tlvU16(set.versions.calc_v),
    tlvU16(set.versions.policy_v),

    tlvBytes32(set.agreement_id),

    tlvU8(payrollTypeToU8(set.period.period_type)),
    tlvU32(set.period.period_start),
    tlvU32(set.period.period_end),

    tlvU8(set.currency_code),

    tlvU32(count),
  ];

  for (const it of items) {
    tlvs.push(
      tlvBytes32(it.receipt_anchor),
      tlvU32(it.receipt_height),
      tlvBytes32(it.payroll_inputs_hash),
      tlvU8(receiptKindToU8(it.kind))
    );
  }

  return encodeObject(OBJ_INPUTS_SET, tlvs);
}

export function computeInputsHash(set: InputsSet): Hex32 {
  return hashHex32(encodeInputsSet(set));
}

/* -----------------------------
 * Merkle leaves (2.6)
 * Leaves are canonical objects -> hash -> merkle
 * ----------------------------- */

export function encodePaystubLeafIdentityBinding(doc: PaystubDocument): Uint8Array {
  const tlvs: Uint8Array[] = [
    tlvU8(LEAF_IDENTITY_BINDING),
    tlvBytes32(doc.agreement_id),
    tlvU32(doc.epoch_id),
    tlvFieldStr(doc.worker_name_hash),
    tlvFieldStr(doc.employer_name_hash),
  ];
  return encodeObject(OBJ_LEAF_PAYSTUB, tlvs);
}

export function encodePaystubLeafAmounts(doc: PaystubDocument): Uint8Array {
  const tlvs: Uint8Array[] = [
    tlvU8(LEAF_AMOUNTS),
    tlvBytes32(doc.agreement_id),
    tlvU32(doc.epoch_id),
    tlvU8(doc.currency_code),
    tlvBigintDec(doc.gross_ledger),
    tlvBigintDec(doc.net_ledger),
    tlvBigintDec(doc.tax_withheld_ledger),
    tlvBigintDec(doc.fee_ledger),
  ];
  return encodeObject(OBJ_LEAF_PAYSTUB, tlvs);
}

export function encodePaystubLeafProvenance(doc: PaystubDocument): Uint8Array {
  const auditAnchor = doc.audit_anchor ?? "0".repeat(64);
  const auditHeight = doc.audit_anchor_height ?? 0;

  const tlvs: Uint8Array[] = [
    tlvU8(LEAF_PROVENANCE),
    tlvBytes32(doc.agreement_id),
    tlvU32(doc.epoch_id),
    tlvBytes32(doc.payroll_inputs_hash),
    tlvBytes32(doc.receipt_anchor),
    tlvU32(doc.receipt_height),
    tlvBytes32(auditAnchor),
    tlvU32(auditHeight),
    tlvBytes32(doc.utc_time_hash),
  ];
  return encodeObject(OBJ_LEAF_PAYSTUB, tlvs);
}

export function computePaystubLeafHashes(doc: PaystubDocument): Hex32[] {
  return [
    hashHex32(encodePaystubLeafIdentityBinding(doc)),
    hashHex32(encodePaystubLeafAmounts(doc)),
    hashHex32(encodePaystubLeafProvenance(doc)),
  ];
}

export function encodeSummaryLeafPeriodBinding(doc: PayrollSummaryDocument): Uint8Array {
  const tlvs: Uint8Array[] = [
    tlvU8(LEAF_PERIOD_BINDING),
    tlvBytes32(doc.agreement_id),
    tlvU8(payrollTypeToU8(doc.summary_type)),
    tlvU32(doc.period.period_start),
    tlvU32(doc.period.period_end),
    tlvFieldStr(doc.worker_name_hash),
    tlvFieldStr(doc.employer_name_hash),
  ];
  return encodeObject(OBJ_LEAF_SUMMARY, tlvs);
}

export function encodeSummaryLeafTotals(doc: PayrollSummaryDocument): Uint8Array {
  const tlvs: Uint8Array[] = [
    tlvU8(LEAF_TOTALS),
    tlvBytes32(doc.agreement_id),
    tlvU8(payrollTypeToU8(doc.summary_type)),
    tlvU8(doc.currency_code),
    tlvBigintDec(doc.gross_total_ledger),
    tlvBigintDec(doc.net_total_ledger),
    tlvBigintDec(doc.tax_total_ledger),
    tlvBigintDec(doc.fee_total_ledger),
  ];
  return encodeObject(OBJ_LEAF_SUMMARY, tlvs);
}

export function encodeSummaryLeafProvenance(doc: PayrollSummaryDocument): Uint8Array {
  const auditAnchor = doc.audit_anchor ?? "0".repeat(64);
  const auditHeight = doc.audit_anchor_height ?? 0;

  const tlvs: Uint8Array[] = [
    tlvU8(LEAF_SUM_PROVENANCE),
    tlvBytes32(doc.agreement_id),
    tlvU8(payrollTypeToU8(doc.summary_type)),
    tlvBytes32(doc.inputs_hash),
    tlvBytes32(auditAnchor),
    tlvU32(auditHeight),
  ];
  return encodeObject(OBJ_LEAF_SUMMARY, tlvs);
}

export function computeSummaryLeafHashes(doc: PayrollSummaryDocument): Hex32[] {
  return [
    hashHex32(encodeSummaryLeafPeriodBinding(doc)),
    hashHex32(encodeSummaryLeafTotals(doc)),
    hashHex32(encodeSummaryLeafProvenance(doc)),
  ];
}

/* -----------------------------
 * Merkle root (BLAKE3-256)
 * - Leaves are 32-byte hashes (Hex32)
 * - Pair hash = BLAKE3(left || right)
 * - If odd count at a level, duplicate last
 * ----------------------------- */

export function merkleRootFromLeafHashes(leafHashes: Hex32[]): Hex32 {
  assert(leafHashes.length > 0, "Merkle requires at least 1 leaf");

  let level: Uint8Array[] = leafHashes.map((h) => hexToBytes(h));

  while (level.length > 1) {
    const next: Uint8Array[] = [];
    for (let i = 0; i < level.length; i += 2) {
      const left = level[i];
      const right = (i + 1 < level.length) ? level[i + 1] : left;
      const parent = blake3_256(concatBytes([left, right]));
      next.push(parent);
    }
    level = next;
  }

  return bytesToHexLower(level[0]);
}

/* -----------------------------
 * Convenience: compute doc_hash + root for paystub/summary
 * ----------------------------- */

export function computePaystubDocHash(doc: PaystubDocument): Hex32 {
  return hashHex32(encodePaystubDocument(doc));
}

export function computePaystubMerkleRoot(doc: PaystubDocument): Hex32 {
  return merkleRootFromLeafHashes(computePaystubLeafHashes(doc));
}

export function computeSummaryDocHash(doc: PayrollSummaryDocument): Hex32 {
  return hashHex32(encodePayrollSummaryDocument(doc));
}

export function computeSummaryMerkleRoot(doc: PayrollSummaryDocument): Hex32 {
  return merkleRootFromLeafHashes(computeSummaryLeafHashes(doc));
}
