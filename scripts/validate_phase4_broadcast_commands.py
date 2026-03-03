#!/usr/bin/env python3
"""Validate Phase 4 broadcast command payloads for common snarkOS misconfigurations."""

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path


def parse_inner_tokens(command: str) -> list[str]:
    command = command.strip()
    if command.startswith("bash -lc "):
        quoted = command[len("bash -lc ") :].strip()
        try:
            inner = shlex.split(quoted)[0]
        except Exception:
            inner = quoted.strip("'\"")
        try:
            return shlex.split(inner)
        except Exception:
            return []
    try:
        return shlex.split(command)
    except Exception:
        return []


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("Usage: validate_phase4_broadcast_commands.py <broadcast_commands.json>")

    path = Path(sys.argv[1])
    if not path.is_file():
        raise SystemExit(f"ERROR: file not found: {path}")

    obj = json.loads(path.read_text(encoding="utf-8"))
    commands = obj.get("commands")
    if not isinstance(commands, list) or not commands:
        raise SystemExit("ERROR: commands must be a non-empty list")

    errors: list[str] = []
    warnings: list[str] = []

    for i, entry in enumerate(commands):
        if not isinstance(entry, dict):
            errors.append(f"commands[{i}] must be an object")
            continue
        name = str(entry.get("name") or f"command_{i}")
        command = str(entry.get("command") or "")
        if not command.strip():
            errors.append(f"{name}: missing non-empty command")
            continue

        tokens = parse_inner_tokens(command)
        joined = " ".join(tokens) if tokens else command

        if "snarkos" in joined and " developer " in f" {joined} " and " execute " in f" {joined} ":
            if not command.strip().startswith("bash -lc "):
                errors.append(
                    f"{name}: command should be wrapped with 'bash -lc ...' to avoid /bin/sh parsing differences in CI"
                )
            if "--endpoint" not in tokens and "--endpoint=" not in joined:
                warnings.append(f"{name}: snarkos execute command does not include --endpoint")

            # Common anti-pattern: passing a concrete URL argument to --broadcast
            # while also using --endpoint. This can produce provider/schema mismatch errors.
            for j, tok in enumerate(tokens):
                if tok == "--broadcast" and j + 1 < len(tokens):
                    nxt = tokens[j + 1]
                    if nxt.startswith("http://") or nxt.startswith("https://") or "transaction/broadcast" in nxt:
                        errors.append(
                            f"{name}: avoid passing URL argument to --broadcast ('{nxt}'). "
                            "Use '--broadcast' as a flag and set submit target via --endpoint."
                        )
                if tok.startswith("--broadcast="):
                    val = tok.split("=", 1)[1]
                    if val.startswith("http://") or val.startswith("https://") or "transaction/broadcast" in val:
                        errors.append(
                            f"{name}: avoid --broadcast URL value ('{val}'). "
                            "Use '--broadcast' flag and --endpoint for the submit target."
                        )

            if "$SNARKOS_ENDPOINT/testnet/transaction/broadcast" in joined:
                errors.append(
                    f"{name}: detected '$SNARKOS_ENDPOINT/testnet/transaction/broadcast' anti-pattern. "
                    "This usually breaks snarkOS error decoding; keep endpoint in --endpoint only."
                )

    for w in warnings:
        print(f"WARN: {w}")

    if errors:
        for e in errors:
            print(f"ERROR: {e}", file=sys.stderr)
        raise SystemExit(1)

    print(f"broadcast commands validation: PASS - {path}")


if __name__ == "__main__":
    main()
