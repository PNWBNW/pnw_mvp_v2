// portal/src/commitments/audit_scope_encoder.ts
//
// Canonical encoding and hash derivation for audit authorization scope,
// consent requests, and authorization events.
//
// Builds on the existing TLV/BLAKE3 infrastructure in canonical_encoder.ts.
// All hash computations here produce inputs that are anchored in Layer 1
// (payroll_audit_log.aleo) before mint_authorization_nft is called.
//
// Encoding spec object tags (extending canonical_encoder.ts series):
//   0x4001  OBJ_AUDIT_SCOPE             — AuditScopeRequest
//   0x4002  OBJ_AUDIT_CONSENT_REQUEST   — AuditConsentRequest (per role)
//   0x4003  OBJ_AUDIT_AUTHORIZATION_EVENT — combined dual-consent proof

import {
  encodeObject,
  tlvU8,
  tlvU16,
  tlvU32,
  tlvBytes32,
  hashHex32,
  type Hex32,
  type U8,
  type U16,
  type U32,
} from "./canonical_encoder";

// Re-export for consumers that only need audit types
export type { Hex32, U8, U16, U32 };

// ---------------------------------------------------------
// Object tags (Spec v1, audit extension)
// ---------------------------------------------------------

export const OBJ_AUDIT_SCOPE: U16 = 0x4001;
export const OBJ_AUDIT_CONSENT_REQUEST: U16 = 0x4002;
export const OBJ_AUDIT_AUTHORIZATION_EVENT: U16 = 0x4003;

// ---------------------------------------------------------
// Data category bitmask
// ---------------------------------------------------------
//
// The auditor specifies exactly which record types they are requesting.
// Only categories with the bit set can be served by the portal.
// Multiple categories combined with bitwise OR.
//
// Example: payroll_cycle + quarterly_summary = 0x01 | 0x02 = 0x03

export const DATA_CAT_PAYROLL_CYCLE: U16 = 0x0001;      // individual pay period records
export const DATA_CAT_QUARTERLY_SUMMARY: U16 = 0x0002;  // quarterly aggregates
export const DATA_CAT_YTD_SUMMARY: U16 = 0x0004;        // year-to-date aggregates
export const DATA_CAT_EOY_SUMMARY: U16 = 0x0008;        // end-of-year records
export const DATA_CAT_CREDENTIALS: U16 = 0x0010;        // worker credential NFTs
export const DATA_CAT_AUDIT_EVENTS: U16 = 0x0020;       // Layer 1 audit log entries

export type AuditDataCategoryMask = U16;

// Human-readable helper — returns array of set category names
export function describeDataCategories(mask: AuditDataCategoryMask): string[] {
  const out: string[] = [];
  if (mask & DATA_CAT_PAYROLL_CYCLE)      out.push("payroll_cycle");
  if (mask & DATA_CAT_QUARTERLY_SUMMARY)  out.push("quarterly_summary");
  if (mask & DATA_CAT_YTD_SUMMARY)        out.push("ytd_summary");
  if (mask & DATA_CAT_EOY_SUMMARY)        out.push("eoy_summary");
  if (mask & DATA_CAT_CREDENTIALS)        out.push("credentials");
  if (mask & DATA_CAT_AUDIT_EVENTS)       out.push("audit_events");
  return out;
}

// ---------------------------------------------------------
// Audit purpose codes (u8)
// ---------------------------------------------------------

export const PURPOSE_REGULATORY_AUDIT: U8 = 1;    // government / regulatory body
export const PURPOSE_COMPLIANCE_REVIEW: U8 = 2;   // internal compliance
export const PURPOSE_DISPUTE_RESOLUTION: U8 = 3;  // worker/employer dispute
export const PURPOSE_TAX_REVIEW: U8 = 4;          // tax authority
export const PURPOSE_WORKER_REQUEST: U8 = 5;      // worker-initiated own-data access

export type AuditPurposeCode = U8;

