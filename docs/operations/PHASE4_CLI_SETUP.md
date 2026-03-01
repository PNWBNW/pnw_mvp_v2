# Phase 4 CLI Setup (Provable / Aleo)

This guide prepares local environments for Phase 4 adapter execution work.

## Goal

Pin and verify CLI tooling before wiring execution adapters:
- `leo`
- `snarkos`

## 0) Pinned versions for this repo

Use these pins for Phase 4:

- `LEO_VERSION=canary-v3.5.0`
- `SNARKOS_VERSION=v4.4.0`

Reference artifacts:
- Leo: `https://github.com/ProvableHQ/leo/releases/download/canary-v3.5.0/leo-canary-v3.5.0-x86_64-unknown-linux-gnu.zip`
- snarkOS: `https://github.com/ProvableHQ/snarkOS/releases/download/v4.4.0/aleo-v4.4.0-x86_64-unknown-linux-gnu.zip`

## CI workflow bootstrap (GitHub Actions)

This repo also includes a pinned workflow bootstrap:
- `.github/workflows/deploy.yml`

It installs pinned Leo/snarkOS binaries, verifies versions, and runs both planner typecheck gates.
Use `workflow_dispatch` with:
- `run_mode=plan_only` (default), or
- `run_mode=execute` (records intent; full execution wiring lands in follow-up PRs).

## 1) Scaffold status in this repo

Phase 4 now includes a baseline Layer 2 adapter scaffold:
- `portal/src/adapters/aleo_cli_adapter.ts` (plan-only + execute-mode trace shape)
- `portal/tsconfig.phase4.json` (focused adapter scaffold typecheck gate)

Validate scaffold typing with:

```bash
npx --yes --package typescript tsc -p portal/tsconfig.phase4.json
```

## 2) Resolve latest upstream tags (optional helper)

Use:

```bash
scripts/resolve_provable_cli_latest.sh
```

This attempts to read latest release tags from:
- `ProvableHQ/leo`
- `ProvableHQ/snarkOS`

> If your environment blocks GitHub, run this command on a machine with access and copy the tag values back into your local setup notes.

## 3) Export version pins in your shell

```bash
export LEO_VERSION="canary-v3.5.0"
export SNARKOS_VERSION="v4.4.0"
```

Keep these pins consistent across contributors for deterministic behavior.

## 4) Install CLI tools (owner/operator machine)

Install from official Provable repos using your preferred method (cargo, prebuilt binaries, or internal setup scripts), pinned to the versions above.

## 5) Verify local toolchain

Run:

```bash
scripts/verify_provable_cli.sh
```

This validates command availability, prints detected versions, and checks against pinned versions when `LEO_VERSION` / `SNARKOS_VERSION` are set.

## 6) Phase 4 readiness gate

Before adapter PRs, ensure:
- both commands are installed,
- pinned versions match detected versions,
- and verification output is captured in PR testing notes.

## 7) Testnet manifest validation (new gate)

Phase 4 now includes a canonical testnet manifest and validator:
- `config/testnet.manifest.json`
- `scripts/validate_testnet_manifest.py`

Run locally:

```bash
python3 scripts/validate_testnet_manifest.py config/testnet.manifest.json
```

Execute-mode workflows also require env/secrets presence checks via:

```bash
scripts/require_phase4_execute_env.sh
```
