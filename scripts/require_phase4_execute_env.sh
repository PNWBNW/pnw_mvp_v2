#!/usr/bin/env bash
set -euo pipefail

required=(
  ALEO_PRIVATE_KEY
  ALEO_VIEW_KEY
  ALEO_ADDRESS
  RPC_URL
  USDCX_PROGRAM_ID
  MANIFEST_PATH
  PNW_NETWORK
)

missing=()
for name in "${required[@]}"; do
  if [[ -z "${!name:-}" ]]; then
    missing+=("$name")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "execute env check: FAIL - missing required env vars: ${missing[*]}" >&2
  exit 1
fi

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "execute env check: FAIL - MANIFEST_PATH file not found: $MANIFEST_PATH" >&2
  exit 1
fi

if [[ "$RPC_URL" != http://* && "$RPC_URL" != https://* ]]; then
  echo "execute env check: FAIL - RPC_URL must start with http:// or https://" >&2
  exit 1
fi

SNARKOS_ENDPOINT_EFFECTIVE="${SNARKOS_ENDPOINT:-}"
if [[ -z "$SNARKOS_ENDPOINT_EFFECTIVE" ]]; then
  SNARKOS_ENDPOINT_EFFECTIVE="$RPC_URL"
  echo "execute env check: WARN - SNARKOS_ENDPOINT not set; defaulting to RPC_URL for endpoint-compatible tooling" >&2
fi

if [[ "$SNARKOS_ENDPOINT_EFFECTIVE" != http://* && "$SNARKOS_ENDPOINT_EFFECTIVE" != https://* ]]; then
  echo "execute env check: FAIL - SNARKOS_ENDPOINT (effective) must start with http:// or https://" >&2
  exit 1
fi

if [[ "$PNW_NETWORK" == "testnet" && "$SNARKOS_ENDPOINT_EFFECTIVE" != *"/testnet"* ]]; then
  echo "execute env check: WARN - SNARKOS_ENDPOINT does not include '/testnet'; some snarkOS builds expect a network-qualified path while others expect base /v2. If broadcast fails with JSON parse errors, try '/v2/testnet'." >&2
fi

export SNARKOS_ENDPOINT="$SNARKOS_ENDPOINT_EFFECTIVE"

if ! python3 - <<'PY'
import json
import os
import sys

manifest_path = os.environ["MANIFEST_PATH"]
expected_network = os.environ["PNW_NETWORK"]
expected_usdcx = os.environ["USDCX_PROGRAM_ID"]

with open(manifest_path, "r", encoding="utf-8") as f:
    manifest = json.load(f)

network = manifest.get("network")
if network != expected_network:
    print(
        f"execute env check: FAIL - manifest network '{network}' does not match PNW_NETWORK '{expected_network}'",
        file=sys.stderr,
    )
    sys.exit(1)

actual_usdcx = manifest.get("program_ids", {}).get("external", {}).get("usdcx")
if actual_usdcx != expected_usdcx:
    print(
        f"execute env check: FAIL - USDCX_PROGRAM_ID '{expected_usdcx}' does not match manifest external.usdcx '{actual_usdcx}'",
        file=sys.stderr,
    )
    sys.exit(1)
PY
then
  exit 1
fi

echo "execute env check: PASS"
