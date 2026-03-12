#!/usr/bin/env bash
set -euo pipefail

SCENARIO=""
SCENARIO_FILE=""
BROADCAST_COMMANDS_FILE_ARG=""

usage() {
  echo "Usage: scripts/run_phase4_execute_scenario.sh [--scenario <payroll_smoke|onboarding_smoke|nft_smoke>] [--scenario-file <path>] [--broadcast-commands-file <path>]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario)
      SCENARIO="${2:-}"
      shift 2
      ;;
    --scenario-file)
      SCENARIO_FILE="${2:-}"
      shift 2
      ;;
    --broadcast-commands-file)
      BROADCAST_COMMANDS_FILE_ARG="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$SCENARIO" ]]; then
        SCENARIO="$1"
        shift
      else
        echo "ERROR: unsupported argument '$1'" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$SCENARIO" ]]; then
  SCENARIO="${PHASE4_SCENARIO:-payroll_smoke}"
fi

if [[ -z "$SCENARIO_FILE" ]]; then
  SCENARIO_FILE="${PHASE4_SCENARIO_FILE:-}"
fi

case "$SCENARIO" in
  payroll_smoke|onboarding_smoke|nft_smoke|batch_payroll_smoke)
    ;;
  *)
    echo "ERROR: unsupported scenario '$SCENARIO'" >&2
    usage
    exit 1
    ;;
esac

ARTIFACT_DIR="artifacts/phase4_execute_bundle"
MANIFEST_PATH="${MANIFEST_PATH:-config/testnet.manifest.json}"
NETWORK="${PNW_NETWORK:-testnet}"
ENDPOINT="${ENDPOINT:-}"
EXECUTE_BROADCAST="${EXECUTE_BROADCAST:-false}"
BROADCAST_COMMANDS_FILE="${BROADCAST_COMMANDS_FILE_ARG:-${PHASE4_BROADCAST_COMMANDS_FILE:-}}"

if [[ "$EXECUTE_BROADCAST" != "true" && "$EXECUTE_BROADCAST" != "false" ]]; then
  echo "ERROR: EXECUTE_BROADCAST must be true or false (got: $EXECUTE_BROADCAST)" >&2
  exit 1
fi

mkdir -p "$ARTIFACT_DIR"

python3 scripts/validate_testnet_manifest.py "$MANIFEST_PATH"
scripts/require_phase4_execute_env.sh

SCENARIO_PAYLOAD_ID=""
SCENARIO_PAYLOAD_MODE=""
SCENARIO_PAYLOAD_KIND=""

# Resolved scenario file — may be a substituted temp copy
RESOLVED_SCENARIO_FILE=""

if [[ -n "$SCENARIO_FILE" ]]; then
  if [[ ! -f "$SCENARIO_FILE" ]]; then
    echo "ERROR: scenario file not found: $SCENARIO_FILE" >&2
    exit 1
  fi

  # Substitute address tokens from env into a temp file.
  # ALEO_ADDRESS: employer address (GitHub Variable)
  # WORKER_ADDRESS: single-worker scenarios (GitHub Variable)
  # WORKER1_ADDRESS, WORKER2_ADDRESS, WORKER3_ADDRESS: batch scenarios (GitHub Secrets)
  # Real private keys / view keys must never appear in scenario files.
  RESOLVED_SCENARIO_FILE="$(mktemp /tmp/pnw_scenario_XXXXXX.json)"
  trap 'rm -f "$RESOLVED_SCENARIO_FILE"' EXIT
  ALEO_ADDRESS="${ALEO_ADDRESS:-}" \
  WORKER_ADDRESS="${WORKER_ADDRESS:-}" \
  WORKER1_ADDRESS="${WORKER1_ADDRESS:-}" \
  WORKER2_ADDRESS="${WORKER2_ADDRESS:-}" \
  WORKER3_ADDRESS="${WORKER3_ADDRESS:-}" \
    envsubst '${ALEO_ADDRESS} ${WORKER_ADDRESS} ${WORKER1_ADDRESS} ${WORKER2_ADDRESS} ${WORKER3_ADDRESS}' \
    < "$SCENARIO_FILE" > "$RESOLVED_SCENARIO_FILE"

  python3 scripts/validate_phaseA_scenario.py "$RESOLVED_SCENARIO_FILE"

  SCENARIO_META_RAW="$(python3 - "$RESOLVED_SCENARIO_FILE" "$NETWORK" "$SCENARIO" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
