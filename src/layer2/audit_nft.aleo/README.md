# audit_nft.aleo

**Layer 2 – Audit Authorization NFTs (Commitment-Only)**

---

## Purpose

`audit_nft.aleo` provides the on-chain primitive for audit authorization in PNW v2.

It allows a caller to mint an authorization NFT that is:
- private in payload,
- publicly verifiable in existence/status,
- time-bounded via expiry,
- and usable to anchor audit attestation hashes.

---

## Why this program exists

Layer 1 already anchors audit events, but audits also need a reusable authorization artifact that says:

1. who can disclose within a committed scope,
2. until when that authorization is valid,
3. and what attestations were anchored under that authorization.

This program separates **authorization lifecycle** from payroll settlement and reporting logic.

---

## What this program does

- Mints private `AuditAuthorizationNFT` records
- Requires an existing Layer 1 `authorization_event_hash` anchor before minting
- Tracks authorization status publicly (`active`, `revoked`, `expired`)
- Enforces expiry checks for attestation anchoring
- Anchors attestation hashes and binds each to an authorization id

---

## Privacy model

Private fields include:
- scope/policy commitments
- authorization event hash
- issued/expiry epoch values

Public fields include only:
- authorization anchor height
- status
- expiry value
- revocation height
- attestation anchor heights + authorization linkage

No plaintext audit package or identity payload is emitted.

---

## Typical flow

1. Layer 1 audit event hash is anchored.
2. Caller mints `AuditAuthorizationNFT` with scope + expiry commitments.
3. Verifiers check authorization status/expiry through public utilities.
4. During authorized window, caller anchors attestation hash.
5. Anyone can verify the attestation exists and which authorization it references.

---

## Non-goals

- ❌ Execute payroll
- ❌ Move USDCx
- ❌ Reveal audit payload contents
- ❌ Replace Layer 1 audit event anchoring

---

## License

This program is **PROPRIETARY**.
