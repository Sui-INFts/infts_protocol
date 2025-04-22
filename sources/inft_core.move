// module inft_core::inft_core {
//     use std::string::{Self, String};
//     use sui::object::{Self, ID, UID};
//     use sui::tx_context::{Self, TxContext};
//     use sui::url::{Self, Url};
//     use sui::transfer;
//     use sui::package;
//     use sui::display;
//     use sui::event;
//     use sui::coin::Coin;
//     use sui::sui::SUI;

//     const EInsufficientPayment: u64 = 0;
//     const EIncorrectNFTType: u64 = 1;

//     // Type of NFTs 
//     const TYPE_COMMON: u8 = 0;
//     const TYPE_RARE: u8 = 1;
//     const TYPE_EPIC: u8 = 2;
//     const TYPE_LEGENDARY: u8 = 3;

//     const PRICE_COMMON: u64 = 1_000_000_000; // 1 SUI
//     const PRICE_RARE: u64 = 5_000_000_000;   // 5 SUI
//     const PRICE_EPIC: u64 = 10_000_000_000;  // 10 SUI
//     const PRICE_LEGENDARY: u64 = 25_000_000_000; // 25 SUI

//     //Hardcoded Admin Address for testing purposes
//     const ADMIN_ADDRESS: address = @0x0db3cbc4637f1fc289a65b8b5e5018ffe2df8681f84229d51264f95558e15d5f;

//     // Admin
//     public struct AdminCap has key { id: UID }

//     // NFT 
//     public struct INFT has key, store {
//         id: UID,
//         name: String,
//         description: String,
//         public_metadata_uri: Url, //get from walrus
//         encrypted_content_uri: Url, //get from walrus
//         policy_id: String,
//         nft_type: u8,
//         creator: address,
//         created_at: u64,
//     }

//     // Publishers for NFT Display
//     public struct INFTPublisher has key { id: UID }

//     // Events
//     public struct NFTMinted has copy, drop {
//         object_id: ID,
//         creator: address,
//         owner: address,
//         nft_type: u8,
//         name: String,
//         public_metadata_uri: String,
//     }

//     public struct PolicyAttached has copy, drop {
//         object_id: ID,
//         policy_id: String,
//     }

//     public struct INFT_CORE has drop {}

//     fun init(witness: INFT_CORE, ctx: &mut TxContext) {
//         // Create and transfer Admin capability
//         let admin_cap = AdminCap {
//             id: object::new(ctx),
//         };
//         transfer::transfer(admin_cap, tx_context::sender(ctx)); // Admin Privileges transfer to sender

//         // Create Publisher for NFT Display
//         let publisher = package::claim(witness, ctx);
        
//         // Display for INFT
//         let mut display_builder = display::new_with_fields<INFT>(
//             &publisher,
//             vector[
//                 string::utf8(b"name"),
//                 string::utf8(b"description"),
//                 string::utf8(b"image"),
//                 string::utf8(b"creator"),
//                 string::utf8(b"type"),
//             ],
//             vector[
//                 string::utf8(b"{name}"),
//                 string::utf8(b"{description}"),         
//                 string::utf8(b"{public_metadata_uri}"), 
//                 string::utf8(b"{creator}"),             
//                 string::utf8(b"{nft_type}"),
//             ],
//             ctx
//         );
//         display::update_version(&mut display_builder);
//         transfer::public_share_object(display_builder);

//         // Transfer publisher 
//         let publisher_obj = INFTPublisher {
//             id: object::new(ctx),
//         };
//         transfer::share_object(publisher_obj);
//         transfer::public_transfer(publisher, tx_context::sender(ctx));
//     }

//     public entry fun mint_nft(
//         payment: &mut Coin<SUI>,
//         name: vector<u8>,
//         description: vector<u8>,
//         public_metadata_uri: vector<u8>,
//         encrypted_content_uri: vector<u8>,
//         policy_id: vector<u8>,
//         nft_type: u8,
//         ctx: &mut TxContext
//     ) {
//         assert!(nft_type <= TYPE_LEGENDARY, EIncorrectNFTType);
//         let price = get_price_by_type(nft_type);
//         assert!(sui::coin::value(payment) >= price, EInsufficientPayment);
        
//         // Extract payment 
//         let paid = sui::coin::split(payment, price, ctx);
//         // transfer::public_transfer(paid, tx_context::sender(ctx)); //(just for the testnet)
//         transfer::public_transfer(paid, ADMIN_ADDRESS);
        
//         // Create the NFT
//         let nft = INFT {
//             id: object::new(ctx),
//             name: string::utf8(name),
//             description: string::utf8(description),
//             public_metadata_uri: url::new_unsafe_from_bytes(public_metadata_uri),
//             encrypted_content_uri: url::new_unsafe_from_bytes(encrypted_content_uri),
//             policy_id: string::utf8(policy_id),
//             nft_type,
//             creator: tx_context::sender(ctx),
//             created_at: tx_context::epoch(ctx),
//         };
        
