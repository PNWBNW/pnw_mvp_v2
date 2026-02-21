// portal/src/workflows/profile_update_workflow.ts
//
// Phase 1 workflow definition (planning-only).
// Describes profile revision intent for worker/employer identities.

import type { CallPlanStep } from "../router/layer1_router";

export type WorkerProfileUpdateInput = {
  update_profile: Extract<CallPlanStep, { kind: "update_worker_profile" }>;
  include_anchor_assertion?: boolean;
};

export type EmployerProfileUpdateInput = {
  update_profile: Extract<CallPlanStep, { kind: "update_employer_profile" }>;
  include_anchor_assertion?: boolean;
};

export type ProfileUpdateWorkflowOutput = {
  plan: CallPlanStep[];
  outputs: {
    participant_type: "worker" | "employer";
    new_profile_anchor: string;
  };
};

export function buildWorkerProfileUpdateWorkflow(input: WorkerProfileUpdateInput): ProfileUpdateWorkflowOutput {
  const plan: CallPlanStep[] = [input.update_profile];

  if (input.include_anchor_assertion === true) {
    plan.push({
      kind: "assert_worker_profile_anchored",
      profile_anchor: input.update_profile.args.new_profile_anchor,
    });
  }

  return {
    plan,
    outputs: {
      participant_type: "worker",
      new_profile_anchor: input.update_profile.args.new_profile_anchor,
    },
  };
}

export function buildEmployerProfileUpdateWorkflow(input: EmployerProfileUpdateInput): ProfileUpdateWorkflowOutput {
  const plan: CallPlanStep[] = [input.update_profile];

  if (input.include_anchor_assertion === true) {
    plan.push({
      kind: "assert_employer_profile_anchored",
      profile_anchor: input.update_profile.args.new_profile_anchor,
    });
  }

  return {
    plan,
    outputs: {
      participant_type: "employer",
      new_profile_anchor: input.update_profile.args.new_profile_anchor,
    },
  };
}
