# Phase 3 Signoff — Portal Layer 2 Routing

This checklist formalizes Phase 3 completion criteria before any Phase 4 execution work.

---

## Exit Criteria

- [x] Layer 2 router step coverage complete for payroll, credential, and audit NFT surfaces.
- [x] Program/transition strings remain adapter-owned (no execution strings in routers/workflows).
- [x] Router API freeze decision made:
  - stable helper methods are available for common UI opportunities,
  - raw `plan` / `planMany` remain available for advanced composition.
- [x] Shared scalar/record type contracts are fixed for planner modules:
  - `portal/src/types/aleo_types.ts`
  - `portal/src/types/aleo_records.ts`
- [x] Focused planner typecheck gate exists and passes:
  - `portal/tsconfig.phase3.json`

---

## Notes for Phase 4

- Keep workflows planning-only.
- Keep adapters as the only execution boundary.
- Add new helper methods only when they represent reusable capability surfaces (not one-off UI variants).
