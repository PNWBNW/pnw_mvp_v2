import {
  Layer2CliAdapter,
  type CliCommandExecutor,
  type Layer2CliExecutionReport,
} from "../src/adapters/aleo_cli_adapter";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(`ASSERTION FAILED: ${message}`);
  }
}

function bytes32(fill: number): Uint8Array {
  return new Uint8Array(32).fill(fill);
}

async function testRecordEncodingUsesRawPayload(): Promise<void> {
  const adapter = new Layer2CliAdapter("plan_only");

  const wrappedRecord = {
    __record_tag: "PayrollNftRecord",
    raw: "{ owner: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqm3k3f.private, amount: 1u64.private }",
  };

  const report = (await adapter.executePlan("testnet", [
    { kind: "revoke_payroll_nft", nft: wrappedRecord as never },
  ])) as Layer2CliExecutionReport;

  assert(report.steps.length === 1, "expected exactly one step trace");
  const command = report.steps[0].command;
  assert(command.includes("revoke_nft"), "expected revoke transition in generated command");
  assert(command.includes("owner:"), "expected raw Leo record payload in command");
  assert(!command.includes("__record_tag"), "wrapper metadata must not be encoded into command args");
}

async function testRetryOnThrownExecutionError(): Promise<void> {
  let calls = 0;

  const executor: CliCommandExecutor = {
    async run(): Promise<{ exit_code: number; stdout: string; stderr: string }> {
      calls += 1;
      if (calls === 1) {
        throw new Error("temporary timeout from executor");
      }

      return { exit_code: 0, stdout: "ok", stderr: "" };
    },
  };

  const adapter = new Layer2CliAdapter("execute", executor, {
    retry_policy: { max_attempts: 2, retry_delay_ms: 0 },
  });

  const report = (await adapter.executePlan("testnet", [
    { kind: "assert_payroll_nft_exists", nft_id: bytes32(7) },
  ])) as Layer2CliExecutionReport;

  assert(calls === 2, "expected one retry after thrown execution error");
  assert(report.summary.executed_steps === 1, "expected one executed step");
  assert(report.steps[0].attempts === 2, "expected step trace to record retry attempts");
}

async function main(): Promise<void> {
  await testRecordEncodingUsesRawPayload();
  await testRetryOnThrownExecutionError();
  console.log("phase4_adapter.test: PASS");
}

void main();
