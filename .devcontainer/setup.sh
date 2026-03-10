#!/usr/bin/env bash
# PNW MVP v2 — Codespace bootstrap
# Installs Leo + snarkOS at the exact pinned versions used by CI.
set -euo pipefail

LEO_VERSION="3.5.0"
SNARKOS_VERSION="v4.5.1"
LEO_URL="https://github.com/ProvableHQ/leo/releases/download/v${LEO_VERSION}/leo-release-3.5-x86_64-unknown-linux-gnu.zip"
SNARKOS_URL="https://github.com/ProvableHQ/snarkOS/releases/download/${SNARKOS_VERSION}/aleo-v4.5.1-x86_64-unknown-linux-gnu.zip"
SNARKOS_SHA256="f32830e828a3e6ecb403bbc3ad6969b05f1b47e5de687f03f09d7662a6fbcd3c"

echo "=== Installing Leo ${LEO_VERSION} ==="
curl -fsSL "$LEO_URL" -o /tmp/leo.zip
if [[ -n "${LEO_SHA256:-}" ]]; then
  echo "${LEO_SHA256}  /tmp/leo.zip" | sha256sum -c -
else
  echo "WARN: LEO_SHA256 not set; skipping Leo artifact checksum verification"
fi
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
# Secrets (ALEO_PRIVATE_KEY etc.) are injected via Codespace secrets — not stored here.
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "INFO: Copied .env.example → .env"
  echo "      Fill in ALEO_PRIVATE_KEY / ALEO_VIEW_KEY / ALEO_ADDRESS before running execute scripts."
fi

echo ""
echo "=== Toolchain ready ==="
leo --version
snarkos --version
node --version
python3 --version
echo ""
echo "Run plan-gate validation:"
echo "  npx --yes --package typescript tsc -p portal/tsconfig.phase4.json"
echo "  bash scripts/run_phase4_adapter_tests.sh"
echo "  python3 scripts/validate_testnet_manifest.py config/testnet.manifest.json"