//         // Emit event
//         event::emit(NFTMinted {
//             object_id: object::id(&nft),
//             creator: tx_context::sender(ctx),
//             owner: tx_context::sender(ctx),
//             nft_type,
//             name: string::utf8(name),
//             public_metadata_uri: string::utf8(public_metadata_uri),
//         });
        
//         // Emit policy event
//         event::emit(PolicyAttached {
//             object_id: object::id(&nft),
//             policy_id: string::utf8(policy_id),
//         });
        
//         // Transfer NFT to sender
//         transfer::transfer(nft, tx_context::sender(ctx));
//     }

//     // Admin function to mint NFT without payment (for promotions, etc.)
//     // No payment required
//     // Only callable by admin
//     // Admin can mint any type of NFT
//     public entry fun admin_mint_nft(
//         _: &AdminCap,
//         name: vector<u8>,
//         description: vector<u8>,
//         public_metadata_uri: vector<u8>,
//         encrypted_content_uri: vector<u8>,
//         policy_id: vector<u8>,
//         nft_type: u8,
//         recipient: address,
//         ctx: &mut TxContext
//     ) {
//         // Validate NFT type
//         assert!(nft_type <= TYPE_LEGENDARY, EIncorrectNFTType);
        
//         // Create the NFT
//         let nft = INFT {
//             id: object::new(ctx),
//             name: string::utf8(name),
//             description: string::utf8(description),
//             public_metadata_uri: url::new_unsafe_from_bytes(public_metadata_uri),
//             encrypted_content_uri: url::new_unsafe_from_bytes(encrypted_content_uri),
//             policy_id: string::utf8(policy_id),
//             nft_type,
//             creator: tx_context::sender(ctx),
//             created_at: tx_context::epoch(ctx),
//         };
        
//         // Emit event
//         event::emit(NFTMinted {
//             object_id: object::id(&nft),
//             creator: tx_context::sender(ctx),
//             owner: recipient,
//             nft_type,
//             name: string::utf8(name),
//             public_metadata_uri: string::utf8(public_metadata_uri),
//         });
        
//         // Emit policy event
//         event::emit(PolicyAttached {
//             object_id: object::id(&nft),
//             policy_id: string::utf8(policy_id),
//         });
        
//         // Transfer NFT to recipient
//         transfer::transfer(nft, recipient);
//     }

//     // Get price based on NFT type
//     public fun get_price_by_type(nft_type: u8): u64 {
//         if (nft_type == TYPE_COMMON) {
//             PRICE_COMMON
//         } else if (nft_type == TYPE_RARE) {
//             PRICE_RARE
//         } else if (nft_type == TYPE_EPIC) {
//             PRICE_EPIC
//         } else if (nft_type == TYPE_LEGENDARY) {
//             PRICE_LEGENDARY
//         } else {
//             abort EIncorrectNFTType
//         }
//     }

//     // Function to update metadata URI (admin only)
//     public entry fun update_metadata_uri(
//         _: &AdminCap,
//         nft: &mut INFT,
//         new_uri: vector<u8>,
//     ) {
//         nft.public_metadata_uri = url::new_unsafe_from_bytes(new_uri);
//     }

//     // Function to update encrypted URI (admin only)
//     public entry fun update_encrypted_uri(
//         _: &AdminCap,
//         nft: &mut INFT,
//         new_uri: vector<u8>,
//     ) {
//         nft.encrypted_content_uri = url::new_unsafe_from_bytes(new_uri);
//     }

//     // Function to update policy ID (admin only)
//     public entry fun update_policy_id(
//         _: &AdminCap,
//         nft: &mut INFT,
//         new_policy_id: vector<u8>,
//     ) {
//         nft.policy_id = string::utf8(new_policy_id);
        
//         // Emit updated policy event
//         event::emit(PolicyAttached {
//             object_id: object::id(nft),
//             policy_id: string::utf8(new_policy_id),
//         });
//     }

//     // Public view functions for NFT attributes
//     public fun get_name(nft: &INFT): String {
//         nft.name
//     }

//     public fun get_description(nft: &INFT): String {
//         nft.description
//     }

//     public fun get_public_metadata_uri(nft: &INFT): Url {
//         nft.public_metadata_uri
//     }

//     public fun get_encrypted_content_uri(nft: &INFT): Url {
//         nft.encrypted_content_uri
//     }

//     public fun get_policy_id(nft: &INFT): String {
//         nft.policy_id
//     }

//     public fun get_nft_type(nft: &INFT): u8 {
//         nft.nft_type
//     }

//     public fun get_creator(nft: &INFT): address {
//         nft.creator
//     }

//     public fun get_created_at(nft: &INFT): u64 {
//         nft.created_at
//     }
// }