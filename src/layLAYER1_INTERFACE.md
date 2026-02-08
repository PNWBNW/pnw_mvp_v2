# LAYER1_INTERFACE.md 

Layer 1 Interface Reference

This document defines the **canonical callable interface** for all Layer 1 Aleo programs in the PNW MVP.

It is a **strict extraction** of public transitions, records, and callable functions intended for:
- the Portal router
- SDK / adapter layers
- external integrators
- future maintainers

## What this document includes
- Public `transition` signatures
- Public record types returned or consumed by transitions
- Public helper functions callable by other programs

## What this document intentionally omits
- Internal helpers
- Mappings
- Constants
- Validation logic
- Implementation details

This file exists to provide a **single, stable source of truth** for how off-chain systems and other programs interact with Layer 1, without requiring readers to inspect individual `.aleo` implementations.

---

## employer_agreement.aleo

### Transitions

```
transition create_job_offer(
    agreement_id: [u8; 32],
    parties_key: [u8; 32],
    employer_name_hash: field,
    worker_name_hash: field,
    worker_address: address,
    industry_code: u8,
    pay_frequency_code: u8,
    start_epoch: u32,
    end_epoch: u32,
    review_epoch: u32,
    agreement_rev: u16,
    schema_v: u16,
    policy_v: u16,
    terms_doc_hash: [u8; 32],
    terms_root: [u8; 32],
    offer_time_hash: [u8; 32]
) -> PendingAgreement

transition accept_job_offer(
    offer: PendingAgreement,
    accept_time_hash: [u8; 32]
) -> FinalAgreement

transition pause_agreement(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)

transition terminate_agreement(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)

transition resume_agreement_employer(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)

transition resume_agreement_worker(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)

transition resume_agreement_dao(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)

transition finalize_resume(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)

transition supersede_agreement(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)

transition assert_agreement_active(
    agreement_id: [u8; 32]
)

transition get_anchor_height(
    agreement_id: [u8; 32]
) -> u32
```
### Functions
```
assert_status_valid

function assert_status_valid(s: u8)

assert_pay_frequency

function assert_pay_frequency(code: u8)

anchor_once

function anchor_once(agreement_id: [u8; 32])

assert_agreement_exists

function assert_agreement_exists(agreement_id: [u8; 32])

assert_parties_key_matches

function assert_parties_key_matches(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)

assert_is_employer

function assert_is_employer(employer_name_hash: field)

assert_is_worker

function assert_is_worker(worker_name_hash: field)

assert_is_dao

function assert_is_dao()
```

---

## employer_license_registry.aleo

### Transitions
```
transition set_verified(wallet: address, license_hash: [u8; 32], verified: bool)
async transition assert_verified(wallet: address) -> Future
transition get_license_hash(wallet: address) -> [u8; 32]
```
### Functions
```
async function do_assert_verified(wallet: address) -> Future
```
---

## employer_profiles.aleo

### Records
```
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
```
### Transitions
```
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
) -> EmployerProfile

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
) -> EmployerProfile

transition assert_profile_anchored(profile_anchor: [u8; 32])

transition get_anchor_height(profile_anchor: [u8; 32]) -> u32
```
### Functions
```
function anchor_once(profile_anchor: [u8; 32])
```
---
## payroll_audit_log.aleo

### Transitions
```
transition anchor_event(event_hash: [u8; 32])

transition assert_event_anchored(event_hash: [u8; 32])

transition get_event_height(event_hash: [u8; 32]) -> u32
```
### Functions
```
function anchor_unique(event_hash: [u8; 32])
```

---
## payroll_core.aleo

### Transitions
```
transition execute_payroll(
    employer_usdcx: test_usdcx_stablecoin.Record,
    employer_addr: address,
    worker_addr: address,
    employer_name_hash: field,
    worker_name_hash: field,
    agreement_id: [u8; 32],
    epoch_id: u32,
    gross_amount: u128,
    net_amount: u128,
    tax_withheld: u128,
    fee_amount: u128,
    receipt_anchor: [u8; 32],
    receipt_pair_hash: [u8; 32],
    payroll_inputs_hash: [u8; 32],
    utc_time_hash: [u8; 32],
    audit_event_hash: [u8; 32]
) -> (
    test_usdcx_stablecoin.Record,
    paystub_receipts.WorkerPaystubReceipt,
    paystub_receipts.EmployerPaystubReceipt
)
```

## paystub_receipts.aleo

