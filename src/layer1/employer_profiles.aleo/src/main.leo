import pnw_name_registry.aleo;
import employer_license_registry.aleo;

program employer_profiles.aleo {

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
    async transition create_employer_profile(
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
    ) -> (EmployerProfile, Future) {

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
        let f1: Future = employer_license_registry.aleo/assert_verified(self.caller);

        // Must own the employer name hash + suffix must match
        let f2: Future = pnw_name_registry.aleo/assert_employer_owner(employer_name_hash, self.caller, suffix_code);

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

        return (rec, fin_create_employer_profile(f1, f2, profile_anchor));
    }

    async function fin_create_employer_profile(f1: Future, f2: Future, profile_anchor: [u8; 32]) {
        f1.await();
        f2.await();

        // anchor_once (inlined)
        let existing: u32 = profile_anchor_height.get_or_use(profile_anchor, 0u32);
        if existing == 0u32 {
            profile_anchor_height.set(profile_anchor, block.height);
        }
    }

    // ---------------------------------------------------------
    // Update employer profile (consume + re-mint)
    // ---------------------------------------------------------
    async transition update_employer_profile(
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
    ) -> (EmployerProfile, Future) {

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
        let f1: Future = employer_license_registry.aleo/assert_verified(self.caller);

        // Must still own the employer name hash + suffix
        let f2: Future = pnw_name_registry.aleo/assert_employer_owner(
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

        return (rec, fin_update_employer_profile(f1, f2, new_profile_anchor));
    }

    async function fin_update_employer_profile(f1: Future, f2: Future, new_profile_anchor: [u8; 32]) {
        f1.await();
        f2.await();

        // anchor_once (inlined)
        let existing: u32 = profile_anchor_height.get_or_use(new_profile_anchor, 0u32);
        if existing == 0u32 {
            profile_anchor_height.set(new_profile_anchor, block.height);
        }
    }

    // ---------------------------------------------------------
    // Public assertion: anchor exists
    // ---------------------------------------------------------
    async transition assert_profile_anchored(profile_anchor: [u8; 32]) -> Future {
        return fin_assert_profile_anchored(profile_anchor);
    }

    async function fin_assert_profile_anchored(profile_anchor: [u8; 32]) {
        let h: u32 = profile_anchor_height.get_or_use(profile_anchor, 0u32);
        assert(h != 0u32);
    }

    // ---------------------------------------------------------
    // Cross-program assertion: profile anchor for employer exists
    // ---------------------------------------------------------
    async transition assert_employer_exists(profile_anchor: [u8; 32]) -> Future {
        return fin_assert_profile_anchored(profile_anchor);
    }

    @noupgrade async constructor() {}
}