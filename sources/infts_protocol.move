/*
/// Module: infts_protocol
module infts_protocol::infts_protocol;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions
module infts_protocol::infts {
    use sui::tx_context; // Remove redundant aliases
    use sui::object;
    use sui::transfer;
    use sui::package;
    use sui::display;
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use std::string::{Self, String};

    public struct INFT has key, store {
        id: object::UID,
        name: String,
        description: String,
        walrus_blob_id: String,
        walrus_sui_object: String,
        balance: Balance<SUI>,
    }

    public struct INFTs_NFT has drop {}

    const ENO_EMPTY_NAME: u64 = 0;
    const ENO_EMPTY_BLOB_ID: u64 = 1;
    const EINSUFFICIENT_BALANCE: u64 = 2; // Added for withdraw safety

    // Getter functions for testing
    public fun name(self: &INFT): String {
        self.name
    }

    public fun description(self: &INFT): String {
        self.description
    }

    public fun walrus_blob_id(self: &INFT): String {
        self.walrus_blob_id
    }

    public fun walrus_sui_object(self: &INFT): String {
        self.walrus_sui_object
    }

    public fun balance(self: &INFT): &Balance<SUI> {
        &self.balance
    }

   #[test_only]
    public fun init_for_testing(ctx: &mut tx_context::TxContext) {
        let witness = INFTs_NFT {};
        initialize(witness, ctx);
    }

    fun initialize(witness: INFTs_NFT, ctx: &mut tx_context::TxContext) {
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
        ];
        
        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{description}"),
            string::utf8(b"https://aggregator.walrus-testnet.walrus.space/v1/{walrus_blob_id}"),
        ];
        
        let publisher = package::claim(witness, ctx);
        let mut display = display::new_with_fields<INFT>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);
        
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    public entry fun mint_nft(
        name: String,
        description: String,
        walrus_blob_id: String,
        walrus_sui_object: String,
        ctx: &mut tx_context::TxContext,
    ) {
        assert!(!string::is_empty(&name), ENO_EMPTY_NAME);
        assert!(!string::is_empty(&walrus_blob_id), ENO_EMPTY_BLOB_ID);

        let nft = INFT {
            id: object::new(ctx),
            name,
            description,
            walrus_blob_id,
            walrus_sui_object,
            balance: balance::zero(),
        };

        transfer::transfer(nft, tx_context::sender(ctx));
    }

    public entry fun add_balance(
        self: &mut INFT,
        payment: &mut Coin<SUI>,
        amount: u64,
    ) {
        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, amount);
        balance::join(&mut self.balance, paid);
    }

    public entry fun withdraw_balance(
        self: &mut INFT,
        amount: u64,
        ctx: &mut tx_context::TxContext,
    ) {
        assert!(amount <= self.balance.value(), EINSUFFICIENT_BALANCE); // Added safety
        let withdrawn = coin::from_balance(
            balance::split(&mut self.balance, amount),
            ctx,
        );
        transfer::public_transfer(withdrawn, tx_context::sender(ctx));
    }
}

