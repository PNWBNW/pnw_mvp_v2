// portal/src/adapters/aleo_cli_adapter.ts
//
// Phase 4 implementation (PR A start):
// - Deterministic Layer 2 step.kind -> endpoint + arg codec command generation.
// - Typed adapter error taxonomy.
// - Structured execution traces for plan-only and execute modes.

import type { Network } from "../config/env";
import { assertU16, assertU32 } from "../types/aleo_types";
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

export class Layer2CliAdapterError extends Error {
  readonly category: "input" | "execution" | "invariant";
  readonly step_index: number;
  readonly step_kind: Layer2CallPlanStep["kind"];

  constructor(
    message: string,
    category: "input" | "execution" | "invariant",
    step_index: number,
    step_kind: Layer2CallPlanStep["kind"],
    options?: { cause?: unknown },
  ) {
    super(message);
    if (options?.cause !== undefined) {
      (this as Error & { cause?: unknown }).cause = options.cause;
    }
    this.name = "Layer2CliAdapterError";
    this.category = category;
    this.step_index = step_index;
    this.step_kind = step_kind;
  }
}

export class Layer2CliInputError extends Layer2CliAdapterError {
  constructor(message: string, step_index: number, step_kind: Layer2CallPlanStep["kind"], options?: { cause?: unknown }) {
    super(message, "input", step_index, step_kind, options);
    this.name = "Layer2CliInputError";
  }
}

export class Layer2CliExecutionError extends Layer2CliAdapterError {
  readonly command: string;
  readonly stderr?: string;

  constructor(
    message: string,
    step_index: number,
    step_kind: Layer2CallPlanStep["kind"],
    command: string,
    stderr?: string,
    options?: { cause?: unknown },
  ) {
    super(message, "execution", step_index, step_kind, options);
    this.name = "Layer2CliExecutionError";
    this.command = command;
    this.stderr = stderr;
  }
}

export class Layer2CliInvariantError extends Layer2CliAdapterError {
  constructor(message: string, step_index: number, step_kind: Layer2CallPlanStep["kind"], options?: { cause?: unknown }) {
    super(message, "invariant", step_index, step_kind, options);
    this.name = "Layer2CliInvariantError";
  }
}

export type CliStepTrace<TKind extends string, TMeta> = {
  index: number;
  kind: TKind;
  endpoint: TMeta;
  command: string;
  status: "planned" | "executed" | "failed";
  started_at_ms: number;
  finished_at_ms: number;
  duration_ms: number;
  result?: CliCommandResult;
  error?: {
    category: "input" | "execution" | "invariant";
    message: string;
  };
};

export type Layer2CliExecutionReport = {
  mode: CliExecutionMode;
  steps: CliStepTrace<Layer2CallPlanStep["kind"], Layer2TxMeta>[];
  summary: {
    total_steps: number;
    executed_steps: number;
    planned_steps: number;
    failed_steps: number;
  };
};

type StepCodec = (step: Layer2CallPlanStep) => string[];

function encodeBytes32(value: Uint8Array, label: string): string {
  if (value.length !== 32) {
    throw new Error(`${label} must be 32 bytes, got ${value.length}`);
  }

  const hex = Array.from(value, (byte) => byte.toString(16).padStart(2, "0")).join("");
  return `0x${hex}`;
}

function encodeU16(value: number, label: string): string {
  assertU16(value, label);
  return `${value}u16`;
}

function encodeU32(value: number, label: string): string {
  assertU32(value, label);
  return `${value}u32`;
}

function encodeRecord(value: unknown): string {
  return JSON.stringify(value);
}

function shellQuote(arg: string): string {
  return `'${arg.replace(/'/g, `'"'"'`)}'`;
}

function expectKind<TKind extends Layer2CallPlanStep["kind"]>(
  step: Layer2CallPlanStep,
  kind: TKind,
): Extract<Layer2CallPlanStep, { kind: TKind }> {
  if (step.kind !== kind) {
    throw new Error(`codec mismatch: expected ${kind}, got ${step.kind}`);
  }

  return step as Extract<Layer2CallPlanStep, { kind: TKind }>;
}

