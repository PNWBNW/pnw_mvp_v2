#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: scripts/dispatch_phase4_execute.sh --repo owner/repo --ref <branch-or-sha> --scenario <payroll_smoke|onboarding_smoke|nft_smoke> [--run-mode execute]

Dispatches the phase4-gates workflow in execute mode using the GitHub Actions workflow_dispatch API.

Required environment variables:
  GH_TOKEN   GitHub token with workflow dispatch permission for the target repository.

Optional environment variables:
  GITHUB_API_URL   Defaults to https://api.github.com
USAGE
}

REPO=""
REF=""
SCENARIO=""
RUN_MODE="execute"

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
    --run-mode)
      RUN_MODE="${2:-}"
      shift 2
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

if [[ "$RUN_MODE" != "execute" ]]; then
  echo "ERROR: --run-mode currently only supports 'execute'." >&2
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

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "ERROR: GH_TOKEN is required." >&2
  exit 1
fi

API_URL="${GITHUB_API_URL:-https://api.github.com}"
WORKFLOW_FILE="deploy.yml"

read -r -d '' PAYLOAD <<JSON || true
{
  "ref": "${REF}",
  "inputs": {
    "run_mode": "${RUN_MODE}",
    "scenario": "${SCENARIO}"
  }
}
JSON

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

echo "Dispatched ${WORKFLOW_FILE} on ${REPO}@${REF} with scenario='${SCENARIO}' and run_mode='${RUN_MODE}'."
