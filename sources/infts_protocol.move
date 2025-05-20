module infts_protocol::inft_core {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::package;
    use sui::display;
    use sui::event;
    // use sui::balance::{Self, Balance};
    use sui::balance::{Self, Balance, split};
    use sui::sui::SUI;
    // use sui::coin::{Self, Coin};
    use sui::coin::{Self, Coin, from_balance};
    use std::string::{Self, String};
    use std::option::{Self, Option};
    use infts_protocol::utils::{Self};

    // INFT struct: Represents an intelligent NFT with dynamic state
    public struct INFT has key, store {
        id: UID,
        name: String,
        description: String,
        image_url: String, // Direct Upload URL from Walrus
        public_metadata_uri: String, // Walrus URI for public metadata (e.g., metadata.json)
        private_metadata_uri: String, // Walrus URI for encrypted private data (e.g., private.json)
        atoma_model_id: String, // Atoma AI model reference
        interaction_count: u64, // Tracks user interactions
        evolution_stage: u64, // Current evolution level
        quote_count: u64, // Tracks number of quotes associated with the iNFT
        balance: Balance<SUI>, // For fees or rewards
        owner: address, // Explicit owner field
        listing_price: Option<u64>, // Price in MIST (1 SUI = 10^9 MIST), None if not listed
    }

    // Marketplace shared object to track listings
    public struct Marketplace has key {
        id: UID,
        listings_count: u64,
        protocol_fee_percentage: u64, // Fee in basis points (e.g., 250 = 2.5%)
        fee_recipient: address,
    }

    // Witness for one-time initialization
    public struct INFT_CORE has drop {}

    // Events
    public struct MintINFTEvent has copy, drop {
        nft_id: ID,
        name: String,
        image_url: String,
        public_metadata_uri: String,
        quote_count: u64,
        owner: address,
    }

    public struct TransferINFTEvent has copy, drop {
        nft_id: ID,
        from: address,
        to: address,
    }

    public struct UpdateBalanceEvent has copy, drop {
        nft_id: ID,
        amount: u64, // Amount added in MIST
        quote_count: u64, // Updated quote count
        owner: address,
    }

    // New marketplace events
    public struct ListINFTEvent has copy, drop {
        nft_id: ID,
        owner: address,
        price: u64,
    }

    public struct UpdateListingEvent has copy, drop {
        nft_id: ID,
        owner: address,
        old_price: u64,
        new_price: u64,
    }

    public struct CancelListingEvent has copy, drop {
        nft_id: ID,
        owner: address,
    }

    public struct PurchaseINFTEvent has copy, drop {
        nft_id: ID,
        seller: address,
        buyer: address,
        price: u64,
        fee_amount: u64,
    }

    // Error codes
    const ENO_EMPTY_NAME: u64 = 0;
    const ENO_EMPTY_IMAGE_URL: u64 = 1;
    const ENO_EMPTY_PUBLIC_URI: u64 = 2;
    const ENO_EMPTY_ATOMA_MODEL: u64 = 3;
    const ENO_OWNER: u64 = 4;
    const ENO_NOT_LISTED: u64 = 5;
    const ENO_ALREADY_LISTED: u64 = 6;
    const ENO_INSUFFICIENT_PAYMENT: u64 = 7;
    const ENO_MARKETPLACE_ADMIN: u64 = 8;
    const ENO_ZERO_PRICE: u64 = 9;

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

    public fun quote_count(self: &INFT): u64 {
        self.quote_count
    }

    public fun balance(self: &INFT): &Balance<SUI> {
        &self.balance
    }

    public fun owner(self: &INFT): address {
        self.owner
    }

    public fun listing_price(self: &INFT): Option<u64> {
        self.listing_price
    }

    public fun is_listed(self: &INFT): bool {
        option::is_some(&self.listing_price)
    }

    // Setter functions for evolution_logic and internal use
    public fun set_image_url(self: &mut INFT, url: String, ctx: &TxContext) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        self.image_url = url;
    }

    public fun set_public_metadata_uri(self: &mut INFT, uri: String) {
        self.public_metadata_uri = uri;
    }

    public fun set_private_metadata_uri(self: &mut INFT, uri: String) {
        self.private_metadata_uri = uri;
    }

    public fun increment_interaction_count(self: &mut INFT) {
        self.interaction_count = self.interaction_count + 1;
    }

    public fun increment_evolution_stage(self: &mut INFT) {
        self.evolution_stage = self.evolution_stage + 1;
    }

    public fun increment_quote_count(self: &mut INFT) {
        self.quote_count = self.quote_count + 1;
    }

    // Set the owner field directly in functions that need it

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
            string::utf8(b"quote_count"),
            string::utf8(b"listing_price"),
        ];
        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{description}"),
            string::utf8(b"{image_url}"),
            string::utf8(b"{evolution_stage}"),
            string::utf8(b"{quote_count}"),
            string::utf8(b"{listing_price}"),
        ];

        let publisher = package::claim(witness, ctx);
        let mut display = display::new_with_fields<INFT>(
            &publisher, keys, values, ctx
        );
        display::update_version(&mut display);

        // Create and share the marketplace object
        let marketplace = Marketplace {
            id: object::new(ctx),
            listings_count: 0,
            protocol_fee_percentage: 250, // 2.5% fee
            fee_recipient: tx_context::sender(ctx),
        };

        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
        transfer::share_object(marketplace);
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
        assert!(!string::is_empty(&public_metadata_uri), ENO_EMPTY_PUBLIC_URI);
        assert!(!string::is_empty(&image_url), ENO_EMPTY_IMAGE_URL);
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
            quote_count: 0,
            balance: balance::zero(),
            owner,
            listing_price: option::none(),
        };

        let nft_id = object::uid_to_inner(&nft.id);
        event::emit(MintINFTEvent {
            nft_id,
            name,
            image_url,
            public_metadata_uri,
            quote_count: 0,
            owner,
        });
        nft
    }

    // Create a new INFT with listing price (doesn't transfer)
    public fun create_nft_with_listing(
        name: String,
        description: String,
        image_url: String,
        public_metadata_uri: String,
        private_metadata_uri: String,
        atoma_model_id: String,
        owner: address,
        price: u64,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext,
    ): INFT {
        assert!(price > 0, ENO_ZERO_PRICE);
        
        let mut nft = create_nft(
            name,
            description,
            image_url,
            public_metadata_uri,
            private_metadata_uri,
            atoma_model_id,
            owner,
            ctx,
        );
        
        // Set listing price
        nft.listing_price = option::some(price);
        
        // Update marketplace listings count
        marketplace.listings_count = marketplace.listings_count + 1;
        
        // Emit listing event
        let nft_id = object::uid_to_inner(&nft.id);
        event::emit(ListINFTEvent {
            nft_id,
            owner,
            price,
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

    // Mint a new INFT with listing price
    public entry fun mint_nft_with_listing(
        name: String,
        description: String,
        image_url: String,
        public_metadata_uri: String,
        private_metadata_uri: String,
        atoma_model_id: String,
        price: u64,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let nft = create_nft_with_listing(
            name,
            description,
            image_url,
            public_metadata_uri,
            private_metadata_uri,
            atoma_model_id,
            sender,
            price,
            marketplace,
            ctx
        );

        // Transfer the INFT to the sender
        transfer::public_transfer(nft, sender);
    }

    // Transfer INFT to a new owner
    public entry fun transfer_nft(
        nft: INFT,
        new_owner: address,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == nft.owner, ENO_OWNER);
        let old_owner = nft.owner;
        let nft_id = object::uid_to_inner(&nft.id);
        
        // Create mutable instance with updated owner
        let mut updated_nft = nft;
        
        // Reset listing if any
        if (option::is_some(&updated_nft.listing_price)) {
            updated_nft.listing_price = option::none();
        };
        
        // Update owner directly
        updated_nft.owner = new_owner;
        
        event::emit(TransferINFTEvent {
            nft_id,
            from: old_owner,
            to: new_owner,
        });
        transfer::public_transfer(updated_nft, new_owner);
    }

    // List an INFT for sale
    public entry fun list_nft(
        self: &mut INFT,
        price: u64,
        marketplace: &mut Marketplace,
        ctx: &TxContext,
    ) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        assert!(price > 0, ENO_ZERO_PRICE);
        assert!(option::is_none(&self.listing_price), ENO_ALREADY_LISTED);
        
        // Set listing price
        self.listing_price = option::some(price);
        
        // Update marketplace listings count
        marketplace.listings_count = marketplace.listings_count + 1;
        
        // Emit listing event
        let nft_id = object::uid_to_inner(&self.id);
        event::emit(ListINFTEvent {
            nft_id,
            owner: self.owner,
            price,
        });
    }

    // Update an INFT listing price
    public entry fun update_listing(
        self: &mut INFT,
        new_price: u64,
        ctx: &TxContext,
    ) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        assert!(new_price > 0, ENO_ZERO_PRICE);
        assert!(option::is_some(&self.listing_price), ENO_NOT_LISTED);
        
        let old_price = *option::borrow(&self.listing_price);
        
        // Update listing price
        self.listing_price = option::some(new_price);
        
        // Emit update event
        let nft_id = object::uid_to_inner(&self.id);
        event::emit(UpdateListingEvent {
            nft_id,
            owner: self.owner,
            old_price,
            new_price,
        });
    }

    // Cancel an INFT listing
    public entry fun cancel_listing(
        self: &mut INFT,
        marketplace: &mut Marketplace,
        ctx: &TxContext,
    ) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        assert!(option::is_some(&self.listing_price), ENO_NOT_LISTED);
        
        // Remove listing
        self.listing_price = option::none();
        
        // Update marketplace listings count
        marketplace.listings_count = marketplace.listings_count - 1;
        
        // Emit cancel event
        let nft_id = object::uid_to_inner(&self.id);
        event::emit(CancelListingEvent {
            nft_id,
            owner: self.owner,
        });
    }

    // Purchase an INFT by paying the listing price
    public entry fun purchase_nft(
        nft: INFT,
        payment: &mut Coin<SUI>,
        marketplace: &mut Marketplace,
        ctx: &mut TxContext,
    ) {
        let buyer = tx_context::sender(ctx);
        let seller = nft.owner;
        
        // Verify NFT is listed
        assert!(option::is_some(&nft.listing_price), ENO_NOT_LISTED);
        
        // Get listing price
        let price = *option::borrow(&nft.listing_price);
        
        // Verify payment has enough funds
        assert!(coin::value(payment) >= price, ENO_INSUFFICIENT_PAYMENT);
        
        // Calculate protocol fee (fee_percentage is in basis points)
        let fee_amount = (price * marketplace.protocol_fee_percentage) / 10000;
        let seller_amount = price - fee_amount;
        
        // Process payment
        let coin_balance = coin::balance_mut(payment);
        
        // Send fee to protocol
        if (fee_amount > 0) {
            let fee_payment = balance::split(coin_balance, fee_amount);
            let fee_coin = coin::from_balance(fee_payment, ctx);
            transfer::public_transfer(fee_coin, marketplace.fee_recipient);
        };
        
        // Send payment to seller
        let seller_payment = balance::split(coin_balance, seller_amount);
        let seller_coin = coin::from_balance(seller_payment, ctx);
        transfer::public_transfer(seller_coin, seller);
        
        // Update marketplace listings count
        marketplace.listings_count = marketplace.listings_count - 1;
        
        // Create mutable instance with updated state
        let mut updated_nft = nft;
        
        // Remove listing and update owner
        updated_nft.listing_price = option::none();
        updated_nft.owner = buyer;
        
        // Emit purchase event
        let nft_id = object::uid_to_inner(&updated_nft.id);
        event::emit(PurchaseINFTEvent {
            nft_id,
            seller,
            buyer,
            price,
            fee_amount,
        });
        
        // Transfer NFT to buyer
        transfer::public_transfer(updated_nft, buyer);
    }

    // Add SUI to INFT balance and increment quote_count (1 SUI = 10 quotes)
    public entry fun add_balance(
        self: &mut INFT,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        assert!(amount > 0, utils::einsufficient_balance());

        // Add SUI to balance
        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, amount);
        balance::join(&mut self.balance, paid);

        // Calculate quote_count increment: 1 SUI (10^9 MIST) = 10 quotes
        let sui_amount = amount / 1_000_000_000; // Convert MIST to SUI
        let quote_increment = sui_amount * 10; // 10 quotes per SUI
        self.quote_count = self.quote_count + quote_increment;

        // Emit event for frontend
        let nft_id = object::uid_to_inner(&self.id);
        event::emit(UpdateBalanceEvent {
            nft_id,
            amount,
            quote_count: self.quote_count,
            owner: self.owner,
        });
    }

    // Withdraw SUI from INFT balance
    public entry fun withdraw_balance(
        self: &mut INFT,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        assert!(tx_context::sender(ctx) == self.owner, ENO_OWNER);
        assert!(amount <= balance::value(&self.balance), utils::einsufficient_balance());
        let withdrawn = coin::from_balance(
            balance::split(&mut self.balance, amount),
            ctx,
        );
        transfer::public_transfer(withdrawn, tx_context::sender(ctx));
    }

    // Marketplace admin functions
    public entry fun update_protocol_fee(
        marketplace: &mut Marketplace,
        new_fee_percentage: u64,
        ctx: &TxContext,
    ) {
        assert!(tx_context::sender(ctx) == marketplace.fee_recipient, ENO_MARKETPLACE_ADMIN);
        assert!(new_fee_percentage <= 1000, 0); // Max 10% fee
        marketplace.protocol_fee_percentage = new_fee_percentage;
    }

    public entry fun update_fee_recipient(
        marketplace: &mut Marketplace,
        new_recipient: address,
        ctx: &TxContext,
    ) {
        assert!(tx_context::sender(ctx) == marketplace.fee_recipient, ENO_MARKETPLACE_ADMIN);
        marketplace.fee_recipient = new_recipient;
    }
}