#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from pathlib import Path
import shutil
p = Path('.tmp_phase4_tests')
if p.exists():
    shutil.rmtree(p)
PY

npx --yes --package typescript tsc -p portal/tsconfig.phase4.tests.json
node .tmp_phase4_tests/tests/phase4_adapter.test.js
