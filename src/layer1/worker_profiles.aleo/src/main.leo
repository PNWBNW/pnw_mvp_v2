import pnw_name_registry.aleo;

program worker_profiles.aleo {

    // ---------------------------------------------------------
    // Worker Profiles (Layer 1) - PNW MVP v2
    // ---------------------------------------------------------
    // Privacy-first, PNW-native identity system.
    // - All sensitive identity fields are PRIVATE inside records.
    // - Only hash anchors are published on-chain (anchor -> first-seen height).

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
        worker_name_hash: field,

        // Identity fields (private)
        first_name_u128: u128,
        middle_name_u128: u128,
        last_name_u128: u128,

        age: u8,
        gender: u8,

        // Geography / government (private)
        residency_state_code: u16,
        country_code: u16,
        state_issue_id_u128: u128,

        // Classification
        industry_code: u8,

        // Optional policy flags
        citizenship_flag: u8,

        // Versioning
        schema_v: u16,
        policy_v: u16,
        profile_rev: u16,

        // Commitment anchor
        profile_anchor: [u8; 32],

        // Metadata (sentinel 0u32; actual height in profile_anchor_height mapping)
        issued_height: u32,

        // Ownership
        owner: address,
    }

    // ---------------------------------------------------------
    // Public anchor index (hash-only)
    // ---------------------------------------------------------
    mapping profile_anchor_height: [u8; 32] => u32;

    // ---------------------------------------------------------
    // Create worker profile
    // ---------------------------------------------------------
    async transition create_worker_profile(
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
    ) -> (WorkerProfile, Future) {

        // Guards (circuit-time)
        assert_gender(gender);
        assert(age <= 120u8);
        assert(residency_state_code != 0u16);
        assert(country_code != 0u16);
        assert(industry_code != 0u8);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        assert(profile_rev != 0u16);

        // Must own the name hash claimed for this profile
        let f_owner: Future = pnw_name_registry.aleo/assert_is_owner(worker_name_hash, self.caller);

        let rec: WorkerProfile = WorkerProfile {
            worker_name_hash: worker_name_hash,
            first_name_u128: first_name_u128,
            middle_name_u128: middle_name_u128,
            last_name_u128: last_name_u128,
            age: age,
            gender: gender,
            residency_state_code: residency_state_code,
            country_code: country_code,
            state_issue_id_u128: state_issue_id_u128,
            industry_code: industry_code,
            citizenship_flag: citizenship_flag,
            schema_v: schema_v,
            policy_v: policy_v,
            profile_rev: profile_rev,
            profile_anchor: profile_anchor,
            issued_height: 0u32,
            owner: self.caller,
        };

        return (rec, finalize_create_worker_profile(f_owner, profile_anchor));
    }

    async function finalize_create_worker_profile(f_owner: Future, profile_anchor: [u8; 32]) {
        f_owner.await();

        // anchor_once (inlined): write first-seen height
        let existing: u32 = profile_anchor_height.get_or_use(profile_anchor, 0u32);
        if existing == 0u32 {
            profile_anchor_height.set(profile_anchor, block.height);
        }
    }

    // ---------------------------------------------------------
    // Update worker profile (consume + re-mint)
    // ---------------------------------------------------------
    async transition update_worker_profile(
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
    ) -> (WorkerProfile, Future) {

        // Record owner must be self.caller
        assert(old_profile.owner == self.caller);

        // Guards
        assert_gender(gender);
        assert(age <= 120u8);
        assert(residency_state_code != 0u16);
        assert(country_code != 0u16);
        assert(industry_code != 0u8);
        assert(schema_v != 0u16);
        assert(policy_v != 0u16);
        assert(new_profile_rev > old_profile.profile_rev);

        // Must still own the name hash
        let f_owner: Future = pnw_name_registry.aleo/assert_is_owner(old_profile.worker_name_hash, self.caller);

        let rec: WorkerProfile = WorkerProfile {
            worker_name_hash: old_profile.worker_name_hash,
            first_name_u128: first_name_u128,
            middle_name_u128: middle_name_u128,
            last_name_u128: last_name_u128,
            age: age,
            gender: gender,
            residency_state_code: residency_state_code,
            country_code: country_code,
            state_issue_id_u128: state_issue_id_u128,
            industry_code: industry_code,
            citizenship_flag: citizenship_flag,
            schema_v: schema_v,
            policy_v: policy_v,
            profile_rev: new_profile_rev,
            profile_anchor: new_profile_anchor,
            issued_height: 0u32,
            owner: self.caller,
        };

        return (rec, finalize_update_worker_profile(f_owner, new_profile_anchor));
    }

    async function finalize_update_worker_profile(f_owner: Future, new_profile_anchor: [u8; 32]) {
        f_owner.await();

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
        return finalize_assert_profile_anchored(profile_anchor);
    }

    async function finalize_assert_profile_anchored(profile_anchor: [u8; 32]) {
        let h: u32 = profile_anchor_height.get_or_use(profile_anchor, 0u32);
        assert(h != 0u32);
    }

    // ---------------------------------------------------------
    // Cross-program assertion: profile anchor for worker name exists
    // ---------------------------------------------------------
    async transition assert_worker_exists(profile_anchor: [u8; 32]) -> Future {
        return finalize_assert_profile_anchored(profile_anchor);
    }
}
