pnw_mvp_v2/
├─ README.md                               # Project overview, architecture summary, phase status, repo navigation
├─ ARCHITECTURE.md                         # Deep technical architecture, trust/privacy model, and layering rationale
├─ CLAUDE.md                               # Session context: phase status, bug list, file map, architecture invariants
├─ NOTES.md                                # Full issue tracker, fix priority order, per-issue acceptance criteria
├─ LICENSE.md                              # Proprietary license terms
├─ DIRECTORY.md                            # This repo map with per-file descriptions
├─ .env.example                            # Environment variable template (copy to .env, never commit .env)
│
├─ docs/
│  ├─ EMPLOYMENT_PORTAL.md                 # Two-sided portal product spec (employer, worker, audit zone, PDF docs)
│  ├─ MULTI_REPO_PLAN.md                   # Three-repo architecture: pnw_mvp_v2, employment portal, auditing portal
│  └─ operations/
│     ├─ PHASE4_CLI_SETUP.md               # Phase 4 CLI pin/verification guide; snarkOS/Leo install; happy-path wrapper
│     └─ PHASE4_TESTNET_GAMEPLAN.md        # PR sequence A→D, Phase 5/6 deployment plan, testnet operator runbook
│
├─ .github/
│  └─ workflows/
│     ├─ deploy.yml                        # plan_gate: typecheck + codec tests + manifest + leakage guards (no secrets)
│     └─ execute_testnet.yml               # execute_gate: full testnet scenario with broadcast + receipt verification
│
├─ config/
│  ├─ testnet.manifest.json                # Canonical deployed program ID registry — source of truth for both portal repos
│  └─ scenarios/
│     ├─ README.md                         # Scenario file format and usage notes
│     ├─ schema.phaseA.json                # JSON schema for phaseA.scenario.v1 payloads
│     └─ testnet/
│        ├─ min_spend.payroll.json          # Minimum payroll smoke scenario (addresses injected from env at runtime)
│        ├─ min_spend.onboarding.json       # Minimum onboarding smoke scenario (addresses injected from env at runtime)
│        ├─ onboarding_mint_args.sample.json # Sample mint args for credential_nft onboarding (placeholder hashes)
│        ├─ broadcast_commands.sample.json  # Sample broadcast command payload structure reference
│        └─ broadcast_commands.onboarding.template.json  # Template for onboarding broadcast command generation
│
├─ src/
│  ├─ layer1/
│  │  ├─ README.md                         # Layer 1 program index and canonical responsibilities
│  │  ├─ LAYER1_INTERFACE.md               # Frozen Layer 1 callable surface (records/transitions/functions)
│  │  │
│  │  ├─ pnw_router.aleo/
│  │  │  ├─ README.md                      # Router-level narrative and scope
│  │  │  ├─ main.leo                       # On-chain orchestration entrypoints for key Layer 1 flows
│  │  │  └─ program.json                   # Program manifest/config for pnw_router
│  │  │
│  │  ├─ pnw_name_registry.aleo/
│  │  │  ├─ README.md                      # .pnw naming model, suffix codes, and registration rules
│  │  │  ├─ main.leo                       # Worker/employer name registration, ownership, sellback logic
│  │  │  └─ program.json                   # Program manifest/config for name registry
│  │  │
│  │  ├─ employer_license_registry.aleo/
│  │  │  ├─ README.md                      # Employer license verification gating model
│  │  │  ├─ main.leo                       # Verified status + license hash assertions/lookups
│  │  │  └─ program.json                   # Program manifest/config for employer license registry
│  │  │
│  │  ├─ worker_profiles.aleo/
│  │  │  ├─ README.md                      # Worker profile commitment model
│  │  │  ├─ main.leo                       # Create/update worker profile records + profile anchor checks
│  │  │  └─ program.json                   # Program manifest/config for worker profiles
│  │  │
│  │  ├─ employer_profiles.aleo/
│  │  │  ├─ README.md                      # Employer profile commitment model
│  │  │  ├─ main.leo                       # Create/update employer profile records + profile anchor checks
│  │  │  └─ program.json                   # Program manifest/config for employer profiles
│  │  │
│  │  ├─ employer_agreement.aleo/
│  │  │  ├─ README.md                      # Employment agreement lifecycle narrative
│  │  │  ├─ main.leo                       # Offer/accept/pause/terminate/resume/supersede agreement transitions
│  │  │  └─ program.json                   # Program manifest/config for employer agreement
│  │  │
│  │  ├─ payroll_core.aleo/
│  │  │  ├─ README.md                      # Canonical payroll execution model (USDCx + anchors)
│  │  │  ├─ main.leo                       # Execute payroll settlement; anti-double-pay guards; audit hash anchor
│  │  │  └─ program.json                   # Program manifest/config for payroll core
│  │  │
│  │  ├─ paystub_receipts.aleo/
│  │  │  ├─ README.md                      # Private paystub receipt minting and correction/reversal model
│  │  │  ├─ main.leo                       # Worker/employer receipt records + receipt anchor mapping utilities
│  │  │  └─ program.json                   # Program manifest/config for paystub receipts
│  │  │
│  │  └─ payroll_audit_log.aleo/
│  │     ├─ main.leo                       # Hash-only audit event anchoring + block height lookups
│  │     └─ program.json                   # Program manifest/config for payroll audit log
│  │
│  └─ layer2/
│     ├─ payroll_nfts.aleo/
│     │  ├─ README.md                      # Payroll NFT commitment model (cycle/quarterly/YTD/EOY)
│     │  ├─ main.leo                       # Mint/revoke/supersede payroll NFTs; status and anchor utility transitions
│     │  └─ program.json                   # Program manifest/config for payroll NFTs
│     │
│     ├─ credential_nft.aleo/
│     │  ├─ README.md                      # Credential NFT model for capability/authorization proofs
│     │  ├─ main.leo                       # Mint/revoke credential NFTs; scope anchoring and status checks
│     │  └─ program.json                   # Program manifest/config for credential NFTs
│     │
│     └─ audit_nft.aleo/
│        ├─ README.md                      # Audit authorization NFT model and attestation anchoring
│        ├─ audit_repo.md                  # Audit NFT design notes and scope reference
│        ├─ main.leo                       # Authorization mint/revoke/expiry; audit attestation anchor transitions
│        └─ program.json                   # Program manifest/config for audit NFTs
│
├─ portal/
│  ├─ tsconfig.phase3.json                 # Focused no-emit typecheck gate for Phase 3 planning surfaces
│  ├─ tsconfig.phase4.json                 # Focused no-emit typecheck gate for Phase 4 adapter scaffold
│  ├─ tests/
│  │  └─ phase4_adapter.test.ts            # Adapter codec tests: command shape, arg encoding, step kind dispatch
│  └─ src/
│     ├─ README.md                         # Portal architecture overview and folder responsibilities
│     │
│     ├─ config/
│     │  ├─ README.md                      # Config philosophy and usage notes
│     │  ├─ env.ts                         # Env parsing/validation + network selection
│     │  └─ programs.ts                    # Program identifier registry by network
│     │
│     ├─ types/
│     │  ├─ aleo_types.ts                  # Shared scalar aliases/guards (Field, Address, U8/U16/U32/U64/U128)
│     │  ├─ aleo_records.ts                # Opaque record contracts used by planners/adapters
│     │  └─ node.d.ts                      # Minimal NodeJS process/env type shims for TS compile
│     │
│     ├─ commitments/
│     │  ├─ README.md                      # Commitments subsystem narrative and constraints
│     │  ├─ canonical_types.ts             # Canonical doc field/type contracts for encoding/commitments
│     │  ├─ canonical_encoder.ts           # Deterministic canonical encoding + commitment builder
│     │  ├─ hash.ts                        # Domain-separated BLAKE3 hashing utilities
│     │  ├─ merkle.ts                      # Deterministic Merkle tree construction helpers
│     │  └─ token_id.ts                    # Deterministic token ID derivation utilities
│     │
│     ├─ payroll/
│     │  ├─ README.md                      # Payroll aggregation pipeline overview
│     │  ├─ types.ts                       # Payroll domain types/contracts for normalized and indexed data
│     │  ├─ normalize.ts                   # Receipt normalization into deterministic base events
│     │  ├─ indexer.ts                     # Deterministic grouping/sorting/indexing of normalized events
│     │  ├─ paystub_builder.ts             # Canonical single-payroll paystub document construction
│     │  ├─ summary_builder.ts             # Canonical quarterly/YTD/EOY summary document construction
│     │  └─ mint_payroll_nfts.ts           # Build deterministic Layer 2 payroll NFT mint payloads (planning only)
│     │
│     ├─ workflows/
│     │  ├─ README.md                      # Planning-only workflow narratives and constraints
│     │  ├─ payroll_workflow.ts            # Canonical payroll workflow planner (prechecks + execute_payroll)
│     │  ├─ audit_workflow.ts              # Audit authorization workflow planner and outputs
│     │  ├─ onboarding_workflow.ts         # Worker/employer onboarding workflow planners
│     │  └─ profile_update_workflow.ts     # Worker/employer profile update workflow planners
│     │
│     ├─ router/
│     │  ├─ layer1_router.ts               # Typed Layer 1 call-plan surface + adapter execution handoff
│     │  └─ layer2_router.ts               # Typed Layer 2 call-plan surface + stable helper planners
│     │
│     └─ adapters/
│        ├─ layer1_adapter.ts              # Layer 1 step→program/transition endpoint resolver
│        ├─ layer2_adapter.ts              # Layer 2 step→program/transition endpoint resolver
│        └─ aleo_cli_adapter.ts            # THE execution boundary — builds snarkos developer execute commands
│
└─ scripts/
   ├─ verify_provable_cli.sh               # Verify leo/snarkos availability and version pins
   ├─ resolve_provable_cli_latest.sh       # Query latest ProvableHQ release tags (leo/snarkOS)
   ├─ validate_workflow_yaml.sh            # YAML structure check for CI workflow files (no PyYAML needed)
   ├─ validate_testnet_manifest.py         # Validate testnet.manifest.json schema and program ID format
   ├─ validate_phaseA_scenario.py          # Validate phaseA.scenario.v1 JSON payloads before execute
   ├─ validate_phase4_broadcast_commands.py # Validate broadcast command payload structure before execute
   ├─ derive_phaseA_name_hash.py           # Derive deterministic name hash for phaseA scenario inputs
   ├─ check_layer1_public_leakage_guards.py # Enforce no plaintext wages/addresses in public Layer 1 mappings
   ├─ check_phase4_negative_path_guards.sh # Enforce scenario/file mismatch rejection in execute scenario logic
   ├─ require_phase4_execute_env.sh        # Validate all required env vars are set before execute gate runs
   ├─ run_phase4_adapter_tests.sh          # Run Phase 4 adapter codec unit tests
   ├─ run_phase4_execute_scenario.sh       # Execute a named scenario; substitute env tokens; emit artifact bundle
   ├─ run_phase4_testnet_happy_path.sh     # End-to-end happy path wrapper: manifest → env check → scenario → bundle
   ├─ build_onboarding_broadcast_commands.py # Generate broadcast command payload from onboarding mint args
   ├─ dispatch_phase4_execute.sh           # Dispatch execute_testnet.yml workflow_dispatch via GitHub API
   ├─ verify_phase4_execute_artifacts.py   # Verify execute evidence bundle SHA integrity post-run
   └─ verify_phase4_receipts.py            # Verify broadcast tx IDs against Aleo REST endpoint (best-effort)
