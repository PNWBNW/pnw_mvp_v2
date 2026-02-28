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

echo "execute env check: PASS"
