import pnw_name_registry.aleo;
import employer_license_registry.aleo;

program employer_profiles.aleo {

    // ---------------------------------------------------------
    // Employer Profiles (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Privacy-first employer identity/profile system.
    // All sensitive fields are PRIVATE inside records.
    // Only commitment anchors are indexed publicly (hash-only).
    //
    // Requirements enforced:
    // - Caller must be verified (employer_license_registry)
    // - Caller must own the employer name hash (pnw_name_registry)
    // - industry_code must equal suffix_code (profile taxonomy matches name taxonomy)
    // ---------------------------------------------------------

    record EmployerProfile {
        employer_name_hash: field.private,
        suffix_code: u8.private,

        legal_name_u128: u128.private,
        registration_id_u128: u128.private,
        registration_state_code: u16.private,
        country_code: u16.private,

        formation_year: u16.private,
        entity_type_code: u8.private,

        industry_code: u8.private,
        employer_size_code: u8.private,
        operating_region_code: u16.private,

        schema_v: u16.private,
        policy_v: u16.private,
        profile_rev: u16.private,

        profile_anchor: [u8; 32].private,
        issued_height: u32.private,

        owner: address.private,
        _nonce: group.public
    }

    // Public, hash-only anchor index: first-seen block height for a given anchor.
    mapping profile_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    function anchor_once(profile_anchor: [u8; 32]) {
        let h: u32 = block.height;
        let existing: u32 = Mapping::get_or_use(profile_anchor_height, profile_anchor, 0u32);
        if existing == 0u32 {
            Mapping::set(profile_anchor_height, profile_anchor, h);
        }
    }

    transition create_employer_profile(
        employer_name_hash: field,
        suffix_code: u8,

        legal_name_u128: u128,
        registration_id_u128: u128,
        registration_state_code: u16,
        country_code: u16,

        formation_year: u16,
        entity_type_code: u8,

        industry_code: u8,
        employer_size_code: u8,
        operating_region_code: u16,

        schema_v: u16,
        policy_v: u16,
        profile_rev: u16,

        profile_anchor: [u8; 32]
    ) -> EmployerProfile {

        // Must be verified to create/maintain employer profiles.
        employer_license_registry.aleo/assert_verified(caller);

        // Must own the employer name hash + suffix must match the owned registration.
        pnw_name_registry.aleo/assert_employer_owner(employer_name_hash, caller, suffix_code);

        // Naming taxonomy must match profile taxonomy.
        assert(industry_code == suffix_code);

        // Basic sanity
        assert(suffix_code != 0u8);
        assert(industry_code != 0u8);
        assert(registration_state_code != 0u16);
        assert(country_code != 0u16);
        assert(formation_year != 0u16);

        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        assert(profile_rev != 0u16);

        anchor_once(profile_anchor);

        let h: u32 = block.height;

        let rec: EmployerProfile = EmployerProfile {
            employer_name_hash: employer_name_hash.private,
            suffix_code: suffix_code.private,

            legal_name_u128: legal_name_u128.private,
            registration_id_u128: registration_id_u128.private,
            registration_state_code: registration_state_code.private,
            country_code: country_code.private,

            formation_year: formation_year.private,
            entity_type_code: entity_type_code.private,

            industry_code: industry_code.private,
            employer_size_code: employer_size_code.private,
            operating_region_code: operating_region_code.private,

            schema_v: schema_v.private,
            policy_v: policy_v.private,
            profile_rev: profile_rev.private,

            profile_anchor: profile_anchor.private,
            issued_height: h.private,

            owner: caller.private,
            _nonce: group::rand().public
        };

        return rec;
    }

    transition update_employer_profile(
        old_profile: EmployerProfile,

        legal_name_u128: u128,
        registration_id_u128: u128,
        registration_state_code: u16,
        country_code: u16,

        formation_year: u16,
        entity_type_code: u8,

        industry_code: u8,
        employer_size_code: u8,
        operating_region_code: u16,

        schema_v: u16,
        policy_v: u16,
        new_profile_rev: u16,

        new_profile_anchor: [u8; 32]
    ) -> EmployerProfile {

        // Only owner can update.
        assert(old_profile.owner == caller.private);

        // Must remain verified.
        employer_license_registry.aleo/assert_verified(caller);

        // Must still own the employer name hash + suffix.
        pnw_name_registry.aleo/assert_employer_owner(old_profile.employer_name_hash, caller, old_profile.suffix_code);

        // Naming taxonomy must still match.
        assert(industry_code == old_profile.suffix_code);

        // Basic sanity
        assert(registration_state_code != 0u16);
        assert(country_code != 0u16);
        assert(formation_year != 0u16);

        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        assert(new_profile_rev > old_profile.profile_rev);

        consume old_profile;

        anchor_once(new_profile_anchor);

        let h: u32 = block.height;

        let rec: EmployerProfile = EmployerProfile {
            employer_name_hash: old_profile.employer_name_hash,
            suffix_code: old_profile.suffix_code,

            legal_name_u128: legal_name_u128.private,
            registration_id_u128: registration_id_u128.private,
            registration_state_code: registration_state_code.private,
            country_code: country_code.private,

            formation_year: formation_year.private,
            entity_type_code: entity_type_code.private,

            industry_code: industry_code.private,
            employer_size_code: employer_size_code.private,
            operating_region_code: operating_region_code.private,

            schema_v: schema_v.private,
            policy_v: policy_v.private,
            profile_rev: new_profile_rev.private,

            profile_anchor: new_profile_anchor.private,
            issued_height: h.private,

            owner: caller.private,
            _nonce: group::rand().public
        };

        return rec;
    }

    transition assert_profile_anchored(profile_anchor: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(profile_anchor_height, profile_anchor, 0u32);
        assert(h != 0u32);
    }

    transition get_anchor_height(profile_anchor: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(profile_anchor_height, profile_anchor, 0u32);
        return h;
    }
}
