program employer_license_registry.aleo {

    // -----------------------------------------
    // Employer License Registry (Layer 1)
    // -----------------------------------------
    // Purpose:
    // - Gate employer name purchases behind a verified business license.
    // - Store only minimal eligibility signals on-chain (no plaintext license data).
    //
    // Model:
    // - An authority (PNW / SubDAO oversight) sets verification for a wallet.
    // - pnw_name_registry.aleo checks verification before allowing employer names.
    //

    // Update this to the authorized issuer address for your environment.
    const AUTHORITY: address = 0address;

    // wallet -> verified flag
    mapping is_verified:
        key as address.public,
        value as bool.public;

    // wallet -> license commitment (optional)
    mapping license_hash_of:
        key as address.public,
        value as [u8; 32].public;

    transition set_verified(wallet: address, license_hash: [u8; 32], verified: bool) {
        assert(caller == AUTHORITY);
        is_verified.set(wallet, verified);
        license_hash_of.set(wallet, license_hash);
    }

    transition assert_verified(wallet: address) {
        let ok: bool = is_verified.get_or_use(wallet, false);
        assert(ok);
    }
}
