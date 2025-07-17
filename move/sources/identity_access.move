module eia::identity_access;

use sui::table::{Self, Table};
use sui::clock::{Self, Clock};
use sui::event;
use sui::hash;
use std::bcs;
use eia::event_management::{Self, Event};

// Error codes
const EEventNotActive: u64 = 1;
const EAlreadyRegistered: u64 = 2;
const ECapacityReached: u64 = 6;
const ENotRegistered: u64 = 7;

// Pass validity duration (24 hours in milliseconds)
const PASS_VALIDITY_DURATION: u64 = 86400000;

// Registration storage
public struct RegistrationRegistry has key {
    id: UID,
    // event_id -> registrations
    event_registrations: Table<ID, EventRegistrations>,
    // wallet -> registered events
    user_registrations: Table<address, vector<ID>>,
}

public struct EventRegistrations has store {
    registrations: Table<address, Registration>,
    pass_mappings: Table<vector<u8>, PassInfo>, // pass_hash -> info
    total_registered: u64,
}

public struct Registration has store, drop, copy {
    wallet: address,
    registered_at: u64,
    pass_hash: vector<u8>,
    checked_in: bool,
}

public struct PassInfo has store, drop, copy {
    wallet: address,
    event_id: ID,
    created_at: u64,
    expires_at: u64,
    used: bool,
    pass_id: u64, // Unique identifier for the pass
}

// Events emitted
public struct UserRegistered has copy, drop {
    event_id: ID,
    wallet: address,
    registered_at: u64,
}

public struct PassGenerated has copy, drop {
    event_id: ID,
    wallet: address,
    pass_id: u64,
    expires_at: u64,
}

public struct PassValidated has copy, drop {
    event_id: ID,
    wallet: address,
    pass_id: u64,
}

// Initialize the module
fun init(ctx: &mut TxContext) {
    let registry = RegistrationRegistry {
        id: object::new(ctx),
        event_registrations: table::new(ctx),
        user_registrations: table::new(ctx),
    };
    transfer::share_object(registry);
}

// Register for an event
public fun register_for_event(
    event: &mut Event,
    registry: &mut RegistrationRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let wallet = tx_context::sender(ctx);
    let event_id = event_management::get_event_id(event);
    
    // Verify event is active
    assert!(event_management::is_event_active(event), EEventNotActive);
    
    // Check capacity
    assert!(
        event_management::get_current_attendees(event) < event_management::get_event_capacity(event),
        ECapacityReached
    );

    // Initialize event registrations if needed
    if (!table::contains(&registry.event_registrations, event_id)) {
        let event_regs = EventRegistrations {
            registrations: table::new(ctx),
            pass_mappings: table::new(ctx),
            total_registered: 0,
        };
        table::add(&mut registry.event_registrations, event_id, event_regs);
    };

    let event_regs = table::borrow_mut(&mut registry.event_registrations, event_id);
    
    // Check if already registered
    assert!(!table::contains(&event_regs.registrations, wallet), EAlreadyRegistered);

    let registered_at = clock::timestamp_ms(clock);
    let pass_id = generate_pass_id(wallet, event_id, registered_at);
    let pass_hash = generate_pass_hash(pass_id, event_id, wallet);

    // Create registration
    let registration = Registration {
        wallet,
        registered_at,
        pass_hash,
        checked_in: false,
    };

    // Store registration
    table::add(&mut event_regs.registrations, wallet, registration);
    event_regs.total_registered = event_regs.total_registered + 1;

    // Update user's registration list
    if (!table::contains(&registry.user_registrations, wallet)) {
        table::add(&mut registry.user_registrations, wallet, vector::empty());
    };
    let user_events = table::borrow_mut(&mut registry.user_registrations, wallet);
    vector::push_back(user_events, event_id);

    // Generate and store pass info
    let expires_at = registered_at + PASS_VALIDITY_DURATION;
    let pass_info = PassInfo {
        wallet,
        event_id,
        created_at: registered_at,
        expires_at,
        used: false,
        pass_id,
    };
    table::add(&mut event_regs.pass_mappings, pass_hash, pass_info);

    event::emit(UserRegistered {
        event_id,
        wallet,
        registered_at,
    });

    event::emit(PassGenerated {
        event_id,
        wallet,
        pass_id,
        expires_at,
    });
}

