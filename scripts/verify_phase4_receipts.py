#!/usr/bin/env python3
"""Receipt verification for Phase4 execute tx_ids using RPC/explorer endpoints."""

from __future__ import annotations

import json
import sys
import time
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


def verify_with_retries(rpc_url: str, tx_id: str, attempts: int = 4) -> tuple[bool, str, str | None]:
    last_detail = ""
    for attempt in range(1, attempts + 1):
        ok, detail = get_url(f"{rpc_url.rstrip('/')}/transaction/{tx_id}")
        if ok:
            return True, detail, "http:/transaction/{id}"

        ok2, detail2 = post_json(rpc_url, {"jsonrpc": "2.0", "id": attempt, "method": "getTransaction", "params": {"id": tx_id}})
        if ok2:
            return True, detail2, "rpc:getTransaction"

        last_detail = f"attempt {attempt}/{attempts}: {detail}; {detail2}"
        if attempt < attempts:
            time.sleep(min(2 ** (attempt - 1), 4))

    return False, last_detail or "verification failed", None


def main() -> None:
    if len(sys.argv) not in (3, 4):
        print("usage: scripts/verify_phase4_receipts.py <artifact_dir> <rpc_url> [best_effort|required]", file=sys.stderr)
        raise SystemExit(1)

    base = Path(sys.argv[1])
    rpc_url = sys.argv[2].strip()
    mode = (sys.argv[3].strip() if len(sys.argv) == 4 else "best_effort")
    if mode not in {"best_effort", "required"}:
        print("receipt verification: FAIL - mode must be best_effort or required", file=sys.stderr)
        raise SystemExit(1)

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
        "mode": mode,
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

        ok, detail, method = verify_with_retries(rpc_url, tx_id)
        if ok:
            result.update({"verified": True, "method": method, "detail": detail})
            report["verified"] += 1
        else:
            result.update({"detail": detail})
            report["missing"] += 1
        report["results"].append(result)

    report["status"] = "pass" if report["missing"] == 0 else ("fail" if mode == "required" else "warn")
    (base / "receipt_verification.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    if report["missing"] == 0:
        print(f"receipt verification: PASS - verified {report['verified']}/{report['total_entries']}")
        return

    msg = f"receipt verification: {'FAIL' if mode == 'required' else 'WARN'} - verified {report['verified']}/{report['total_entries']} (missing={report['missing']})"
    print(msg, file=sys.stderr)
    if mode == "required":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
