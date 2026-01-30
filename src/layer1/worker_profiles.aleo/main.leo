import pnw_name_registry.aleo;

program worker_profiles.aleo {

    // ---------------------------------------------------------
    // Worker Profiles (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Privacy-first, PNW-native identity system.
    // - All sensitive identity fields are PRIVATE inside records.
    // - Only hash anchors are published on-chain (anchor -> first-seen height).
    //
    // Notes:
    // - The portal supplies encoded u128 fields and profile_anchor deterministically.
    // - Name ownership is asserted via pnw_name_registry.
    // ---------------------------------------------------------

    // -----------------------------
    // Gender codes (strict enum)
    // -----------------------------
    const GENDER_MALE: u8 = 1u8;
    const GENDER_FEMALE: u8 = 2u8;
    const GENDER_PREFER_NOT: u8 = 3u8;

    function assert_gender(code: u8) {
        assert(
            code == GENDER_MALE ||
            code == GENDER_FEMALE ||
            code == GENDER_PREFER_NOT
        );
    }

    // -----------------------------
    // Worker profile record (private)
    // -----------------------------
    record WorkerProfile {
        // Binding
        worker_name_hash: field.private,

        // Identity fields (private)
        first_name_u128: u128.private,
        middle_name_u128: u128.private,
        last_name_u128: u128.private,

        age: u8.private,
        gender: u8.private,

        // Geography / government (private)
        residency_state_code: u16.private,
        country_code: u16.private,
        state_issue_id_u128: u128.private,

        // Classification
        industry_code: u8.private,

        // Optional policy flags (reserved; portal-defined enum)
        citizenship_flag: u8.private,

        // Versioning
        schema_v: u16.private,
        policy_v: u16.private,
        profile_rev: u16.private,

        // Commitment anchor
        profile_anchor: [u8; 32].private,

        // Metadata
        issued_height: u32.private,

        // Ownership
        owner: address.private,
        _nonce: group.public
    }

    // ---------------------------------------------------------
    // Public anchor index (hash-only)
    // ---------------------------------------------------------
    mapping profile_anchor_height:
        key as [u8; 32].public,
        value as u32.public;

    // ---------------------------------------------------------
    // Internal: anchor once
    // ---------------------------------------------------------
    function anchor_once(profile_anchor: [u8; 32]) {
        let h: u32 = block.height;
        let existing: u32 = Mapping::get_or_use(profile_anchor_height, profile_anchor, 0u32);
        if existing == 0u32 {
            Mapping::set(profile_anchor_height, profile_anchor, h);
        }
    }

    // ---------------------------------------------------------
    // Create worker profile
    // ---------------------------------------------------------
    transition create_worker_profile(
        worker_name_hash: field,

        first_name_u128: u128,
        middle_name_u128: u128,
        last_name_u128: u128,

        age: u8,
        gender: u8,

        residency_state_code: u16,
        country_code: u16,
        state_issue_id_u128: u128,

        industry_code: u8,
        citizenship_flag: u8,

        schema_v: u16,
        policy_v: u16,
        profile_rev: u16,

        profile_anchor: [u8; 32]
    ) -> WorkerProfile {

        // Must own the name hash claimed for this profile.
        // (If you want strict "worker-kind" enforcement at the registry level,
        // we can re-add assert_worker_owner in pnw_name_registry later.)
        pnw_name_registry.aleo/assert_is_owner(worker_name_hash, caller);

        // Guards
        assert_gender(gender);
        assert(age <= 120u8);
        assert(residency_state_code != 0u16);
        assert(country_code != 0u16);
        assert(industry_code != 0u8);

        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        assert(profile_rev != 0u16);

        anchor_once(profile_anchor);

        let h: u32 = block.height;

        let rec: WorkerProfile = WorkerProfile {
            worker_name_hash: worker_name_hash.private,

            first_name_u128: first_name_u128.private,
            middle_name_u128: middle_name_u128.private,
            last_name_u128: last_name_u128.private,

            age: age.private,
            gender: gender.private,

            residency_state_code: residency_state_code.private,
            country_code: country_code.private,
            state_issue_id_u128: state_issue_id_u128.private,

            industry_code: industry_code.private,
            citizenship_flag: citizenship_flag.private,

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

    // ---------------------------------------------------------
    // Update worker profile (consume + re-mint)
    // ---------------------------------------------------------
    transition update_worker_profile(
        old_profile: WorkerProfile,

        first_name_u128: u128,
        middle_name_u128: u128,
        last_name_u128: u128,

        age: u8,
        gender: u8,

        residency_state_code: u16,
        country_code: u16,
        state_issue_id_u128: u128,

        industry_code: u8,
        citizenship_flag: u8,

        schema_v: u16,
        policy_v: u16,
        new_profile_rev: u16,

        new_profile_anchor: [u8; 32]
    ) -> WorkerProfile {

        // Record owner must be caller.
        assert(old_profile.owner == caller.private);

        // Must still own the name hash.
        pnw_name_registry.aleo/assert_is_owner(old_profile.worker_name_hash, caller);

        // Guards
        assert_gender(gender);
        assert(age <= 120u8);
        assert(residency_state_code != 0u16);
        assert(country_code != 0u16);
        assert(industry_code != 0u8);

        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        assert(new_profile_rev > old_profile.profile_rev);

        consume old_profile;

        anchor_once(new_profile_anchor);

        let h: u32 = block.height;

        let rec: WorkerProfile = WorkerProfile {
            worker_name_hash: old_profile.worker_name_hash,

            first_name_u128: first_name_u128.private,
            middle_name_u128: middle_name_u128.private,
            last_name_u128: last_name_u128.private,

            age: age.private,
            gender: gender.private,

            residency_state_code: residency_state_code.private,
            country_code: country_code.private,
            state_issue_id_u128: state_issue_id_u128.private,

            industry_code: industry_code.private,
            citizenship_flag: citizenship_flag.private,

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

    // ---------------------------------------------------------
    // Public assertion: anchor exists
    // ---------------------------------------------------------
    transition assert_profile_anchored(profile_anchor: [u8; 32]) {
        let h: u32 = Mapping::get_or_use(profile_anchor_height, profile_anchor, 0u32);
        assert(h != 0u32);
    }

    // ---------------------------------------------------------
    // Public utility: read anchor height
    // ---------------------------------------------------------
    transition get_anchor_height(profile_anchor: [u8; 32]) -> u32 {
        let h: u32 = Mapping::get_or_use(profile_anchor_height, profile_anchor, 0u32);
        return h;
    }
}
