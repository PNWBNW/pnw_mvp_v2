#!/usr/bin/env bash
set -euo pipefail

ok=true

if command -v leo >/dev/null 2>&1; then
  echo "leo: $(leo --version)"
else
  echo "leo: MISSING"
  ok=false
fi

if command -v snarkos >/dev/null 2>&1; then
  echo "snarkos: $(snarkos --version)"
else
  echo "snarkos: MISSING"
  ok=false
fi

if [[ "$ok" != true ]]; then
  echo "One or more required CLI tools are missing." >&2
  exit 1
fi
