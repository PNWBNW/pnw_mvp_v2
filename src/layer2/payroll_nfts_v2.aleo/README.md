# payroll_nfts_v2.aleo

A commitment anchor for a run of payroll. After a cycle settles, the employer mints a private
`PayrollNFT` holding the batch root; the chain gets the NFT's id, its anchor height and its status.
Quarter, year-to-date and year-end anchors roll cycles up the same way. Nothing here moves money.

Upgrades: `@noupgrade`. Deployed on testnet (replacing `payroll_nfts.aleo`, which imported
`employer_agreement_v2` and couldn't follow it to v4; that one is in `../archive/`).

| Function | Does |
|---|---|
| `mint_cycle_nft(...)` | One pay cycle, checked against an active `employer_agreement_v4` agreement |
| `mint_quarter_nft(...)`, `mint_ytd_nft(...)`, `mint_eoy_nft(...)` | Roll-ups over cycles |
| `revoke_nft(nft)` | Marks one revoked |
| `mark_superseded(old_nft, new_nft_id)` | Points an old anchor at its replacement |
| `assert_nft_exists(nft_id)` | For other programs |

Public state: `nft_anchor_height`, `nft_status` (active 1, revoked 2, superseded 3),
`superseded_by`.

Hewn today: deployed, not called. The first cycle NFT was minted from the old portal on
2026-04-10 (`at1d8ht598hqqjgmqfxjwvt0cf47aqafgynzjhazhtreze6j22hzcrq5992r5`). Hewn's payroll
settled on one private transfer per worker, so what an anchor should cover is being redesigned
(Hewn's `docs/AUDIT_DESIGN.md`).
