
---

# employer_agreement.aleo

## Transitions

### create_job_offer
```text
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
```
### accept_job_offer
```
transition accept_job_offer(
    offer: PendingAgreement,
    accept_time_hash: [u8; 32]
) -> FinalAgreement
```
### pause_agreement
```
transition pause_agreement(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)
```
### terminate_agreement
```
transition terminate_agreement(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)
```
### resume_agreement_employer
```
transition resume_agreement_employer(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)
```
### resume_agreement_worker
```
transition resume_agreement_worker(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)
```
### resume_agreement_dao
```
transition resume_agreement_dao(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)
```
### finalize_resume
```
transition finalize_resume(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)
```
### supersede_agreement
```
transition supersede_agreement(
    agreement_id: [u8; 32],
    parties_key: [u8; 32]
)
```
### assert_agreement_active
```
transition assert_agreement_active(
    agreement_id: [u8; 32]
)
```
### get_anchor_height
```
transition get_anchor_height(
    agreement_id: [u8; 32]
) -> u32
```
## Functions
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

# employer_license_registry.aleo

## Transitions
```text
transition set_verified(wallet: address, license_hash: [u8; 32], verified: bool)
async transition assert_verified(wallet: address) -> Future
transition get_license_hash(wallet: address) -> [u8; 32]
```
## Functions
```
async function do_assert_verified(wallet: address) -> Future
```

---

