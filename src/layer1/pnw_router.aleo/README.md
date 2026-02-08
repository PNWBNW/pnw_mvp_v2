```markdown
# pnw_router.aleo

`pnw_router.aleo` is the Layer 1 **workflow router** for PNW MVP v2.

It exists to provide the portal a **single stable entry surface** and to **orchestrate prerequisite ordering** across Layer 1 programs.

## What it does
- Calls into `employer_agreement.aleo` for agreement lifecycle transitions
- Calls into `worker_profiles.aleo` / `employer_profiles.aleo` for anchor assertions
- Calls into `pnw_name_registry.aleo` for ownership assertions

## What it does NOT do
- Store state
- Compute hashes
- Aggregate or summarize data
- Mint Layer 2 NFTs
- Move USDCx funds (that happens in `payroll_core.aleo`)

## Dependencies
- `employer_agreement.aleo`
- `employer_profiles.aleo`
- `worker_profiles.aleo`
- `pnw_name_registry.aleo`

## Notes
- All document hashes, anchors, and summaries are portal-supplied.
- This router is intentionally minimal: it’s a stable orchestration layer, not a logic layer.
```
