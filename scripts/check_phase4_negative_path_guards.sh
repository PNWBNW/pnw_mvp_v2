#!/usr/bin/env bash
set -euo pipefail

# Intentional negative-path check: onboarding scenario must reject payroll scenario file.
# This prevents false-pass regressions in execute scenario guard logic.

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# provide minimal required execute env contract for local validation path
export ALEO_PRIVATE_KEY="dummy"
export ALEO_VIEW_KEY="dummy"
export ALEO_ADDRESS="aleo1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqs3ljyz"
export RPC_URL="https://api.provable.com/v2/testnet"
export SNARKOS_ENDPOINT="https://api.explorer.provable.com/v2/testnet"
export USDCX_PROGRAM_ID="test_usdcx_stablecoin.aleo"
export MANIFEST_PATH="config/testnet.manifest.json"
export PNW_NETWORK="testnet"
export EXECUTE_BROADCAST="false"

set +e
scripts/run_phase4_execute_scenario.sh \
  --scenario onboarding_smoke \
  --scenario-file config/scenarios/testnet/min_spend.payroll.json \
  >"$TMP_DIR/stdout.log" 2>"$TMP_DIR/stderr.log"
exit_code=$?
set -e

if [[ "$exit_code" -eq 0 ]]; then
  echo "negative-path guard: FAIL - mismatch scenario/file unexpectedly succeeded" >&2
  cat "$TMP_DIR/stdout.log" >&2
  cat "$TMP_DIR/stderr.log" >&2
  exit 1
fi

if ! grep -q "expects scenario_kind 'onboarding'" "$TMP_DIR/stderr.log"; then
  echo "negative-path guard: FAIL - expected mismatch error text not found" >&2
  cat "$TMP_DIR/stderr.log" >&2
  exit 1
fi

echo "negative-path guard: PASS - onboarding/payroll mismatch rejected as expected"
