# Phase 4 CLI Setup (Provable / Aleo)

This guide prepares local environments for Phase 4 adapter execution work.

## Goal

Pin and verify CLI tooling before wiring execution adapters:
- `leo`
- `snarkos`

## 1) Resolve latest upstream tags (optional helper)

Use:

```bash
scripts/resolve_provable_cli_latest.sh
```

This attempts to read latest release tags from:
- `ProvableHQ/leo`
- `ProvableHQ/snarkOS`

> If your environment blocks GitHub, run this command on a machine with access and copy the tag values back into your local setup notes.

## 2) Pin versions for your workstation

Record chosen versions (example):

```bash
export LEO_VERSION="<pin-me>"
export SNARKOS_VERSION="<pin-me>"
```

Keep these pins consistent across contributors for deterministic behavior.

## 3) Install CLI tools (owner/operator machine)

Install from official Provable repos using your preferred method (cargo, prebuilt binaries, or internal setup scripts), pinned to the versions above.

## 4) Verify local toolchain

Run:

```bash
scripts/verify_provable_cli.sh
```

This validates command availability and prints versions.

## 5) Phase 4 readiness gate

Before adapter PRs, ensure:
- both commands are installed,
- versions are pinned in team notes,
- and verification output is captured in PR testing notes.
