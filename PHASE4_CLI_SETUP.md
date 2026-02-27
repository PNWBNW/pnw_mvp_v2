# Phase 4 CLI Setup (Provable / Aleo)

This guide prepares local environments for Phase 4 adapter execution work.

## Goal

Pin and verify CLI tooling before wiring execution adapters:
- `leo`
- `aleo` (from snarkOS release artifacts)

## Required CLI binaries (current Phase 4 scope)

For this repo's current Phase 4 bootstrap, only these executables are required:

1. `leo`
   - Source: `ProvableHQ/leo` release artifact
   - Purpose: Leo program tooling used by build/compile related steps

2. `aleo`
   - Source: `ProvableHQ/snarkOS` release artifact (`aleo-...zip`)
   - Purpose: chain/client CLI used for network-facing operations in follow-up execution wiring

Not required for the current bootstrap gates:
- `snarkos` daemon binary
- local validator/network process

The CI workflow is intentionally remote-first and currently verifies only `leo` + `aleo` plus TypeScript gates.

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

It installs pinned Leo plus the Aleo CLI binary from snarkOS releases, verifies versions, and runs both planner typecheck gates.
Use `workflow_dispatch` with:
- `run_mode=plan_only` (default), or
- `run_mode=execute` (records intent; full execution wiring lands in follow-up PRs).

## 1) Scaffold status in this repo

Phase 4 now includes a baseline Layer 2 adapter scaffold:
- `portal/src/adapters/aleo_cli_adapter.ts` (plan-only + execute-mode trace shape)
- `portal/tsconfig.phase4.json` (focused adapter scaffold typecheck gate)

Validate scaffold typing with:

```bash
npx --yes tsc -p portal/tsconfig.phase4.json
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
export SNARKOS_CLI_CMD="aleo"
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

By default it validates snarkOS version against `aleo --version`. Override with `SNARKOS_CLI_CMD` only if your environment intentionally uses a different command name.

## 6) Phase 4 readiness gate

Before adapter PRs, ensure:
- `leo` and `aleo` are installed,
- pinned versions match detected versions,
- and verification output is captured in PR testing notes.
