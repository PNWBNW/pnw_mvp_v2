#!/usr/bin/env bash
set -euo pipefail

# Attempts to resolve latest release tags for Provable CLI repos.
# Requires: curl, jq, network access to api.github.com

resolve_latest_tag() {
  local repo="$1"
  curl -fsSL \
    -H 'Accept: application/vnd.github+json' \
    -H 'User-Agent: pnw-mvp-v2-phase4-bootstrap' \
    "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name'
}

echo "Resolving latest release tags from ProvableHQ..."

echo "LEO_REPO=ProvableHQ/leo"
if leo_tag=$(resolve_latest_tag "ProvableHQ/leo" 2>/dev/null); then
  echo "LEO_LATEST_TAG=${leo_tag}"
else
  echo "LEO_LATEST_TAG=<unresolved>"
  echo "WARN: Could not resolve ProvableHQ/leo latest tag (network/rate-limit/access issue)." >&2
fi

echo "SNARKOS_REPO=ProvableHQ/snarkOS"
if snarkos_tag=$(resolve_latest_tag "ProvableHQ/snarkOS" 2>/dev/null); then
  echo "SNARKOS_LATEST_TAG=${snarkos_tag}"
else
  echo "SNARKOS_LATEST_TAG=<unresolved>"
  echo "WARN: Could not resolve ProvableHQ/snarkOS latest tag (network/rate-limit/access issue)." >&2
fi
