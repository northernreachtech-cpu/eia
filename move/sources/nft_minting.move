module eia::nft_minting;

use std::string::{Self, String};
use sui::event;
use sui::table::{Self, Table};
use sui::display;
use sui::package;
use eia::attendance_verification::{Self, MintPoACapability, MintCompletionCapability};

// Error codes
const EInvalidCapability: u64 = 1;
const EAlreadyMinted: u64 = 2;

// NFT Types
public struct ProofOfAttendance has key, store {
    id: UID,
    event_id: ID,
    event_name: String,
    attendee: address,
    check_in_time: u64,
    metadata: NFTMetadata,
}

public struct NFTOfCompletion has key, store {
    id: UID,
    event_id: ID,
    event_name: String,
    attendee: address,
    check_in_time: u64,
    check_out_time: u64,
    attendance_duration: u64,
    metadata: NFTMetadata,
}

public struct NFTMetadata has store, drop, copy {
    description: String,
    image_url: String,
    location: String,
    organizer: address,
    attributes: vector<Attribute>,
}

public struct Attribute has store, drop, copy {
    trait_type: String,
    value: String,
}

// NFT Registry for tracking minted tokens
public struct NFTRegistry has key {
    id: UID,
    // event_id -> minted NFTs tracking
    event_nfts: Table<ID, EventNFTs>,
    // wallet -> owned NFTs
    user_nfts: Table<address, UserNFTs>,
    total_poa_minted: u64,
    total_completion_minted: u64,
}

public struct EventNFTs has store {
    poa_minted: Table<address, ID>, // wallet -> NFT ID
    completion_minted: Table<address, ID>, // wallet -> NFT ID
    total_poa: u64,
    total_completions: u64,
    event_metadata: EventMetadata,
}

public struct UserNFTs has store {
    poa_tokens: vector<ID>,
    completion_tokens: vector<ID>,
}

public struct EventMetadata has store, drop, copy {
    event_name: String,
    image_url: String,
    location: String,
    organizer: address,
}

// One-time witness for display
public struct NFT_MINTING has drop {}

// Events
public struct PoAMinted has copy, drop {
    nft_id: ID,
    event_id: ID,
    attendee: address,
    check_in_time: u64,
}

public struct CompletionMinted has copy, drop {
    nft_id: ID,
    event_id: ID,
    attendee: address,
    attendance_duration: u64,
}

// Initialize the module
fun init(otw: NFT_MINTING, ctx: &mut TxContext) {
    let registry = NFTRegistry {
        id: object::new(ctx),
        event_nfts: table::new(ctx),
        user_nfts: table::new(ctx),
        total_poa_minted: 0,
        total_completion_minted: 0,
    };
    transfer::share_object(registry);

    // Set up display for ProofOfAttendance
    let publisher = package::claim(otw, ctx);
    let mut poa_display = display::new<ProofOfAttendance>(&publisher, ctx);
    display::add(&mut poa_display, string::utf8(b"name"), string::utf8(b"Proof of Attendance - {event_name}"));
    display::add(&mut poa_display, string::utf8(b"description"), string::utf8(b"{metadata.description}"));
    display::add(&mut poa_display, string::utf8(b"image_url"), string::utf8(b"{metadata.image_url}"));
    display::add(&mut poa_display, string::utf8(b"project_url"), string::utf8(b"https://eia-frontend.vercel.app"));
    display::update_version(&mut poa_display);

    // Set up display for NFTOfCompletion
    let mut completion_display = display::new<NFTOfCompletion>(&publisher, ctx);
    display::add(&mut completion_display, string::utf8(b"name"), string::utf8(b"Certificate of Completion - {event_name}"));
    display::add(&mut completion_display, string::utf8(b"description"), string::utf8(b"{metadata.description}"));
    display::add(&mut completion_display, string::utf8(b"image_url"), string::utf8(b"{metadata.image_url}"));
    display::add(&mut completion_display, string::utf8(b"project_url"), string::utf8(b"https://eia-frontend.vercel.app"));
    display::update_version(&mut completion_display);

    transfer::public_transfer(poa_display, tx_context::sender(ctx));
    transfer::public_transfer(completion_display, tx_context::sender(ctx));
    transfer::public_transfer(publisher, tx_context::sender(ctx));
}

