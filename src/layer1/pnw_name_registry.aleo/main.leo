import employer_license_registry.aleo;
import test_usdcx_stablecoin.aleo;

program pnw_name_registry.aleo {

    // ---------------------------------------------------------
    // PNW Naming Registry (Layer 1, soulbound-by-design)
    // ---------------------------------------------------------
    // Names are registered as hashed identifiers (field).
    // - No plaintext strings on-chain.
    // - No transfers or sales between users.
    //
    // Workers:
    // - 1 active name per address
    // - purchase: 1 USDCx + fee_amount (fees non-refundable)
    // - can release to pool and switch (no refund)
    //
    // Employers:
    // - max 3 names per address
    // - purchase tiers: 10 / 100 / 300 USDCx + fee_amount (fees non-refundable)
    // - requires business verification (employer_license_registry)
    // - can sell back ONLY to registrar for 75% of BASE price (fees never refunded)
    // ---------------------------------------------------------

    // -------------------
    // Environment constants
    // -------------------
    const REGISTRAR_TREASURY: address =
        aleo1s8t86aza932zah3mv5knclvnn5zy4gedpl5a4wn5h2yrt08mxqzsw5amdd;

    const USDCX_SCALE: u128 = 1_000_000u128;

    const WORKER_PRICE_BASE: u128 = 1u128 * USDCX_SCALE;

    const EMP_PRICE_1_BASE: u128 = 10u128 * USDCX_SCALE;
    const EMP_PRICE_2_BASE: u128 = 100u128 * USDCX_SCALE;
    const EMP_PRICE_3_BASE: u128 = 300u128 * USDCX_SCALE;

    const REFUND_NUM: u128 = 75u128;
    const REFUND_DEN: u128 = 100u128;

    // -------------------
    // Name kind codes
    // -------------------
    const KIND_WORKER: u8 = 1u8;
    const KIND_EMPLOYER: u8 = 2u8;

    // -------------------
    // Employer 5-char suffix codes
    // -------------------
    const SUF_AGRIC: u8 = 1u8;   // agric
    const SUF_FOODS: u8 = 2u8;   // foods
    const SUF_SERVC: u8 = 3u8;   // servc
    const SUF_BUSNS: u8 = 4u8;   // busns
    const SUF_WORKS: u8 = 5u8;   // works

    const SUF_COOPS: u8 = 6u8;   // coops
    const SUF_ORGNS: u8 = 7u8;   // orgns
    const SUF_INCOR: u8 = 8u8;   // incor
    const SUF_BUILD: u8 = 9u8;   // build
    const SUF_LANDS: u8 = 10u8;  // lands

    const SUF_MANUF: u8 = 11u8;  // manuf
    const SUF_TRANS: u8 = 12u8;  // trans
    const SUF_UTILT: u8 = 13u8;  // utilt
    const SUF_MECHN: u8 = 14u8;  // mechn
    const SUF_ELECT: u8 = 15u8;  // elect

    const SUF_METAL: u8 = 16u8;  // metal
    const SUF_TIMBR: u8 = 17u8;  // timbr

    const SUF_TECHN: u8 = 18u8;  // techn
    const SUF_DATAS: u8 = 19u8;  // datas
    const SUF_CYBER: u8 = 20u8;  // cyber
    const SUF_MEDIA: u8 = 21u8;  // media
    const SUF_LABRD: u8 = 22u8;  // labrd (research labs / R&D)

    const SUF_HEALT: u8 = 23u8;  // healt
    const SUF_CARED: u8 = 24u8;  // cared
    const SUF_PHARM: u8 = 25u8;  // pharm
    const SUF_THERA: u8 = 26u8;  // thera

    const SUF_EDUCA: u8 = 27u8;  // educa
    const SUF_TRAIN: u8 = 28u8;  // train
    const SUF_SKILL: u8 = 29u8;  // skill

    const SUF_RETAL: u8 = 30u8;  // retal
    const SUF_HOSTL: u8 = 31u8;  // hostl
    const SUF_TOURS: u8 = 32u8;  // tours (tourism, guides)
    const SUF_EVENT: u8 = 33u8;  // event

    const SUF_FINAN: u8 = 34u8;  // finan
    const SUF_LEGAL: u8 = 35u8;  // legal
    const SUF_ACCTS: u8 = 36u8;  // accts
    const SUF_ADMIN: u8 = 37u8;  // admin

    const SUF_CIVIC: u8 = 38u8;  // civic
    const SUF_MUNIC: u8 = 39u8;  // munic
