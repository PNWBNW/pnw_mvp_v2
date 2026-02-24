// portal/src/commitments/canonical_types.ts
// Shared hash bundle contracts for deterministic portal planning.

import type { Bytes32 } from "../types/aleo_types";

export type CanonicalHashes = {
  doc_hash: Bytes32;
  inputs_hash: Bytes32;
  root: Bytes32;
};
