# config/

**`testnet.manifest.json`** is the source of truth for what is deployed: the program id behind
each role (`program_ids`) and, for each deployed program, its transaction, date and notes
(`deployments`). Hewn's `packages/config` reads its program ids from this file's values; nothing
anywhere hard-codes one. When a program is deployed or upgraded, this file changes in the same pull
request as the migration note under `docs/migrations/`.

`scripts/validate_testnet_manifest.py` checks it on every pull request.

**`scenarios/`** holds the inputs for the command-line execute gate (see its own README): a schema
and sample payloads for onboarding and payroll on testnet. They are test fixtures with
placeholder values, not records of real people.
