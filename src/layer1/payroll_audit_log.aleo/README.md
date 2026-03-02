# payroll_audit_log.aleo

## Purpose

`payroll_audit_log.aleo` is intentionally a **minimal hash-anchor sink**.

It is used to prove:
- an audit event existed,
- the first-seen block height,
- and append-only ordering.

It is intentionally not used to store:
- cumulative payroll totals,
- plaintext wages,
- identity metadata,
- or per-actor balances.

## Why this matters for privacy

A common privacy failure in payroll/accounting programs is exposing cumulative totals in public mappings (for example `new_total_spent` deltas). Those deltas can leak salary magnitude over time.

PNW avoids this pattern by anchoring only opaque, domain-separated `event_hash` values.

## Auditor-facing model (what auditors actually need)

Auditors generally need distinct evidence classes, not one undifferentiated "spent total":

1. **Existence/ordering evidence**
   - `event_hash -> first_seen_height`
2. **Document commitment evidence**
   - `doc_hash`, `root`, `inputs_hash`
3. **Scope/authority evidence**
   - authorization credentials / audit authorization NFTs
4. **Selective disclosure evidence**
   - Merkle proofs and (future) ZK statements

`payroll_audit_log.aleo` covers only class (1) by design.

## Non-goal: protocol custody/budget pools

This program does not custody funds and does not hold pooled budgets.

Payroll settlement is performed by consuming employer-owned USDCx records and distributing worker-owned output records in `payroll_core.aleo`.
