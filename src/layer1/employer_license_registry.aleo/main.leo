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
    //
    // Notes:
    // - We keep this intentionally minimal: (wallet -> verified) + optional license_hash.
    // - "license_hash" is a portal-supplied commitment (state license #, docs, etc) hashed off-chain.

    // Authorized issuer (provided by you).
    const AUTHORITY: address = aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    // wallet -> verified flag
    mapping is_verified:
        key as address.public,
        value as bool.public;

    // wallet -> license commitment (optional)
    mapping license_hash_of:
        key as address.public,
        value as [u8; 32].public;

    // ---------------------------------------------------------
    // Admin: set / update verification status
    // ---------------------------------------------------------
    transition set_verified(wallet: address, license_hash: [u8; 32], verified: bool) {
        // Assertion #1: Only authority can set verification.
        assert(caller == AUTHORITY);

        // Write minimal state.
        Mapping::set(is_verified, wallet, verified);
        Mapping::set(license_hash_of, wallet, license_hash);
    }

    // ---------------------------------------------------------
    // Public utility: assert wallet is verified
    // ---------------------------------------------------------
    async transition assert_verified(wallet: address) -> Future {
        // Route mapping reads through an async function for consistency across the repo.
        let f: Future = do_assert_verified(wallet);
        return f;
    }

    async function do_assert_verified(wallet: address) -> Future {
        let ok: bool = is_verified.get_or_use(wallet, false);

        // Assertion #2: Wallet must be verified.
        assert(ok);

        return 0future;
    }

    // ---------------------------------------------------------
    // Public utility: read license hash (commitment) for a wallet
    // ---------------------------------------------------------
    transition get_license_hash(wallet: address) -> [u8; 32] {
        // If not set, returns 32 zero bytes.
        let h: [u8; 32] = license_hash_of.get_or_use(wallet, [0u8; 32]);
        return h;
    }
}
