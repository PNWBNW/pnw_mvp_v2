# employer_profiles.aleo — README

**Layer:** 1 (Canonical)  
**Language:** Leo v3.4.0 semantics  
**Role:** Private employer profile records + minimal public anchor for existence/auditability

---

## 1) What this program does

`employer_profiles.aleo` creates and updates **privacy-preserving employer profile records**.

It is a canonical Layer 1 program responsible for:
- verifying the caller is eligible to act as an employer (license-gated)
- verifying the caller owns the employer `.pnw` name hash (suffix-gated)
- enforcing naming taxonomy alignment (industry code matches employer suffix code)
- issuing private `EmployerProfile` records that hold sensitive attributes
- anchoring profile existence on-chain via a public `profile_anchor` hash

This program does **not** publish employer identity or profile details in plaintext.

---

## 2) Privacy model

All sensitive fields are stored **private inside the record**:
- employer name hash (private)
- legal name (u128 encoding, private)
- registration ID (u128 encoding, private)
- location codes and demographic-like profile codes (private)
- schema/policy/revision fields (private)
- profile anchor hash (private)

The only on-chain public state is:
- a mapping from `profile_anchor -> first-seen block.height`

This enables permissible auditability (“this profile existed by height H”) without exposing contents.

---

## 3) Eligibility requirements (enforced on-chain)

### 3.1 Employer license verification
Before a profile can be created or updated, the caller must be verified via:

- `employer_license_registry.aleo/assert_verified(caller)`

### 3.2 Employer name ownership + suffix enforcement
Before a profile can be created or updated, the caller must own the employer name hash and satisfy suffix constraints via:

- `pnw_name_registry.aleo/assert_employer_owner(employer_name_hash, caller, suffix_code)`

### 3.3 Taxonomy alignment
The employer’s profile taxonomy must match naming taxonomy:

- `assert(industry_code == suffix_code);`

This binds the employer’s declared industry classification to the suffix they registered.

---

## 4) Records

### 4.1 `EmployerProfile` (private record)
The canonical employer profile record containing:
- name hash + suffix code
- registration identifiers and jurisdiction codes
- formation year, entity type, employer size, operating region
- schema/policy versions and `profile_rev`
- `profile_anchor` commitment and issuance height
- `owner` address (private) and `_nonce`

Profiles are updated via consume + re-mint, producing a new record with a higher revision.

---

## 5) Public anchoring

### 5.1 `profile_anchor_height`
A minimal public mapping:

- `profile_anchor -> u32 (first-seen block.height)`

Anchoring is idempotent: first write wins.

### 5.2 Intended usage
The portal constructs `profile_anchor` as a deterministic hash commitment to the full profile document or its canonical encoding.
Later, a verifier can confirm:
- the anchor exists
- and when it first appeared (by block height)

---

## 6) Core transitions

### 6.1 `create_employer_profile(...) -> EmployerProfile`
- Verifies employer license
- Verifies employer name ownership + suffix constraints
- Enforces `industry_code == suffix_code`
- Anchors `profile_anchor` (first-seen height)
- Returns a private `EmployerProfile` record

### 6.2 `update_employer_profile(old_profile, ...) -> EmployerProfile`
- Asserts caller owns the existing profile record
- Re-checks license verification and name ownership
- Requires monotonic revision bump (`new_profile_rev > old_profile.profile_rev`)
- Consumes old record and returns an updated private profile record
- Anchors the new profile anchor

### 6.3 `assert_profile_anchored(profile_anchor)`
Public utility assertion that verifies the anchor exists on-chain.

---

## 7) Dependencies

This program depends on:
- `pnw_name_registry.aleo` (employer name ownership + suffix enforcement)
- `employer_license_registry.aleo` (license verification gate)

---

## 8) License

**PROPRIETARY** — no rights are granted for reuse, redistribution, or deployment without explicit authorization.
