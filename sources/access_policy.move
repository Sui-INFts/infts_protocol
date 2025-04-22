// Copyright (c) Infts.
// SPDX-License-Identifier: Apache-2.0

module infts_protocol::access_policy {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::dynamic_field as df;
    use sui::event;
    use std::string::{Self, String};
    use infts_protocol::inft_core::{Self, INFT};
    use infts_protocol::utils;

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

    // Error codes
    const ENO_OWNER: u64 = 3;

    // Attach a Seal policy to an INFT
    public entry fun attach_policy(
        inft: &mut INFT,
        seal_policy_id: String,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == inft_core::owner(inft), ENO_OWNER);

        let policy = AccessPolicy {
            id: object::new(ctx),
            inft_id: object::uid_to_inner(inft_core::id(inft)),
            seal_policy_id,
        };

        // Attach seal_policy_id as a dynamic field on INFT
        df::add(inft_core::id_mut(inft), string::utf8(b"seal_policy"), policy.seal_policy_id);

        event::emit(PolicyAttachedEvent {
            policy_id: object::uid_to_inner(&policy.id),
            inft_id: policy.inft_id,
            seal_policy_id,
        });

        transfer::public_transfer(policy, tx_context::sender(ctx));
    }

    // Get the Seal policy ID for an INFT
    public fun get_policy_id(inft: &INFT): String {
        *df::borrow<String, String>(inft_core::id(inft), string::utf8(b"seal_policy"))
    }

    public fun get_seal_policy_id(policy: &AccessPolicy): String {
        policy.seal_policy_id
    }

    // Verify access (called by dApp, not enforced on-chain)
    public fun verify_access(
        inft: &INFT,
        user: address,
        _ctx: &TxContext,
    ): bool {
        // Placeholder: Seal verification happens off-chain via Seal SDK
        // On-chain, we only check ownership as a basic check
        inft_core::owner(inft) == user
    }
}
