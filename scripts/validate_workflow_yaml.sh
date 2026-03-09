#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -gt 0 ]]; then
  WORKFLOW_PATHS=("$@")
else
  WORKFLOW_PATHS=(
    .github/workflows/deploy.yml
    .github/workflows/execute_testnet.yml
  )
fi

for WORKFLOW_PATH in "${WORKFLOW_PATHS[@]}"; do
  if [[ ! -f "$WORKFLOW_PATH" ]]; then
    echo "ERROR: workflow file not found: $WORKFLOW_PATH" >&2
    exit 1
  fi

  # Ruby ships with a standard YAML parser on most CI/dev images.
  ruby -e 'require "yaml"; path=ARGV[0]; YAML.safe_load(File.read(path), permitted_classes: [], aliases: true); puts "workflow yaml parse: PASS - #{path}"' "$WORKFLOW_PATH"
done
