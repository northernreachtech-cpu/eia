module eia::event_management;

use std::string::String;
use sui::clock::{Self, Clock};
use sui::table::{Self, Table};
use sui::event;

// Error codes
const ENotOrganizer: u64 = 1;
const EEventNotActive: u64 = 2;
const EEventAlreadyCompleted: u64 = 3;
const EInvalidCapacity: u64 = 4;
const EInvalidTimestamp: u64 = 5;

// Event states
const STATE_CREATED: u8 = 0;
const STATE_ACTIVE: u8 = 1;
const STATE_COMPLETED: u8 = 2;
const STATE_SETTLED: u8 = 3;

// Core event struct
public struct Event has key, store {
    id: UID,
    name: String,
    description: String,
    location: String,
    start_time: u64,
    end_time: u64,
    capacity: u64,
    current_attendees: u64,
    organizer: address,
    state: u8,
    created_at: u64,
    sponsor_conditions: SponsorConditions,
    metadata_uri: String, // Walrus storage reference
}

// Sponsor performance conditions
public struct SponsorConditions has store, drop, copy {
    min_attendees: u64,
    min_completion_rate: u64, // Percentage * 100 (e.g., 8000 = 80%)
    min_avg_rating: u64, // Rating * 100 (e.g., 450 = 4.5/5)
    custom_benchmarks: vector<CustomBenchmark>,
}

public struct CustomBenchmark has store, drop, copy {
    metric_name: String,
    target_value: u64,
    comparison_type: u8, // 0: >=, 1: <=, 2: ==
}

// Organizer profile for reputation tracking
public struct OrganizerProfile has key, store {
    id: UID,
    address: address,
    name: String,
    bio: String,
    total_events: u64,
    successful_events: u64,
    total_attendees_served: u64,
    avg_rating: u64, // Rating * 100
    created_at: u64,
}

// Event registry for discovery
public struct EventRegistry has key {
    id: UID,
    events: Table<ID, EventInfo>,
    events_by_organizer: Table<address, vector<ID>>,
}

public struct EventInfo has store, drop, copy {
    event_id: ID,
    name: String,
    start_time: u64,
    organizer: address,
    state: u8,
}

// Capabilities
public struct OrganizerCap has key, store {
    id: UID,
    profile_id: ID,
}

// Events emitted
public struct EventCreated has copy, drop {
    event_id: ID,
    name: String,
    organizer: address,
    start_time: u64,
    capacity: u64,
}

public struct EventActivated has copy, drop {
    event_id: ID,
    activated_at: u64,
}

public struct EventCompleted has copy, drop {
    event_id: ID,
    total_attendees: u64,
    completed_at: u64,
}

// Initialize the module
fun init(ctx: &mut TxContext) {
    let registry = EventRegistry {
        id: object::new(ctx),
        events: table::new(ctx),
        events_by_organizer: table::new(ctx),
    };
    transfer::share_object(registry);
}

// Create organizer profile
public fun create_organizer_profile(
    name: String,
    bio: String,
    clock: &Clock,
    ctx: &mut TxContext
): OrganizerCap {
    let profile = OrganizerProfile {
        id: object::new(ctx),
        address: tx_context::sender(ctx),
        name,
        bio,
        total_events: 0,
        successful_events: 0,
        total_attendees_served: 0,
        avg_rating: 0,
        created_at: clock::timestamp_ms(clock),
    };
    
    let profile_id = object::id(&profile);
    transfer::share_object(profile);
    
    OrganizerCap {
        id: object::new(ctx),
        profile_id,
    }
}

