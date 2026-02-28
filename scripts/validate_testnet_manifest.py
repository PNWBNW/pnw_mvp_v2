#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

RE_ALEO = re.compile(r"^[a-z0-9_]+\.aleo$")

REQUIRED = {
    "layer1": [
        "pnw_router",
        "pnw_name_registry",
        "worker_profiles",
        "employer_profiles",
        "employer_license_registry",
        "employer_agreement",
        "payroll_core",
        "paystub_receipts",
        "payroll_audit_log",
    ],
    "layer2": [
        "payroll_nfts",
        "credential_nft",
        "audit_nft",
    ],
    "external": [
        "usdcx",
    ],
}


def fail(msg: str) -> None:
    print(f"manifest validation: FAIL - {msg}", file=sys.stderr)
    raise SystemExit(1)


def expect_str(data: dict, key: str) -> str:
    val = data.get(key)
    if not isinstance(val, str) or not val.strip():
        fail(f"missing/invalid string field '{key}'")
    return val.strip()


def main() -> None:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "config/testnet.manifest.json")
    if not path.exists():
        fail(f"manifest path does not exist: {path}")

    try:
        manifest = json.loads(path.read_text())
    except Exception as exc:
        fail(f"invalid JSON ({exc})")

    if not isinstance(manifest, dict):
        fail("manifest root must be an object")

    schema_version = expect_str(manifest, "schema_version")
    network = expect_str(manifest, "network")

    if network != "testnet":
        fail(f"network must be 'testnet' (got '{network}')")

    program_ids = manifest.get("program_ids")
    if not isinstance(program_ids, dict):
        fail("'program_ids' must be an object")

    for group, keys in REQUIRED.items():
        section = program_ids.get(group)
        if not isinstance(section, dict):
            fail(f"'program_ids.{group}' must be an object")

        for key in keys:
            value = section.get(key)
            if not isinstance(value, str) or not RE_ALEO.match(value):
                fail(f"'program_ids.{group}.{key}' must be a *.aleo program id")

    print(
        "manifest validation: PASS"
        f" (schema_version={schema_version}, network={network}, path={path})"
    )


if __name__ == "__main__":
    main()
