# credential_nft_v3.aleo

A credential an employer issues to a worker: a private `CredentialNFT` binding the worker to a
scope and a document commitment, with a public status so it can be revoked and checked. The point
of v3 is that **only the right employer can mint it.** v2 let anyone mint a convincing credential
for any worker; v3 proves three things on chain before minting:

1. the caller owns the employer's name (`pnw_name_registry_v2::assert_is_owner`);
2. the target wallet owns the worker's name (same);
3. the caller holds an active agreement with that worker
   (`employer_agreement_v4::assert_employer_authorized`, which reproduces the private parties
   commitment from the caller's inputs).

Forging one would take the employer's name and the `parties_key` from inside their private
agreement record.

Upgrades: `@admin` while it is iterated; to become `@noupgrade` at mainnet. Deployed on testnet.

| Function | Does |
|---|---|
| `mint_credential_nft(...)` | The dual-record mint, after the three checks |
| `revoke_by_issuer(...)` | The employer revokes |
| `revoke_by_owner(nft)` | The worker revokes their own |
| `burn_view(nft)` | Burns a view copy |
| `assert_credential_exists(credential_id)`, `assert_scope_anchored(scope_hash)` | For other programs |

Public state: `credential_anchor_height`, `credential_status` (active 1, revoked 2),
`credential_revoked_height`, `credential_issuer`, `scope_anchor_height`.

Hewn today: deployed, not called; credentials are a later phase. The old portal minted the first
ones on 2026-04-12, with generative art drawn from the credential id. v1 and v2 are in
`../archive/`; `credential_nft_v4.aleo` adds a licence check on top of this program.
