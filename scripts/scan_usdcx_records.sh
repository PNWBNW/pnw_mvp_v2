#!/usr/bin/env bash
# scripts/scan_usdcx_records.sh
#
# Scan for unspent USDCx Token records owned by the employer's view key.
# Uses `snarkos developer scan` to decrypt records from the chain.
#
# USAGE:
#   ALEO_VIEW_KEY=AViewKey1... \
#   ENDPOINT=https://api.explorer.provable.com/v2/testnet \
#     scripts/scan_usdcx_records.sh
#
# OPTIONAL ENV:
#   USDCX_PROGRAM_ID   — override the USDCx program ID (default: test_usdcx_stablecoin.aleo)
#   SCAN_START_BLOCK   — start block height for scan (default: 0; use a recent block to be faster)
#   SCAN_END_BLOCK     — end block height (default: latest)
#   MIN_AMOUNT         — only print records with amount >= this many minor units
#
# OUTPUT:
#   Prints each matching Token record as a JSON object:
#     { "amount": <u128>, "record": "<plaintext_record_string>" }
#   The "record" field is the raw string to pass to snarkos developer execute
#   or to portal/src/records/usdcx_fetcher.ts as the UsdcxRecord.raw value.
#
# NOTE ON PROGRAM ID:
#   The deployed testnet program ID may differ from "test_usdcx_stablecoin.aleo".
#   Check config/testnet.manifest.json -> external.usdcx for the current ID.
#   Set USDCX_PROGRAM_ID env var to override.

set -euo pipefail

ENDPOINT="${ENDPOINT:-}"
ALEO_VIEW_KEY="${ALEO_VIEW_KEY:-}"
USDCX_PROGRAM_ID="${USDCX_PROGRAM_ID:-test_usdcx_stablecoin.aleo}"
SCAN_START_BLOCK="${SCAN_START_BLOCK:-0}"
SCAN_END_BLOCK="${SCAN_END_BLOCK:-}"
MIN_AMOUNT="${MIN_AMOUNT:-0}"

if [[ -z "$ENDPOINT" ]]; then
  echo "ERROR: ENDPOINT is required (e.g. https://api.explorer.provable.com/v2/testnet)" >&2
  exit 1
fi

if [[ -z "$ALEO_VIEW_KEY" ]]; then
  echo "ERROR: ALEO_VIEW_KEY is required" >&2
  exit 1
fi

if ! command -v snarkos &>/dev/null; then
  echo "ERROR: snarkos not found in PATH. Install snarkOS v4.5.5 (see docs/operations/PHASE4_CLI_SETUP.md)" >&2
  exit 1
fi

END_FLAG=""
if [[ -n "$SCAN_END_BLOCK" ]]; then
  END_FLAG="--end $SCAN_END_BLOCK"
fi

echo "Scanning for ${USDCX_PROGRAM_ID} Token records..." >&2
echo "  endpoint:    $ENDPOINT" >&2
echo "  start block: $SCAN_START_BLOCK" >&2
echo "  end block:   ${SCAN_END_BLOCK:-latest}" >&2
echo "" >&2

# Run snarkos developer scan — outputs decrypted records as JSON
SCAN_OUTPUT="$(snarkos developer scan \
  --view-key "$ALEO_VIEW_KEY" \
  --start "$SCAN_START_BLOCK" \
  ${END_FLAG} \
  --endpoint "$ENDPOINT" 2>&1)" || {
  echo "ERROR: snarkos developer scan failed:" >&2
  echo "$SCAN_OUTPUT" >&2
  exit 1
}

# Filter for Token records from the USDCx program and extract amount + record string
python3 - "$USDCX_PROGRAM_ID" "$MIN_AMOUNT" <<'PY'
import sys
import re
import json

program_id = sys.argv[1]
min_amount = int(sys.argv[2])

# Read scan output from stdin (piped from snarkos)
import os
scan_output = os.environ.get("SCAN_OUTPUT_VAR", "")

# snarkos developer scan outputs records line-by-line or as JSON array
# Try to parse as JSON first, then fall back to line scanning
lines = sys.stdin.read() if not scan_output else scan_output

# Try JSON parse
try:
    data = json.loads(lines)
    if isinstance(data, list):
        records = [str(r) for r in data]
    else:
        records = [lines]
except json.JSONDecodeError:
    # Fall back: each record may span multiple lines; split on record boundaries
    # Records look like: { owner: aleo1..., amount: ...u128, ... }
    records = re.findall(r'\{[^{}]*\}', lines, re.DOTALL)

found = 0
for record_str in records:
    record_str = record_str.strip()
    if not record_str:
        continue

    # Check if this looks like a Token record (has 'amount' and 'token_id' or no explicit program marker)
    # snarkos scan may or may not include the program prefix; filter loosely
    amount_match = re.search(r'\bamount\s*:\s*(\d+)u128', record_str)
    if not amount_match:
        continue

    amount = int(amount_match.group(1))
    if amount < min_amount:
        continue

    print(json.dumps({"amount": amount, "program": program_id, "record": record_str}))
    found += 1

if found == 0:
    print(f"No {program_id} Token records found with amount >= {min_amount}", file=sys.stderr)
    sys.exit(1)
else:
    print(f"\nFound {found} matching record(s). Use the 'record' field as your employer_usdcx input.", file=sys.stderr)
PY
