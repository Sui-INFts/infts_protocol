// Copyright (c) Infts.

module infts_protocol::inft_core {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::package;
    use sui::display;
    use sui::event;
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use std::string::{Self, String};
    use infts_protocol::utils::{Self};

    // INFT struct: Represents an intelligent NFT with dynamic state
    public struct INFT has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: String, // Direct image URL from Walrus
        public_metadata_uri: String, // Walrus URI for public metadata (e.g., metadata.json)
        private_metadata_uri: String, // Walrus URI for encrypted private data (e.g., private.json)
        atoma_model_id: String, // Atoma AI model reference
        interaction_count: u64, // Tracks user interactions
        evolution_stage: u64, // Current evolution level
        balance: Balance<SUI>, // For fees or rewards
        owner: address, // Explicit owner field
    }

    // Witness for one-time initialization
    public struct INFT_CORE has drop {}

    // Events
    public struct MintINFTEvent has copy, drop {
        nft_id: ID,
        name: String,
        image_url: String,
        public_metadata_uri: String,
        owner: address,
    }

    public struct TransferINFTEvent has copy, drop {
        nft_id: ID,
        from: address,
        to: address,
    }

    // Error codes
    const ENO_EMPTY_NAME: u64 = 0;
    const ENO_EMPTY_IMAGE_URL: u64 = 1;
    const ENO_EMPTY_PUBLIC_URI: u64 = 2;
    const ENO_EMPTY_ATOMA_MODEL: u64 = 3;
    const ENO_OWNER: u64 = 4;

    // Getter functions for frontend and testing
    public fun id(self: &INFT): &UID {
        &self.id
    }

    public fun id_mut(self: &mut INFT): &mut UID {
        &mut self.id
    }

    public fun name(self: &INFT): String {
        self.name
    }

    public fun image_url(self: &INFT): String {
        self.image_url
    }

    public fun public_metadata_uri(self: &INFT): String {
        self.public_metadata_uri
    }

    public fun private_metadata_uri(self: &INFT): String {
        self.private_metadata_uri
    }

    public fun atoma_model_id(self: &INFT): String {
        self.atoma_model_id
    }

    public fun interaction_count(self: &INFT): u64 {
        self.interaction_count
    }

    public fun evolution_stage(self: &INFT): u64 {
        self.evolution_stage
    }

    public fun balance(self: &INFT): &Balance<SUI> {
        &self.balance
    }

    public fun owner(self: &INFT): address {
        self.owner
    }

    // Setter functions for evolution_logic and internal use
    public fun set_image_url(self: &mut INFT, url: String, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        self.image_url = url;
    }

    public fun set_public_metadata_uri(self: &mut INFT, uri: String, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        self.public_metadata_uri = uri;
    }

    public fun set_private_metadata_uri(self: &mut INFT, uri: String, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        self.private_metadata_uri = uri;
    }

    public fun increment_interaction_count(self: &mut INFT, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        self.interaction_count = self.interaction_count + 1;
    }

    public fun increment_evolution_stage(self: &mut INFT, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        self.evolution_stage = self.evolution_stage + 1;
    }

    fun set_owner(self: &mut INFT, new_owner: address) {
        self.owner = new_owner;
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let witness = INFT_CORE {};
        init(witness, ctx);
    }

    // Initialize the protocol (called once on publish)
    fun init(witness: INFT_CORE, ctx: &mut TxContext) {
        let keys = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
            string::utf8(b"evolution_stage"),
        ];
        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{description}"),
            string::utf8(b"{image_url}"), // This now directly uses image_url field
            string::utf8(b"{evolution_stage}"),
        ];

        let publisher = package::claim(witness, ctx);
        let mut display = display::new_with_fields<INFT>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    // Create a new INFT and return it (doesn't transfer)
    public fun create_nft(
        name: String, 
        description: String,
        image_url: String,
        public_metadata_uri: String,
        private_metadata_uri: String, 
        atoma_model_id: String,
        owner: address,
        ctx: &mut TxContext,
    ): INFT {
        assert!(!string::is_empty(&name), ENO_EMPTY_NAME);
        assert!(!string::is_empty(&image_url), ENO_EMPTY_IMAGE_URL);
        assert!(!string::is_empty(&public_metadata_uri), ENO_EMPTY_PUBLIC_URI);
        assert!(!string::is_empty(&atoma_model_id), ENO_EMPTY_ATOMA_MODEL);

        let nft = INFT {
            id: object::new(ctx),
            name,
            description,
            image_url,
            public_metadata_uri,
            private_metadata_uri,
            atoma_model_id,
            interaction_count: 0,
            evolution_stage: 0,
            balance: balance::zero(),
            owner,
        };

        let nft_id = object::uid_to_inner(&nft.id);
        event::emit(MintINFTEvent {
            nft_id,
            name,
            image_url,
            public_metadata_uri,
            owner,
        });
        nft
    }
    
    // Mint a new INFT
    public entry fun mint_nft(
        name: String,
        description: String,
        image_url: String,
        public_metadata_uri: String,
        private_metadata_uri: String,
        atoma_model_id: String,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let nft = create_nft(
            name,
            description,
            image_url,
            public_metadata_uri,
            private_metadata_uri,
            atoma_model_id,
            sender,
            ctx
        );

        // Transfer the INFT to the sender
        transfer::public_transfer(nft, sender);
    }

    // Transfer INFT to a new owner
    public entry fun transfer_nft(
        self: INFT,
        new_owner: address,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        let old_owner = self.owner;
        let nft_id = object::uid_to_inner(&self.id);
        let mut nft = self;
        set_owner(&mut nft, new_owner);
        event::emit(TransferINFTEvent {
            nft_id,
            from: old_owner,
            to: new_owner,
        });
        transfer::public_transfer(nft, new_owner);
    }

    // Add SUI to INFT balance (e.g., for interaction fees)
    public entry fun add_balance(
        self: &mut INFT,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        assert!(amount > 0, utils::einsufficient_balance());
        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, amount);
        balance::join(&mut self.balance, paid);
    }

    // Withdraw SUI from INFT balance
    public entry fun withdraw_balance(
        self: &mut INFT,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        assert!(amount <= self.balance.value(), utils::einsufficient_balance());
        let withdrawn = coin::from_balance(
            balance::split(&mut self.balance, amount),
            ctx,
        );
        transfer::public_transfer(withdrawn, tx_context::sender(ctx));
    }
}
