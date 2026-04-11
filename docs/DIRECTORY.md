# Repository Directory

> Current as of 2026-04-10 — post-E10 end-to-end testnet run.
> Only lists the files that matter for day-to-day work. For deprecated
> program versions (e.g. `payroll_core.aleo` v1, `employer_agreement_v2`)
> see git history.

```
pnw_mvp_v2/
├─ README.md                # Project overview + phase status (top-level cover page)
├─ CLAUDE.md                # Session context — read first at every session start
├─ LICENSE.md               # Proprietary license terms
├─ .env.example             # Environment variable template (copy to .env, never commit .env)
│
├─ docs/
│  ├─ ARCHITECTURE.md       # Deep technical architecture, trust/privacy model, layering rationale
│  ├─ DIRECTORY.md          # This file
│  ├─ NOTES.md              # Issue tracker, fix priority, per-issue acceptance criteria
│  ├─ MULTI_REPO_PLAN.md    # Three-repo split: mvp_v2 / employment portal / auditing portal
│  └─ operations/
│     ├─ PHASE4_CLI_SETUP.md       # Leo v4.0 + snarkOS v4.6 pinning, install, CI bootstrap
│     └─ PHASE4_TESTNET_GAMEPLAN.md # Phase 5/6 roadmap and operator runbook
│
├─ .github/
│  └─ workflows/
│     ├─ deploy.yml                 # plan_gate: typecheck + codec tests + manifest + leakage guards
│     └─ execute_testnet.yml        # execute_gate: full testnet scenario + broadcast + receipt verify
│
├─ config/
│  ├─ testnet.manifest.json         # Canonical deployed program ID registry (source of truth for portals)
│  └─ scenarios/
│     ├─ README.md                  # Scenario file format and usage notes
│     ├─ schema.phaseA.json         # JSON schema for phaseA.scenario.v1 payloads
│     └─ testnet/                   # Smoke scenarios + sample mint args
│
├─ src/
│  ├─ layer1/
│  │  ├─ README.md                  # Layer 1 program index
│  │  ├─ LAYER1_INTERFACE.md        # Frozen callable surface (records/transitions/mappings)
│  │  │
│  │  │  # ACTIVE programs (deployed to testnet, imported by portal):
│  │  ├─ pnw_name_registry.aleo/       # Name hash registry + ownership assertions
│  │  ├─ employer_license_registry.aleo/ # Employer verification gate (AUTHORITY wallet)
│  │  ├─ employer_agreement_v4.aleo/   # Offer/accept/pause/terminate/resume/supersede
│  │  ├─ payroll_core_v2.aleo/         # Monolithic + batch execute_payroll with double-pay guard
│  │  ├─ paystub_receipts.aleo/        # Private worker + employer receipt records
│  │  ├─ payroll_audit_log.aleo/       # Hash-only audit event anchoring
│  │  ├─ pnw_router_v4.aleo/           # Stable Layer 1 orchestration entrypoint
│  │  │
│  │  │  # NEW v2 program specs drafted in-browser 2026-04-10 (READMEs only, not yet implemented):
│  │  ├─ employer_profiles_v2.aleo/README.md
│  │  ├─ pnw_worker_profiles_v2.aleo/README.md
│  │  └─ pnw_router_v3.aleo/README.md  (superseded by v4; README kept for reference)
│  │
│  └─ layer2/
│     ├─ payroll_nfts_v2.aleo/         # Cycle/quarter/YTD/EOY payroll NFT (imports agreement_v4)
│     ├─ credential_nft.aleo/          # Capability/authorization credentials
│     └─ audit_nft.aleo/                # Dual-consent audit authorization + attestation
│        └─ audit_repo.md               # Bootstrap reference for the future auditing portal repo
│
├─ portal/                              # Planning/adapter TypeScript layer used by CI gates.
│  │                                    # Production code now lives in pnw_employment_portal_v1;
│  │                                    # this dir is kept so `plan_gate` can typecheck manifests.
│  ├─ tsconfig.phase3.json
│  ├─ tsconfig.phase4.json
│  ├─ tests/phase4_adapter.test.ts
│  └─ src/                               # adapters, router, commitments, workflows, payroll builders
│
└─ scripts/                              # Install, validate, dispatch, verify (see each script's header comment)
```

## Deprecated but still present on disk

These are superseded by the active set above. Git history has the full narrative.

| Path | Superseded by |
|---|---|
| `src/layer1/employer_agreement_v2.aleo/` | `employer_agreement_v4.aleo` |
| `src/layer1/employer_agreement_v3.aleo/` | `employer_agreement_v4.aleo` |
| `src/layer1/employer_profiles.aleo/` | `employer_profiles_v2.aleo` (in-browser draft) |
| `src/layer1/payroll_core.aleo/` | `payroll_core_v2.aleo` |
| `src/layer1/pnw_name_registrar{,_v2..v4}.aleo/` | `pnw_name_registrar_v5.aleo` |
| `src/layer1/pnw_name_registry.aleo/` | `pnw_name_registry_v2.aleo` |
| `src/layer1/pnw_router_v2.aleo/` | `pnw_router_v4.aleo` |
| `src/layer1/pnw_worker_profiles.aleo/` | `pnw_worker_profiles_v2.aleo` (in-browser draft) |
| `src/layer2/payroll_nfts.aleo/` | `payroll_nfts_v2.aleo` (was @noupgrade; imports old agreement_v2) |
