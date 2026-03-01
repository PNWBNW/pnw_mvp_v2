import {
  Layer2CliAdapter,
  Layer2CliExecutionError,
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

async function testDeterministicCommandCodecAcrossStepKinds(): Promise<void> {
  const adapter = new Layer2CliAdapter("plan_only");
  const report = (await adapter.executePlan("testnet", [
    {
      kind: "mint_authorization_nft",
      args: {
        auth_id: bytes32(1),
        scope_hash: bytes32(2),
        authorization_event_hash: bytes32(3),
        policy_hash: bytes32(4),
        issued_epoch: 100,
        expires_epoch: 200,
        schema_v: 1,
        policy_v: 2,
      },
    },
    {
      kind: "mark_payroll_nft_superseded",
      old_nft: {
        raw: "{ owner: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqm3k3f.private, amount: 99u64.private }",
      } as never,
      new_nft_id: bytes32(5),
    },
    { kind: "get_credential_status", credential_id: bytes32(6) },
  ])) as Layer2CliExecutionReport;

  assert(report.steps.length === 3, "expected three step traces");

  const [mintAuth, supersede, credentialStatus] = report.steps;

  assert(mintAuth.endpoint.program === "audit_nft.aleo", "mint_authorization_nft should resolve to audit_nft.aleo");
  assert(mintAuth.command.includes("mint_authorization_nft"), "expected mint_authorization_nft transition in command");
  assert(mintAuth.command.includes("100u32"), "expected issued_epoch encoded as u32");
  assert(mintAuth.command.includes("1u16") && mintAuth.command.includes("2u16"), "expected schema/policy encoded as u16");

  assert(supersede.endpoint.transition === "mark_superseded", "expected mark_payroll_nft_superseded transition mapping");
  assert(supersede.command.includes("mark_superseded"), "expected mark_superseded transition in command");
  assert(supersede.command.includes("amount: 99u64.private"), "expected record raw payload in supersede command");

  assert(credentialStatus.endpoint.program === "credential_nft.aleo", "expected credential endpoint program");
  assert(credentialStatus.endpoint.transition === "get_credential_status", "expected credential status transition mapping");
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

async function testExecuteFailureRaisesTypedExecutionError(): Promise<void> {
  const executor: CliCommandExecutor = {
    async run(): Promise<{ exit_code: number; stdout: string; stderr: string }> {
      return { exit_code: 1, stdout: "", stderr: "transaction rejected" };
    },
  };

  const adapter = new Layer2CliAdapter("execute", executor, {
    retry_policy: { max_attempts: 1, retry_delay_ms: 0 },
  });

  let caught: unknown;
  try {
    await adapter.executePlan("testnet", [{ kind: "get_authorization_status", auth_id: bytes32(8) }]);
  } catch (error) {
    caught = error;
  }

  assert(caught instanceof Layer2CliExecutionError, "expected typed Layer2CliExecutionError on non-zero exit");
  assert((caught as Layer2CliExecutionError).stderr?.includes("transaction rejected"), "expected stderr in typed execution error");
}

async function main(): Promise<void> {
  await testRecordEncodingUsesRawPayload();
  await testDeterministicCommandCodecAcrossStepKinds();
  await testRetryOnThrownExecutionError();
  await testExecuteFailureRaisesTypedExecutionError();
  console.log("phase4_adapter.test: PASS");
}

void main();
