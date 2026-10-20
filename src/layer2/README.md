# src/layer2 — commitment anchors

Layer 2 programs never move money. Each one mints a private record and writes a hash and a block
height to a public mapping, so a fact (a payroll cycle happened, a credential was issued, an audit
was authorised) can be proved later without the chain ever showing what it was about. They import
Layer 1 for their authorisation checks.

All four are deployed on testnet and none is called by Hewn yet: the app's audit design
(`docs/AUDIT_DESIGN.md` in the Hewn repo) and credentials are later phases. Superseded versions are
in [`archive/`](archive/README.md).

| Program | Upgrades | What it does |
|---|---|---|
| [`payroll_nfts_v2.aleo`](payroll_nfts_v2.aleo/README.md) | `@noupgrade` | A `PayrollNFT` per cycle, quarter, year to date or year end, anchored to its batch root; revoke and supersede. |
| [`credential_nft_v3.aleo`](credential_nft_v3.aleo/README.md) | `@admin` | A `CredentialNFT` binding a worker to a scope and a document, mintable only by the employer who holds an active agreement with that worker. |
| [`credential_nft_v4.aleo`](credential_nft_v4.aleo/README.md) | `@admin`, staged | v3 plus a check that the employer's licence is still verified. |
| [`audit_nft.aleo`](audit_nft.aleo/README.md) | `@noupgrade` | Dual-consent audit authorisations that expire by block height, and anchored attestations. |
