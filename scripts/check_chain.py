#!/usr/bin/env python3
"""What is on chain is what the manifest records (CLAUDE.md, Immutability; Hewn's INV-20).

An `@admin` program can be upgraded in place by whoever holds the admin key, and an upgrade may
change the logic inside any existing function, not only add new ones (snarkVM
`check_upgrade_is_valid`). Nothing else would notice: a wallet proves against the newest edition
without saying so. So `config/testnet.manifest.json` records, for every program of ours, the
edition on chain and the SHA-256 of its text there, and this check reads the chain and compares.

It fails when:
  - a program's edition or text on chain differs from the manifest (it was upgraded, or the
    manifest was edited);
  - a program the manifest says is not on chain is there, or one it says is there is gone;
  - a program folder under src/layer1, src/layer2 or their archives has no entry under
    `deployments`, so nothing would watch it;
  - a program under `watched` (one we rely on and don't own, such as the stablecoin every Hewn
    payment runs) is at another edition or text than recorded: its owner upgraded it.

    python3 -I scripts/check_chain.py               # compare; exit 1 on a difference, 2 if the explorer can't be reached
    python3 -I scripts/check_chain.py --offline-ok  # the plan gate: an unreachable explorer is a warning, not a failure
    python3 -I scripts/check_chain.py --write       # record what the chain holds now, in the pull request of a deploy or upgrade

After `--write`, read the diff: a changed edition or hash on an existing entry is an upgrade, and
it needs its migration note. The daily `chain-watch` workflow runs the strict form.

The text hashed is the program exactly as the explorer returns it (`/program/<id>`), UTF-8. Reads
only public data; no key, no secret. Standard library only.
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "config" / "testnet.manifest.json"
BASE = os.environ.get("ENDPOINT", "https://api.explorer.provable.com/v2").rstrip("/") + "/testnet"
FOLDERS = ["src/layer1", "src/layer2", "src/layer1/archive", "src/layer2/archive"]
PROGRAM = re.compile(r"^([a-z][a-z0-9_]*\.aleo)(?:-\d{4}-\d{2}-\d{2})?$")  # a snapshot folder carries a date after the id


class Unreachable(Exception):
    """The explorer didn't answer, as opposed to answering "no such program"."""


def get(path: str):
    """The decoded JSON at `path`, or None for 404. Three tries, then Unreachable."""
    last = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(f"{BASE}{path}", headers={"User-Agent": "hewn-chain-check"})
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            if error.code == 404:
                return None
            last = error
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as error:
            last = error
        time.sleep(2 * (attempt + 1))
    raise Unreachable(f"{path}: {last}")


def on_chain(program: str):
    """(edition, sha256 of the text) for a deployed program, or None when it isn't on chain."""
    text = get(f"/program/{program}")
    if text is None:
        return None
    if not isinstance(text, str):
        raise Unreachable(f"/program/{program}: not program text")
    edition = get(f"/program/{program}/latest_edition")
    if not isinstance(edition, int):
        raise Unreachable(f"/program/{program}/latest_edition: not a number")
    return edition, hashlib.sha256(text.encode("utf-8")).hexdigest()


def source_programs() -> list[str]:
    """Every program id that has a folder in the tree, live or archived."""
    found = set()
    for folder in FOLDERS:
        for path in sorted((ROOT / folder).iterdir()):
            match = PROGRAM.match(path.name)
            if path.is_dir() and match:
                found.add(match.group(1))
    return sorted(found)


def main(argv: list[str]) -> int:
    write = "--write" in argv
    offline_ok = "--offline-ok" in argv
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    deployments = manifest["deployments"]
    problems = []

    for program in source_programs():
        if program not in deployments:
            if write:
                deployments[program] = {"status": "legacy", "notes": "archived; recorded so the chain check watches it"}
            else:
                problems.append(f"{program}: has a folder in the tree but no entry under deployments, so nothing watches it")

    watched = manifest.get("watched", {})
    entries = list(deployments.items()) + list(watched.items())

    try:
        for program, entry in entries:
            found = on_chain(program)
            if write:
                entry.pop("edition", None)
                entry.pop("sha256", None)
                entry.pop("on_chain", None)
                if found is None:
                    entry["on_chain"] = False
                else:
                    entry["edition"], entry["sha256"] = found
                continue
            if entry.get("on_chain") is False:
                if found is not None:
                    problems.append(f"{program}: the manifest says it isn't on chain, and it is (edition {found[0]})")
                continue
            if "edition" not in entry or "sha256" not in entry:
                problems.append(f"{program}: the manifest records no edition and hash; run with --write and review the diff")
                continue
            if found is None:
                problems.append(f"{program}: the manifest says edition {entry['edition']} is on chain, and the explorer has no such program")
                continue
            edition, digest = found
            if edition != entry["edition"]:
                what = "It was upgraded: read the new text before anything else" if edition > entry["edition"] else "The manifest is ahead of the chain"
                if program in watched and edition > entry["edition"]:
                    what += "; it isn't ours, so Hewn's pins (@pnw/config EXTERNAL_EDITIONS) stop payments until a release lists it"
                problems.append(f"{program}: edition {edition} on chain, {entry['edition']} in the manifest. {what}")
            elif digest != entry["sha256"]:
                problems.append(f"{program}: edition {edition} as recorded, but its text on chain has a different hash")
    except Unreachable as error:
        if offline_ok and not write:
            print(f"chain check: SKIPPED - the explorer couldn't be reached ({error}); the daily chain-watch run is strict")
            return 0
        print(f"chain check: UNREACHABLE - {error}", file=sys.stderr)
        return 2

    if write:
        MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        there = sum(1 for e in deployments.values() if "edition" in e)
        print(f"chain check: wrote {there} programs' editions and hashes, {len(deployments) - there} not on chain, and {len(watched)} watched; review the diff")
        return 0
    if problems:
        print("chain check: FAIL", file=sys.stderr)
        for line in problems:
            print(f"  - {line}", file=sys.stderr)
        return 1
    there = sum(1 for e in deployments.values() if "edition" in e)
    upgraded = sorted(p for p, e in deployments.items() if e.get("edition", 0) > 0)
    print(f"chain check: PASS - {there} programs on chain are the edition and text recorded ({len(deployments) - there} recorded as not on chain), and {len(watched)} watched programs too; past edition 0: {', '.join(upgraded) or 'none'}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
