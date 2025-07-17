module eia::rating_reputation;

use std::string::String;
use sui::table::{Self, Table};
use sui::event;
use sui::clock::{Self, Clock};
use eia::attendance_verification::{Self, AttendanceRegistry};
use eia::event_management::{Self, Event, OrganizerProfile};

// Error codes
const ENotEligibleToRate: u64 = 1;
const EAlreadyRated: u64 = 2;
const EInvalidRating: u64 = 3;
const ERatingPeriodExpired: u64 = 4;
const EEventNotCompleted: u64 = 5;

// Constants
const MAX_RATING: u64 = 500; // 5.0 * 100
const MIN_RATING: u64 = 100; // 1.0 * 100
const RATING_PERIOD: u64 = 604800000; // 7 days in milliseconds

// Rating registry
public struct RatingRegistry has key {
    id: UID,
    event_ratings: Table<ID, EventRatings>,
    user_ratings: Table<address, vector<UserRating>>,
    convener_ratings: Table<address, ConvenerReputation>,
}

public struct EventRatings has store {
    ratings: Table<address, Rating>,
    total_rating_sum: u64,
    total_ratings: u64,
    average_rating: u64,
    rating_deadline: u64,
}

public struct Rating has store, drop, copy {
    rater: address,
    event_rating: u64,
    convener_rating: u64,
    feedback: String,
    timestamp: u64,
}

public struct UserRating has store, drop, copy {
    event_id: ID,
    rating_given: u64,
    timestamp: u64,
}

public struct ConvenerReputation has store {
    total_events_rated: u64,
    total_rating_sum: u64,
    average_rating: u64,
    rating_history: vector<ConvenerRatingEntry>,
}

public struct ConvenerRatingEntry has store, drop, copy {
    event_id: ID,
    rating: u64,
    rater_count: u64,
    timestamp: u64,
}

// Events
public struct RatingSubmitted has copy, drop {
    event_id: ID,
    rater: address,
    event_rating: u64,
    convener_rating: u64,
    timestamp: u64,
}

public struct ConvenerReputationUpdated has copy, drop {
    convener: address,
    new_average: u64,
    total_events: u64,
}

// Initialize the module
fun init(ctx: &mut TxContext) {
    let registry = RatingRegistry {
        id: object::new(ctx),
        event_ratings: table::new(ctx),
        user_ratings: table::new(ctx),
        convener_ratings: table::new(ctx),
    };
    transfer::share_object(registry);
}

// Submit rating for an event
public fun submit_rating(
    event: &Event,
    event_rating: u64,
    convener_rating: u64,
    feedback: String,
    registry: &mut RatingRegistry,
    attendance_registry: &AttendanceRegistry,
    organizer_profile: &mut OrganizerProfile,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let rater = tx_context::sender(ctx);
    let event_id = event_management::get_event_id(event);
    let current_time = clock::timestamp_ms(clock);
    
    // Verify event is completed
    assert!(event_management::is_event_completed(event), EEventNotCompleted);
    
    // Verify rater attended and completed the event
    assert!(
        attendance_verification::verify_attendance_completion(rater, event_id, attendance_registry),
        ENotEligibleToRate
    );
    
    // Validate ratings
    assert!(event_rating >= MIN_RATING && event_rating <= MAX_RATING, EInvalidRating);
    assert!(convener_rating >= MIN_RATING && convener_rating <= MAX_RATING, EInvalidRating);
    
    // Initialize event ratings if needed
    if (!table::contains(&registry.event_ratings, event_id)) {
        let event_ratings = EventRatings {
            ratings: table::new(ctx),
            total_rating_sum: 0,
            total_ratings: 0,
            average_rating: 0,
            rating_deadline: current_time + RATING_PERIOD,
        };
        table::add(&mut registry.event_ratings, event_id, event_ratings);
    };
    
    let event_ratings = table::borrow_mut(&mut registry.event_ratings, event_id);
    
    // Check rating period
    assert!(current_time <= event_ratings.rating_deadline, ERatingPeriodExpired);
    
    // Check if already rated
    assert!(!table::contains(&event_ratings.ratings, rater), EAlreadyRated);
    
    // Create rating
    let rating = Rating {
        rater,
        event_rating,
        convener_rating,
        feedback,
        timestamp: current_time,
    };
    
    // Store rating
    table::add(&mut event_ratings.ratings, rater, rating);
    
    // Update event statistics
    event_ratings.total_rating_sum = event_ratings.total_rating_sum + event_rating;
    event_ratings.total_ratings = event_ratings.total_ratings + 1;
    event_ratings.average_rating = event_ratings.total_rating_sum / event_ratings.total_ratings;
    
    // Update user's rating history
    if (!table::contains(&registry.user_ratings, rater)) {
        table::add(&mut registry.user_ratings, rater, vector::empty());
    };
    let user_ratings = table::borrow_mut(&mut registry.user_ratings, rater);
    vector::push_back(user_ratings, UserRating {
        event_id,
        rating_given: event_rating,
        timestamp: current_time,
    });
    
    // Update convener reputation
    let convener = event_management::get_event_organizer(event);
    update_convener_reputation(
        convener,
        event_id,
        convener_rating,
        registry,
        organizer_profile,
        current_time,
    );
    
    event::emit(RatingSubmitted {
        event_id,
        rater,
        event_rating,
        convener_rating,
        timestamp: current_time,
    });
}

