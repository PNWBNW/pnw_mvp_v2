# Portal Configuration

This folder defines **environment and program configuration** for the PNW portal.

Its purpose is to provide a **single source of truth** for:
- network selection (testnet / mainnet)
- program identifiers
- future execution and CLI wiring

No business logic lives here.  
No network calls are made here.  
No secrets are required at runtime unless explicitly enabled later.

---

## Design Philosophy

- **Configuration, not behavior**
- **Testnet-first**
- **Offline-safe by default**
- **Future-ready without premature coupling**

This folder exists so that:
- routers
- CLI scripts
- minting flows
- execution adapters  

can all reference **the same canonical configuration**.

---

## Folder Contents

    portal/src/config/
    ├─ env.ts
    └─ programs.ts

---

## `env.ts` — Environment Configuration

`env.ts` is responsible for **reading and validating environment variables** used by the portal.

### Current Responsibilities
- Select active network (`testnet` or `mainnet`)
- Expose optional RPC and signing fields
- Provide a typed, validated environment object

### Important Notes
- Most fields are **optional by design**
- At this stage, the portal performs **no network execution**
- These values will become relevant when CLI tooling is added

### Key Variables
- `PNW_NETWORK` — selects testnet or mainnet (defaults to testnet)
- `ALEO_RPC_URL` — optional RPC endpoint (unused until CLI phase)
- `PORTAL_PRIVATE_KEY` / `VIEW_KEY` / `ADDRESS` — optional signing context
- `PNW_DEBUG` — optional debug flag

`env.ts` is intentionally permissive today and will be tightened later when execution paths are finalized.

---

## `programs.ts` — Program Registry

`programs.ts` defines the **canonical mapping of program identifiers** used by the portal.

### Responsibilities
- Centralize all Aleo program names
- Support testnet vs mainnet program resolution
- Prevent hardcoded strings throughout the codebase

### Program Groups
- **external** — programs not owned by PNW (e.g., USDCx)
- **layer1** — canonical payroll and identity logic
- **layer2** — commitment-based NFT programs

### USDCx Handling
USDCx is resolved dynamically based on network:
- Testnet → `test_usdcx_stablecoin.aleo`
- Mainnet → `usdcx_stablecoin.aleo`

This ensures:
- no accidental cross-network usage
- clean separation between environments

---

## How This Folder Is Used

Other portal modules import from `config/` to:
- determine which programs to call
- select the correct network
- remain environment-agnostic

This avoids:
- duplicated constants
- mismatched program names
- accidental mainnet/testnet confusion

---

## What This Folder Does NOT Do

- ❌ Execute transactions
- ❌ Hold secrets securely
- ❌ Perform signing
- ❌ Make RPC calls
- ❌ Contain business logic

Those responsibilities live elsewhere.

---

## Future Extensions (Planned)

Later phases may add:
- transition name registries
- network execution adapters
- stricter env validation for CLI-only flows
- feature flags for dry-run vs broadcast modes

For now, this folder provides a **stable configuration foundation** for the rest of the portal.
