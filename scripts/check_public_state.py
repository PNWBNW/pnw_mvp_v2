#!/usr/bin/env python3
"""Keep docs/PUBLIC_STATE.md complete.

Fails when:
  - a mapping in a program's source (src/layer1/*.aleo, src/layer2/*.aleo; not the archives) has
    no row in the page, or a row names a mapping that doesn't exist;
  - a program folder, or an active program in config/testnet.manifest.json with a source folder,
    isn't mentioned on the page;
  - a row's "Tests" column says yes or no where .github/workflows/deploy.yml says otherwise
    (a program has tests in the gate when deploy.yml names its src/layer*/<program> folder).

Standard library only. Run from the repository root: python3 -I scripts/check_public_state.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs" / "PUBLIC_STATE.md"
MAPPING = re.compile(r"^\s*mapping\s+(\w+)\s*:\s*(.+?)\s*=>\s*(.+);")
ROW = re.compile(r"^\|\s*`([\w]+\.aleo)`\s*\|\s*`(\w+)`\s*\|(.*)\|\s*$")


def source_mappings() -> dict[str, set[str]]:
    found: dict[str, set[str]] = {}
    for layer in ("layer1", "layer2"):
        for main in sorted((ROOT / "src" / layer).glob("*.aleo/src/main.leo")):
            program = main.parent.parent.name
            names = set()
            for line in main.read_text().splitlines():
                code = line.split("//", 1)[0]
                m = MAPPING.match(code)
                if m:
                    names.add(m.group(1))
            found[program] = names
    return found


def page_rows(text: str) -> dict[tuple[str, str], list[str]]:
    rows = {}
    for line in text.splitlines():
        m = ROW.match(line)
        if m:
            cells = [c.strip() for c in m.group(3).split("|")]
            rows[(m.group(1), m.group(2))] = cells
    return rows


def main() -> int:
    if not PAGE.exists():
        print(f"public-state check: FAIL - {PAGE.relative_to(ROOT)} is missing", file=sys.stderr)
        return 1
    text = PAGE.read_text()
    rows = page_rows(text)
    source = source_mappings()
    gate = (ROOT / ".github" / "workflows" / "deploy.yml").read_text()
    manifest = json.loads((ROOT / "config" / "testnet.manifest.json").read_text())
    problems = []

    for program, names in source.items():
        if f"`{program}`" not in text:
            problems.append(f"{program}: not mentioned on the page")
        for name in sorted(names):
            if (program, name) not in rows:
                problems.append(f"{program}: mapping `{name}` has no row")
    for (program, name), cells in rows.items():
        if name not in source.get(program, set()):
            problems.append(f"{program}: the page lists `{name}`, which the source doesn't declare")
        tested = re.search(rf"src/layer[12]/{re.escape(program)}\b", gate) is not None
        said = cells[-1].lower() if cells else ""
        if said not in ("yes", "no"):
            problems.append(f"{program}/{name}: Tests column reads {said!r}, expected yes or no")
        elif (said == "yes") != tested:
            problems.append(f"{program}/{name}: Tests column says {said}, but deploy.yml {'runs' if tested else 'does not run'} its Leo tests")
    for program, entry in manifest.get("deployments", {}).items():
        if entry.get("status") == "active" and program in source and f"`{program}`" not in text:
            problems.append(f"{program}: active in the manifest but not on the page")

    if problems:
        print("public-state check: FAIL", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        return 1
    total = sum(len(v) for v in source.values())
    print(f"public-state check: PASS - {total} mappings in {len(source)} programs, all listed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