network = sys.argv[2]
scenario = sys.argv[3]
data = json.loads(path.read_text(encoding="utf-8"))

if data.get("network") != network:
    print(f"ERROR: scenario file network '{data.get('network')}' does not match PNW_NETWORK '{network}'", file=sys.stderr)
    raise SystemExit(1)

scenario_kind = data.get("scenario_kind")
expected_kind = {
    "payroll_smoke": "payroll",
    "onboarding_smoke": "onboarding",
    "batch_payroll_smoke": "batch_payroll",
}.get(scenario)
if expected_kind is not None and scenario_kind != expected_kind:
    print(
        f"ERROR: scenario '{scenario}' expects scenario_kind '{expected_kind}' but scenario file has '{scenario_kind}'",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(data.get("scenario_id", ""))
print(data.get("execution_mode", ""))
print(scenario_kind or "")
PY
 )" || exit 1
  IFS=$'\n' read -r -d '' -a SCENARIO_META < <(printf '%s\0' "$SCENARIO_META_RAW")
  SCENARIO_PAYLOAD_ID="${SCENARIO_META[0]:-}"
  SCENARIO_PAYLOAD_MODE="${SCENARIO_META[1]:-}"
  SCENARIO_PAYLOAD_KIND="${SCENARIO_META[2]:-}"
fi

# Pass RESOLVED_SCENARIO_FILE for data reading; SCENARIO_FILE (original path) as the trace label.
_RESOLVED_FOR_PY="${RESOLVED_SCENARIO_FILE:-$SCENARIO_FILE}"
python3 - "$SCENARIO" "$NETWORK" "$MANIFEST_PATH" "$ARTIFACT_DIR" "$_RESOLVED_FOR_PY" "$SCENARIO_PAYLOAD_ID" "$SCENARIO_PAYLOAD_MODE" "$SCENARIO_PAYLOAD_KIND" "$ENDPOINT" "$EXECUTE_BROADCAST" "$BROADCAST_COMMANDS_FILE" "$SCENARIO_FILE" <<'PY'
import json
import sys
import time
import re
import subprocess
import shlex
from pathlib import Path

scenario, network, manifest_path, artifact_dir, scenario_file, scenario_payload_id, scenario_payload_mode, scenario_payload_kind, endpoint, execute_broadcast, broadcast_commands_file, scenario_file_label = sys.argv[1:13]
base = Path(artifact_dir)
base.mkdir(parents=True, exist_ok=True)

scenario_steps = {
    "payroll_smoke": [
        "assert_payroll_nft_exists",
        "get_payroll_nft_status",
        "get_payroll_nft_anchor_height",
    ],
    "onboarding_smoke": [
        "assert_credential_exists",
        "assert_scope_anchored",
        "get_scope_anchor_height",
    ],
    "nft_smoke": [
        "assert_authorization_exists",
        "assert_authorization_active",
        "get_authorization_status",
    ],
    "batch_payroll_smoke": [
        # Tx 1: execute_payroll_batch_2 (workers 1 + 2)
        "assert_agreement_active_worker1",
        "assert_agreement_active_worker2",
        "execute_payroll_batch_2",
        # Tx 2: execute_payroll (worker 3)
        "assert_agreement_active_worker3",
        "execute_payroll_worker3",
    ],
}