const STEP_CODEC_MAP: Record<Layer2CallPlanStep["kind"], StepCodec> = {
  mint_cycle_nft: (step) => {
    const s = expectKind(step, "mint_cycle_nft");
    return [
      encodeBytes32(s.args.nft_id, "nft_id"),
      encodeBytes32(s.args.agreement_id, "agreement_id"),
      encodeU32(s.args.period_start, "period_start"),
      encodeU32(s.args.period_end, "period_end"),
      encodeBytes32(s.args.doc_hash, "doc_hash"),
      encodeBytes32(s.args.root, "root"),
      encodeBytes32(s.args.inputs_hash, "inputs_hash"),
      encodeU16(s.args.schema_v, "schema_v"),
      encodeU16(s.args.calc_v, "calc_v"),
      encodeU16(s.args.policy_v, "policy_v"),
    ];
  },
  mint_quarter_nft: (step) => {
    const s = expectKind(step, "mint_quarter_nft");
    return [
      encodeBytes32(s.args.nft_id, "nft_id"),
      encodeBytes32(s.args.agreement_id, "agreement_id"),
      encodeU32(s.args.period_start, "period_start"),
      encodeU32(s.args.period_end, "period_end"),
      encodeBytes32(s.args.doc_hash, "doc_hash"),
      encodeBytes32(s.args.root, "root"),
      encodeBytes32(s.args.inputs_hash, "inputs_hash"),
      encodeU16(s.args.schema_v, "schema_v"),
      encodeU16(s.args.calc_v, "calc_v"),
      encodeU16(s.args.policy_v, "policy_v"),
    ];
  },
  mint_ytd_nft: (step) => {
    const s = expectKind(step, "mint_ytd_nft");
    return [
      encodeBytes32(s.args.nft_id, "nft_id"),
      encodeBytes32(s.args.agreement_id, "agreement_id"),
      encodeU32(s.args.period_start, "period_start"),
      encodeU32(s.args.period_end, "period_end"),
      encodeBytes32(s.args.doc_hash, "doc_hash"),
      encodeBytes32(s.args.root, "root"),
      encodeBytes32(s.args.inputs_hash, "inputs_hash"),
      encodeU16(s.args.schema_v, "schema_v"),
      encodeU16(s.args.calc_v, "calc_v"),
      encodeU16(s.args.policy_v, "policy_v"),
    ];
  },
  mint_eoy_nft: (step) => {
    const s = expectKind(step, "mint_eoy_nft");
    return [
      encodeBytes32(s.args.nft_id, "nft_id"),
      encodeBytes32(s.args.agreement_id, "agreement_id"),
      encodeU32(s.args.period_start, "period_start"),
      encodeU32(s.args.period_end, "period_end"),
      encodeBytes32(s.args.doc_hash, "doc_hash"),
      encodeBytes32(s.args.root, "root"),
      encodeBytes32(s.args.inputs_hash, "inputs_hash"),
      encodeU16(s.args.schema_v, "schema_v"),
      encodeU16(s.args.calc_v, "calc_v"),
      encodeU16(s.args.policy_v, "policy_v"),
    ];
  },
  revoke_payroll_nft: (step) => {
    const s = expectKind(step, "revoke_payroll_nft");
    return [encodeRecord(s.nft)];
  },
  mark_payroll_nft_superseded: (step) => {
    const s = expectKind(step, "mark_payroll_nft_superseded");
    return [encodeRecord(s.old_nft), encodeBytes32(s.new_nft_id, "new_nft_id")];
  },
  assert_payroll_nft_exists: (step) => {
    const s = expectKind(step, "assert_payroll_nft_exists");
    return [encodeBytes32(s.nft_id, "nft_id")];
  },
  get_payroll_nft_anchor_height: (step) => {
    const s = expectKind(step, "get_payroll_nft_anchor_height");
    return [encodeBytes32(s.nft_id, "nft_id")];
  },
  get_payroll_nft_status: (step) => {
    const s = expectKind(step, "get_payroll_nft_status");
    return [encodeBytes32(s.nft_id, "nft_id")];
  },
  get_payroll_nft_superseded_by: (step) => {
    const s = expectKind(step, "get_payroll_nft_superseded_by");
    return [encodeBytes32(s.nft_id, "nft_id")];
  },
  mint_credential_nft: (step) => {
    const s = expectKind(step, "mint_credential_nft");
    return [
      encodeBytes32(s.args.credential_id, "credential_id"),
      encodeBytes32(s.args.subject_hash, "subject_hash"),
      encodeBytes32(s.args.issuer_hash, "issuer_hash"),
      encodeBytes32(s.args.scope_hash, "scope_hash"),
      encodeBytes32(s.args.doc_hash, "doc_hash"),
      encodeBytes32(s.args.root, "root"),
      encodeU16(s.args.schema_v, "schema_v"),
      encodeU16(s.args.policy_v, "policy_v"),
    ];
  },
  revoke_credential_nft: (step) => {
    const s = expectKind(step, "revoke_credential_nft");
    return [encodeRecord(s.nft)];
  },
  assert_credential_exists: (step) => {
    const s = expectKind(step, "assert_credential_exists");
    return [encodeBytes32(s.credential_id, "credential_id")];
  },
  get_credential_anchor_height: (step) => {
    const s = expectKind(step, "get_credential_anchor_height");
    return [encodeBytes32(s.credential_id, "credential_id")];
  },
  get_credential_status: (step) => {
    const s = expectKind(step, "get_credential_status");
    return [encodeBytes32(s.credential_id, "credential_id")];
  },
  get_credential_revoked_height: (step) => {
    const s = expectKind(step, "get_credential_revoked_height");
    return [encodeBytes32(s.credential_id, "credential_id")];
  },
  assert_scope_anchored: (step) => {
    const s = expectKind(step, "assert_scope_anchored");
    return [encodeBytes32(s.scope_hash, "scope_hash")];
  },
  get_scope_anchor_height: (step) => {
    const s = expectKind(step, "get_scope_anchor_height");
    return [encodeBytes32(s.scope_hash, "scope_hash")];
  },
  mint_authorization_nft: (step) => {
    const s = expectKind(step, "mint_authorization_nft");
    return [
      encodeBytes32(s.args.auth_id, "auth_id"),
      encodeBytes32(s.args.scope_hash, "scope_hash"),
      encodeBytes32(s.args.authorization_event_hash, "authorization_event_hash"),
      encodeBytes32(s.args.policy_hash, "policy_hash"),
      encodeU32(s.args.issued_epoch, "issued_epoch"),
      encodeU32(s.args.expires_epoch, "expires_epoch"),
      encodeU16(s.args.schema_v, "schema_v"),
      encodeU16(s.args.policy_v, "policy_v"),
    ];
  },
  revoke_authorization_nft: (step) => {
    const s = expectKind(step, "revoke_authorization_nft");
    return [encodeRecord(s.nft)];
  },
  mark_authorization_expired: (step) => {
    const s = expectKind(step, "mark_authorization_expired");
    return [encodeBytes32(s.auth_id, "auth_id"), encodeU32(s.current_epoch, "current_epoch")];
  },
  anchor_audit_attestation: (step) => {
    const s = expectKind(step, "anchor_audit_attestation");
    return [
      encodeBytes32(s.auth_id, "auth_id"),
      encodeBytes32(s.attestation_hash, "attestation_hash"),
      encodeU32(s.current_epoch, "current_epoch"),
    ];
  },
  assert_authorization_exists: (step) => {
    const s = expectKind(step, "assert_authorization_exists");
    return [encodeBytes32(s.auth_id, "auth_id")];
  },
  assert_authorization_active: (step) => {
    const s = expectKind(step, "assert_authorization_active");
    return [encodeBytes32(s.auth_id, "auth_id"), encodeU32(s.current_epoch, "current_epoch")];
  },
  get_authorization_anchor_height: (step) => {
    const s = expectKind(step, "get_authorization_anchor_height");
    return [encodeBytes32(s.auth_id, "auth_id")];
  },
  get_authorization_status: (step) => {
    const s = expectKind(step, "get_authorization_status");
    return [encodeBytes32(s.auth_id, "auth_id")];
  },
  get_authorization_expiry: (step) => {
    const s = expectKind(step, "get_authorization_expiry");
    return [encodeBytes32(s.auth_id, "auth_id")];
  },
  get_authorization_revoked_height: (step) => {
    const s = expectKind(step, "get_authorization_revoked_height");
    return [encodeBytes32(s.auth_id, "auth_id")];
  },
  assert_attestation_anchored: (step) => {
    const s = expectKind(step, "assert_attestation_anchored");
    return [encodeBytes32(s.attestation_hash, "attestation_hash")];
  },
  get_attestation_anchor_height: (step) => {
    const s = expectKind(step, "get_attestation_anchor_height");
    return [encodeBytes32(s.attestation_hash, "attestation_hash")];
  },
  get_attestation_authorization: (step) => {
    const s = expectKind(step, "get_attestation_authorization");
    return [encodeBytes32(s.attestation_hash, "attestation_hash")];
  },
};

