#!/usr/bin/env bash
set -euo pipefail

SCENARIO="${1:-}"
if [[ -z "$SCENARIO" ]]; then
  echo "ERROR: scenario argument is required" >&2
  echo "Usage: scripts/run_phase4_execute_scenario.sh <payroll_smoke|onboarding_smoke|nft_smoke>" >&2
  exit 1
fi

case "$SCENARIO" in
  payroll_smoke|onboarding_smoke|nft_smoke)
    ;;
  *)
    echo "ERROR: unsupported scenario '$SCENARIO'" >&2
    exit 1
    ;;
esac

ARTIFACT_DIR="artifacts/phase4_execute_bundle"
MANIFEST_PATH="${MANIFEST_PATH:-config/testnet.manifest.json}"
NETWORK="${PNW_NETWORK:-testnet}"

mkdir -p "$ARTIFACT_DIR"

python3 scripts/validate_testnet_manifest.py "$MANIFEST_PATH"
scripts/require_phase4_execute_env.sh

python3 - "$SCENARIO" "$NETWORK" "$MANIFEST_PATH" "$ARTIFACT_DIR" <<'PY'
import json
import sys
import time
from pathlib import Path

scenario, network, manifest_path, artifact_dir = sys.argv[1:5]
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
    "network": network,
    "manifest_path": manifest_path,
    "steps": steps,
}

transaction_ids = {
    "schema_version": "phase4.tx_ids.v1",
    "scenario": scenario,
    "network": network,
    "tx_ids": [],
}

verification_summary = {
    "schema_version": "phase4.verification_summary.v1",
    "scenario": scenario,
    "network": network,
    "checks": [
        {"name": "manifest_valid", "status": "pass"},
        {"name": "execute_env_valid", "status": "pass"},
        {"name": "scenario_selected", "status": "pass", "value": scenario},
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
