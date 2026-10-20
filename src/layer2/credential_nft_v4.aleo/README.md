# credential_nft_v4.aleo

`credential_nft_v3.aleo` plus one more check before a mint: the employer's licence is still
verified (`employer_license_registry::assert_verified`). Without it, an employer whose licence was
revoked could keep issuing credentials through an agreement that is still active. Everything else
is v3's: the same records, functions, mappings and the three authorisation checks (see v3's
README).

Upgrades: `@admin`. Deployed on testnet on 2026-04-12 and **staged**: the manifest's live
credential program is still v3, because Hewn's free registration path doesn't require a licence.
When licences matter again, the manifest switches to v4.
