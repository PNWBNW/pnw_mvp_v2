program employer_license_registry.aleo {

    // ---------------------------------------------------------
    // Employer License Registry (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Purpose:
    // - Gate employer name purchases behind a verified business license.
    // - Store only minimal eligibility signals on-chain (no plaintext license data).
    //
    // Model:
    // - AUTHORITY (PNW / SubDAO oversight) sets verification for a wallet.
    // - pnw_name_registry.aleo checks verification before allowing employer names.

    // Authorized issuer.
    const AUTHORITY: address = aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    // wallet -> verified flag
    mapping is_verified: address => bool;

    // wallet -> license commitment (field = portal-supplied hash of license docs)
    mapping license_hash_of: address => field;

    // ---------------------------------------------------------
    // Admin: set / update verification status
    // ---------------------------------------------------------
    async transition set_verified(wallet: address, license_hash: field, verified: bool) -> Future {
        assert(caller == AUTHORITY);
        return finalize_set_verified(wallet, license_hash, verified);
    }

    async function finalize_set_verified(wallet: address, license_hash: field, verified: bool) {
        is_verified.set(wallet, verified);
        license_hash_of.set(wallet, license_hash);
    }

    // ---------------------------------------------------------
    // Cross-program assertion: assert wallet is verified
    // Called by pnw_name_registry, employer_agreement, etc.
    // ---------------------------------------------------------
    async transition assert_verified(wallet: address) -> Future {
        return finalize_assert_verified(wallet);
    }

    async function finalize_assert_verified(wallet: address) {
        let ok: bool = is_verified.get_or_use(wallet, false);
        assert(ok);
    }
}
