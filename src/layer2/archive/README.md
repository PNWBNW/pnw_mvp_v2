# Layer 2 archive

Superseded versions of the commitment-anchor programs, kept exactly as they were. Not built,
tested or deployed by CI; nothing live depends on them. They stay because deployed Aleo programs
can't be removed from the chain, and because the reasons each version was replaced are part of
the record.

| Archived | Replaced by | Why |
|---|---|---|
| `payroll_nfts.aleo` (`@noupgrade`) | `payroll_nfts_v2.aleo` | v1 imported `employer_agreement_v2` and couldn't be upgraded; v2 points at `employer_agreement_v4` |
| `credential_nft.aleo` (`@noupgrade`) | `credential_nft_v3.aleo` | v1 had no authorisation check on mint |
| `credential_nft_v2.aleo` | `credential_nft_v3.aleo` | v2 still let anyone mint for any worker; v3 proves the caller holds an active agreement with that worker |

`credential_nft_v4.aleo` (v3 plus an employer licence check) is not archived: it is deployed and
staged in `src/layer2/`. Which program is live is decided by `config/testnet.manifest.json`.
