#!/usr/bin/env python3
"""Superseded programs stay unchanged and listed (CLAUDE.md, Immutability; Hewn's
docs/INVARIANTS.md, INV-21).

For src/layer1/archive and src/layer2/archive, this fails when:
  - a folder in the archive has no row in that archive's README.md (a row may name later versions
    of the same program by suffix: `pnw_name_registrar.aleo`, `_v2`, `_v3`);
  - a file in the archive isn't in that archive's SHA256SUMS, or its hash differs (an archived
    program was edited), or SHA256SUMS names a file that is gone.

Archiving a program adds its folder, a README row and its lines in SHA256SUMS in the same pull
request:  python3 -I scripts/check_archive.py --write  rewrites SHA256SUMS from the tree; review
the diff, since a changed hash on an existing line means an archived file was edited.

Standard library only. Run from the repository root: python3 -I scripts/check_archive.py
"""
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHIVES = [ROOT / "src" / "layer1" / "archive", ROOT / "src" / "layer2" / "archive"]
SKIP = {"README.md", "SHA256SUMS"}


def archived_files(archive: Path) -> dict[str, str]:
    out = {}
    for path in sorted(archive.rglob("*")):
        if path.is_file() and path.relative_to(archive).as_posix() not in SKIP:
            out[path.relative_to(archive).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    return out


def listed_folders(readme: str) -> set[str]:
    names = set()
    for line in readme.splitlines():
        if not line.startswith("|"):
            continue
        first_cell = line.split("|")[1] if line.count("|") >= 2 else ""
        tokens = re.findall(r"`([^`]+)`", first_cell)
        base = None
        for token in tokens:
            token = token.rstrip("/")
            if token.startswith("_v") and base:
                names.add(f"{base}{token}.aleo")
                continue
            m = re.match(r"([a-z0-9_]+?)(?:_v\d+)?\.aleo(?:-\d{4}-\d{2}-\d{2})?$", token)
            if m:
                base = m.group(1)
                names.add(token)
    return names


def main() -> int:
    write = "--write" in sys.argv[1:]
    problems = []
    total = 0
    for archive in ARCHIVES:
        rel = archive.relative_to(ROOT).as_posix()
        if not archive.is_dir():
            problems.append(f"{rel}: missing")
            continue
        readme = (archive / "README.md").read_text() if (archive / "README.md").exists() else ""
        listed = listed_folders(readme)
        for folder in sorted(p.name for p in archive.iterdir() if p.is_dir()):
            if folder not in listed:
                problems.append(f"{rel}/{folder}: no row in {rel}/README.md")
        files = archived_files(archive)
        total += len(files)
        sums_path = archive / "SHA256SUMS"
        if write:
            sums_path.write_text("".join(f"{h}  {name}\n" for name, h in files.items()))
            continue
        if not sums_path.exists():
            problems.append(f"{rel}/SHA256SUMS: missing (run with --write once, then review)")
            continue
        recorded = {}
        for line in sums_path.read_text().splitlines():
            if line.strip():
                h, name = line.split(None, 1)
                recorded[name.strip()] = h
        for name, h in files.items():
            if name not in recorded:
                problems.append(f"{rel}/{name}: not in SHA256SUMS (archive it with --write, in the same PR as its README row)")
            elif recorded[name] != h:
                problems.append(f"{rel}/{name}: changed since it was archived")
        for name in recorded:
            if name not in files:
                problems.append(f"{rel}/{name}: in SHA256SUMS but gone from the archive")
    if write:
        print(f"archive check: wrote SHA256SUMS for {total} files")
        return 0
    if problems:
        print("archive check: FAIL", file=sys.stderr)
        for p in problems:
            print(f"  - {p}", file=sys.stderr)
        return 1
    print(f"archive check: PASS - {total} archived files unchanged, every folder listed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