// Generate a new ephemeral pass for registered user
public fun regenerate_pass(
    event: &Event,
    registry: &mut RegistrationRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let wallet = tx_context::sender(ctx);
    let event_id = event_management::get_event_id(event);
    
    // Verify event is active
    assert!(event_management::is_event_active(event), EEventNotActive);
    
    // Check if event has any registrations first
    assert!(table::contains(&registry.event_registrations, event_id), ENotRegistered);
    
    let event_regs = table::borrow_mut(&mut registry.event_registrations, event_id);
    
    // Check if registered
    assert!(table::contains(&event_regs.registrations, wallet), ENotRegistered);
    
    let registration = table::borrow_mut(&mut event_regs.registrations, wallet);
    
    // Remove old pass mapping
    table::remove(&mut event_regs.pass_mappings, registration.pass_hash);
    
    // Generate new pass
    let current_time = clock::timestamp_ms(clock);
    let pass_id = generate_pass_id(wallet, event_id, current_time);
    let pass_hash = generate_pass_hash(pass_id, event_id, wallet);
    let expires_at = current_time + PASS_VALIDITY_DURATION;
    
    // Update registration
    registration.pass_hash = pass_hash;
    
    // Store new pass info
    let pass_info = PassInfo {
        wallet,
        event_id,
        created_at: current_time,
        expires_at,
        used: false,
        pass_id,
    };
    table::add(&mut event_regs.pass_mappings, pass_hash, pass_info);

    event::emit(PassGenerated {
        event_id,
        wallet,
        pass_id,
        expires_at,
    });
}

// Validate ephemeral pass (called by verifier)
public fun validate_pass(
    pass_hash: vector<u8>,
    event_id: ID,
    registry: &mut RegistrationRegistry,
    clock: &Clock,
): (bool, address) {
    if (!table::contains(&registry.event_registrations, event_id)) {
        return (false, @0x0)
    };

    let event_regs = table::borrow_mut(&mut registry.event_registrations, event_id);
    
    if (!table::contains(&event_regs.pass_mappings, pass_hash)) {
        return (false, @0x0)
    };

    let pass_info = table::borrow_mut(&mut event_regs.pass_mappings, pass_hash);
    let current_time = clock::timestamp_ms(clock);

    // Check if pass is valid
    if (pass_info.used || current_time > pass_info.expires_at) {
        return (false, @0x0)
    };

    // Mark pass as used
    pass_info.used = true;

    event::emit(PassValidated {
        event_id,
        wallet: pass_info.wallet,
        pass_id: pass_info.pass_id,
    });

    (true, pass_info.wallet)
}

// Mark user as checked in (called by attendance contract)
public fun mark_checked_in(
    wallet: address,
    event_id: ID,
    registry: &mut RegistrationRegistry,
) {
    let event_regs = table::borrow_mut(&mut registry.event_registrations, event_id);
    let registration = table::borrow_mut(&mut event_regs.registrations, wallet);
    registration.checked_in = true;
}

// Check if a wallet is registered for an event
public fun is_registered(
    wallet: address,
    event_id: ID,
    registry: &RegistrationRegistry,
): bool {
    if (!table::contains(&registry.event_registrations, event_id)) {
        return false
    };
    
    let event_regs = table::borrow(&registry.event_registrations, event_id);
    table::contains(&event_regs.registrations, wallet)
}

// Get registration details
public fun get_registration(
    wallet: address,
    event_id: ID,
    registry: &RegistrationRegistry,
): (u64, bool) {
    let event_regs = table::borrow(&registry.event_registrations, event_id);
    let registration = table::borrow(&event_regs.registrations, wallet);
    (registration.registered_at, registration.checked_in)
}

// Get user's registered events
public fun get_user_events(
    wallet: address,
    registry: &RegistrationRegistry,
): vector<ID> {
    if (!table::contains(&registry.user_registrations, wallet)) {
        return vector::empty()
    };
    
    *table::borrow(&registry.user_registrations, wallet)
}

// Helper function to generate pass ID
fun generate_pass_id(wallet: address, event_id: ID, timestamp: u64): u64 {
    let mut data = vector::empty<u8>();
    vector::append(&mut data, bcs::to_bytes(&wallet));
    vector::append(&mut data, bcs::to_bytes(&event_id));
    vector::append(&mut data, bcs::to_bytes(&timestamp));
    
    let hash = hash::keccak256(&data);
    // Convert first 8 bytes to u64
    let mut result = 0u64;
    let mut i = 0;
    while (i < 8) {
        result = (result << 8) | (*vector::borrow(&hash, i) as u64);
        i = i + 1;
    };
    result
}

// Helper function to generate pass hash
fun generate_pass_hash(pass_id: u64, event_id: ID, wallet: address): vector<u8> {
    let mut data = vector::empty<u8>();
    vector::append(&mut data, bcs::to_bytes(&pass_id));
    vector::append(&mut data, bcs::to_bytes(&event_id));
    vector::append(&mut data, bcs::to_bytes(&wallet));
    
    hash::keccak256(&data)
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}