// Create a new event
public fun create_event(
    name: String,
    description: String,
    location: String,
    start_time: u64,
    end_time: u64,
    capacity: u64,
    min_attendees: u64,
    min_completion_rate: u64,
    min_avg_rating: u64,
    metadata_uri: String,
    clock: &Clock,
    registry: &mut EventRegistry,
    profile: &mut OrganizerProfile,
    ctx: &mut TxContext
): ID {
    let sender = tx_context::sender(ctx);
    assert!(profile.address == sender, ENotOrganizer);
    assert!(capacity > 0, EInvalidCapacity);
    assert!(start_time > clock::timestamp_ms(clock), EInvalidTimestamp);
    assert!(end_time > start_time, EInvalidTimestamp);

    let sponsor_conditions = SponsorConditions {
        min_attendees,
        min_completion_rate,
        min_avg_rating,
        custom_benchmarks: vector::empty(),
    };

    let event = Event {
        id: object::new(ctx),
        name: name,
        description,
        location,
        start_time,
        end_time,
        capacity,
        current_attendees: 0,
        organizer: sender,
        state: STATE_CREATED,
        created_at: clock::timestamp_ms(clock),
        sponsor_conditions,
        metadata_uri,
    };

    let event_id = object::id(&event);
    let event_info = EventInfo {
        event_id,
        name: event.name,
        start_time: event.start_time,
        organizer: event.organizer,
        state: event.state,
    };

    // Update registry
    table::add(&mut registry.events, event_id, event_info);
    
    if (!table::contains(&registry.events_by_organizer, sender)) {
        table::add(&mut registry.events_by_organizer, sender, vector::empty());
    };
    let organizer_events = table::borrow_mut(&mut registry.events_by_organizer, sender);
    vector::push_back(organizer_events, event_id);

    // Update organizer profile
    profile.total_events = profile.total_events + 1;

    // Emit event
    event::emit(EventCreated {
        event_id,
        name: event.name,
        organizer: event.organizer,
        start_time: event.start_time,
        capacity: event.capacity,
    });

    transfer::share_object(event);
    event_id
}

// Add custom benchmark to sponsor conditions
public fun add_custom_benchmark(
    event: &mut Event,
    metric_name: String,
    target_value: u64,
    comparison_type: u8,
    ctx: &mut TxContext
) {
    assert!(event.organizer == tx_context::sender(ctx), ENotOrganizer);
    assert!(event.state == STATE_CREATED, EEventNotActive);

    let benchmark = CustomBenchmark {
        metric_name,
        target_value,
        comparison_type,
    };

    vector::push_back(&mut event.sponsor_conditions.custom_benchmarks, benchmark);
}

// Activate event for registration
public fun activate_event(
    event: &mut Event,
    clock: &Clock,
    registry: &mut EventRegistry,
    ctx: &mut TxContext
) {
    assert!(event.organizer == tx_context::sender(ctx), ENotOrganizer);
    assert!(event.state == STATE_CREATED, EEventNotActive);

    event.state = STATE_ACTIVE;
    
    // Update registry
    let event_info = table::borrow_mut(&mut registry.events, object::id(event));
    event_info.state = STATE_ACTIVE;

    event::emit(EventActivated {
        event_id: object::id(event),
        activated_at: clock::timestamp_ms(clock),
    });
}

// Update event details (only before activation)
public fun update_event_details(
    event: &mut Event,
    name: String,
    description: String,
    location: String,
    metadata_uri: String,
    ctx: &mut TxContext
) {
    assert!(event.organizer == tx_context::sender(ctx), ENotOrganizer);
    assert!(event.state == STATE_CREATED, EEventNotActive);

    event.name = name;
    event.description = description;
    event.location = location;
    event.metadata_uri = metadata_uri;
}

// Complete event
public fun complete_event(
    event: &mut Event,
    clock: &Clock,
    registry: &mut EventRegistry,
    profile: &mut OrganizerProfile,
    ctx: &mut TxContext
) {
    assert!(event.organizer == tx_context::sender(ctx), ENotOrganizer);
    assert!(event.state == STATE_ACTIVE, EEventNotActive);
    assert!(clock::timestamp_ms(clock) >= event.end_time, EEventAlreadyCompleted);

    event.state = STATE_COMPLETED;
    
    // Update registry
    let event_info = table::borrow_mut(&mut registry.events, object::id(event));
    event_info.state = STATE_COMPLETED;

    // Update organizer stats
    profile.total_attendees_served = profile.total_attendees_served + event.current_attendees;

    event::emit(EventCompleted {
        event_id: object::id(event),
        total_attendees: event.current_attendees,
        completed_at: clock::timestamp_ms(clock),
    });
}

