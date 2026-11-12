# Phase 4 CLI Setup (Provable / Aleo)

This guide prepares local environments for Phase 4 adapter execution work.

## Goal

Pin and verify CLI tooling before wiring execution adapters:
- `leo`
- `snarkos`

## 0) Pinned versions for this repo

Use these pins (updated 2026-11-06; Leo and snarkOS moved from ProvableHQ to
`aleo-labs-protocol` in late October 2026, and Leo's tags are `leo-lang-vX.Y.Z` since 4.1):

- `LEO_VERSION=4.0.0` (the language the programs are written in; Leo 4.4 refuses their source)
- `SNARKOS_VERSION=v4.12.0`

Reference artifacts (the checksums are in `.github/workflows/deploy.yml`):
- Leo: `https://github.com/aleo-labs-protocol/leo/releases/download/v4.0.0/leo-master-x86_64-unknown-linux-gnu.zip`
- snarkOS: `https://github.com/aleo-labs-protocol/snarkOS/releases/download/v4.12.0/aleo-v4.12.0-x86_64-unknown-linux-gnu.zip`

## CI (GitHub Actions)

`.github/workflows/deploy.yml` is the plan gate: it installs the pinned Leo and snarkOS, verifies
their versions and runs the checks and the Leo tests on every pull request and push to `main`. It
uses no secrets.

There is no execute workflow any more (removed 2026-11-12, `docs/archive/README.md`). It ran the
scripts below inside GitHub with an account's keys, on a push to a branch named `work` or by
hand. The harness still runs from your own machine with your own environment (section 8); no key
goes into GitHub for it.

Optional local workflow YAML validation (no PyYAML required):

```bash
scripts/validate_workflow_yaml.sh .github/workflows/deploy.yml
```

## 1) Scaffold status in this repo

The TypeScript adapter scaffold that used to live in `portal/` was deleted on 2026-11-04
(`docs/archive/README.md`). The harness runs the pre-built commands in `config/scenarios/`.

## 2) Resolve latest upstream tags (optional helper)

Use:

```bash
scripts/resolve_provable_cli_latest.sh
```

This attempts to read latest release tags from:
- `aleo-labs-protocol/leo`
- `aleo-labs-protocol/snarkOS`

> If your environment blocks GitHub, run this command on a machine with access and copy the tag values back into your local setup notes.

## 3) Export version pins in your shell

```bash
export LEO_VERSION="4.0.0"
export SNARKOS_VERSION="v4.12.0"
```

Keep these pins consistent across contributors for deterministic behavior.

Optional hardening (recommended in CI):

```bash
export LEO_SHA256="95bcda063c8f0abad5f7484f5f6dbf9e5608bf0e5ce78082e2da8469366df705"
export SNARKOS_SHA256="31818f467c1b6bef6376c932c72fc47209f78a3a93662057f9c77cdef7913545"
```

If set, CI validates downloaded artifacts with `sha256sum -c` before install.

The workflows are pinned to known-good SHA256 values for the current Leo/snarkOS URLs.
If you rotate versions/URLs, update the two SHA values in workflow env first, then optionally refresh repo variables/docs.


## 4) Install CLI tools (owner/operator machine)

Install from official Provable repos using your preferred method (cargo, prebuilt binaries, or internal setup scripts), pinned to the versions above.

## 5) Verify local toolchain

Run:

```bash
scripts/verify_provable_cli.sh
```

This validates command availability, prints detected versions, and checks against pinned versions when `LEO_VERSION` / `SNARKOS_VERSION` are set.

By default, version-token checks are non-strict (`STRICT_VERSION_CHECK=false`) because some Provable binaries print branch/commit metadata instead of release tags. Set `STRICT_VERSION_CHECK=true` to hard-fail on pin token mismatch in `--version` output.

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


## 8) Reproducible happy-path execute wrapper

Run the end-to-end testnet happy-path wrapper:

```bash
MANIFEST_PATH=config/testnet.manifest.json \
PNW_NETWORK=testnet \
RPC_URL="https://api.explorer.provable.com/v2" \
USDCX_PROGRAM_ID="test_usdcx_stablecoin.aleo" \
ALEO_PRIVATE_KEY="<private-key>" \
ALEO_VIEW_KEY="<view-key>" \
ALEO_ADDRESS="<address>" \
scripts/run_phase4_testnet_happy_path.sh \
  --scenario payroll_smoke \
  --scenario-file config/scenarios/testnet/min_spend.payroll.json \
  --execute-broadcast false
```

This wraps manifest validation, execute env checks, scenario execution, and emits a compact artifact summary.

`scripts/verify_phase4_execute_artifacts.py` checks the evidence bundle's integrity.
`scripts/verify_phase4_receipts.py` does a best-effort receipt verification (writes `artifacts/phase4_execute_bundle/receipt_verification.json`).
