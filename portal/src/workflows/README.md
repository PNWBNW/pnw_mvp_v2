# portal/src/workflows/

Planning-only workflow definitions for PNW Portal.

## Constraints
- No CLI calls
- No wallet integration
- No network execution
- No testnet/mainnet side effects

Workflows describe **intent and ordering** only, then hand plans to routers/adapters.

## Files
- `payroll_workflow.ts` — canonical payroll flow planning
  - validates workflow-level ordering
  - returns deterministic Layer 1 call plan
  - exposes reusable output anchors/hashes for downstream reporting/NFT flows

- `audit_workflow.ts` — canonical audit authorization flow planning
  - models authorization request + scope commitment
  - supports batched anchoring by composing multiple planned steps
  - includes optional expiry metadata for downstream enforcement
