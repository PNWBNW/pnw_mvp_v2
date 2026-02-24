// portal/src/types/aleo_records.ts
//
// Opaque Leo record contracts returned by execution adapters.
// Router/workflow layers should not depend on concrete record internals.

export type OpaqueLeoRecord<TTag extends string> = {
  readonly __record_tag: TTag;
  readonly raw: unknown;
};

// Layer 1 records
export type PendingAgreementRecord = OpaqueLeoRecord<"PendingAgreementRecord">;
export type FinalAgreementRecord = OpaqueLeoRecord<"FinalAgreementRecord">;
export type EmployerProfileRecord = OpaqueLeoRecord<"EmployerProfileRecord">;
export type WorkerProfileRecord = OpaqueLeoRecord<"WorkerProfileRecord">;
export type WorkerPaystubReceiptRecord = OpaqueLeoRecord<"WorkerPaystubReceiptRecord">;
export type EmployerPaystubReceiptRecord = OpaqueLeoRecord<"EmployerPaystubReceiptRecord">;
export type UsdcxRecord = OpaqueLeoRecord<"UsdcxRecord">;

// Layer 2 records
export type PayrollNftRecord = OpaqueLeoRecord<"PayrollNftRecord">;
export type CredentialNftRecord = OpaqueLeoRecord<"CredentialNftRecord">;
export type AuditAuthorizationNftRecord = OpaqueLeoRecord<"AuditAuthorizationNftRecord">;
