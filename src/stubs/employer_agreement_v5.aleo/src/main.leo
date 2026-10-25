// ---------------------------------------------------------
// employer_agreement_v5.aleo — LOCAL STUB
// ---------------------------------------------------------
// The part of the deployed agreement program other programs
// call, so `leo build` and `leo test` run without a network
// fetch: the pair tag (the same hash over the same struct as
// deployed), the `pair_status` mapping, and `assert_pair_active`
// and `assert_pair_agreed` as deployed, plus one test-only call
// to seed them: `set_test_pair` (a key, the two accounts and a
// status). On the network a pair's status is set only by offers
// and the agreement's lifecycle; here a test sets it directly.
// Never deployed. Programs that depend on it switch to the
// network copy to deploy (deploy_program.yml).
// ---------------------------------------------------------

const STATUS_PENDING: u8 = 0u8;
const STATUS_ACTIVE: u8 = 1u8;
const STATUS_PAUSED: u8 = 2u8;
const STATUS_ENDED: u8 = 3u8;
const STATUS_WITHDRAWN: u8 = 4u8;
const STATUS_NONE: u8 = 255u8;

// What the pair tag is made of. Private: only the two parties hold the key.
struct PairTagInput {
    parties_key: [u128; 2],
    employer: address,
    worker: address,
}

fn pair_tag(parties_key: [u128; 2], employer: address, worker: address) -> field {
    return BHP1024::hash_to_field(PairTagInput {
        parties_key: parties_key,
        employer: employer,
        worker: worker,
    });
}

program employer_agreement_v5.aleo {
    mapping pair_status: field => u8;

    // Test-only: the real program sets a pair's status through create_offer,
    // accept_offer, withdraw_offer, the pauses, resume and the three endings.
    fn set_test_pair(parties_key: [u128; 2], employer: address, worker: address, status: u8) -> Final {
        assert(status <= STATUS_WITHDRAWN);
        let tag: field = pair_tag(parties_key, employer, worker);
        return final {
            pair_status.set(tag, status);
        };
    }

    fn assert_pair_active(parties_key: [u128; 2], employer: address, worker: address) -> Final {
        let tag: field = pair_tag(parties_key, employer, worker);
        return final {
            let p: u8 = pair_status.get_or_use(tag, STATUS_NONE);
            assert(p == STATUS_ACTIVE);
        };
    }

    // The two accounts did agree, at some point: active, paused or ended.
    // Not a pending offer, not a withdrawn one.
    fn assert_pair_agreed(parties_key: [u128; 2], employer: address, worker: address) -> Final {
        let tag: field = pair_tag(parties_key, employer, worker);
        return final {
            let p: u8 = pair_status.get_or_use(tag, STATUS_NONE);
            assert(p == STATUS_ACTIVE || p == STATUS_PAUSED || p == STATUS_ENDED);
        };
    }

    @noupgrade
    constructor() {}
}
