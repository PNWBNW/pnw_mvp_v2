#!/usr/bin/env bash
set -euo pipefail

ok=true

LEO_PIN="${LEO_VERSION:-}"
SNARKOS_PIN="${SNARKOS_VERSION:-}"

leo_out=""
snarkos_out=""

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
    echo "snarkos pin check: PASS (${SNARKOS_PIN})"
  else
    echo "snarkos pin check: FAIL (expected contains: ${SNARKOS_PIN})" >&2
    ok=false
  fi
fi

if [[ "$ok" != true ]]; then
  echo "One or more required CLI checks failed." >&2
  exit 1
fi
