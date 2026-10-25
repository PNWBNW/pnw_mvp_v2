#!/usr/bin/env python3
"""Layer 2 never moves funds (CLAUDE.md, Privacy; Hewn's docs/INVARIANTS.md, INV-24).

Layer 2 programs are commitment anchors. This fails when a program under src/layer2 (not its
archive):
  - imports a program outside the allowed set: Layer 1 programs that hold no money
    (agreements, names, licences, profiles, the audit log);
  - calls another program's function whose name doesn't start with `assert_` (a check, not a
    move);
  - names a token program (credits.aleo, a stablecoin, anything with "usdc" or "token") or a
    transfer function anywhere in its code.

Standard library only. Run from the repository root: python3 -I scripts/check_layer2_moves_no_funds.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAYER2 = ROOT / "src" / "layer2"
ALLOWED_IMPORTS = re.compile(
    r"^(?:employer_agreement_v\d+|pnw_name_registry(?:_v\d+)?|employer_license_registry|employer_profiles(?:_v\d+)?|"
    r"pnw_worker_profiles(?:_v\d+)?|payroll_audit_log)\.aleo$"
)
IMPORT = re.compile(r"^\s*import\s+([a-z0-9_]+\.aleo)\s*;", re.M)
CALL = re.compile(r"\b([a-z0-9_]+\.aleo)::(\w+)\s*\(")
FUNDS = re.compile(r"\bcredits\.aleo\b|\b\w*(?:usdc|stablecoin|token)\w*\.aleo\b|\btransfer_\w+|\bjoin\s*\(|\bsplit\s*\(", re.I)


def code_only(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.S)
    return "\n".join(line.split("//", 1)[0] for line in text.splitlines())


def main() -> int:
    problems = []
    programs = sorted(p for p in LAYER2.glob("*.aleo") if p.is_dir())
    for program in programs:
        for leo in sorted(program.rglob("*.leo")):
            rel = leo.relative_to(ROOT).as_posix()
            if "/tests/" in rel:
                continue
            code = code_only(leo.read_text())
            for imported in IMPORT.findall(code):
                if not ALLOWED_IMPORTS.match(imported):
                    problems.append(f"{rel}: imports {imported}, which isn't a money-free Layer 1 program")
            for number, line in enumerate(code.splitlines(), 1):
                for target, fn in CALL.findall(line):
                    if not fn.startswith("assert_"):
                        problems.append(f"{rel}:{number}: calls {target}::{fn}, not a check (assert_...)")
                if FUNDS.search(line):
                    problems.append(f"{rel}:{number}: names a token program or a transfer")
    if not programs:
        problems.append("no Layer 2 programs found: run it from the repository root's scripts/ folder")
    if problems:
        print("layer 2 funds check: FAIL", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        return 1
    print(f"layer 2 funds check: PASS - {len(programs)} programs import only money-free programs and call only assert_ checks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
