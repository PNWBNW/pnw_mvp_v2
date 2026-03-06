# Phase 4 CLI Setup (Provable / Aleo)

This guide prepares local environments for Phase 4 adapter execution work.

## Goal

Pin and verify CLI tooling before wiring execution adapters:
- `leo`
- `snarkos`

## 0) Pinned versions for this repo

Use these pins for Phase 4:

- `LEO_VERSION=3.4.0`
- `SNARKOS_VERSION=v4.4.0`

Reference artifacts:
- Leo: `https://github.com/ProvableHQ/leo/releases/download/v3.4.0/leo-v3.4.0-x86_64-unknown-linux-gnu.zip`
- snarkOS: `https://github.com/ProvableHQ/snarkOS/releases/download/v4.4.0/aleo-v4.4.0-x86_64-unknown-linux-gnu.zip`

## CI workflow bootstrap (GitHub Actions)

This repo now uses split workflows:
- `.github/workflows/deploy.yml` for plan/test gates only
- `.github/workflows/execute_testnet.yml` for testnet execute gate

`deploy.yml` installs pinned Leo/snarkOS binaries, verifies versions, and runs planner/typecheck/test guards (triggered on pull requests and pushes to `main`).
`execute_testnet.yml` runs execute-mode scenarios on `work` pushes or manual `workflow_dispatch`.

Optional local workflow YAML validation (no PyYAML required):

```bash
scripts/validate_workflow_yaml.sh .github/workflows/deploy.yml
scripts/validate_workflow_yaml.sh .github/workflows/execute_testnet.yml
```


### Dispatch execute runs from an app/backend

If you are building a React/dApp UI, trigger workflow dispatch from a backend service (not directly from browser code).

Helper script:

```bash
GH_TOKEN="<github-token>" \
  scripts/dispatch_phase4_execute.sh \
  --repo "<owner>/<repo>" \
  --ref "main" \
  --scenario "payroll_smoke" \
  --scenario-file "config/scenarios/testnet/min_spend.payroll.json" \
  --execute-broadcast "false" \
  --broadcast-commands-file "config/scenarios/testnet/broadcast_commands.sample.json" \
  # OR pass inline JSON from this interface:
  # --broadcast-commands-json "{\"schema_version\":\"phase4.broadcast_commands.v1\",\"commands\":[{\"name\":\"submit\",\"command\":\"<real command>\"}]}"
```

This sends the selected `scenario` into `.github/workflows/execute_testnet.yml`.

`execute_gate` runs automatically on pushes to the `work` branch (testnet-staging environment), or by manual workflow dispatch.

You can preview the exact dispatch payload without calling GitHub using `--dry-run`.

The workflow is streamlined to a single operator choice (`scenario`). Scenario payload path is resolved automatically by workflow mapping.

Broadcast mode is hardcoded ON in this lane (`EXECUTE_BROADCAST=true`) with strict receipt verification (`RECEIPT_VERIFICATION_MODE=required`) for testnet-ready execution evidence.


> **Important:** execute runs in this workflow are configured for broadcast + strict receipts.
>
> Provide `PHASE4_BROADCAST_COMMANDS_JSON` as a protected environment secret containing real submit commands that emit real tx ids.
>
> Keep `RPC_URL` explicitly set to your intended node endpoint (for testnet, e.g. `https://api.provable.com/v2/testnet`) so endpoint intent is captured in execute verification metadata.
> Set `SNARKOS_ENDPOINT` to the snarkOS REST endpoint used by `snarkos developer execute --endpoint ...` (provider/CLI combos may expect either `.../v2` or `.../v2/testnet`).


For `onboarding_smoke`, generate this secret payload from deterministic codec inputs:

```bash
python3 scripts/build_onboarding_broadcast_commands.py \
  --args-file config/scenarios/testnet/onboarding_mint_args.sample.json \
  --submit-prefix 'snarkos developer execute --endpoint "https://api.explorer.provable.com/v2/testnet" --broadcast --private-key "$ALEO_PRIVATE_KEY" credential_nft.aleo mint_credential_nft' \
  --out artifacts/phase4_broadcast_commands.required.json
```