// Internal function to update convener reputation
fun update_convener_reputation(
    convener: address,
    event_id: ID,
    rating: u64,
    registry: &mut RatingRegistry,
    organizer_profile: &mut OrganizerProfile,
    timestamp: u64,
) {
    // Initialize convener reputation if needed
    if (!table::contains(&registry.convener_ratings, convener)) {
        let reputation = ConvenerReputation {
            total_events_rated: 0,
            total_rating_sum: 0,
            average_rating: 0,
            rating_history: vector::empty(),
        };
        table::add(&mut registry.convener_ratings, convener, reputation);
    };
    
    let reputation = table::borrow_mut(&mut registry.convener_ratings, convener);
    
    // Check if this event already has ratings
    let event_index = find_event_in_history(&reputation.rating_history, event_id);
    
    if (event_index < vector::length(&reputation.rating_history)) {
        // Update existing event rating
        let entry = vector::borrow_mut(&mut reputation.rating_history, event_index);
        let old_sum = entry.rating * entry.rater_count;
        entry.rater_count = entry.rater_count + 1;
        entry.rating = (old_sum + rating) / entry.rater_count;
        
        // Recalculate total average
        recalculate_convener_average(reputation);
    } else {
        // New event rating
        let entry = ConvenerRatingEntry {
            event_id,
            rating,
            rater_count: 1,
            timestamp,
        };
        vector::push_back(&mut reputation.rating_history, entry);
        
        reputation.total_events_rated = reputation.total_events_rated + 1;
        reputation.total_rating_sum = reputation.total_rating_sum + rating;
        reputation.average_rating = reputation.total_rating_sum / reputation.total_events_rated;
    };
    
    // Update organizer profile
    event_management::update_organizer_rating(
        organizer_profile,
        reputation.total_rating_sum,
        reputation.total_events_rated
    );
    
    event::emit(ConvenerReputationUpdated {
        convener,
        new_average: reputation.average_rating,
        total_events: reputation.total_events_rated,
    });
}

// Helper function to find event in rating history
fun find_event_in_history(history: &vector<ConvenerRatingEntry>, event_id: ID): u64 {
    let mut i = 0;
    let len = vector::length(history);
    while (i < len) {
        if (vector::borrow(history, i).event_id == event_id) {
            return i
        };
        i = i + 1;
    };
    len // Return length if not found
}

// Helper function to recalculate convener average
fun recalculate_convener_average(reputation: &mut ConvenerReputation) {
    let mut total_sum = 0u64;
    let mut total_count = 0u64;
    
    let mut i = 0;
    let len = vector::length(&reputation.rating_history);
    while (i < len) {
        let entry = vector::borrow(&reputation.rating_history, i);
        total_sum = total_sum + (entry.rating * entry.rater_count);
        total_count = total_count + entry.rater_count;
        i = i + 1;
    };
    
    if (total_count > 0) {
        reputation.total_rating_sum = total_sum;
        reputation.average_rating = total_sum / total_count;
    };
}

// Get event average rating
public fun get_event_average_rating(
    event_id: ID,
    registry: &RatingRegistry
): u64 {
    if (!table::contains(&registry.event_ratings, event_id)) {
        return 0
    };
    
    let event_ratings = table::borrow(&registry.event_ratings, event_id);
    event_ratings.average_rating
}

// Get event rating details
public fun get_event_rating_stats(
    event_id: ID,
    registry: &RatingRegistry
): (u64, u64, u64) {
    if (!table::contains(&registry.event_ratings, event_id)) {
        return (0, 0, 0)
    };
    
    let event_ratings = table::borrow(&registry.event_ratings, event_id);
    (event_ratings.total_ratings, event_ratings.average_rating, event_ratings.rating_deadline)
}

// Get convener reputation
public fun get_convener_reputation(
    convener: address,
    registry: &RatingRegistry
): (u64, u64, u64) {
    if (!table::contains(&registry.convener_ratings, convener)) {
        return (0, 0, 0)
    };
    
    let reputation = table::borrow(&registry.convener_ratings, convener);
    (reputation.total_events_rated, reputation.average_rating, vector::length(&reputation.rating_history))
}

// Check if user has rated an event
public fun has_user_rated(
    rater: address,
    event_id: ID,
    registry: &RatingRegistry
): bool {
    if (!table::contains(&registry.event_ratings, event_id)) {
        return false
    };
    
    let event_ratings = table::borrow(&registry.event_ratings, event_id);
    table::contains(&event_ratings.ratings, rater)
}

// Get user's rating for an event
public fun get_user_rating(
    rater: address,
    event_id: ID,
    registry: &RatingRegistry
): (u64, u64, String) {
    let event_ratings = table::borrow(&registry.event_ratings, event_id);
    let rating = table::borrow(&event_ratings.ratings, rater);
    (rating.event_rating, rating.convener_rating, rating.feedback)
}

// Get top conveners (simplified - would need more sophisticated sorting in production)
public fun get_convener_rating_history(
    convener: address,
    registry: &RatingRegistry
): vector<ConvenerRatingEntry> {
    if (!table::contains(&registry.convener_ratings, convener)) {
        return vector::empty()
    };
    
    let reputation = table::borrow(&registry.convener_ratings, convener);
    reputation.rating_history
}


#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}