// Mark event as settled (called by escrow contract)
public fun mark_event_settled(
    event: &mut Event,
    success: bool,
    profile: &mut OrganizerProfile,
) {
    assert!(event.state == STATE_COMPLETED, EEventAlreadyCompleted);
    
    event.state = STATE_SETTLED;
    
    if (success) {
        profile.successful_events = profile.successful_events + 1;
    };
}

// Increment attendee count (called by attendance contract)
public fun increment_attendees(event: &mut Event) {
    assert!(event.state == STATE_ACTIVE, EEventNotActive);
    assert!(event.current_attendees < event.capacity, EInvalidCapacity);
    event.current_attendees = event.current_attendees + 1;
}

// Update organizer rating (called by rating contract)
public fun update_organizer_rating(
    profile: &mut OrganizerProfile,
    new_rating_sum: u64,
    total_ratings: u64,
) {
    if (total_ratings > 0) {
        profile.avg_rating = new_rating_sum / total_ratings;
    };
}

// Getters
public fun get_event_state(event: &Event): u8 {
    event.state
}

public fun get_event_organizer(event: &Event): address {
    event.organizer
}

public fun get_event_capacity(event: &Event): u64 {
    event.capacity
}

public fun get_current_attendees(event: &Event): u64 {
    event.current_attendees
}

public fun get_sponsor_conditions(event: &Event): &SponsorConditions {
    &event.sponsor_conditions
}

public fun get_condition_details(conditions: &SponsorConditions): (u64, u64, u64, u64) {
    (
        conditions.min_attendees,
        conditions.min_completion_rate,
        conditions.min_avg_rating,
        vector::length(&conditions.custom_benchmarks)
    )
}

public fun get_event_sponsor_conditions(event: &Event): (u64, u64, u64, u64) {
    let conditions = &event.sponsor_conditions;
    (
        conditions.min_attendees,
        conditions.min_completion_rate,
        conditions.min_avg_rating,
        vector::length(&conditions.custom_benchmarks)
    )
}

public fun get_event_id(event: &Event): ID {
    object::id(event)
}

public fun is_event_active(event: &Event): bool {
    event.state == STATE_ACTIVE
}

public fun is_event_completed(event: &Event): bool {
    event.state == STATE_COMPLETED
}

public fun event_exists(registry: &EventRegistry, event_id: ID): bool {
    table::contains(&registry.events, event_id)
}

public fun get_organizer_stats(profile: &OrganizerProfile): (u64, u64, u64, u64) {
    (
        profile.total_events,
        profile.successful_events,
        profile.total_attendees_served,
        profile.avg_rating
    )
}

public fun get_event_metadata_uri(event: &Event): String {
    event.metadata_uri
}

public fun get_event_timing(event: &Event): (u64, u64, u64) {
    (event.start_time, event.end_time, event.created_at)
}

public fun get_organizer_event_ids(
    registry: &EventRegistry, 
    organizer: address
): vector<ID> {
    if (table::contains(&registry.events_by_organizer, organizer)) {
        *table::borrow(&registry.events_by_organizer, organizer)
    } else {
        vector::empty()
    }
}

public fun get_event_info_fields(
    registry: &EventRegistry,
    id: ID
): (ID, String, u64, address, u8) {
    let info = table::borrow(&registry.events, id);
    (info.event_id, info.name, info.start_time, info.organizer, info.state)
}

public fun get_custom_benchmarks(conditions: &SponsorConditions): &vector<CustomBenchmark> {
    &conditions.custom_benchmarks
}

public fun get_benchmark_metric_name(benchmark: &CustomBenchmark): String {
    benchmark.metric_name
}

public fun get_benchmark_target_value(benchmark: &CustomBenchmark): u64 {
    benchmark.target_value
}

public fun get_benchmark_comparison_type(benchmark: &CustomBenchmark): u8 {
    benchmark.comparison_type
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
