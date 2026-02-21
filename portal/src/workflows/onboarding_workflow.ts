// portal/src/workflows/onboarding_workflow.ts
//
// Phase 1 workflow definition (planning-only).
// Describes first-time participant onboarding intent without executing network calls.

import type { CallPlanStep } from "../router/layer1_router";

export type WorkerOnboardingInput = {
  register_name: Extract<CallPlanStep, { kind: "register_worker_name" }>;
  create_profile: Extract<CallPlanStep, { kind: "create_worker_profile" }>;
};

export type EmployerOnboardingInput = {
  // Employer paths require license verification before name/profile actions.
  assert_license_verified: Extract<CallPlanStep, { kind: "license_assert_verified" }>;
  register_name: Extract<CallPlanStep, { kind: "register_employer_name" }>;
  create_profile: Extract<CallPlanStep, { kind: "create_employer_profile" }>;
};

export type OnboardingWorkflowOutput = {
  plan: CallPlanStep[];
  outputs: {
    participant_type: "worker" | "employer";
    name_hash: string;
    profile_anchor: string;
  };
};

export function buildWorkerOnboardingWorkflow(input: WorkerOnboardingInput): OnboardingWorkflowOutput {
  const plan: CallPlanStep[] = [
    input.register_name,
    input.create_profile,
  ];

  return {
    plan,
    outputs: {
      participant_type: "worker",
      name_hash: input.register_name.name_hash,
      profile_anchor: input.create_profile.args.profile_anchor,
    },
  };
}

export function buildEmployerOnboardingWorkflow(input: EmployerOnboardingInput): OnboardingWorkflowOutput {
  const plan: CallPlanStep[] = [
    input.assert_license_verified,
    input.register_name,
    input.create_profile,
  ];

  return {
    plan,
    outputs: {
      participant_type: "employer",
      name_hash: input.register_name.name_hash,
      profile_anchor: input.create_profile.args.profile_anchor,
    },
  };
}
