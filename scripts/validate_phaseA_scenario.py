#!/usr/bin/env python3
"""Minimal validator for config/scenarios/schema.phaseA.json payloads.

Dependency-free validator so operators can run checks without pip installs.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

FIELD_HEX_RE = re.compile(r"^0x[0-9a-fA-F]{1,64}$")
BYTES32_HEX_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
ALEO_ADDRESS_RE = re.compile(r"^aleo1[0-9a-z]{30,80}$")
U128_STR_RE = re.compile(r"^[0-9]+$")


def fail(msg: str) -> None:
    print(f"phaseA scenario validation: FAIL - {msg}", file=sys.stderr)
    raise SystemExit(1)


def expect(condition: bool, msg: str) -> None:
    if not condition:
        fail(msg)


def expect_key(obj: dict, key: str, where: str) -> None:
    expect(key in obj, f"missing key '{where}.{key}'")


def local_name_hash(name_raw: str) -> str:
    normalized = " ".join(name_raw.strip().split()).lower()
    digest = hashlib.sha256(f"pnw:phaseA:v1:{normalized}".encode("utf-8")).hexdigest()
    return f"0x{digest}"


def validate_payroll(payroll: dict) -> None:
    required = [
        "agreement_id_hex",
        "epoch_id",
        "gross_amount",
        "net_amount",
        "tax_withheld",
        "fee_amount",
        "receipt_anchor_hex",
        "receipt_pair_hash_hex",
        "payroll_inputs_hash_hex",
        "utc_time_hash_hex",
        "audit_event_hash_hex",
        "employer_usdcx_record",
    ]
    for key in required:
        expect_key(payroll, key, "payroll")

    expect(BYTES32_HEX_RE.match(str(payroll["agreement_id_hex"])) is not None, "payroll.agreement_id_hex invalid")
    epoch_id = payroll["epoch_id"]
    expect(isinstance(epoch_id, int) and 0 <= epoch_id <= 2**32 - 1, "payroll.epoch_id must be u32")

    for k in ("gross_amount", "net_amount", "tax_withheld", "fee_amount"):
        val = str(payroll[k])
        expect(U128_STR_RE.match(val) is not None, f"payroll.{k} must be decimal string")

    gross = int(str(payroll["gross_amount"]))
    net = int(str(payroll["net_amount"]))
    tax = int(str(payroll["tax_withheld"]))
    fee = int(str(payroll["fee_amount"]))
    expect(net <= gross, "payroll.net_amount cannot exceed gross_amount")
    expect(net + tax + fee <= gross, "payroll.net_amount + tax_withheld + fee_amount cannot exceed gross_amount")

    for k in (
        "receipt_anchor_hex",
        "receipt_pair_hash_hex",
        "payroll_inputs_hash_hex",
        "utc_time_hash_hex",
        "audit_event_hash_hex",
    ):
        expect(BYTES32_HEX_RE.match(str(payroll[k])) is not None, f"payroll.{k} invalid bytes32 hex")

    record = payroll.get("employer_usdcx_record")
    expect(isinstance(record, dict), "payroll.employer_usdcx_record must be object")
    raw = record.get("raw")
    expect(isinstance(raw, str) and len(raw) >= 8, "payroll.employer_usdcx_record.raw must be non-empty string")


def validate_onboarding(onboarding: dict) -> None:
    required = ["employer_suffix_code", "employer_suffix_label", "worker_fee_amount", "employer_fee_amount"]
    for key in required:
        expect_key(onboarding, key, "onboarding")

    suffix_code = onboarding["employer_suffix_code"]
    expect(isinstance(suffix_code, int) and 1 <= suffix_code <= 40, "onboarding.employer_suffix_code must be in [1,40]")
    expect(isinstance(onboarding["employer_suffix_label"], str) and len(onboarding["employer_suffix_label"].strip()) > 0, "onboarding.employer_suffix_label invalid")

    for key in ("worker_fee_amount", "employer_fee_amount"):
        expect(U128_STR_RE.match(str(onboarding[key])) is not None, f"onboarding.{key} must be decimal string")


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: scripts/validate_phaseA_scenario.py <scenario.json>")

    path = Path(sys.argv[1])
    expect(path.is_file(), f"file not found: {path}")

    with path.open("r", encoding="utf-8") as f:
        data = json.load(f)

    expect(data.get("schema_version") == "phaseA.scenario.v1", "schema_version must be phaseA.scenario.v1")
    expect(data.get("network") in {"testnet", "mainnet"}, "network must be testnet|mainnet")
    expect(data.get("execution_mode") in {"plan_only", "dry_run", "broadcast"}, "execution_mode invalid")
    expect(data.get("scenario_kind") in {"payroll", "onboarding"}, "scenario_kind must be payroll|onboarding")

    participants = data.get("participants")
    expect(isinstance(participants, dict), "participants must be object")
    for role in ("employer", "worker"):
        expect_key(participants, role, "participants")
        p = participants[role]
        expect(isinstance(p, dict), f"participants.{role} must be object")
        name_hash = str(p.get("name_hash_hex", ""))
        expect(FIELD_HEX_RE.match(name_hash) is not None, f"participants.{role}.name_hash_hex invalid")
        expect(ALEO_ADDRESS_RE.match(str(p.get("address", ""))) is not None, f"participants.{role}.address invalid")

        name_raw = p.get("name_raw")
        if name_raw is not None:
            expect(isinstance(name_raw, str) and len(name_raw.strip()) > 0, f"participants.{role}.name_raw invalid")
            expected_hash = local_name_hash(name_raw)
            expect(
                name_hash.lower() == expected_hash.lower(),
                f"participants.{role}.name_hash_hex does not match local hash of name_raw (expected {expected_hash})",
            )

    scenario_kind = data["scenario_kind"]
    if scenario_kind == "payroll":
        payroll = data.get("payroll")
        expect(isinstance(payroll, dict), "payroll must be object for scenario_kind=payroll")
        validate_payroll(payroll)
    else:
        onboarding = data.get("onboarding")
        expect(isinstance(onboarding, dict), "onboarding must be object for scenario_kind=onboarding")
        validate_onboarding(onboarding)

    print(f"phaseA scenario validation: PASS - {path}")


if __name__ == "__main__":
    main()
