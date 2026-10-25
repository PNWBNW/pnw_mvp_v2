// ---------------------------------------------------------
// hewn_credentials_v1.aleo — a worker's credentials
// ---------------------------------------------------------
//
// A credential is a business vouching for a person it has an agreement
// with: employment verified, a skill, a clearance, or something custom.
// It lives in two private records, the issuer's copy and the subject's,
// and the only public thing about it is a commitment (one hash over its
// fields and a random nonce) with a status and the block it was issued
// at. No name, no account, no counter in public state: nothing on chain
// links the business and the person. The worker's app draws each live
// credential as a landmark on their land and the business's app keeps
// its copy (docs/HEWN_ART.md in PNWBNW/hewn, "A worker's land and its
// landmarks"); what a credential says stays in the two vaults, and the
// record carries only a hash of it (`scope`).
//
// Who may issue: the signer must be the employer of an agreement the two
// did make. It passes the agreement's parties key and the worker's
// account privately, and the program calls
// employer_agreement_v5.aleo::assert_pair_agreed(key, self.signer, worker)
// (active, paused or ended: a past employer may still vouch for work that
// was done). The pair tag is the one public finalize input of that call,
// as for every program that checks an agreement; the tag is a pseudonym,
// not a name. No registry call: the app checks names off chain, as
// employer_agreement_v5 does. A credential to oneself can't happen: v5
// refuses an offer to yourself, so no agreed pair has one account on
// both sides.
//
// Two-party, like an offer: issuing leaves the credential OFFERED; the
// subject accepts it (ACTIVE) or declines it (DECLINED) with their own
// copy; the issuer revokes it (REVOKED) with its own copy, offered or
// active. Every move takes the mover's own record, so a stranger holds
// nothing to call with (a record is spent only by its owner), and the
// role byte in each copy says which side makes which move.
//
// Public state: credential_status[commitment] = u8 and
// credential_anchor[commitment] = u32 (the issue block). Nothing else.
// A commitment can't be guessed from public data: the nonce is random
// and private, and so are the two accounts.
//
// Immutable (@noupgrade): a change ships as hewn_credentials_v2.
// ---------------------------------------------------------

import employer_agreement_v5.aleo;

const STATUS_NONE: u8 = 0u8;
const STATUS_OFFERED: u8 = 1u8;
const STATUS_ACTIVE: u8 = 2u8;
const STATUS_REVOKED: u8 = 3u8;
const STATUS_DECLINED: u8 = 4u8;

const KIND_EMPLOYMENT: u8 = 1u8;
const KIND_SKILLS: u8 = 2u8;
const KIND_CLEARANCE: u8 = 3u8;
const KIND_CUSTOM: u8 = 4u8;

const ROLE_ISSUER: u8 = 1u8;
const ROLE_SUBJECT: u8 = 2u8;

// What the commitment is made of. Private: only the two parties hold the nonce.
struct CommitInput {
    kind: u8,
    issuer: address,
    subject: address,
    scope: [u128; 2],
    nonce: [u128; 2],
}

fn commitment_of(kind: u8, issuer: address, subject: address, scope: [u128; 2], nonce: [u128; 2]) -> field {
    return BHP1024::hash_to_field(CommitInput {
        kind: kind,
        issuer: issuer,
        subject: subject,
        scope: scope,
        nonce: nonce,
    });
}

fn assert_kind(kind: u8) {
    assert(kind == KIND_EMPLOYMENT || kind == KIND_SKILLS || kind == KIND_CLEARANCE || kind == KIND_CUSTOM);
}

