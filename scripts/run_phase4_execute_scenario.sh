#!/usr/bin/env bash
set -euo pipefail

SCENARIO=""
SCENARIO_FILE=""

usage() {
  echo "Usage: scripts/run_phase4_execute_scenario.sh [--scenario <payroll_smoke|onboarding_smoke|nft_smoke>] [--scenario-file <path>]" >&2
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
  payroll_smoke|onboarding_smoke|nft_smoke)
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

mkdir -p "$ARTIFACT_DIR"

python3 scripts/validate_testnet_manifest.py "$MANIFEST_PATH"
scripts/require_phase4_execute_env.sh

SCENARIO_PAYLOAD_ID=""
SCENARIO_PAYLOAD_MODE=""
if [[ -n "$SCENARIO_FILE" ]]; then
  if [[ ! -f "$SCENARIO_FILE" ]]; then
    echo "ERROR: scenario file not found: $SCENARIO_FILE" >&2
    exit 1
  fi

  python3 scripts/validate_phaseA_scenario.py "$SCENARIO_FILE"

  readarray -t SCENARIO_META < <(python3 - "$SCENARIO_FILE" "$NETWORK" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
network = sys.argv[2]
data = json.loads(path.read_text(encoding="utf-8"))

if data.get("network") != network:
    print(f"ERROR: scenario file network '{data.get('network')}' does not match PNW_NETWORK '{network}'", file=sys.stderr)
    raise SystemExit(1)

print(data.get("scenario_id", ""))
print(data.get("execution_mode", ""))
PY
)
  SCENARIO_PAYLOAD_ID="${SCENARIO_META[0]:-}"
  SCENARIO_PAYLOAD_MODE="${SCENARIO_META[1]:-}"
fi

python3 - "$SCENARIO" "$NETWORK" "$MANIFEST_PATH" "$ARTIFACT_DIR" "$SCENARIO_FILE" "$SCENARIO_PAYLOAD_ID" "$SCENARIO_PAYLOAD_MODE" <<'PY'
import json
import sys
import time
from pathlib import Path

scenario, network, manifest_path, artifact_dir, scenario_file, scenario_payload_id, scenario_payload_mode = sys.argv[1:8]
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
    "scenario_file": scenario_file or None,
    "scenario_payload_id": scenario_payload_id or None,
    "scenario_payload_mode": scenario_payload_mode or None,
    "network": network,
    "manifest_path": manifest_path,
    "steps": steps,
}

transaction_ids = {
    "schema_version": "phase4.tx_ids.v1",
    "scenario": scenario,
    "scenario_file": scenario_file or None,
    "network": network,
    "tx_ids": [],
}

verification_summary = {
    "schema_version": "phase4.verification_summary.v1",
    "scenario": scenario,
    "scenario_file": scenario_file or None,
    "network": network,
    "checks": [
        {"name": "manifest_valid", "status": "pass"},
        {"name": "execute_env_valid", "status": "pass"},
        {"name": "scenario_selected", "status": "pass", "value": scenario},
        {
            "name": "scenario_file_valid",
            "status": "pass" if scenario_file else "skip",
            "value": scenario_file or None,
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

echo "Generated execute evidence bundle in $ARTIFACT_DIR for scenario '$SCENARIO'."
