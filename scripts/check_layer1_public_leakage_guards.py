#!/usr/bin/env python3
"""Guardrail check for Layer 1 public-state leakage patterns.

Fails if suspicious cumulative spend counter identifiers appear in Layer 1 Leo sources.
This is a lightweight static check intended for CI gates.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAYER1_DIR = ROOT / "src" / "layer1"

# Terms intentionally focused on publicly-leaky cumulative accounting semantics.
FORBIDDEN_IDENTIFIERS = [
    "total_spent",
    "new_total_spent",
    "spent_total",
    "cumulative_spent",
    "salary_total",
]


def strip_comments(text: str) -> str:
    lines = []
    for line in text.splitlines():
        if "//" in line:
            line = line.split("//", 1)[0]
        lines.append(line)
    return "\n".join(lines)


def main() -> int:
    leo_files = sorted(LAYER1_DIR.glob("**/*.leo"))
    if not leo_files:
        print("layer1 leakage guard: FAIL - no .leo files found", file=sys.stderr)
        return 1

    bad_hits: list[tuple[Path, int, str]] = []
    patterns = [re.compile(rf"\b{re.escape(term)}\b", re.IGNORECASE) for term in FORBIDDEN_IDENTIFIERS]

    for path in leo_files:
        raw = path.read_text(encoding="utf-8")
        content = strip_comments(raw)
        for line_no, line in enumerate(content.splitlines(), start=1):
            for pattern in patterns:
                if pattern.search(line):
                    bad_hits.append((path, line_no, line.strip()))

    if bad_hits:
        print("layer1 leakage guard: FAIL - forbidden cumulative identifier(s) found:", file=sys.stderr)
        for path, line_no, line in bad_hits:
            rel = path.relative_to(ROOT)
            print(f"  - {rel}:{line_no}: {line}", file=sys.stderr)
        return 1

    print(f"layer1 leakage guard: PASS - checked {len(leo_files)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
