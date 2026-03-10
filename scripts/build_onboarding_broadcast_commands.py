#!/usr/bin/env python3
"""Build deterministic onboarding_smoke broadcast command JSON.

Generates `phase4.broadcast_commands.v1` payload using concrete
`credential_nft.aleo/mint_credential_nft` argument codec:
- 6x [u8;32] args (input as hex, encoded to Leo u8-array literals)
- 2x u16 args

The caller supplies a submit command prefix that already includes
CLI-specific flags (network/rpc/private-key/etc.). This avoids hardcoding
one CLI dialect in repo while keeping arg ordering deterministic.
"""

from __future__ import annotations

import argparse
import json
import re
import shlex
from urllib.parse import urlparse
from pathlib import Path
from typing import Any

HEX32_RE = re.compile(r"^0x[a-fA-F0-9]{64}$")


def must_hex32(name: str, value: Any) -> str:
    if not isinstance(value, str) or not HEX32_RE.fullmatch(value):
        raise SystemExit(f"ERROR: {name} must be 0x-prefixed 32-byte hex (64 nybbles)")
    return value.lower()


def encode_hex32_as_u8_array(name: str, value: Any) -> str:
    hex_value = must_hex32(name, value)
    raw = bytes.fromhex(hex_value[2:])
    return "[" + ", ".join(f"{b}u8" for b in raw) + "]"


def must_u16(name: str, value: Any) -> str:
    if not isinstance(value, int) or value < 0 or value > 65535:
        raise SystemExit(f"ERROR: {name} must be integer in [0, 65535]")
    if value == 0:
        raise SystemExit(f"ERROR: {name} must be non-zero for mint_credential_nft")
    return f"{value}u16"


def main() -> None:
    ap = argparse.ArgumentParser(description="Build onboarding_smoke PHASE4_BROADCAST_COMMANDS_JSON payload")
    ap.add_argument("--args-file", required=True, help="JSON file containing mint_credential_nft args")
    ap.add_argument(
        "--submit-prefix",
        required=True,
        help=(
            "Shell command prefix used to submit transition (must include executable/flags/program/transition). "
            "Example: \"snarkos developer execute --endpoint 'https://api.explorer.provable.com/v2/testnet' --broadcast --private-key '$ALEO_PRIVATE_KEY' credential_nft.aleo mint_credential_nft\""
        ),
    )
    ap.add_argument("--name", default="submit_onboarding", help="Command entry name")
    ap.add_argument("--out", default="-", help="Output file path or '-' for stdout")
    ns = ap.parse_args()

    data = json.loads(Path(ns.args_file).read_text(encoding="utf-8"))

    args = [
        encode_hex32_as_u8_array("credential_id_hex", data.get("credential_id_hex")),
        encode_hex32_as_u8_array("subject_hash_hex", data.get("subject_hash_hex")),
        encode_hex32_as_u8_array("issuer_hash_hex", data.get("issuer_hash_hex")),
        encode_hex32_as_u8_array("scope_hash_hex", data.get("scope_hash_hex")),
        encode_hex32_as_u8_array("doc_hash_hex", data.get("doc_hash_hex")),
        encode_hex32_as_u8_array("root_hex", data.get("root_hex")),
        must_u16("schema_v", data.get("schema_v")),
        must_u16("policy_v", data.get("policy_v")),
    ]

    encoded_args = " ".join(shlex.quote(v) for v in args)
    prefix = ns.submit_prefix.strip()
    if not prefix:
        raise SystemExit("ERROR: --submit-prefix must be non-empty")
    if "--endpoint" not in prefix:
        raise SystemExit("ERROR: --submit-prefix must include an explicit --endpoint '<broadcast-uri>'")
    if "$SNARKOS_ENDPOINT" in prefix or "${SNARKOS_ENDPOINT}" in prefix:
        raise SystemExit(
            "ERROR: --submit-prefix must use an explicit broadcast URI (do not pass SNARKOS_ENDPOINT env interpolation)"
        )

    tokens = shlex.split(prefix)
    endpoint = ""
    for i, tok in enumerate(tokens):
        if tok == "--endpoint":
            endpoint = tokens[i + 1] if i + 1 < len(tokens) else ""
            break
        if tok.startswith("--endpoint="):
            endpoint = tok.split("=", 1)[1]
            break

    if not endpoint:
        raise SystemExit("ERROR: --submit-prefix must provide a concrete endpoint value for --endpoint")
    if "$" in endpoint or "{" in endpoint or "}" in endpoint:
        raise SystemExit("ERROR: endpoint must be a concrete URI, not a shell variable expression")
    parsed = urlparse(endpoint)
    if parsed.scheme not in {"http", "https"}:
        raise SystemExit("ERROR: endpoint must be an http(s) URI")
    if "/testnet" not in parsed.path:
        print(
            "WARNING: endpoint does not include '/testnet'. Some environments require a network-qualified URI "
            "(for example https://api.explorer.provable.com/v2/testnet).",
            flush=True,
        )

    command = (
        "bash -lc "
        + shlex.quote(
            "set -euo pipefail; "
            "set +e; "
            f"out=$({prefix} {encoded_args} 2>&1); "
            "rc=$?; "
            "set -e; "
            "printf '%s\\n' \"$out\"; "
            "if [ \"$rc\" -ne 0 ]; then "
            "echo \"broadcast submit command failed with exit $rc\" >&2; "
            "exit \"$rc\"; "
            "fi; "
            "tx=$(printf '%s\\n' \"$out\" | sed -nE 's/.*[Tt]ransaction[[:space:]]+[Ii][Dd][[:space:]]*[:=][[:space:]]*([A-Za-z0-9_.:-]+).*/\\1/p; s/.*\\b([a-fA-F0-9]{64})\\b.*/\\1/p' | head -n1); "
            "test -n \"$tx\"; "
            "echo \"transaction id: $tx\""
        )
    )

    payload = {
        "schema_version": "phase4.broadcast_commands.v1",
        "notes": [
            "Generated by scripts/build_onboarding_broadcast_commands.py",
            "Codec mapping: credential_nft.aleo/mint_credential_nft",
            "Args order: credential_id, subject_hash, issuer_hash, scope_hash, doc_hash, root, schema_v, policy_v",
            "Hex inputs are encoded into Leo [u8;32] literals for snarkOS CLI compatibility.",
            "Endpoint behavior may vary by snarkOS/provider; if submit returns non-JSON parse errors, test both /v2 and /v2/testnet endpoint forms.",
            "Submit wrapper prints captured output before failing when the submit command exits non-zero.",
        ],
        "commands": [{"name": ns.name, "command": command}],
    }

    out_text = json.dumps(payload, indent=2) + "\n"
    if ns.out == "-":
        print(out_text, end="")
    else:
        out_path = Path(ns.out)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(out_text, encoding="utf-8")


if __name__ == "__main__":
    main()
