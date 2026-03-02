#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: scripts/dispatch_phase4_execute.sh --repo owner/repo --ref <branch-or-sha> --scenario <payroll_smoke|onboarding_smoke|nft_smoke> [--scenario-file <path>] [--execute-broadcast <true|false>] [--broadcast-commands-file <path>] [--dry-run]

Dispatches the phase4 testnet execute workflow using the GitHub Actions workflow_dispatch API.

Required environment variables:
  GH_TOKEN   GitHub token with workflow dispatch permission for the target repository.

Optional environment variables:
  GITHUB_API_URL   Defaults to https://api.github.com
USAGE
}

REPO=""
REF=""
SCENARIO=""
SCENARIO_FILE=""
EXECUTE_BROADCAST="false"
BROADCAST_COMMANDS_FILE=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:-}"
      shift 2
      ;;
    --ref)
      REF="${2:-}"
      shift 2
      ;;
    --scenario)
      SCENARIO="${2:-}"
      shift 2
      ;;
    --scenario-file)
      SCENARIO_FILE="${2:-}"
      shift 2
      ;;
    --execute-broadcast)
      EXECUTE_BROADCAST="${2:-}"
      shift 2
      ;;
    --broadcast-commands-file)
      BROADCAST_COMMANDS_FILE="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$REPO" || -z "$REF" || -z "$SCENARIO" ]]; then
  echo "ERROR: --repo, --ref, and --scenario are required." >&2
  usage >&2
  exit 1
fi

case "$SCENARIO" in
  payroll_smoke|onboarding_smoke|nft_smoke)
    ;;
  *)
    echo "ERROR: unsupported scenario '$SCENARIO'." >&2
    exit 1
    ;;
esac

if [[ "$EXECUTE_BROADCAST" != "true" && "$EXECUTE_BROADCAST" != "false" ]]; then
  echo "ERROR: --execute-broadcast must be true or false." >&2
  exit 1
fi

if [[ "$DRY_RUN" != "true" && -z "${GH_TOKEN:-}" ]]; then
  echo "ERROR: GH_TOKEN is required." >&2
  exit 1
fi

API_URL="${GITHUB_API_URL:-https://api.github.com}"
WORKFLOW_FILE="execute_testnet.yml"

read -r -d '' PAYLOAD <<JSON || true
{
  "ref": "${REF}",
  "inputs": {
    "scenario": "${SCENARIO}",
    "scenario_file": "${SCENARIO_FILE}",
    "execute_broadcast": "${EXECUTE_BROADCAST}",
    "broadcast_commands_file": "${BROADCAST_COMMANDS_FILE}"
  }
}
JSON

if [[ "$DRY_RUN" == "true" ]]; then
  echo "DRY RUN: would dispatch ${WORKFLOW_FILE} on ${REPO}@${REF} with payload:"
  echo "$PAYLOAD"
  exit 0
fi

HTTP_CODE=$(curl -sS -o /tmp/phase4_dispatch_response.json -w "%{http_code}" \
  -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${GH_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "${API_URL}/repos/${REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches" \
  -d "$PAYLOAD")

if [[ "$HTTP_CODE" != "204" ]]; then
  echo "ERROR: dispatch failed with status ${HTTP_CODE}. Response:" >&2
  cat /tmp/phase4_dispatch_response.json >&2
  exit 1
fi

echo "Dispatched ${WORKFLOW_FILE} on ${REPO}@${REF} with scenario='${SCENARIO}' scenario_file='${SCENARIO_FILE}', execute_broadcast='${EXECUTE_BROADCAST}', and broadcast_commands_file='${BROADCAST_COMMANDS_FILE}'."