This sends the selected `scenario` into `.github/workflows/execute_testnet.yml`.

`execute_gate` runs automatically on pushes to the `work` and `main` branches (testnet-staging environment), or by manual workflow dispatch.

You can preview the exact dispatch payload without calling GitHub using `--dry-run`.

The workflow is streamlined to a single operator choice (`scenario`). Scenario payload path is resolved automatically by workflow mapping.

Broadcast mode is hardcoded ON in this lane (`EXECUTE_BROADCAST=true`) with strict receipt verification (`RECEIPT_VERIFICATION_MODE=required`) for testnet-ready execution evidence.


> **Important:** execute runs in this workflow are configured for broadcast + strict receipts.
>
> You can provide broadcast inputs in either mode:
> 1. `PHASE4_BROADCAST_COMMANDS_JSON` (full command payload secret), or
> 2. for `onboarding_smoke`, `PHASE4_ONBOARDING_MINT_ARGS_JSON` (typed args JSON) and the workflow will generate broadcast commands on the fly.
>
> Keep `RPC_URL` explicitly set to your intended node endpoint (for testnet, e.g. `https://api.provable.com/v2/testnet`) so endpoint intent is captured in execute verification metadata.
> Set `SNARKOS_ENDPOINT` to the snarkOS REST endpoint used by `snarkos developer execute --endpoint ...` (provider/CLI combos may expect either `.../v2` or `.../v2/testnet`).


For `onboarding_smoke`, generate this secret payload from deterministic codec inputs:

```bash
python3 scripts/build_onboarding_broadcast_commands.py \
  --args-file config/scenarios/testnet/onboarding_mint_args.sample.json \
  --submit-prefix 'snarkos developer execute --endpoint "https://api.explorer.provable.com/v2/testnet" --broadcast --private-key "$ALEO_PRIVATE_KEY" credential_nft.aleo mint_credential_nft' \
  --out artifacts/phase4_broadcast_commands.required.json
```

Then copy the JSON file contents into the protected `PHASE4_BROADCAST_COMMANDS_JSON` secret.

Alternative (recommended for onboarding): store the args JSON itself in `PHASE4_ONBOARDING_MINT_ARGS_JSON` and let the workflow generate `artifacts/phase4_broadcast_commands.required.json` during execute.

> **Broadcast flag gotcha (important):** for `snarkos developer execute`, use `--broadcast` as a flag.
> Do **not** pass a URL argument like `--broadcast "$SNARKOS_ENDPOINT/testnet/transaction/broadcast"`.
> Keep the target URI in `--endpoint` only.


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
export LEO_VERSION="3.4.0"
export SNARKOS_VERSION="v4.4.0"
```

Keep these pins consistent across contributors for deterministic behavior.

Optional hardening (recommended in CI):

```bash
export LEO_SHA256="<sha256-of-leo-zip>"
export SNARKOS_SHA256="<sha256-of-snarkos-zip>"
```

If set, CI validates downloaded artifacts with `sha256sum -c` before install.

Recommended GitHub setup:
- Add repository variables (Settings -> Secrets and variables -> Actions -> Variables):
  - `LEO_SHA256`
  - `SNARKOS_SHA256`
- Run `.github/workflows/generate_sha256.yml` via `workflow_dispatch` to compute current hash values for pinned URLs and copy values from logs.


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
RPC_URL="https://api.provable.com/v2/testnet" \
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

`execute_testnet.yml` now also verifies execute evidence bundle integrity before artifact upload via `scripts/verify_phase4_execute_artifacts.py`.
`execute_testnet.yml` now also performs best-effort receipt verification via `scripts/verify_phase4_receipts.py` (writes `artifacts/phase4_execute_bundle/receipt_verification.json`).
