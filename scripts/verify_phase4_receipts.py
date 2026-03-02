#!/usr/bin/env python3
"""Best-effort receipt verification for Phase4 execute tx_ids using RPC/explorer endpoints."""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def post_json(url: str, payload: dict[str, Any], timeout_s: float = 8.0) -> tuple[bool, str]:
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            text = resp.read().decode("utf-8", errors="replace")
            data = json.loads(text)
            if isinstance(data, dict) and data.get("error"):
                return False, f"rpc error: {data.get('error')}"
            if isinstance(data, dict) and data.get("result") is not None:
                return True, "rpc result present"
            return False, "rpc result missing"
    except Exception as e:  # noqa: BLE001
        return False, f"rpc request failed: {e}"


def get_url(url: str, timeout_s: float = 8.0) -> tuple[bool, str]:
    req = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as resp:
            text = resp.read().decode("utf-8", errors="replace")
            if resp.status == 200 and text.strip():
                return True, "http 200 with body"
            return False, f"http {resp.status}"
    except urllib.error.HTTPError as e:
        return False, f"http error {e.code}"
    except Exception as e:  # noqa: BLE001
        return False, f"http request failed: {e}"


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: scripts/verify_phase4_receipts.py <artifact_dir> <rpc_url>", file=sys.stderr)
        raise SystemExit(1)

    base = Path(sys.argv[1])
    rpc_url = sys.argv[2].strip()
    tx_file = base / "tx_ids.json"
    if not tx_file.is_file():
        print("receipt verification: FAIL - tx_ids.json not found", file=sys.stderr)
        raise SystemExit(1)

    payload = load_json(tx_file)
    entries = payload.get("tx_ids")
    if not isinstance(entries, list):
        print("receipt verification: FAIL - tx_ids must be a list", file=sys.stderr)
        raise SystemExit(1)

    report: dict[str, Any] = {
        "schema_version": "phase4.receipt_verification.v1",
        "rpc_url": rpc_url or None,
        "total_entries": len(entries),
        "verified": 0,
        "missing": 0,
        "results": [],
    }

    if not entries:
        report["status"] = "skip"
        report["reason"] = "no_tx_ids"
        (base / "receipt_verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print("receipt verification: PASS - skipped (no tx ids)")
        return

    for i, entry in enumerate(entries):
        tx_id = entry.get("tx_id") if isinstance(entry, dict) else None
        result = {"index": i, "tx_id": tx_id, "verified": False, "method": None, "detail": None}

        if not tx_id or not isinstance(tx_id, str):
            result["detail"] = "missing tx_id"
            report["missing"] += 1
            report["results"].append(result)
            continue

        ok, detail = post_json(rpc_url, {"jsonrpc": "2.0", "id": i + 1, "method": "getTransaction", "params": {"id": tx_id}})
        if ok:
            result.update({"verified": True, "method": "rpc:getTransaction", "detail": detail})
            report["verified"] += 1
            report["results"].append(result)
            continue

        ok2, detail2 = get_url(f"{rpc_url.rstrip('/')}/transaction/{tx_id}")
        if ok2:
            result.update({"verified": True, "method": "http:/transaction/{id}", "detail": detail2})
            report["verified"] += 1
        else:
            result.update({"detail": f"{detail}; {detail2}"})
            report["missing"] += 1
        report["results"].append(result)

    report["status"] = "pass" if report["missing"] == 0 else "warn"
    (base / "receipt_verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    if report["missing"] == 0:
        print(f"receipt verification: PASS - verified {report['verified']}/{report['total_entries']}")
    else:
        print(
            f"receipt verification: WARN - verified {report['verified']}/{report['total_entries']} (missing={report['missing']})",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
