# worker_profiles.aleo

**Layer:** 1 (Canonical)  
**Purpose:** Private worker identity profiles anchored by deterministic commitments

---

## Overview

`worker_profiles.aleo` is the canonical Layer 1 worker identity/profile program for PNW MVP v2.

It stores worker identity payloads as **private record fields**, and publishes only a **hash anchor index** that proves a profile existed at or before a given block height.

This is the source of truth used by:
- employer agreements (eligibility + binding)
- payroll execution (eligibility + receipts)
- Layer 2 document assembly (paystubs, summaries, audit disclosures)

---

## Privacy model

### Private (record fields)
- full name (first/middle/last)
- age and gender (enum)
- residency state code, country code
- state-issued ID (encoded u128)
- industry_code and policy flags
- schema/policy versions and profile revision
- the profile_anchor itself

### Public (allowed)
- `profile_anchor_height[profile_anchor] -> first_seen_block_height`
  - hash-only existence index
  - does not reveal identity fields

No plaintext names, addresses, wages, or other linkable identity details are published.

---

## Name binding

Worker profiles are bound to a worker `.pnw` identity via:
- `worker_name_hash: field`

Ownership is asserted using `pnw_name_registry.aleo`:
- `assert_is_owner(worker_name_hash, caller)`

(If we want strict worker-kind enforcement inside the registry, we can re-add a registry helper like `assert_worker_owner` later. This program is already compatible with that upgrade.)

---

## Anchoring

The portal provides:
- `profile_anchor: [u8; 32]`

The program stores:
- the anchor privately in the record, and
- a public “first-seen” index `profile_anchor_height` (anchor -> height)

Anchoring is **write-once** per anchor; reusing the same anchor will not overwrite the original height.

---

## Transitions

### `create_worker_profile(...) -> WorkerProfile`
- asserts caller owns the claimed `worker_name_hash`
- validates basic constraints (gender enum, bounds, non-zero codes)
- anchors `profile_anchor` to first-seen block height
- returns a new private WorkerProfile record

### `update_worker_profile(old_profile, ...) -> WorkerProfile`
- asserts caller owns the old record (record owner check)
- asserts caller still owns the bound name hash
- consumes old record and returns a new one
- requires `new_profile_rev > old_profile.profile_rev`
- anchors the new profile anchor

### `assert_profile_anchored(profile_anchor)`
- public utility to assert a given anchor exists on-chain

### `get_anchor_height(profile_anchor) -> u32`
- public read utility to fetch the first-seen block height (0 if absent)

---

## Portal responsibilities

The portal must:
- normalize and hash names into `worker_name_hash`
- encode identity fields into deterministic `u128` values
- compute `profile_anchor` deterministically (domain-separated)
- maintain local taxonomies (state/country/industry mappings)

---

## License

**PROPRIETARY**  
No rights are granted for reuse, redistribution, or deployment without explicit authorization.
