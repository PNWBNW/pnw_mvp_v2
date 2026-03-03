#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: scripts/run_phase4_testnet_happy_path.sh [--scenario <payroll_smoke|onboarding_smoke|nft_smoke>] [--scenario-file <path>] [--execute-broadcast <true|false>]

Runs a reproducible Phase 4 testnet happy-path sequence:
  1) validate testnet manifest
  2) enforce execute env requirements
  3) run execute scenario
  4) print compact summary from emitted artifacts
USAGE
}

SCENARIO="payroll_smoke"
SCENARIO_FILE=""
EXECUTE_BROADCAST="false"

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
    --execute-broadcast)
      EXECUTE_BROADCAST="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unsupported argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

case "$SCENARIO" in
  payroll_smoke|onboarding_smoke|nft_smoke) ;;
  *)
    echo "ERROR: unsupported scenario '$SCENARIO'" >&2
    exit 1
    ;;
esac

if [[ "$EXECUTE_BROADCAST" != "true" && "$EXECUTE_BROADCAST" != "false" ]]; then
  echo "ERROR: --execute-broadcast must be true or false" >&2
  exit 1
fi

MANIFEST_PATH="${MANIFEST_PATH:-config/testnet.manifest.json}"

python3 scripts/validate_testnet_manifest.py "$MANIFEST_PATH"
scripts/require_phase4_execute_env.sh

if [[ -n "$SCENARIO_FILE" ]]; then
  EXECUTE_BROADCAST="$EXECUTE_BROADCAST" scripts/run_phase4_execute_scenario.sh --scenario "$SCENARIO" --scenario-file "$SCENARIO_FILE"
else
  EXECUTE_BROADCAST="$EXECUTE_BROADCAST" scripts/run_phase4_execute_scenario.sh --scenario "$SCENARIO"
fi

python3 - <<'PY'
import json
from pathlib import Path

base = Path("artifacts/phase4_execute_bundle")
summary = json.loads((base / "verification_summary.json").read_text(encoding="utf-8"))
txids = json.loads((base / "tx_ids.json").read_text(encoding="utf-8"))
manifest = json.loads((base / "bundle_manifest.json").read_text(encoding="utf-8"))

checks = {c.get("name"): c for c in summary.get("checks", [])}
print("phase4 happy-path summary:")
print(f"- scenario: {summary.get('scenario')}")
print(f"- network: {summary.get('network')}")
print(f"- execute_broadcast: {checks.get('execute_broadcast', {}).get('value')}")
print(f"- broadcast_mode: {checks.get('broadcast_mode', {}).get('value')}")
print(f"- tx_id_count: {len(txids.get('tx_ids', []))}")
print(f"- artifact_files: {', '.join(f['name'] for f in manifest.get('files', []))}")
PY
