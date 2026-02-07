// portal/src/commitments/merkle.ts
//
// Deterministic Merkle tree:
// - leaves are Bytes32
// - odd node duplication rule (duplicate last element)
// - parent = H(PNW::MERKLE_NODE, left || right)

import { concatBytes } from "@noble/hashes/utils";
import { Bytes32, HASH_DOMAINS, assertBytes32, hashDomain } from "./hash";

export type MerkleProofStep = {
  sibling: Bytes32;
  // If sibling is on the left, current hash is on the right, and vice versa.
  side: "L" | "R";
};

export function merkleParent(left: Bytes32, right: Bytes32): Bytes32 {
  assertBytes32(left, "left");
  assertBytes32(right, "right");
  return hashDomain(HASH_DOMAINS.MERKLE_NODE, concatBytes(left, right));
}

/**
 * Builds the full Merkle root from leaves (Bytes32).
 * If leaves is empty, throws (explicit is better than implicit).
 */
export function merkleRoot(leaves: Bytes32[]): Bytes32 {
  if (!Array.isArray(leaves)) throw new Error("leaves must be an array");
  if (leaves.length === 0) throw new Error("cannot build Merkle root of empty leaves");

  let level: Bytes32[] = leaves.map((l, i) => {
    assertBytes32(l, `leaf[${i}]`);
    return l;
  });

  while (level.length > 1) {
    const next: Bytes32[] = [];
    for (let i = 0; i < level.length; i += 2) {
      const left = level[i];
      const right = i + 1 < level.length ? level[i + 1] : level[i]; // duplicate last
      next.push(merkleParent(left, right));
    }
    level = next;
  }
  return level[0];
}

/**
 * Builds an inclusion proof for the leaf at `index`.
 * Proof steps are ordered from leaf level upward.
 */
export function merkleProof(leaves: Bytes32[], index: number): MerkleProofStep[] {
  if (leaves.length === 0) throw new Error("cannot prove membership in empty tree");
  if (index < 0 || index >= leaves.length) throw new Error("index out of range");

  // Validate leaves
  leaves.forEach((l, i) => assertBytes32(l, `leaf[${i}]`));

  let idx = index;
  let level: Bytes32[] = leaves.slice();
  const proof: MerkleProofStep[] = [];

  while (level.length > 1) {
    const isRight = idx % 2 === 1;
    const pairIndex = isRight ? idx - 1 : idx + 1;

    const sibling = pairIndex < level.length ? level[pairIndex] : level[idx]; // duplicate last
    proof.push({
      sibling,
      side: isRight ? "L" : "R",
    });

    // build next level
    const next: Bytes32[] = [];
    for (let i = 0; i < level.length; i += 2) {
      const left = level[i];
      const right = i + 1 < level.length ? level[i + 1] : level[i];
      next.push(merkleParent(left, right));
    }

    level = next;
    idx = Math.floor(idx / 2);
  }

  return proof;
}

/**
 * Verifies membership proof against a root.
 */
export function verifyMerkleProof(root: Bytes32, leaf: Bytes32, proof: MerkleProofStep[]): boolean {
  assertBytes32(root, "root");
  assertBytes32(leaf, "leaf");

  let acc: Bytes32 = leaf;
  for (let i = 0; i < proof.length; i++) {
    const step = proof[i];
    assertBytes32(step.sibling, `proof[${i}].sibling`);
    acc = step.side === "L" ? merkleParent(step.sibling, acc) : merkleParent(acc, step.sibling);
  }

  // constant-time compare is ideal, but this is sufficient for non-crypto-critical UI checks
  if (acc.length !== root.length) return false;
  for (let i = 0; i < acc.length; i++) if (acc[i] !== root[i]) return false;
  return true;
}