now_ms = int(time.time() * 1000)
steps = []
for idx, kind in enumerate(scenario_steps[scenario]):
    steps.append(
        {
            "index": idx,
            "kind": kind,
            "status": "planned",
            "started_at_ms": now_ms,
            "finished_at_ms": now_ms,
            "duration_ms": 0,
            "attempts": 0,
            "tx_id": None,
            "error_code": None,
        }
    )

step_traces = {
    "schema_version": "phase4.step_traces.v1",
    "scenario": scenario,
    "scenario_file": scenario_file_label or None,
    "scenario_payload_id": scenario_payload_id or None,
    "scenario_payload_mode": scenario_payload_mode or None,
    "scenario_payload_kind": scenario_payload_kind or None,
    "network": network,
    "manifest_path": manifest_path,
    "steps": steps,
}

tx_id_entries = []

if execute_broadcast == "true":
    if not broadcast_commands_file:
        raise SystemExit("ERROR: EXECUTE_BROADCAST=true requires PHASE4_BROADCAST_COMMANDS_FILE")

    commands_path = Path(broadcast_commands_file)
    if not commands_path.is_file():
        raise SystemExit(f"ERROR: broadcast commands file not found: {commands_path}")

    payload = json.loads(commands_path.read_text(encoding="utf-8"))
    commands = payload.get("commands")
    if not isinstance(commands, list) or len(commands) == 0:
        raise SystemExit("ERROR: broadcast commands file must contain a non-empty 'commands' list")

    txid_patterns = [
        re.compile(r"transaction\s+id\s*[:=]\s*([A-Za-z0-9_.:-]+)", re.IGNORECASE),
        re.compile(r"\b([a-fA-F0-9]{64})\b"),
    ]

    for i, cmd in enumerate(commands):
        if not isinstance(cmd, dict):
            raise SystemExit("ERROR: each broadcast command entry must be an object")
        name = str(cmd.get("name") or f"command_{i}")
        command = str(cmd.get("command") or "").strip()
        if not command:
            raise SystemExit(f"ERROR: broadcast command missing 'command' at index {i}")
        if "REPLACE_WITH_REAL_SUBMIT_COMMAND" in command or ("<" in command and ">" in command):
            raise SystemExit(
                f"ERROR: broadcast command '{name}' appears to be a placeholder. "
                "Replace template text with a real submit command before running EXECUTE_BROADCAST=true."
            )

        run_kwargs = {"text": True, "capture_output": True}
        if command.startswith("bash -lc "):
            try:
                argv = shlex.split(command)
            except ValueError as exc:
                raise SystemExit(f"ERROR: broadcast command parse failed ({name}): {exc}")
            proc = subprocess.run(argv, **run_kwargs)
        else:
            proc = subprocess.run(command, shell=True, executable="/bin/bash", **run_kwargs)
        if proc.returncode != 0:
            stdout_text = proc.stdout.strip()
            stderr_text = proc.stderr.strip()
            hint = ""
            merged_err = f"{stdout_text}\n{stderr_text}".lower()
            if "failed to parse json error response" in merged_err or "line 1 column 1" in merged_err:
                hint = (
                    " hint=submit endpoint likely returned non-JSON; verify ENDPOINT uses explicit testnet URI "
                    "(e.g. https://api.explorer.provable.com/v1/testnet)"
                )
            raise SystemExit(
                f"ERROR: broadcast command failed ({name}) exit={proc.returncode} "
                f"stdout={stdout_text} stderr={stderr_text}{hint}"
            )

        merged = f"{proc.stdout}\n{proc.stderr}"
        tx_id = None
        for pattern in txid_patterns:
            m = pattern.search(merged)
            if m:
                tx_id = m.group(1)
                break

        tx_id_entries.append(
            {
                "index": i,
                "name": name,
                "command_redacted": True,
                "tx_id": tx_id,
                "stdout": proc.stdout.strip(),
                "stderr": proc.stderr.strip(),
            }
        )

