import {
  Layer2CliAdapter,
  Layer2CliExecutionError,
  type CliCommandExecutor,
  type Layer2CliExecutionReport,
} from "../src/adapters/aleo_cli_adapter";
import type { Layer2CallPlanStep } from "../src/router/layer2_router";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(`ASSERTION FAILED: ${message}`);
  }
}

function bytes32(fill: number): Uint8Array {
  return new Uint8Array(32).fill(fill);
}

function payrollRecord(amount = 1): { raw: string } {
  return {
    raw: `{ owner: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqm3k3f.private, amount: ${amount}u64.private }`,
  };
}

function authorizationRecord(): { raw: string } {
  return {
    raw: "{ owner: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqm3k3f.private, auth_id: [1u8; 32].private }",
  };
}

function credentialRecord(): { raw: string } {
  return {
    raw: "{ owner: aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqm3k3f.private, credential_id: [2u8; 32].private }",
  };
}

function buildCoveragePlan(): Layer2CallPlanStep[] {
  return [
    {
      kind: "mint_cycle_nft",
      args: {
        nft_id: bytes32(1),
        agreement_id: bytes32(2),
        period_start: 1,
        period_end: 2,
        doc_hash: bytes32(3),
        root: bytes32(4),
        inputs_hash: bytes32(5),
        schema_v: 1,
        calc_v: 1,
        policy_v: 1,
      },
    },
    {
      kind: "mint_quarter_nft",
      args: {
        nft_id: bytes32(6),
        agreement_id: bytes32(7),
        period_start: 1,
        period_end: 2,
        doc_hash: bytes32(8),
        root: bytes32(9),
        inputs_hash: bytes32(10),
        schema_v: 1,
        calc_v: 1,
        policy_v: 1,
      },
    },
    {
      kind: "mint_ytd_nft",
      args: {
        nft_id: bytes32(11),
        agreement_id: bytes32(12),
        period_start: 1,
        period_end: 2,
        doc_hash: bytes32(13),
        root: bytes32(14),
        inputs_hash: bytes32(15),
        schema_v: 1,
        calc_v: 1,
        policy_v: 1,
      },
    },
    {
      kind: "mint_eoy_nft",
      args: {
        nft_id: bytes32(16),
        agreement_id: bytes32(17),
        period_start: 1,
        period_end: 2,
        doc_hash: bytes32(18),
        root: bytes32(19),
        inputs_hash: bytes32(20),
        schema_v: 1,
        calc_v: 1,
        policy_v: 1,
      },
    },
    { kind: "revoke_payroll_nft", nft: payrollRecord(1) as never },
    { kind: "mark_payroll_nft_superseded", old_nft: payrollRecord(2) as never, new_nft_id: bytes32(21) },
    { kind: "assert_payroll_nft_exists", nft_id: bytes32(22) },
    { kind: "get_payroll_nft_anchor_height", nft_id: bytes32(23) },
    { kind: "get_payroll_nft_status", nft_id: bytes32(24) },
    { kind: "get_payroll_nft_superseded_by", nft_id: bytes32(25) },

    {
      kind: "mint_credential_nft",
      args: {
        credential_id: bytes32(26),
        subject_hash: bytes32(27),
        issuer_hash: bytes32(28),
        scope_hash: bytes32(29),
        doc_hash: bytes32(30),
        root: bytes32(31),
        schema_v: 1,
        policy_v: 1,
      },
    },
    { kind: "revoke_credential_nft", nft: credentialRecord() as never },
    { kind: "assert_credential_exists", credential_id: bytes32(32) },
    { kind: "get_credential_anchor_height", credential_id: bytes32(33) },
    { kind: "get_credential_status", credential_id: bytes32(34) },
    { kind: "get_credential_revoked_height", credential_id: bytes32(35) },
    { kind: "assert_scope_anchored", scope_hash: bytes32(36) },
    { kind: "get_scope_anchor_height", scope_hash: bytes32(37) },

    {
      kind: "mint_authorization_nft",
      args: {
        auth_id: bytes32(38),
        scope_hash: bytes32(39),
        authorization_event_hash: bytes32(40),
        policy_hash: bytes32(41),
        issued_epoch: 10,
        expires_epoch: 20,
        schema_v: 1,
        policy_v: 1,
      },
    },
    { kind: "revoke_authorization_nft", nft: authorizationRecord() as never },
    { kind: "mark_authorization_expired", auth_id: bytes32(42), current_epoch: 11 },
    { kind: "anchor_audit_attestation", auth_id: bytes32(43), attestation_hash: bytes32(44), current_epoch: 12 },
    { kind: "assert_authorization_exists", auth_id: bytes32(45) },
    { kind: "assert_authorization_active", auth_id: bytes32(46), current_epoch: 13 },
    { kind: "get_authorization_anchor_height", auth_id: bytes32(47) },
    { kind: "get_authorization_status", auth_id: bytes32(48) },
    { kind: "get_authorization_expiry", auth_id: bytes32(49) },
    { kind: "get_authorization_revoked_height", auth_id: bytes32(50) },
    { kind: "assert_attestation_anchored", attestation_hash: bytes32(51) },
    { kind: "get_attestation_anchor_height", attestation_hash: bytes32(52) },
    { kind: "get_attestation_authorization", attestation_hash: bytes32(53) },
  ];
}

async function testAllStepKindsBuildCommands(): Promise<void> {
  const adapter = new Layer2CliAdapter("plan_only");
  const plan = buildCoveragePlan();
  const report = (await adapter.executePlan("testnet", plan)) as Layer2CliExecutionReport;

  assert(report.steps.length === plan.length, "expected one trace per plan step");
  for (const step of report.steps) {
    assert(step.command.includes("snarkos developer execute"), `expected command prefix for ${step.kind}`);
    assert(step.command.includes(" --endpoint "), `expected endpoint flag for ${step.kind}`);
    assert(step.command.includes(" --broadcast"), `expected broadcast flag for ${step.kind}`);
    assert(!step.command.includes("--query"), `query flag must not be present for ${step.kind}`);
    assert(step.endpoint.program.endsWith(".aleo"), `expected aleo program for ${step.kind}`);
    assert(step.endpoint.transition.length > 0, `expected transition for ${step.kind}`);
  }
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
    private_key: "APrivateKey1zkpDummyTestKeyForRetryTest000000000000000000",
    node_url: "https://api.explorer.provable.com/v2/testnet",
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
    private_key: "APrivateKey1zkpDummyTestKeyForExecuteErrorTest0000000000",
    node_url: "https://api.explorer.provable.com/v2/testnet",
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
  await testAllStepKindsBuildCommands();
  await testRecordEncodingUsesRawPayload();
  await testDeterministicCommandCodecAcrossStepKinds();
  await testRetryOnThrownExecutionError();
  await testExecuteFailureRaisesTypedExecutionError();
  console.log("phase4_adapter.test: PASS");
}

void main();
