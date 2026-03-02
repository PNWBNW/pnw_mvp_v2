#!/usr/bin/env bash
set -euo pipefail

TMP_OUT=".tmp_phase4_tests"
TEST_JS="$TMP_OUT/tests/phase4_adapter.test.js"

python3 - <<'PY'
from pathlib import Path
import shutil
p = Path('.tmp_phase4_tests')
if p.exists():
    shutil.rmtree(p)
PY

if command -v tsc >/dev/null 2>&1; then
  COMPILE_CMD=(tsc -p portal/tsconfig.phase4.tests.json)
elif [[ -x "./node_modules/.bin/tsc" ]]; then
  COMPILE_CMD=(./node_modules/.bin/tsc -p portal/tsconfig.phase4.tests.json)
else
  COMPILE_CMD=(npx --yes --package typescript tsc -p portal/tsconfig.phase4.tests.json)
fi

if ! "${COMPILE_CMD[@]}"; then
  echo "phase4 adapter tests: FAIL - unable to compile tests (typescript toolchain unavailable)" >&2
  exit 1
fi

if [[ ! -f "$TEST_JS" ]]; then
  echo "phase4 adapter tests: FAIL - expected compiled test not found at $TEST_JS" >&2
  exit 1
fi

node "$TEST_JS"
