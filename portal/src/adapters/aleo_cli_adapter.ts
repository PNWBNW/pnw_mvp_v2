// portal/src/adapters/aleo_cli_adapter.ts
//
// Phase 4 scaffold:
// - Concrete adapter implementation for Layer 2 planner execution.
// - Supports "plan_only" mode now (no network side effects).
// - Preserves adapter isolation and structured step traces.

import type { Network } from "../config/env";
import type { Layer2CallPlanResult, Layer2CallPlanStep } from "../router/layer2_router";
import { resolveLayer2Endpoint, type Layer2Adapter, type Layer2TxMeta } from "./layer2_adapter";

export type CliExecutionMode = "plan_only" | "execute";

export type CliCommandResult = {
  exit_code: number;
  stdout: string;
  stderr: string;
};

export interface CliCommandExecutor {
  run(command: string): Promise<CliCommandResult>;
}

export class UnconfiguredCliCommandExecutor implements CliCommandExecutor {
  async run(_command: string): Promise<CliCommandResult> {
    throw new Error("CLI executor is not configured for execute mode");
  }
}

export type CliStepTrace<TKind extends string, TMeta> = {
  index: number;
  kind: TKind;
  endpoint: TMeta;
  command: string;
  status: "planned" | "executed";
  result?: CliCommandResult;
};

export type Layer2CliExecutionReport = {
  mode: CliExecutionMode;
  steps: CliStepTrace<Layer2CallPlanStep["kind"], Layer2TxMeta>[];
};

function quoteJson(value: unknown): string {
  return JSON.stringify(value).split('"').join('\\"');
}

function buildCliCommand(meta: { program: string; transition: string; network: Network }, step: unknown): string {
  // Command format is scaffold-level and intentionally generic for now.
  // A follow-up PR should replace this with exact Aleo CLI syntax + argument codec mapping.
  return [
    "aleo",
    "execute",
    `${meta.program}/${meta.transition}`,
    "--network",
    meta.network,
    "--args-json",
    `\"${quoteJson(step)}\"`,
  ].join(" ");
}

export class Layer2CliAdapter implements Layer2Adapter {
  private readonly mode: CliExecutionMode;
  private readonly executor: CliCommandExecutor;

  constructor(mode: CliExecutionMode = "plan_only", executor: CliCommandExecutor = new UnconfiguredCliCommandExecutor()) {
    this.mode = mode;
    this.executor = executor;
  }

  async executePlan(network: Network, plan: Layer2CallPlanStep[]): Promise<Layer2CallPlanResult> {
    const traces: CliStepTrace<Layer2CallPlanStep["kind"], Layer2TxMeta>[] = [];

    for (const [index, step] of plan.entries()) {
      const endpoint = resolveLayer2Endpoint(network, step);
      const command = buildCliCommand(endpoint, step);

      if (this.mode === "execute") {
        const result = await this.executor.run(command);
        traces.push({ index, kind: step.kind, endpoint, command, status: "executed", result });
      } else {
        traces.push({ index, kind: step.kind, endpoint, command, status: "planned" });
      }
    }

    const report: Layer2CliExecutionReport = {
      mode: this.mode,
      steps: traces,
    };

    return report;
  }
}
