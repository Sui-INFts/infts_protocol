// Copyright (c) Infts.
// SPDX-License-Identifier: Apache-2.0

module infts_protocol::access_policy {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::dynamic_field as df;
    use sui::event;
    use sui::transfer;
    use sui::coin;
    use sui::balance;
    use sui::sui::SUI;
    use std::string::{Self, String};
    use infts_protocol::utils;
    use infts_protocol::inft_core::{Self, INFT};

    // Policy struct: Stores Seal policy ID for an INFT
    public struct AccessPolicy has key, store {
        id: UID,
        inft_id: ID, // Reference to INFT
        seal_policy_id: String, // Seal policy ID
    }

    // Events
    public struct PolicyAttachedEvent has copy, drop {
        policy_id: ID,
        inft_id: ID,
        seal_policy_id: String,
    }

    // Admin Capability
    public struct AdminCap has key { id: UID }

    // Error codes
    const ENO_OWNER: u64 = 3;
    const ENO_INVALID_NFT_TYPE: u64 = 4;

    // Attach a Seal policy to an INFT
    public entry fun attach_policy(
        inft: &mut INFT,
        seal_policy_id: String,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == inft_core::owner(inft), ENO_OWNER);

        let inft_id = object::uid_to_inner(inft_core::id(inft));
        
        let policy = AccessPolicy {
            id: object::new(ctx),
            inft_id,
            seal_policy_id,
        };

        // Attach seal_policy_id as a dynamic field on INFT
        let inft_uid = inft_core::id_mut(inft);
        df::add(inft_uid, string::utf8(b"seal_policy"), seal_policy_id);

        event::emit(PolicyAttachedEvent {
            policy_id: object::uid_to_inner(&policy.id),
            inft_id,
            seal_policy_id,
        });

        transfer::public_transfer(policy, tx_context::sender(ctx));
    }

    // Get the Seal policy ID for an INFT
    public fun get_policy_id(inft: &INFT): String {
        let inft_uid = inft_core::id(inft);
        if (df::exists_(inft_uid, string::utf8(b"seal_policy"))) {
            *df::borrow<String, String>(inft_uid, string::utf8(b"seal_policy"))
        } else {
            string::utf8(b"")
        }
    }

    public fun get_seal_policy_id(policy: &AccessPolicy): String {
        policy.seal_policy_id
    }

    // Verify access (called by dApp, not enforced on-chain)
    public fun verify_access(
        inft: &INFT,
        user: address,
    ): bool {
        // Check if user is the owner
        inft_core::owner(inft) == user
    }

    // Admin function to mint NFT without payment (for promotions, etc.)
    public entry fun admin_mint_nft(
        _admin_cap: &AdminCap,
        name: String,
        description: String,
        public_metadata_uri: String,
        private_metadata_uri: String,
        atoma_model_id: String,
        policy_id: String,
        nft_type: u8,
        recipient: address,
        ctx: &mut TxContext
    ) {
        // Validate NFT type
        assert!(nft_type <= 3, ENO_INVALID_NFT_TYPE);

        // Create the new NFT via inft_core module
        let mut inft = inft_core::create_nft(
        name,
        description,
        public_metadata_uri,
        private_metadata_uri,
        atoma_model_id,
        recipient,
        ctx
    );

        // Get the INFT object ID for tracking
        let inft_id = object::uid_to_inner(inft_core::id(&inft));

        // Attach policy_id as a dynamic field to the INFT
        let inft_uid = inft_core::id_mut(&mut inft);
        df::add(inft_uid, string::utf8(b"seal_policy"), policy_id);

        // Create the policy object to track this relationship
        let policy = AccessPolicy {
            id: object::new(ctx),
            inft_id,
            seal_policy_id: policy_id,
        };
        
        // Emit event for policy attachment
        event::emit(PolicyAttachedEvent {
            policy_id: object::uid_to_inner(&policy.id),
            inft_id,
            seal_policy_id: policy_id,
        });
        
        // Transfer the policy to the recipient
        transfer::public_transfer(policy, recipient);
        
        // Transfer the NFT to the recipient
        transfer::public_transfer(inft, recipient);
    }

    // Function to update metadata URI (owner only)
    public entry fun update_metadata_uri(
        inft: &mut INFT,
        new_uri: String,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == inft_core::owner(inft), ENO_OWNER);
        inft_core::set_public_metadata_uri(inft, new_uri);
    }

    // Function to update encrypted URI (owner only)
    public entry fun update_encrypted_uri(
        inft: &mut INFT,
        new_uri: String,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == inft_core::owner(inft), ENO_OWNER);
        inft_core::set_private_metadata_uri(inft, new_uri);
    }

    // Function to update policy ID (owner only)
    public entry fun update_policy_id(
    inft: &mut INFT,
    new_policy_id: String,
    ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == inft_core::owner(inft), ENO_OWNER);

        let inft_uid = inft_core::id_mut(inft);

        // Define key once outside with clear type inference
        let key = string::utf8(b"seal_policy");
        
        if (df::exists_(inft_uid, key)) {
            let _: String = df::remove<String, String>(inft_uid, key);
        };

        df::add<String, String>(inft_uid, key, new_policy_id);
    }
    
    // Create admin capability (should be called only once during initialization)
    public fun create_admin_cap(ctx: &mut TxContext): AdminCap {
        AdminCap { id: object::new(ctx) }
    }
}