// Set event metadata for NFTs
public fun set_event_metadata(
    event_id: ID,
    event_name: String,
    image_url: String,
    location: String,
    organizer: address,
    registry: &mut NFTRegistry,
    ctx: &mut TxContext
) {
    if (!table::contains(&registry.event_nfts, event_id)) {
        let event_nfts = EventNFTs {
            poa_minted: table::new(ctx),
            completion_minted: table::new(ctx),
            total_poa: 0,
            total_completions: 0,
            event_metadata: EventMetadata {
                event_name,
                image_url,
                location,
                organizer,
            },
        };
        table::add(&mut registry.event_nfts, event_id, event_nfts);
    } else {
        let event_nfts = table::borrow_mut(&mut registry.event_nfts, event_id);
        event_nfts.event_metadata = EventMetadata {
            event_name,
            image_url,
            location,
            organizer,
        };
    };
}

// Mint Proof of Attendance NFT
public fun mint_proof_of_attendance(
    capability: MintPoACapability,
    registry: &mut NFTRegistry,
    ctx: &mut TxContext
): ID {
    let (event_id, attendee, check_in_time) = attendance_verification::consume_poa_capability(capability);
    
    // Ensure event metadata is set
    assert!(table::contains(&registry.event_nfts, event_id), EInvalidCapability);
    
    let event_nfts = table::borrow_mut(&mut registry.event_nfts, event_id);
    
    // Check if already minted
    assert!(!table::contains(&event_nfts.poa_minted, attendee), EAlreadyMinted);
    
    let event_metadata = event_nfts.event_metadata;
    
    // Create NFT metadata
    let mut attributes = vector::empty<Attribute>();
    vector::push_back(&mut attributes, Attribute {
        trait_type: string::utf8(b"Event Type"),
        value: string::utf8(b"Proof of Attendance"),
    });
    vector::push_back(&mut attributes, Attribute {
        trait_type: string::utf8(b"Check-in Time"),
        value: u64_to_string(check_in_time),
    });
    vector::push_back(&mut attributes, Attribute {
        trait_type: string::utf8(b"Location"),
        value: event_metadata.location,
    });

    let metadata = NFTMetadata {
        description: string::utf8(b"This NFT certifies attendance at the event"),
        image_url: event_metadata.image_url,
        location: event_metadata.location,
        organizer: event_metadata.organizer,
        attributes,
    };

    // Create NFT
    let nft = ProofOfAttendance {
        id: object::new(ctx),
        event_id,
        event_name: event_metadata.event_name,
        attendee,
        check_in_time,
        metadata,
    };

    let nft_id = object::id(&nft);
    
    // Update registry
    table::add(&mut event_nfts.poa_minted, attendee, nft_id);
    event_nfts.total_poa = event_nfts.total_poa + 1;
    registry.total_poa_minted = registry.total_poa_minted + 1;

    // Update user's NFT list
    if (!table::contains(&registry.user_nfts, attendee)) {
        table::add(&mut registry.user_nfts, attendee, UserNFTs {
            poa_tokens: vector::empty(),
            completion_tokens: vector::empty(),
        });
    };
    let user_nfts = table::borrow_mut(&mut registry.user_nfts, attendee);
    vector::push_back(&mut user_nfts.poa_tokens, nft_id);

    // Transfer NFT to attendee
    transfer::transfer(nft, attendee);

    event::emit(PoAMinted {
        nft_id,
        event_id,
        attendee,
        check_in_time,
    });

    nft_id
}

