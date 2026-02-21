# credential_nft.aleo

**Layer 2 – Credential NFTs (Commitment-Only Anchors)**

---

## Purpose

`credential_nft.aleo` provides a privacy-preserving credential primitive for PNW Layer 2.

It exists to let a caller mint an NFT that proves:
- a credential exists,
- it belongs to a specific scope,
- and it can later be revoked,

without publishing the underlying credential contents.

---

## Why this program exists

Payroll NFTs handle payroll summary commitments.

Credential NFTs are different: they represent **authorization/attestation style artifacts**
that can be reused across audit and disclosure flows while keeping plaintext content private.

This gives the protocol a clean way to separate:
- monetary settlement proofs,
- payroll-reporting proofs,
- credential/authorization proofs.

---

## What this program does

- Mints a private `CredentialNFT` record
- Anchors credential existence publicly by `credential_id`
- Anchors scope existence publicly by `scope_hash`
- Supports owner-driven revocation
- Exposes public verification utilities (existence, status, anchor heights)

---

## Privacy model

Private record fields include:
- `subject_hash`
- `issuer_hash`
- `scope_hash`
- `doc_hash`
- `root`
- version fields

Public state includes only:
- credential anchor height
- status (`active` / `revoked`)
- revoked height
- scope anchor height

No plaintext identity or credential content is stored publicly.

---

## Typical flow

1. Portal computes scope/document commitments off-chain.
2. User mints credential NFT with commitment fields.
3. Program anchors `credential_id` and `scope_hash` for verification.
4. Verifiers check status/anchor height publicly.
5. If needed, owner revokes credential NFT and status flips to revoked.

---

## Non-goals

- ❌ Execute payroll
- ❌ Move USDCx
- ❌ Render documents
- ❌ Expose plaintext credential payloads

---

## License

This program is **PROPRIETARY**.