program hewn_credentials_v1.aleo {

    // One credential, in two copies that differ only in owner and role.
    record Credential {
        owner: address,
        role: u8,            // ROLE_ISSUER in the issuer's copy, ROLE_SUBJECT in the subject's
        kind: u8,            // KIND_EMPLOYMENT, KIND_SKILLS, KIND_CLEARANCE or KIND_CUSTOM
        issuer: address,
        subject: address,
        scope: [u128; 2],    // a hash of what it says; the document stays in the two vaults
        nonce: [u128; 2],    // random, from the issuer's app: makes the commitment unguessable
        commitment: field,   // the key of the credential's public status
    }

    mapping credential_status: field => u8;
    mapping credential_anchor: field => u32;

    // -----------------------------
    // 1) Issue (the employer of an agreement with the subject): two copies, offered
    // -----------------------------
    fn issue(
        parties_key: [u128; 2],
        subject: address,
        kind: u8,
        scope: [u128; 2],
        nonce: [u128; 2]
    ) -> (Credential, Credential, Final) {
        assert_kind(kind);
        assert(nonce[0u32] != 0u128 || nonce[1u32] != 0u128);
        let issuer: address = self.signer;
        let c: field = commitment_of(kind, issuer, subject, scope, nonce);
        let agreed: Final = employer_agreement_v5.aleo::assert_pair_agreed(parties_key, issuer, subject);

        let issuer_copy: Credential = Credential {
            owner: issuer,
            role: ROLE_ISSUER,
            kind: kind,
            issuer: issuer,
            subject: subject,
            scope: scope,
            nonce: nonce,
            commitment: c,
        };

        let subject_copy: Credential = Credential {
            owner: subject,
            role: ROLE_SUBJECT,
            kind: kind,
            issuer: issuer,
            subject: subject,
            scope: scope,
            nonce: nonce,
            commitment: c,
        };

        return (issuer_copy, subject_copy, final {
            agreed.run();
            let s: u8 = credential_status.get_or_use(c, STATUS_NONE);
            assert(s == STATUS_NONE);
            credential_status.set(c, STATUS_OFFERED);
            credential_anchor.set(c, block.height);
        });
    }

    // -----------------------------
    // 2) Accept (the subject, with their copy): offered → active.
    //    The copy comes back to them unchanged (a fresh record, the same fields).
    // -----------------------------
    fn accept(c: Credential) -> (Credential, Final) {
        assert(c.role == ROLE_SUBJECT);
        let commitment: field = c.commitment;
        return (c, final {
            let s: u8 = credential_status.get_or_use(commitment, STATUS_NONE);
            assert(s == STATUS_OFFERED);
            credential_status.set(commitment, STATUS_ACTIVE);
        });
    }

    // -----------------------------
    // 3) Decline (the subject, with their copy): offered → declined.
    //    The copy is spent; nothing is drawn. The issuer's copy stays, dead.
    // -----------------------------
    fn decline(c: Credential) -> Final {
        assert(c.role == ROLE_SUBJECT);
        let commitment: field = c.commitment;
        return final {
            let s: u8 = credential_status.get_or_use(commitment, STATUS_NONE);
            assert(s == STATUS_OFFERED);
            credential_status.set(commitment, STATUS_DECLINED);
        };
    }

    // -----------------------------
    // 4) Revoke (the issuer, with its copy): offered or active → revoked.
    //    The copy is spent; the subject's copy stays and draws as a ghost.
    // -----------------------------
    fn revoke(c: Credential) -> Final {
        assert(c.role == ROLE_ISSUER);
        let commitment: field = c.commitment;
        return final {
            let s: u8 = credential_status.get_or_use(commitment, STATUS_NONE);
            assert(s == STATUS_OFFERED || s == STATUS_ACTIVE);
            credential_status.set(commitment, STATUS_REVOKED);
        };
    }

    // -----------------------------
    // 5) For other programs: the credential stands (accepted, not revoked).
    //    The commitment is a pseudonym; whoever passes it chose to show it.
    // -----------------------------
    fn assert_active(commitment: field) -> Final {
        return final {
            let s: u8 = credential_status.get_or_use(commitment, STATUS_NONE);
            assert(s == STATUS_ACTIVE);
        };
    }

    // Immutable: no admin key can change what a credential means. A change ships as hewn_credentials_v2.
    @noupgrade
    constructor() {}
}