function buildCliCommand(meta: Layer2TxMeta, step: Layer2CallPlanStep): string {
  const codec = STEP_CODEC_MAP[step.kind];
  const encoded_args = codec(step).map(shellQuote);

  // Deterministic command assembly: aleo execute <program>/<transition> <args...> --network <network>
  return [
    "aleo",
    "execute",
    `${meta.program}/${meta.transition}`,
    ...encoded_args,
    "--network",
    meta.network,
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
      const started_at_ms = Date.now();
      const endpoint = resolveLayer2Endpoint(network, step);

      let command = "";

      try {
        command = buildCliCommand(endpoint, step);

        if (this.mode === "execute") {
          const result = await this.executor.run(command);

          if (result.exit_code !== 0) {
            throw new Layer2CliExecutionError(
              `CLI command failed with exit code ${result.exit_code}`,
              index,
              step.kind,
              command,
              result.stderr,
            );
          }

          const finished_at_ms = Date.now();
          traces.push({
            index,
            kind: step.kind,
            endpoint,
            command,
            status: "executed",
            started_at_ms,
            finished_at_ms,
            duration_ms: finished_at_ms - started_at_ms,
            result,
          });
        } else {
          const finished_at_ms = Date.now();
          traces.push({
            index,
            kind: step.kind,
            endpoint,
            command,
            status: "planned",
            started_at_ms,
            finished_at_ms,
            duration_ms: finished_at_ms - started_at_ms,
          });
        }
      } catch (error) {
        const finished_at_ms = Date.now();

        const normalized_error =
          error instanceof Layer2CliAdapterError
            ? error
            : error instanceof Error
              ? new Layer2CliInputError(error.message, index, step.kind, { cause: error })
              : new Layer2CliInvariantError("Unknown adapter failure", index, step.kind, { cause: error });

        traces.push({
          index,
          kind: step.kind,
          endpoint,
          command,
          status: "failed",
          started_at_ms,
          finished_at_ms,
          duration_ms: finished_at_ms - started_at_ms,
          error: {
            category: normalized_error.category,
            message: normalized_error.message,
          },
        });

        throw normalized_error;
      }
    }

    const report: Layer2CliExecutionReport = {
      mode: this.mode,
      steps: traces,
      summary: {
        total_steps: traces.length,
        executed_steps: traces.filter((step) => step.status === "executed").length,
        planned_steps: traces.filter((step) => step.status === "planned").length,
        failed_steps: traces.filter((step) => step.status === "failed").length,
      },
    };

    return report;
  }
}