// ---------------------------------------------------------
// Consent role codes (u8)
// ---------------------------------------------------------

export const CONSENT_ROLE_EMPLOYER: U8 = 1;
export const CONSENT_ROLE_WORKER: U8 = 2;

export type ConsentRole = "employer" | "worker";

export function consentRoleToU8(role: ConsentRole): U8 {
  return role === "employer" ? CONSENT_ROLE_EMPLOYER : CONSENT_ROLE_WORKER;
}

// ---------------------------------------------------------
// AuditScopeRequest — what the auditor declares upfront
// ---------------------------------------------------------
//
// This is the binding contract for what data the auditor can access.
// All fields are committed to in scope_hash. The auditor must reveal
// this full object to the portal; the portal verifies the hash matches
// nft.scope_hash before serving any data.
//
// Fields:
//   data_categories:        bitmask of DATA_CAT_* values
//   period_start_epoch:     start of the data time range (inclusive)
//   period_end_epoch:       end of the data time range (inclusive)
//   worker_id_hash:         BLAKE3 of the worker identifier (never plaintext)
//   employer_id_hash:       BLAKE3 of the employer identifier
//   purpose_code:           one of PURPOSE_* values
//   access_duration_epochs: how long the auditor is requesting access
//                           (enforced: expires_epoch = issued_epoch + this value)

export interface AuditScopeRequest {
  data_categories: AuditDataCategoryMask;
  period_start_epoch: U32;
  period_end_epoch: U32;
  worker_id_hash: Hex32;
  employer_id_hash: Hex32;
  purpose_code: AuditPurposeCode;
  access_duration_epochs: U32;
}

// ---------------------------------------------------------
// AuditConsentRequest — what each consenting party signs
// ---------------------------------------------------------
//
// Both employer and worker sign the same set of fields with different role codes.
// This ensures neither party can be deceived about what scope or duration they approved.
//
// consent_role:  CONSENT_ROLE_EMPLOYER or CONSENT_ROLE_WORKER
// expires_epoch: issued_epoch + access_duration_epochs (portal derives this)

export interface AuditConsentRequest {
  request_id: Hex32;
  scope_hash: Hex32;
  auditor_addr_hash: Hex32;         // BLAKE3 of the auditor's Aleo address
  access_duration_epochs: U32;
  expires_epoch: U32;               // issued_epoch + access_duration_epochs
  employer_id_hash: Hex32;          // which employer is in scope
  worker_id_hash: Hex32;            // which worker is in scope
  consent_role: ConsentRole;
}

// ---------------------------------------------------------
// AuditAuthorizationEvent — combined dual-consent proof
// ---------------------------------------------------------

export interface AuditAuthorizationEvent {
  employer_consent_hash: Hex32;
  worker_consent_hash: Hex32;
  request_id: Hex32;
}

// ---------------------------------------------------------
// Encoders
// ---------------------------------------------------------

export function encodeAuditScope(scope: AuditScopeRequest): Uint8Array {
  if (scope.data_categories === 0) {
    throw new Error("data_categories must not be zero — auditor must specify at least one category");
  }
  if (scope.access_duration_epochs === 0) {
    throw new Error("access_duration_epochs must not be zero");
  }
  if (scope.period_end_epoch < scope.period_start_epoch) {
    throw new Error("period_end_epoch must be >= period_start_epoch");
  }

  const tlvs: Uint8Array[] = [
    tlvU16(scope.data_categories),
    tlvU32(scope.period_start_epoch),
    tlvU32(scope.period_end_epoch),
    tlvBytes32(scope.worker_id_hash),
    tlvBytes32(scope.employer_id_hash),
    tlvU8(scope.purpose_code),
    tlvU32(scope.access_duration_epochs),
  ];

  return encodeObject(OBJ_AUDIT_SCOPE, tlvs);
}

export function computeScopeHash(scope: AuditScopeRequest): Hex32 {
  return hashHex32(encodeAuditScope(scope));
}

