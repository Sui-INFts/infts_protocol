// Copyright (c) Infts
// SPDX-License-Identifier: Apache-2.0

module infts_protocol::evolution_logic {
    use sui::tx_context::{Self, TxContext};
    use sui::event;
    use sui::object;
    use std::string::{Self, String};
    use infts_protocol::inft_core::{Self, INFT};
    use infts_protocol::access_policy;
    use infts_protocol::utils;

    // Events
    public struct StateUpdatedEvent has copy, drop {
        nft_id: ID,
        new_public_metadata_uri: String,
        new_private_metadata_uri: String,
        new_evolution_stage: u64,
    }

    // Error codes
    const ENO_AUTHORIZED: u64 = 4;

    // Update INFT state (e.g., after AI interaction)
    public entry fun update_state(
        inft: &mut INFT,
        new_public_metadata_uri: String,
        new_private_metadata_uri: String,
        ctx: &mut TxContext,
    ) {
        assert!(access_policy::verify_access(inft, tx_context::sender(ctx)), ENO_AUTHORIZED);

        // Use setters to update fields
        inft_core::set_public_metadata_uri(inft, new_public_metadata_uri);
        inft_core::set_private_metadata_uri(inft, new_private_metadata_uri);
        inft_core::increment_interaction_count(inft);
        inft_core::increment_evolution_stage(inft);

        // Use getters for event emission
        event::emit(StateUpdatedEvent {
            nft_id: object::uid_to_inner(inft_core::id(inft)),
            new_public_metadata_uri,
            new_private_metadata_uri,
            new_evolution_stage: inft_core::evolution_stage(inft),
        });
    }
}