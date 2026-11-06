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

# Leo and snarkOS moved from ProvableHQ to aleo-labs-protocol (late October 2026). Leo's
# releases are tagged leo-lang-vX.Y.Z since 4.1; snarkOS keeps vX.Y.Z.
echo "Resolving latest release tags from aleo-labs-protocol..."

echo "LEO_REPO=aleo-labs-protocol/leo"
if leo_tag=$(resolve_latest_tag "aleo-labs-protocol/leo" 2>/dev/null); then
  echo "LEO_LATEST_TAG=${leo_tag}"
else
  echo "LEO_LATEST_TAG=<unresolved>"
  echo "WARN: Could not resolve aleo-labs-protocol/leo latest tag (network/rate-limit/access issue)." >&2
fi

echo "SNARKOS_REPO=aleo-labs-protocol/snarkOS"
if snarkos_tag=$(resolve_latest_tag "aleo-labs-protocol/snarkOS" 2>/dev/null); then
  echo "SNARKOS_LATEST_TAG=${snarkos_tag}"
else
  echo "SNARKOS_LATEST_TAG=<unresolved>"
  echo "WARN: Could not resolve aleo-labs-protocol/snarkOS latest tag (network/rate-limit/access issue)." >&2
fi
