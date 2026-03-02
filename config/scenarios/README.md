# Scenario Inputs (Phase A)

This folder defines canonical, reusable scenario payloads for test and future app-backed execution.

## Goal

Use one stable shape for:
- operator test runs,
- CI smoke execution wiring,
- and future React/backend dispatch.

This avoids reformatting payloads between "test deploy" and "real deploy" paths.

## Files

- `schema.phaseA.json` — canonical scenario schema for current planning/execution boundary.
- `testnet/min_spend.payroll.json` — starter low-value sample using placeholder identifiers.

## Notes

- These files are **non-secret** and can be committed.
- Wallet keys, RPC endpoints, and signing credentials remain in environment secrets.
- Replace placeholder values before real execution.