export function encodeAuditConsentRequest(consent: AuditConsentRequest): Uint8Array {
  if (consent.expires_epoch === 0) {
    throw new Error("expires_epoch must not be zero");
  }
  if (consent.access_duration_epochs === 0) {
    throw new Error("access_duration_epochs must not be zero");
  }

  const tlvs: Uint8Array[] = [
    tlvBytes32(consent.request_id),
    tlvBytes32(consent.scope_hash),
    tlvBytes32(consent.auditor_addr_hash),
    tlvU32(consent.access_duration_epochs),
    tlvU32(consent.expires_epoch),
    tlvBytes32(consent.employer_id_hash),
    tlvBytes32(consent.worker_id_hash),
    tlvU8(consentRoleToU8(consent.consent_role)),
  ];

  return encodeObject(OBJ_AUDIT_CONSENT_REQUEST, tlvs);
}

export function computeConsentHash(consent: AuditConsentRequest): Hex32 {
  return hashHex32(encodeAuditConsentRequest(consent));
}

export function encodeAuditAuthorizationEvent(event: AuditAuthorizationEvent): Uint8Array {
  const tlvs: Uint8Array[] = [
    tlvBytes32(event.employer_consent_hash),
    tlvBytes32(event.worker_consent_hash),
    tlvBytes32(event.request_id),
  ];

  return encodeObject(OBJ_AUDIT_AUTHORIZATION_EVENT, tlvs);
}

export function computeAuthorizationEventHash(event: AuditAuthorizationEvent): Hex32 {
  return hashHex32(encodeAuditAuthorizationEvent(event));
}

// ---------------------------------------------------------
// Convenience: derive all hashes from a single request
// ---------------------------------------------------------
//
// Given the auditor's scope request and the issued_epoch, derive all three
// hashes that need to be anchored in Layer 1 before minting the NFT.
//
// Usage:
//   const hashes = deriveAuditHashes({
//     request_id, scope, issued_epoch, auditor_addr_hash,
//     employer_id_hash, worker_id_hash,
//   });
//   // anchor hashes.employer_consent_hash (employer signs)
//   // anchor hashes.worker_consent_hash   (worker signs)
//   // anchor hashes.authorization_event_hash (portal anchors after both)

export interface AuditHashDerivationInput {
  request_id: Hex32;
  scope: AuditScopeRequest;
  issued_epoch: U32;
  auditor_addr_hash: Hex32;
  employer_id_hash: Hex32;    // can differ from scope.employer_id_hash if needed, but should match
  worker_id_hash: Hex32;      // same note
}

export interface DerivedAuditHashes {
  scope_hash: Hex32;
  expires_epoch: U32;
  employer_consent_hash: Hex32;
  worker_consent_hash: Hex32;
  authorization_event_hash: Hex32;
}

export function deriveAuditHashes(input: AuditHashDerivationInput): DerivedAuditHashes {
  const expires_epoch: U32 = input.issued_epoch + input.scope.access_duration_epochs;

  const scope_hash = computeScopeHash(input.scope);

  const employerConsent: AuditConsentRequest = {
    request_id: input.request_id,
    scope_hash,
    auditor_addr_hash: input.auditor_addr_hash,
    access_duration_epochs: input.scope.access_duration_epochs,
    expires_epoch,
    employer_id_hash: input.employer_id_hash,
    worker_id_hash: input.worker_id_hash,
    consent_role: "employer",
  };

  const workerConsent: AuditConsentRequest = {
    ...employerConsent,
    consent_role: "worker",
  };

  const employer_consent_hash = computeConsentHash(employerConsent);
  const worker_consent_hash = computeConsentHash(workerConsent);

  const authorization_event_hash = computeAuthorizationEventHash({
    employer_consent_hash,
    worker_consent_hash,
    request_id: input.request_id,
  });

  return {
    scope_hash,
    expires_epoch,
    employer_consent_hash,
    worker_consent_hash,
    authorization_event_hash,
  };
}
