#!/usr/bin/env bash
# PNW MVP v2 — Codespace bootstrap
# Installs Leo + snarkOS at the exact pinned versions used by CI.
set -euo pipefail

LEO_VERSION="4.4.6"
SNARKOS_VERSION="v4.12.0"
LEO_URL="https://github.com/aleo-labs-protocol/leo/releases/download/leo-lang-v${LEO_VERSION}/leo-lang-v${LEO_VERSION}-x86_64-unknown-linux-gnu.zip"
SNARKOS_URL="https://github.com/aleo-labs-protocol/snarkOS/releases/download/${SNARKOS_VERSION}/aleo-${SNARKOS_VERSION}-x86_64-unknown-linux-gnu.zip"
LEO_SHA256="7888ee2f03554590d9ac9d61ba02a8d0833e37b5b24666f79a735317a0ad8902"
SNARKOS_SHA256="31818f467c1b6bef6376c932c72fc47209f78a3a93662057f9c77cdef7913545"

echo "=== Installing Leo ${LEO_VERSION} ==="
curl -fsSL "$LEO_URL" -o /tmp/leo.zip
echo "${LEO_SHA256}  /tmp/leo.zip" | sha256sum -c -
unzip -q /tmp/leo.zip -d /tmp/leo-bin
sudo install -m 755 /tmp/leo-bin/leo /usr/local/bin/leo
rm -rf /tmp/leo.zip /tmp/leo-bin

echo "=== Installing snarkOS ${SNARKOS_VERSION} ==="
curl -fsSL "$SNARKOS_URL" -o /tmp/snarkos.zip
echo "${SNARKOS_SHA256}  /tmp/snarkos.zip" | sha256sum -c -
unzip -q /tmp/snarkos.zip -d /tmp/snarkos-bin
sudo install -m 755 /tmp/snarkos-bin/snarkos /usr/local/bin/snarkos
rm -rf /tmp/snarkos.zip /tmp/snarkos-bin

# Bootstrap .env from example so plan-gate scripts work immediately.
# Secrets (PRIVATE_KEY etc.) are injected via Codespace secrets — not stored here.
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "INFO: Copied .env.example → .env"
  echo "      Fill in PRIVATE_KEY / ALEO_VIEW_KEY / ALEO_ADDRESS before running execute scripts."
fi

echo ""
echo "=== Toolchain ready ==="
leo --version
snarkos --version
node --version
python3 --version
echo ""
echo "Run plan-gate validation:"
echo "  python3 scripts/validate_testnet_manifest.py config/testnet.manifest.json"
