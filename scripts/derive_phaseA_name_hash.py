#!/usr/bin/env python3
"""Derive deterministic local name hash for Phase A scenario authoring.

Algorithm:
- normalize whitespace
- lowercase
- sha256("pnw:phaseA:v1:" + normalized_name)
"""

from __future__ import annotations

import hashlib
import sys


def derive(name_raw: str) -> str:
    normalized = " ".join(name_raw.strip().split()).lower()
    digest = hashlib.sha256(f"pnw:phaseA:v1:{normalized}".encode("utf-8")).hexdigest()
    return f"0x{digest}"


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: scripts/derive_phaseA_name_hash.py \"<raw name>\"", file=sys.stderr)
        raise SystemExit(1)
    print(derive(sys.argv[1]))