// Mint NFT of Completion
public fun mint_nft_of_completion(
    capability: MintCompletionCapability,
    registry: &mut NFTRegistry,
    ctx: &mut TxContext
): ID {
    let (event_id, attendee, check_in_time, check_out_time, attendance_duration) = 
        attendance_verification::consume_completion_capability(capability);
    
    // Ensure event metadata is set
    assert!(table::contains(&registry.event_nfts, event_id), EInvalidCapability);
    
    let event_nfts = table::borrow_mut(&mut registry.event_nfts, event_id);
    
    // Check if already minted
    assert!(!table::contains(&event_nfts.completion_minted, attendee), EAlreadyMinted);
    
    let event_metadata = event_nfts.event_metadata;
    
    // Create NFT metadata
    let mut attributes = vector::empty<Attribute>();
    vector::push_back(&mut attributes, Attribute {
        trait_type: string::utf8(b"Event Type"),
        value: string::utf8(b"Certificate of Completion"),
    });
    vector::push_back(&mut attributes, Attribute {
        trait_type: string::utf8(b"Attendance Duration"),
        value: duration_to_string(attendance_duration),
    });
    vector::push_back(&mut attributes, Attribute {
        trait_type: string::utf8(b"Check-in Time"),
        value: u64_to_string(check_in_time),
    });
    vector::push_back(&mut attributes, Attribute {
        trait_type: string::utf8(b"Check-out Time"),
        value: u64_to_string(check_out_time),
    });
    vector::push_back(&mut attributes, Attribute {
        trait_type: string::utf8(b"Location"),
        value: event_metadata.location,
    });

    let metadata = NFTMetadata {
        description: string::utf8(b"This NFT certifies successful completion of the event"),
        image_url: event_metadata.image_url,
        location: event_metadata.location,
        organizer: event_metadata.organizer,
        attributes,
    };

    // Create NFT
    let nft = NFTOfCompletion {
        id: object::new(ctx),
        event_id,
        event_name: event_metadata.event_name,
        attendee,
        check_in_time,
        check_out_time,
        attendance_duration,
        metadata,
    };

    let nft_id = object::id(&nft);
    
    // Update registry
    table::add(&mut event_nfts.completion_minted, attendee, nft_id);
    event_nfts.total_completions = event_nfts.total_completions + 1;
    registry.total_completion_minted = registry.total_completion_minted + 1;

    // Update user's NFT list
    if (!table::contains(&registry.user_nfts, attendee)) {
        table::add(&mut registry.user_nfts, attendee, UserNFTs {
            poa_tokens: vector::empty(),
            completion_tokens: vector::empty(),
        });
    };
    let user_nfts = table::borrow_mut(&mut registry.user_nfts, attendee);
    vector::push_back(&mut user_nfts.completion_tokens, nft_id);

    // Transfer NFT to attendee
    transfer::transfer(nft, attendee);

    event::emit(CompletionMinted {
        nft_id,
        event_id,
        attendee,
        attendance_duration,
    });

    nft_id
}

// Check if user has PoA for an event
public fun has_proof_of_attendance(
    wallet: address,
    event_id: ID,
    registry: &NFTRegistry
): bool {
    if (!table::contains(&registry.event_nfts, event_id)) {
        return false
    };
    
    let event_nfts = table::borrow(&registry.event_nfts, event_id);
    table::contains(&event_nfts.poa_minted, wallet)
}

// Check if user has completion NFT for an event
public fun has_completion_nft(
    wallet: address,
    event_id: ID,
    registry: &NFTRegistry
): bool {
    if (!table::contains(&registry.event_nfts, event_id)) {
        return false
    };
    
    let event_nfts = table::borrow(&registry.event_nfts, event_id);
    table::contains(&event_nfts.completion_minted, wallet)
}

// Get user's NFTs
public fun get_user_nfts(
    wallet: address,
    registry: &NFTRegistry
): (vector<ID>, vector<ID>) {
    if (!table::contains(&registry.user_nfts, wallet)) {
        return (vector::empty(), vector::empty())
    };
    
    let user_nfts = table::borrow(&registry.user_nfts, wallet);
    (user_nfts.poa_tokens, user_nfts.completion_tokens)
}

// Get event NFT statistics
public fun get_event_nft_stats(
    event_id: ID,
    registry: &NFTRegistry
): (u64, u64) {
    if (!table::contains(&registry.event_nfts, event_id)) {
        return (0, 0)
    };
    
    let event_nfts = table::borrow(&registry.event_nfts, event_id);
    (event_nfts.total_poa, event_nfts.total_completions)
}

// Helper functions
fun u64_to_string(num: u64): String {
    let mut bytes = vector::empty<u8>();
    if (num == 0) {
        vector::push_back(&mut bytes, 48); // '0'
    } else {
        let mut temp = num;
        let mut digits = vector::empty<u8>();
        while (temp > 0) {
            vector::push_back(&mut digits, ((temp % 10) as u8) + 48);
            temp = temp / 10;
        };
        let mut i = vector::length(&digits);
        while (i > 0) {
            i = i - 1;
            vector::push_back(&mut bytes, *vector::borrow(&digits, i));
        };
    };
    string::utf8(bytes)
}

fun duration_to_string(ms: u64): String {
    let hours = ms / 3600000;
    let minutes = (ms % 3600000) / 60000;
    
    let mut result = vector::empty<u8>();
    
    // Add hours
    let hour_str = u64_to_string(hours);
    let hour_bytes = string::as_bytes(&hour_str);
    vector::append(&mut result, *hour_bytes);
    vector::append(&mut result, b"h ");
    
    // Add minutes
    let min_str = u64_to_string(minutes);
    let min_bytes = string::as_bytes(&min_str);
    vector::append(&mut result, *min_bytes);
    vector::append(&mut result, b"m");
    
    string::utf8(result)
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    let witness = NFT_MINTING {};
    init(witness, ctx);
}