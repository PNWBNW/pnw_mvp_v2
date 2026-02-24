// portal/src/types/aleo_types.ts
//
// Shared Aleo-flavored scalar types used by portal routers/workflows/adapters.
// These are compile-time contracts only (planning layer), not runtime codecs.

// Core Aleo scalar aliases used across the planning layer.
export type Field = string;
export type Address = string;

export type U8 = number;
export type U16 = number;
export type U32 = number;
export type U64 = bigint;
export type U128 = bigint;

// Keep a single bytes32 alias aligned with commitment modules.
export type Bytes32 = Uint8Array;

// Optional light-weight guards for adapter boundaries.
export function assertU32(value: number, label = "u32"): asserts value is U32 {
  if (!Number.isInteger(value) || value < 0 || value > 0xffffffff) {
    throw new Error(`${label} must be an integer in [0, 2^32-1]`);
  }
}

export function assertU16(value: number, label = "u16"): asserts value is U16 {
  if (!Number.isInteger(value) || value < 0 || value > 0xffff) {
    throw new Error(`${label} must be an integer in [0, 65535]`);
  }
}

export function assertU8(value: number, label = "u8"): asserts value is U8 {
  if (!Number.isInteger(value) || value < 0 || value > 0xff) {
    throw new Error(`${label} must be an integer in [0, 255]`);
  }
}

export function assertAddress(value: string, label = "address"): asserts value is Address {
  if (value.trim().length === 0) {
    throw new Error(`${label} must be a non-empty string`);
  }
}
