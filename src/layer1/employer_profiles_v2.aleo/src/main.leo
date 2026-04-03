import pnw_name_registry_v2.aleo;
import employer_license_registry.aleo;

program employer_profiles_v2.aleo {

    // ---------------------------------------------------------
    // Employer Profiles (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Privacy-first employer identity/profile system.
    // All sensitive fields are PRIVATE inside records.
    // Only commitment anchors are indexed publicly (hash-only).

    record EmployerProfile {
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

        profile_anchor: [u8; 32],

        // sentinel 0u32; actual height in profile_anchor_height mapping
        issued_height: u32,

        owner: address,
    }

    // Public, hash-only anchor index: first-seen block height for a given anchor.
    mapping profile_anchor_height: [u8; 32] => u32;

    // ---------------------------------------------------------
    // Create employer profile
    // ---------------------------------------------------------
    fn create_employer_profile(
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
    ) -> (EmployerProfile, Final) {

        // Naming taxonomy must match profile taxonomy (circuit-time)
        assert(industry_code == suffix_code);
        assert(suffix_code != 0u8);
        assert(industry_code != 0u8);
        assert(registration_state_code != 0u16);
        assert(country_code != 0u16);
        assert(formation_year != 0u16);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        assert(profile_rev != 0u16);

        // Must be verified to create employer profiles
        let f1: Final = employer_license_registry.aleo::assert_verified(self.caller);

        // Must own the employer name hash + suffix must match
        let f2: Final = pnw_name_registry_v2.aleo::assert_employer_owner(employer_name_hash, self.caller, suffix_code);

        let rec: EmployerProfile = EmployerProfile {
            employer_name_hash: employer_name_hash,
            suffix_code: suffix_code,
            legal_name_u128: legal_name_u128,
            registration_id_u128: registration_id_u128,
            registration_state_code: registration_state_code,
            country_code: country_code,
            formation_year: formation_year,
            entity_type_code: entity_type_code,
            industry_code: industry_code,
            employer_size_code: employer_size_code,
            operating_region_code: operating_region_code,
            schema_v: schema_v,
            policy_v: policy_v,
            profile_rev: profile_rev,
            profile_anchor: profile_anchor,
            issued_height: 0u32,
            owner: self.caller,
        };

        return (rec, final {
            f1.run();
            f2.run();

            // anchor_once (inlined)
            let existing: u32 = profile_anchor_height.get_or_use(profile_anchor, 0u32);
            if existing == 0u32 {
                profile_anchor_height.set(profile_anchor, block.height);
            }
        });
    }

    // ---------------------------------------------------------
    // Update employer profile (consume + re-mint)
    // ---------------------------------------------------------
    fn update_employer_profile(
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
    ) -> (EmployerProfile, Final) {

        // Only owner can update
        assert(old_profile.owner == self.caller);

        // Naming taxonomy must still match
        assert(industry_code == old_profile.suffix_code);
        assert(registration_state_code != 0u16);
        assert(country_code != 0u16);
        assert(formation_year != 0u16);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        assert(new_profile_rev > old_profile.profile_rev);

        // Must remain verified
        let f1: Final = employer_license_registry.aleo::assert_verified(self.caller);

        // Must still own the employer name hash + suffix
        let f2: Final = pnw_name_registry_v2.aleo::assert_employer_owner(
            old_profile.employer_name_hash, self.caller, old_profile.suffix_code
        );

        let rec: EmployerProfile = EmployerProfile {
            employer_name_hash: old_profile.employer_name_hash,
            suffix_code: old_profile.suffix_code,
            legal_name_u128: legal_name_u128,
            registration_id_u128: registration_id_u128,
            registration_state_code: registration_state_code,
            country_code: country_code,
            formation_year: formation_year,
            entity_type_code: entity_type_code,
            industry_code: industry_code,
            employer_size_code: employer_size_code,
            operating_region_code: operating_region_code,
            schema_v: schema_v,
            policy_v: policy_v,
            profile_rev: new_profile_rev,
            profile_anchor: new_profile_anchor,
            issued_height: 0u32,
            owner: self.caller,
        };

        return (rec, final {
            f1.run();
            f2.run();

            // anchor_once (inlined)
            let existing: u32 = profile_anchor_height.get_or_use(new_profile_anchor, 0u32);
            if existing == 0u32 {
                profile_anchor_height.set(new_profile_anchor, block.height);
            }
        });
    }

    // ---------------------------------------------------------
    // Public assertion: anchor exists
    // ---------------------------------------------------------
    fn assert_profile_anchored(profile_anchor: [u8; 32]) -> Final {
        return final {
            let h: u32 = profile_anchor_height.get_or_use(profile_anchor, 0u32);
            assert(h != 0u32);
        };
    }

    // ---------------------------------------------------------
    // Cross-program assertion: profile anchor for employer exists
    // ---------------------------------------------------------
    fn assert_employer_exists(profile_anchor: [u8; 32]) -> Final {
        return final {
            let h: u32 = profile_anchor_height.get_or_use(profile_anchor, 0u32);
            assert(h != 0u32);
        };
    }

    @admin(address = "aleo1a2qje865a7ccrrwg37z6e36uyjtqlm5vdj8yzlrhypvg60xhncqqlev4dx") constructor() {}
}