### Transitions
```
transition mint_paystub_receipts(
    worker_owner: address,
    employer_owner: address,
    worker_name_hash: field,
    employer_name_hash: field,
    agreement_id: [u8; 32],
    epoch_id: u32,
    gross_amount: u128,
    net_amount: u128,
    tax_withheld: u128,
    fee_amount: u128,
    payroll_inputs_hash: [u8; 32],
    receipt_anchor: [u8; 32],
    pair_hash: [u8; 32],
    utc_time_hash: [u8; 32]
) -> (WorkerPaystubReceipt, EmployerPaystubReceipt)

transition mint_reversal_receipts(
    worker_owner: address,
    employer_owner: address,
    worker_name_hash: field,
    employer_name_hash: field,
    agreement_id: [u8; 32],
    epoch_id: u32,
    gross_amount: u128,
    net_amount: u128,
    tax_withheld: u128,
    fee_amount: u128,
    payroll_inputs_hash: [u8; 32],
    reversal_anchor: [u8; 32],
    pair_hash: [u8; 32],
    utc_time_hash: [u8; 32]
) -> (WorkerPaystubReceipt, EmployerPaystubReceipt)

transition assert_receipt_anchored(receipt_anchor: [u8; 32])

transition get_anchor_height(receipt_anchor: [u8; 32]) -> u32
```
### Functions
```
function anchor_unique(receipt_anchor: [u8; 32])
```

---

## pnw_name_registry.aleo

### Transitions
```
async transition register_worker_name(name_hash: field, fee_amount: u128) -> Future

transition release_worker_name()

async transition register_employer_name(name_hash: field, suffix_code: u8, fee_amount: u128) -> Future

transition request_employer_sellback(name_hash: field)

async transition fulfill_employer_sellback(name_hash: field) -> Future

transition assert_is_owner(name_hash: field, owner: address)
```
### Functions
```
function is_valid_suffix(code: u8) -> bool

function calc_employer_base_price(count: u8) -> u128

function calc_refund(base_paid: u128) -> u128

async function finalize_register_worker(pay_f: Future, owner: address, name_hash: field) -> Future

async function finalize_register_employer(
    pay_f: Future,
    owner: address,
    name_hash: field,
    suffix_code: u8,
    base_paid: u128,
    count: u8
) -> Future
```

---

## pnw_router.aleo

### Transitions
```
transition create_job_offer(
    agreement_id: [u8; 32],
    parties_key: [u8; 32],
    employer_name_hash: field,
    worker_name_hash: field,
    industry_code: u8,
    pay_frequency_code: u8,
    start_epoch: u32,
    end_epoch: u32,
    review_epoch: u32,
    agreement_rev: u16,
    schema_v: u16,
    policy_v: u16,
    terms_doc_hash: [u8; 32],
    terms_root: [u8; 32]
)

transition accept_job_offer(pending: employer_agreement.aleo/PendingAgreement)

transition pause_agreement_employer(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field)

transition pause_agreement_worker(agreement_id: [u8; 32], parties_key: [u8; 32], worker_name_hash: field)

transition pause_agreement_dao(agreement_id: [u8; 32], parties_key: [u8; 32])

transition terminate_agreement_employer(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field)

transition terminate_agreement_worker(agreement_id: [u8; 32], parties_key: [u8; 32], worker_name_hash: field)

transition terminate_agreement_dao(agreement_id: [u8; 32], parties_key: [u8; 32])

transition approve_resume_employer(agreement_id: [u8; 32], parties_key: [u8; 32], employer_name_hash: field)

transition approve_resume_worker(agreement_id: [u8; 32], parties_key: [u8; 32], worker_name_hash: field)

transition approve_resume_dao(agreement_id: [u8; 32], parties_key: [u8; 32])

transition resume_agreement(agreement_id: [u8; 32], parties_key: [u8; 32])

transition assert_agreement_active(agreement_id: [u8; 32])

transition assert_agreement_exists(agreement_id: [u8; 32])

transition assert_worker_profile_anchored(profile_anchor: [u8; 32])

transition assert_employer_profile_anchored(profile_anchor: [u8; 32])

transition assert_name_owner(name_hash: field, owner: address)
```

---

## worker_profiles.aleo

### Records
```
- WorkerProfile
```
### Transitions
```
- create_worker_profile(
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
  ) -> WorkerProfile

- update_worker_profile(
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
  ) -> WorkerProfile

- assert_profile_anchored(profile_anchor: [u8; 32])

- get_anchor_height(profile_anchor: [u8; 32]) -> u32
```
