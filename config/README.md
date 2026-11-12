# config/

**`testnet.manifest.json`** is the source of truth for what is deployed: the program id behind
each role (`program_ids`) and, for each deployed program, its transaction, date and notes
(`deployments`). Hewn's `packages/config` reads its program ids from this file's values; nothing
anywhere hard-codes one. When a program is deployed or upgraded, this file changes in the same pull
request as the migration note under `docs/migrations/`.

`scripts/validate_testnet_manifest.py` checks it on every pull request. Each entry under `deployments` also
records the program's edition on chain and the SHA-256 of its text there, written by
`scripts/check_chain.py --write` in the pull request of a deploy or upgrade. The plan gate and the
daily `chain-watch` run read the chain and fail on any difference, which is how an upgrade nobody
recorded gets noticed.

**`scenarios/`** holds the inputs for the command-line harness (see its own README): a schema
and sample payloads for onboarding and payroll on testnet. They are test fixtures with
placeholder values, not records of real people.
