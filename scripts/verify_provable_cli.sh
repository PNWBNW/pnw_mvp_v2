#!/usr/bin/env bash
set -euo pipefail

ok=true

LEO_PIN="${LEO_VERSION:-}"
SNARKOS_PIN="${SNARKOS_VERSION:-}"
SNARKOS_CMD="${SNARKOS_CLI_CMD:-aleo}"

leo_out=""
snarkos_out=""

if command -v leo >/dev/null 2>&1; then
  leo_out="$(leo --version)"
  echo "leo: ${leo_out}"
else
  echo "leo: MISSING"
  ok=false
fi

if command -v "$SNARKOS_CMD" >/dev/null 2>&1; then
  snarkos_out="$("$SNARKOS_CMD" --version)"
  echo "${SNARKOS_CMD}: ${snarkos_out}"
else
  echo "${SNARKOS_CMD}: MISSING"
  ok=false
fi

if [[ -n "$LEO_PIN" && -n "$leo_out" ]]; then
  if [[ "$leo_out" == *"$LEO_PIN"* ]]; then
    echo "leo pin check: PASS (${LEO_PIN})"
  else
    echo "leo pin check: FAIL (expected contains: ${LEO_PIN})" >&2
    ok=false
  fi
fi

if [[ -n "$SNARKOS_PIN" && -n "$snarkos_out" ]]; then
  if [[ "$snarkos_out" == *"$SNARKOS_PIN"* ]]; then
    echo "${SNARKOS_CMD} pin check: PASS (${SNARKOS_PIN})"
  else
    echo "${SNARKOS_CMD} pin check: FAIL (expected contains: ${SNARKOS_PIN})" >&2
    ok=false
  fi
fi

if [[ "$ok" != true ]]; then
  echo "One or more required CLI checks failed." >&2
  exit 1
fi
