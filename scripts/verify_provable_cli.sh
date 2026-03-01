#!/usr/bin/env bash
set -euo pipefail

ok=true

LEO_PIN="${LEO_VERSION:-}"
SNARKOS_PIN="${SNARKOS_VERSION:-}"
LEO_PIN_URL="${LEO_URL:-}"
SNARKOS_PIN_URL="${SNARKOS_URL:-}"
STRICT_VERSION_CHECK="${STRICT_VERSION_CHECK:-false}"

leo_out=""
snarkos_out=""

check_pin() {
  local tool="$1"
  local pin="$2"
  local out="$3"
  local pin_url="$4"

  if [[ -z "$pin" || -z "$out" ]]; then
    return 0
  fi

  if [[ "$out" == *"$pin"* ]]; then
    echo "${tool} pin check: PASS (${pin})"
    return 0
  fi

  if [[ -n "$pin_url" ]]; then
    echo "${tool} pin check note: configured URL=${pin_url}" >&2
  fi

  if [[ "$STRICT_VERSION_CHECK" == "true" ]]; then
    echo "${tool} pin check: FAIL (expected installed version output to contain: ${pin})" >&2
    return 1
  fi

  echo "${tool} pin check: WARN (installed version output did not contain pin token: ${pin}; non-strict mode)" >&2
  return 0
}

if command -v leo >/dev/null 2>&1; then
  leo_out="$(leo --version)"
  echo "leo: ${leo_out}"
else
  echo "leo: MISSING"
  ok=false
fi

if command -v snarkos >/dev/null 2>&1; then
  snarkos_out="$(snarkos --version)"
  echo "snarkos: ${snarkos_out}"
else
  echo "snarkos: MISSING"
  ok=false
fi

if ! check_pin "leo" "$LEO_PIN" "$leo_out" "$LEO_PIN_URL"; then
  ok=false
fi

if ! check_pin "snarkos" "$SNARKOS_PIN" "$snarkos_out" "$SNARKOS_PIN_URL"; then
  ok=false
fi

if [[ "$ok" != true ]]; then
  echo "One or more required CLI checks failed." >&2
  exit 1
fi
