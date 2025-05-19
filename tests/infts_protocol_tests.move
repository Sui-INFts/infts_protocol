// Copyright (c) Infts.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module infts_protocol::infts_protocol_tests {
    use sui::test_scenario::{Self, Scenario};
    use sui::object::{Self, ID};
    use sui::package;
    use sui::display;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance;
    use sui::tx_context;
    use std::string::{Self};
    use infts_protocol::inft_core::{Self, INFT, INFT_CORE};
    use infts_protocol::access_policy::{Self, AccessPolicy};
    use infts_protocol::evolution_logic;
    use infts_protocol::utils;

    // Error codes from utils.move
    const ENO_EMPTY_NAME: u64 = 0;
    const ENO_EMPTY_PUBLIC_URI: u64 = 1;
    const ENO_EMPTY_ATOMA_MODEL: u64 = 2;
    const ENO_INSUFFICIENT_BALANCE: u64 = 3;
    const ENO_OWNER: u64 = 4;
    const ENO_AUTHORIZED: u64 = 5;

    // Test addresses
    const ADMIN: address = @0xa11ce;
    const USER: address = @0xb0b;
    const ATTACKER: address = @0xdead;

    // Helper function to mint a test coin
    fun mint_sui(amount: u64, ctx: &mut tx_context::TxContext): Coin<SUI> {
        coin::from_balance(balance::create_for_testing<SUI>(amount), ctx)
    }

    // Test: Initialize the protocol
    #[test]
    fun test_init() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let publisher = scenario.take_from_sender<package::Publisher>();
            let display = scenario.take_from_sender<display::Display<INFT>>();
            assert!(package::from_module<INFT_CORE>(&publisher), 0);
            test_scenario::return_to_sender(&scenario, publisher);
            test_scenario::return_to_sender(&scenario, display);
        };
        scenario.end();
    }

    // Test: Mint an INFT with valid inputs
    #[test]
    fun test_mint_nft() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b"atoma-123"),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let nft = scenario.take_from_sender<INFT>();
            assert!(inft_core::name(&nft) == string::utf8(b"Test INFT"), 0);
            assert!(inft_core::public_metadata_uri(&nft) == string::utf8(b"walrus://public"), 0);
            assert!(inft_core::private_metadata_uri(&nft) == string::utf8(b"walrus://private"), 0);
            assert!(inft_core::atoma_model_id(&nft) == string::utf8(b"atoma-123"), 0);
            assert!(inft_core::interaction_count(&nft) == 0, 0);
            assert!(inft_core::evolution_stage(&nft) == 0, 0);
            assert!(inft_core::balance(&nft).value() == 0, 0);
            assert!(inft_core::owner(&nft) == USER, 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Mint fails with empty name
    #[test, expected_failure]
    fun test_mint_nft_empty_name() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b""),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b"atoma-123"),
                ctx
            );
        };
        scenario.end();
    }

    // Test: Mint fails with empty public URI
    #[test, expected_failure(abort_code = ENO_EMPTY_PUBLIC_URI)]
    fun test_mint_nft_empty_public_uri() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b""),
                string::utf8(b"walrus://private"),
                string::utf8(b"atoma-123"),
                ctx
            );
        };
        scenario.end();
    }

    // Test: Mint fails with empty Atoma model ID
    #[test, expected_failure]
    fun test_mint_nft_empty_atoma_model() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        scenario.end();
    }

    // Test: Add and withdraw balance
    #[test]
    fun test_add_and_withdraw_balance() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b"atoma-123"),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            let mut payment = mint_sui(1000, ctx);
            inft_core::add_balance(&mut nft, &mut payment, 500, ctx);
            assert!(inft_core::balance(&nft).value() == 500, 0);
            // Destroy remaining coin balance
            let remaining = coin::split(&mut payment, 500, ctx);
            coin::burn_for_testing(remaining);
            coin::burn_for_testing(payment);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            inft_core::withdraw_balance(&mut nft, 300, ctx);
            assert!(inft_core::balance(&nft).value() == 200, 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let coin = scenario.take_from_sender<Coin<SUI>>();
            assert!(coin::value(&coin) == 300, 0);
            coin::burn_for_testing(coin);
        };
        scenario.end();
    }

    // Test: Withdraw fails with insufficient balance
    #[test, expected_failure]
    fun test_withdraw_balance_insufficient() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            inft_core::withdraw_balance(&mut nft, 100, ctx);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Attach and retrieve Seal policy
    #[test]
    fun test_attach_policy() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            access_policy::attach_policy(&mut nft, string::utf8(b"seal-123"), ctx);
            assert!(access_policy::get_policy_id(&nft) == string::utf8(b"seal-123"), 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let policy = scenario.take_from_sender<AccessPolicy>();
            assert!(access_policy::get_seal_policy_id(&policy) == string::utf8(b"seal-123"), 0);
            test_scenario::return_to_sender(&scenario, policy);
        };
        scenario.end();
    }

    // Test: Attach policy fails for non-owner
    #[test, expected_failure]
    fun test_attach_policy_non_owner() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, ATTACKER);
        {
            let mut nft = test_scenario::take_from_address<INFT>(&scenario, USER);
            let ctx = scenario.ctx();
            access_policy::attach_policy(&mut nft, string::utf8(b"seal-123"), ctx);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Verify access for owner
    #[test]
    fun test_verify_access_owner() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b"atoma-123"),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            assert!(access_policy::verify_access(&nft, USER), 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Verify access fails for non-owner
    #[test]
    fun test_verify_access_non_owner() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            assert!(!access_policy::verify_access(&nft, ATTACKER), 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Update INFT state
    #[test]
    fun test_update_state() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            evolution_logic::update_state(
                &mut nft,
                string::utf8(b"walrus://new_public"),
                string::utf8(b"walrus://new_private"),
                ctx
            );
            assert!(inft_core::public_metadata_uri(&nft) == string::utf8(b"walrus://new_public"), 0);
            assert!(inft_core::private_metadata_uri(&nft) == string::utf8(b"walrus://new_private"), 0);
            assert!(inft_core::interaction_count(&nft) == 1, 0);
            assert!(inft_core::evolution_stage(&nft) == 1, 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Update state fails for non-owner
    #[test, expected_failure]
    fun test_update_state_non_owner() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, ATTACKER);
        {
            let mut nft = test_scenario::take_from_address<INFT>(&scenario, USER);
            let ctx = scenario.ctx();
            evolution_logic::update_state(
                &mut nft,
                string::utf8(b"walrus://new_public"),
                string::utf8(b"walrus://new_private"),
                ctx
            );
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Full INFT lifecycle (mint, attach policy, evolve)
    #[test]
    fun test_inft_lifecycle() {
        let mut scenario = test_scenario::begin(ADMIN);
        // Step 1: Initialize protocol
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        // Step 2: Mint INFT
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b"atoma-123"),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        // Step 3: Attach Seal policy
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            access_policy::attach_policy(&mut nft, string::utf8(b"seal-123"), ctx);
            assert!(access_policy::get_policy_id(&nft) == string::utf8(b"seal-123"), 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        // Step 4: Add balance
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            let mut payment = mint_sui(1000, ctx);
            inft_core::add_balance(&mut nft, &mut payment, 500, ctx);
            assert!(inft_core::balance(&nft).value() == 500, 0);
            // Destroy remaining coin balance
            let remaining = coin::split(&mut payment, 500, ctx);
            coin::burn_for_testing(remaining);
            coin::burn_for_testing(payment);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        // Step 5: Evolve INFT
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            evolution_logic::update_state(
                &mut nft,
                string::utf8(b"walrus://new_public"),
                string::utf8(b"walrus://new_private"),
                ctx
            );
            assert!(inft_core::public_metadata_uri(&nft) == string::utf8(b"walrus://new_public"), 0);
            assert!(inft_core::interaction_count(&nft) == 1, 0);
            assert!(inft_core::evolution_stage(&nft) == 1, 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        // Step 6: Withdraw balance
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            inft_core::withdraw_balance(&mut nft, 300, ctx);
            assert!(inft_core::balance(&nft).value() == 200, 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let coin = scenario.take_from_sender<Coin<SUI>>();
            assert!(coin::value(&coin) == 300, 0);
            coin::burn_for_testing(coin);
            let policy = scenario.take_from_sender<AccessPolicy>();
            assert!(access_policy::get_seal_policy_id(&policy) == string::utf8(b"seal-123"), 0);
            test_scenario::return_to_sender(&scenario, policy);
        };
        scenario.end();
    }

    // Test: Update metadata URI as owner
    #[test]
    fun test_update_metadata_uri() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            access_policy::update_metadata_uri(&mut nft, string::utf8(b"walrus://updated_public"), ctx);
            assert!(inft_core::public_metadata_uri(&nft) == string::utf8(b"walrus://updated_public"), 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Update metadata URI fails for non-owner
    #[test, expected_failure]
    fun test_update_metadata_uri_non_owner() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, ATTACKER);
        {
            let mut nft = test_scenario::take_from_address<INFT>(&scenario, USER);
            let ctx = scenario.ctx();
            access_policy::update_metadata_uri(&mut nft, string::utf8(b"walrus://hacked"), ctx);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Update encrypted URI as owner
    #[test]
    fun test_update_encrypted_uri() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            access_policy::update_encrypted_uri(&mut nft, string::utf8(b"walrus://updated_private"), ctx);
            assert!(inft_core::private_metadata_uri(&nft) == string::utf8(b"walrus://updated_private"), 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Update encrypted URI fails for non-owner
    #[test, expected_failure]
    fun test_update_encrypted_uri_non_owner() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, ATTACKER);
        {
            let mut nft = test_scenario::take_from_address<INFT>(&scenario, USER);
            let ctx = scenario.ctx();
            access_policy::update_encrypted_uri(&mut nft, string::utf8(b"walrus://hacked_private"), ctx);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Update policy ID as owner
    #[test]
    fun test_update_policy_id() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            access_policy::attach_policy(&mut nft, string::utf8(b"seal-123"), ctx);
            assert!(access_policy::get_policy_id(&nft) == string::utf8(b"seal-123"), 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            access_policy::update_policy_id(&mut nft, string::utf8(b"seal-456"), ctx);
            assert!(access_policy::get_policy_id(&nft) == string::utf8(b"seal-456"), 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Update policy ID fails for non-owner
    #[test, expected_failure]
    fun test_update_policy_id_non_owner() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                 string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b""),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            access_policy::attach_policy(&mut nft, string::utf8(b"seal-123"), ctx);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, ATTACKER);
        {
            let mut nft = test_scenario::take_from_address<INFT>(&scenario, USER);
            let ctx = scenario.ctx();
            access_policy::update_policy_id(&mut nft, string::utf8(b"seal-hacked"), ctx);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Create and use admin capability
    #[test]
    fun test_admin_cap() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
            let admin_cap = access_policy::create_admin_cap(ctx);
            transfer::public_transfer(admin_cap, ADMIN);
        };
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = scenario.take_from_sender<access_policy::AdminCap>();
            assert!(object::uid_to_address(access_policy::admin_cap_id(&admin_cap)) != @0x0, 0);
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.end();
    }

    // Test: Admin mint NFT
    #[test]
    fun test_admin_mint_nft() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
            let admin_cap = access_policy::create_admin_cap(ctx);
            transfer::public_transfer(admin_cap, ADMIN);
        };
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = scenario.take_from_sender<access_policy::AdminCap>();
            let ctx = scenario.ctx();
            access_policy::admin_mint_nft(
                &admin_cap,
                string::utf8(b"Admin INFT"),
                string::utf8(b"Admin Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://admin_public"),
                string::utf8(b"walrus://admin_private"),
                string::utf8(b"atoma-admin"),
                string::utf8(b"seal-admin"),
                1, // NFT type
                USER, // recipient
                ctx
            );
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let nft = scenario.take_from_sender<INFT>();
            assert!(inft_core::name(&nft) == string::utf8(b"Admin INFT"), 0);
            assert!(inft_core::public_metadata_uri(&nft) == string::utf8(b"walrus://admin_public"), 0);
            assert!(inft_core::private_metadata_uri(&nft) == string::utf8(b"walrus://admin_private"), 0);
            assert!(inft_core::atoma_model_id(&nft) == string::utf8(b"atoma-admin"), 0);
            assert!(inft_core::owner(&nft) == USER, 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let policy = scenario.take_from_sender<AccessPolicy>();
            assert!(access_policy::get_seal_policy_id(&policy) == string::utf8(b"seal-admin"), 0);
            test_scenario::return_to_sender(&scenario, policy);
        };
        scenario.end();
    }

    // Test: Admin mint NFT with invalid NFT type
    #[test, expected_failure]
    fun test_admin_mint_nft_invalid_type() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
            let admin_cap = access_policy::create_admin_cap(ctx);
            transfer::public_transfer(admin_cap, ADMIN);
        };
        test_scenario::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = scenario.take_from_sender<access_policy::AdminCap>();
            let ctx = scenario.ctx();
            access_policy::admin_mint_nft(
                &admin_cap,
                string::utf8(b"Admin INFT"),
                string::utf8(b"Admin Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://admin_public"),
                string::utf8(b"walrus://admin_private"),
                string::utf8(b"atoma-admin"),
                string::utf8(b"seal-admin"),
                4, // Invalid NFT type (should be <= 3)
                USER, // recipient
                ctx
            );
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        scenario.end();
    }

    // Test: Update policy when no policy exists
    #[test]
    fun test_update_policy_id_no_existing_policy() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b"atoma-123"),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            // No policy exists yet, but we can still update
            access_policy::update_policy_id(&mut nft, string::utf8(b"seal-new"), ctx);
            assert!(access_policy::get_policy_id(&nft) == string::utf8(b"seal-new"), 0);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }

    // Test: Add 10 SUI to INFT balance and verify 100 quotes added
    #[test]
    fun test_add_balance_10_sui() {
        let mut scenario = test_scenario::begin(ADMIN);
        {
            let ctx = scenario.ctx();
            inft_core::init_for_testing(ctx);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let ctx = scenario.ctx();
            inft_core::mint_nft(
                string::utf8(b"Test INFT"),
                string::utf8(b"Intelligent NFT"),
                string::utf8(b"walrus://image"),
                string::utf8(b"walrus://public"),
                string::utf8(b"walrus://private"),
                string::utf8(b"atoma-123"),
                ctx
            );
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let mut nft = scenario.take_from_sender<INFT>();
            let ctx = scenario.ctx();
            let mut payment = mint_sui(10_000_000_000, ctx); // 10 SUI
            inft_core::add_balance(&mut nft, &mut payment, 10_000_000_000, ctx);
            assert!(inft_core::balance(&nft).value() == 10_000_000_000, 0);
            assert!(inft_core::quote_count(&nft) == 100, 1);
            coin::burn_for_testing(payment);
            test_scenario::return_to_sender(&scenario, nft);
        };
        test_scenario::next_tx(&mut scenario, USER);
        {
            let nft = scenario.take_from_sender<INFT>();
            assert!(inft_core::balance(&nft).value() == 10_000_000_000, 2);
            assert!(inft_core::quote_count(&nft) == 100, 3);
            assert!(inft_core::owner(&nft) == USER, 4);
            test_scenario::return_to_sender(&scenario, nft);
        };
        scenario.end();
    }
}