transaction_ids = {
    "schema_version": "phase4.tx_ids.v1",
    "scenario": scenario,
    "scenario_file": scenario_file_label or None,
    "network": network,
    "tx_ids": tx_id_entries,
}

if tx_id_entries:
    for i, entry in enumerate(tx_id_entries):
        if i >= len(steps):
            break
        steps[i]["status"] = "submitted"
        steps[i]["tx_id"] = entry.get("tx_id")

verification_summary = {
    "schema_version": "phase4.verification_summary.v1",
    "scenario": scenario,
    "scenario_file": scenario_file_label or None,
    "network": network,
    "checks": [
        {"name": "manifest_valid", "status": "pass"},
        {"name": "execute_env_valid", "status": "pass"},
        {"name": "scenario_selected", "status": "pass", "value": scenario},
        {
            "name": "endpoint",
            "status": "pass" if endpoint else "skip",
            "value": endpoint or None,
        },
        {
            "name": "execute_broadcast",
            "status": "pass",
            "value": execute_broadcast,
        },
        {
            "name": "broadcast_commands_file",
            "status": "pass" if broadcast_commands_file else ("skip" if execute_broadcast != "true" else "fail"),
            "value": broadcast_commands_file or None,
        },
        {
            "name": "broadcast_submission_count",
            "status": "pass" if (execute_broadcast != "true" or len(tx_id_entries) > 0) else "fail",
            "value": len(tx_id_entries),
        },
        {
            "name": "broadcast_mode",
            "status": "pass",
            "value": "command_driven_submission" if execute_broadcast == "true" else "simulated_no_onchain_broadcast",
        },
        {
            "name": "explorer_lookup_expected",
            "status": "skip",
            "value": "transaction ids may be present from command outputs" if execute_broadcast == "true" else "no_tx_ids_emitted_in_current_execute_scaffold",
        },
        {
            "name": "scenario_file_valid",
            "status": "pass" if scenario_file_label else "skip",
            "value": scenario_file_label or None,
        },
    ],
}

(base / "step_traces.json").write_text(json.dumps(step_traces, indent=2) + "\n", encoding="utf-8")
(base / "tx_ids.json").write_text(json.dumps(transaction_ids, indent=2) + "\n", encoding="utf-8")
(base / "verification_summary.json").write_text(json.dumps(verification_summary, indent=2) + "\n", encoding="utf-8")
PY

{
  echo '{'
  echo '  "schema_version": "phase4.execute_bundle_manifest.v1",'
  echo "  \"scenario\": \"${SCENARIO}\"," 
  echo "  \"scenario_file\": \"${SCENARIO_FILE}\"," 
  echo "  \"scenario_payload_id\": \"${SCENARIO_PAYLOAD_ID}\"," 
  echo "  \"scenario_payload_mode\": \"${SCENARIO_PAYLOAD_MODE}\"," 
  echo "  \"scenario_payload_kind\": \"${SCENARIO_PAYLOAD_KIND}\"," 
  echo "  \"network\": \"${NETWORK}\"," 
  echo '  "files": ['
  first=1
  for file in step_traces.json tx_ids.json verification_summary.json; do
    sha=$(sha256sum "$ARTIFACT_DIR/$file" | awk '{print $1}')
    if [[ "$first" -eq 0 ]]; then
      echo '    ,'
    fi
    first=0
    echo '    {'
    echo "      \"name\": \"$file\"," 
    echo "      \"sha256\": \"$sha\""
    echo '    }'
  done
  echo '  ]'
  echo '}'
} > "$ARTIFACT_DIR/bundle_manifest.json"

if [[ "$EXECUTE_BROADCAST" == "true" ]]; then
  echo "WARN: EXECUTE_BROADCAST=true requested; using PHASE4_BROADCAST_COMMANDS_FILE-driven submission path." >&2
fi

echo "Generated execute evidence bundle in $ARTIFACT_DIR for scenario '$SCENARIO'."
