#!/usr/bin/env python3
"""Verify Phase 4 execute artifact bundle integrity and shape."""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path
from typing import Any


def fail(msg: str) -> None:
    print(f"execute artifact verification: FAIL - {msg}", file=sys.stderr)
    raise SystemExit(1)


def expect(cond: bool, msg: str) -> None:
    if not cond:
        fail(msg)


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:  # noqa: BLE001
        fail(f"invalid json at {path}: {e}")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: scripts/verify_phase4_execute_artifacts.py <artifact_dir>")

    base = Path(sys.argv[1])
    expect(base.is_dir(), f"artifact directory not found: {base}")

    required = {
        "step_traces.json",
        "tx_ids.json",
        "verification_summary.json",
        "bundle_manifest.json",
    }

    for name in required:
        expect((base / name).is_file(), f"missing required artifact file: {name}")

    step_traces = load_json(base / "step_traces.json")
    tx_ids = load_json(base / "tx_ids.json")
    verification = load_json(base / "verification_summary.json")
    bundle = load_json(base / "bundle_manifest.json")

    expect(step_traces.get("schema_version") == "phase4.step_traces.v1", "step_traces schema_version mismatch")
    expect(tx_ids.get("schema_version") == "phase4.tx_ids.v1", "tx_ids schema_version mismatch")
    expect(verification.get("schema_version") == "phase4.verification_summary.v1", "verification_summary schema_version mismatch")
    expect(bundle.get("schema_version") == "phase4.execute_bundle_manifest.v1", "bundle_manifest schema_version mismatch")

    checks = verification.get("checks")
    expect(isinstance(checks, list), "verification_summary.checks must be list")
    names = {c.get("name") for c in checks if isinstance(c, dict)}
    for needed in ("manifest_valid", "execute_env_valid", "scenario_selected", "broadcast_mode"):
        expect(needed in names, f"verification check missing: {needed}")

    files = bundle.get("files")
    expect(isinstance(files, list), "bundle_manifest.files must be list")
    manifest_names = {entry.get("name") for entry in files if isinstance(entry, dict)}
    for name in ("step_traces.json", "tx_ids.json", "verification_summary.json"):
        expect(name in manifest_names, f"bundle_manifest missing file entry: {name}")

    for entry in files:
        if not isinstance(entry, dict):
            fail("bundle_manifest.files entries must be objects")
        name = entry.get("name")
        sha = entry.get("sha256")
        expect(isinstance(name, str) and name, "bundle_manifest entry missing name")
        expect(isinstance(sha, str) and len(sha) == 64, f"bundle_manifest invalid sha256 for {name}")
        target = base / name
        expect(target.is_file(), f"bundle_manifest references missing file: {name}")
        actual = sha256_file(target)
        expect(actual == sha, f"sha256 mismatch for {name}: expected {sha}, got {actual}")

    print(f"execute artifact verification: PASS - {base}")


if __name__ == "__main__":
    main()
