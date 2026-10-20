# portal/ — the planning layer, kept for its type gates

This is where the TypeScript side of the programs started: workflow definitions that plan a
payroll run without executing anything, routers that turn a plan into program calls, the command
codec for `snarkos developer execute`, and the commitment hashing. CI still typechecks it
(`tsconfig.phase3.json`, `tsconfig.phase4.json`) and runs the adapter codec test on every pull
request.

**It is not the live copy.** The portal's libraries moved into Hewn in October 2026 and changed
there: `packages/pnw-adapter`, `packages/commitments`, `packages/config` and the rest in
[`hewn/packages/`](https://github.com/PNWBNW/hewn/tree/main/packages). One divergence to know
about: `commitments/hash.ts` here hashes `BLAKE3(domain || 0x00 || payload)`, while the programs on
testnet and Hewn use `BLAKE3(domain || payload)`. Hewn's copy is the truth.

Nothing here runs a network call: workflows and routers plan, the adapter builds commands, and
only the execute gate (`scripts/`) ever sends one.
