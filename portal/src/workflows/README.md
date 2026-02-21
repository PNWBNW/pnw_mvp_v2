# portal/src/workflows/

This folder tells the **story of intent** for the Portal.

When a new developer asks, “How does this system actually operate?”, workflows are the answer:
- they define the ordered business flow,
- they show which on-chain checks must happen,
- and they package deterministic outputs needed by downstream steps.

Importantly, workflows are **planning-only**.
They do not sign, broadcast, or execute anything.

## Why this folder exists
Without workflows, intent gets scattered between routers, adapters, and docs.
That creates ambiguity and onboarding friction.

This folder keeps a human-friendly, deterministic source of truth for:
1. **How** we expect each process to run,
2. **Why** that ordering exists,
3. **What** outputs later layers depend on.

## Constraints (Phase 1)
- No CLI calls
- No wallet integration
- No network execution
- No testnet/mainnet side effects

## Workflow Narrative

### 1) Payroll workflow (`payroll_workflow.ts`)
Use this when payroll is ready to settle.

Narrative:
1. Optionally assert agreement is active.
2. Execute payroll in Layer 1.
3. Return stable anchors/hashes for reporting and Layer 2 commitments.

Why this order?
- We validate agreement state before settlement intent.
- We preserve deterministic outputs for audit/report composition.

### 2) Audit workflow (`audit_workflow.ts`)
Use this when an authorization event for disclosure/audit must be anchored.

Narrative:
1. Anchor authorization event hash.
2. Optionally assert the anchor immediately.
3. Return scope/expiry outputs for downstream policy checks.

Why this order?
- Anchoring first creates immutable proof.
- Optional assertion provides same-plan confidence checks.

### 3) Onboarding workflow (`onboarding_workflow.ts`)
Use this for first-time worker/employer setup.

Narrative (worker):
1. Register worker name.
2. Create worker profile.

Narrative (employer):
1. Assert employer license verification.
2. Register employer name.
3. Create employer profile.

Why this order?
- Employer onboarding requires explicit eligibility before identity/profile creation.

### 4) Profile update workflow (`profile_update_workflow.ts`)
Use this when a participant updates profile commitments.

Narrative:
1. Update profile record.
2. Optionally assert new anchor.

Why this order?
- Keeps update intent explicit while allowing callers to request immediate anchor confirmation.

## Design notes for contributors
- Keep workflows small and declarative.
- Keep all execution logic in adapters.
- Prefer explicit, named outputs over implicit assumptions.
- If a new workflow is added, update this README with the same **How / Why / What outputs** format.
