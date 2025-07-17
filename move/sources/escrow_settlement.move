module eia::escrow_settlement;

use std::string::{Self, String};
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::balance::{Self, Balance};
use sui::table::{Self, Table};
use sui::event;
use sui::clock::{Self, Clock};
use eia::event_management::{Self, Event, SponsorConditions, OrganizerProfile};
use eia::attendance_verification::{Self, AttendanceRegistry};
use eia::rating_reputation::{Self, RatingRegistry};

// Error codes
const EInsufficientFunds: u64 = 1;
const EEventNotCompleted: u64 = 2;
const EAlreadySettled: u64 = 3;
const ENotAuthorized: u64 = 5;
const EEscrowNotFound: u64 = 6;
const ERefundPeriodNotExpired: u64 = 7;

// Settlement grace period (7 days in milliseconds)
const SETTLEMENT_GRACE_PERIOD: u64 = 604800000;

// Escrow registry
public struct EscrowRegistry has key {
    id: UID,
    escrows: Table<ID, Escrow>, // event_id -> escrow
    total_escrowed: u64,
    total_released: u64,
    total_refunded: u64,
    custom_metrics: Table<ID, Table<String, u64>>, // event_id -> (metric_name -> actual_value)
}

public struct Escrow has store {
    event_id: ID,
    organizer: address,
    sponsor: address,
    balance: Balance<SUI>,
    conditions: SponsorConditions,
    created_at: u64,
    settled: bool,
    settlement_time: u64,
    settlement_result: SettlementResult,
}

public struct SettlementResult has store, drop, copy {
    conditions_met: bool,
    attendees_actual: u64,
    attendees_required: u64,
    completion_rate_actual: u64,
    completion_rate_required: u64,
    avg_rating_actual: u64,
    avg_rating_required: u64,
    amount_released: u64,
    amount_refunded: u64,
}

// Events
public struct EscrowCreated has copy, drop {
    event_id: ID,
    organizer: address,
    sponsor: address,
    amount: u64,
    created_at: u64,
}

public struct FundsReleased has copy, drop {
    event_id: ID,
    organizer: address,
    amount: u64,
    settlement_time: u64,
}

public struct FundsRefunded has copy, drop {
    event_id: ID,
    sponsor: address,
    amount: u64,
    reason: String,
}

public struct SettlementCompleted has copy, drop {
    event_id: ID,
    result: SettlementResult,
}

// Initialize the module
fun init(ctx: &mut TxContext) {
    let registry = EscrowRegistry {
        id: object::new(ctx),
        escrows: table::new(ctx),
        total_escrowed: 0,
        total_released: 0,
        total_refunded: 0,
        custom_metrics: table::new(ctx),
    };
    transfer::share_object(registry);
}

// Create escrow for an event
public fun create_escrow(
    event: &Event,
    sponsor: address,
    payment: Coin<SUI>,
    registry: &mut EscrowRegistry,
    clock: &Clock,
    _ctx: &mut TxContext
) {
    let event_id = event_management::get_event_id(event);
    let amount = coin::value(&payment);
    
    assert!(amount > 0, EInsufficientFunds);
    assert!(!table::contains(&registry.escrows, event_id), EAlreadySettled);

    let escrow = Escrow {
        event_id,
        organizer: event_management::get_event_organizer(event),
        sponsor,
        balance: coin::into_balance(payment),
        conditions: *event_management::get_sponsor_conditions(event),
        created_at: clock::timestamp_ms(clock),
        settled: false,
        settlement_time: 0,
        settlement_result: SettlementResult {
            conditions_met: false,
            attendees_actual: 0,
            attendees_required: 0,
            completion_rate_actual: 0,
            completion_rate_required: 0,
            avg_rating_actual: 0,
            avg_rating_required: 0,
            amount_released: 0,
            amount_refunded: 0,
        },
    };

    table::add(&mut registry.escrows, event_id, escrow);
    registry.total_escrowed = registry.total_escrowed + amount;

    event::emit(EscrowCreated {
        event_id,
        organizer: event_management::get_event_organizer(event),
        sponsor,
        amount,
        created_at: clock::timestamp_ms(clock),
    });
}

// Evaluate conditions and settle escrow
public fun settle_escrow(
    event: &mut Event,
    event_id: ID,
    registry: &mut EscrowRegistry,
    attendance_registry: &AttendanceRegistry,
    rating_registry: &RatingRegistry,
    organizer_profile: &mut OrganizerProfile,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(table::contains(&registry.escrows, event_id), EEscrowNotFound);
    
    // Extract all needed data before mutable borrow
    let (organizer, sponsor, conditions, settled) = {
        let escrow_ref = table::borrow(&registry.escrows, event_id);
        (escrow_ref.organizer, escrow_ref.sponsor, escrow_ref.conditions, escrow_ref.settled)
    };
    
    assert!(!settled, EAlreadySettled);
    assert!(event_management::is_event_completed(event), EEventNotCompleted);
    assert!(
        tx_context::sender(ctx) == organizer || 
        tx_context::sender(ctx) == sponsor,
        ENotAuthorized
    );

    // Get event statistics
    let (checked_in, _checked_out, completion_rate) = 
        attendance_verification::get_event_stats(event_id, attendance_registry);
    
    let avg_rating = rating_reputation::get_event_average_rating(event_id, rating_registry);
    
    // Evaluate conditions
    let (min_attendees, min_completion_rate, min_avg_rating, _) = event_management::get_condition_details(&conditions);
    let attendees_met = checked_in >= min_attendees;
    let completion_met = completion_rate >= min_completion_rate;
    let rating_met = avg_rating >= min_avg_rating;
    
    // Check custom benchmarks
    let custom_met = evaluate_custom_benchmarks(event_id, conditions, registry);
    
    let all_conditions_met = attendees_met && completion_met && rating_met && custom_met;
    
    // Now get mutable borrow for settlement
    let escrow = table::borrow_mut(&mut registry.escrows, event_id);
    let amount = balance::value(&escrow.balance);
    let settlement_time = clock::timestamp_ms(clock);
    
    if (all_conditions_met) {
        // Release funds to organizer
        let payment = coin::from_balance(balance::withdraw_all(&mut escrow.balance), ctx);
        transfer::public_transfer(payment, organizer);
        
        registry.total_released = registry.total_released + amount;
        
        // Update organizer profile
        event_management::mark_event_settled(event, true, organizer_profile);
        
        event::emit(FundsReleased {
            event_id,
            organizer,
            amount,
            settlement_time,
        });
        
        escrow.settlement_result = SettlementResult {
            conditions_met: true,
            attendees_actual: checked_in,
            attendees_required: min_attendees,
            completion_rate_actual: completion_rate,
            completion_rate_required: min_completion_rate,
            avg_rating_actual: avg_rating,
            avg_rating_required: min_avg_rating,
            amount_released: amount,
            amount_refunded: 0,
        };
    } else {
        // Refund to sponsor
        let payment = coin::from_balance(balance::withdraw_all(&mut escrow.balance), ctx);
        transfer::public_transfer(payment, sponsor);
        
        registry.total_refunded = registry.total_refunded + amount;
        
        // Update organizer profile
        event_management::mark_event_settled(event, false, organizer_profile);
        
        let mut reason = string::utf8(b"Conditions not met: ");
        if (!attendees_met) {
            string::append(&mut reason, string::utf8(b"insufficient attendees, "));
        };
        if (!completion_met) {
            string::append(&mut reason, string::utf8(b"low completion rate, "));
        };
        if (!rating_met) {
            string::append(&mut reason, string::utf8(b"low rating, "));
        };
        if (!custom_met) {
            string::append(&mut reason, string::utf8(b"custom benchmarks not met, "));
        };
        
        event::emit(FundsRefunded {
            event_id,
            sponsor,
            amount,
            reason,
        });
        
        escrow.settlement_result = SettlementResult {
            conditions_met: false,
            attendees_actual: checked_in,
            attendees_required: min_attendees,
            completion_rate_actual: completion_rate,
            completion_rate_required: min_completion_rate,
            avg_rating_actual: avg_rating,
            avg_rating_required: min_avg_rating,
            amount_released: 0,
            amount_refunded: amount,
        };
    };
    
    escrow.settled = true;
    escrow.settlement_time = settlement_time;
    
    event::emit(SettlementCompleted {
        event_id,
        result: escrow.settlement_result,
    });
}

// Emergency withdrawal (after grace period)
public fun emergency_withdraw(
    event_id: ID,
    registry: &mut EscrowRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(table::contains(&registry.escrows, event_id), EEscrowNotFound);
    
    let escrow = table::borrow_mut(&mut registry.escrows, event_id);
    assert!(!escrow.settled, EAlreadySettled);
    
    let sender = tx_context::sender(ctx);
    assert!(sender == escrow.organizer || sender == escrow.sponsor, ENotAuthorized);
    
    let current_time = clock::timestamp_ms(clock);
    let grace_period_expired = current_time > escrow.created_at + SETTLEMENT_GRACE_PERIOD;
    
    assert!(grace_period_expired, ERefundPeriodNotExpired);
    
    let amount = balance::value(&escrow.balance);
    let payment = coin::from_balance(balance::withdraw_all(&mut escrow.balance), ctx);
    
    // Return to sponsor in emergency withdrawal
    transfer::public_transfer(payment, escrow.sponsor);
    
    registry.total_refunded = registry.total_refunded + amount;
    escrow.settled = true;
    escrow.settlement_time = current_time;
    
    event::emit(FundsRefunded {
        event_id,
        sponsor: escrow.sponsor,
        amount,
        reason: string::utf8(b"Emergency withdrawal after grace period"),
    });
}

// Add additional funds to escrow
public fun add_funds_to_escrow(
    event_id: ID,
    payment: Coin<SUI>,
    registry: &mut EscrowRegistry,
    ctx: &mut TxContext
) {
    assert!(table::contains(&registry.escrows, event_id), EEscrowNotFound);
    
    let escrow = table::borrow_mut(&mut registry.escrows, event_id);
    assert!(!escrow.settled, EAlreadySettled);
    assert!(tx_context::sender(ctx) == escrow.sponsor, ENotAuthorized);
    
    let amount = coin::value(&payment);
    balance::join(&mut escrow.balance, coin::into_balance(payment));
    
    registry.total_escrowed = registry.total_escrowed + amount;
}

public fun update_custom_metric(
    event_id: ID,
    metric_name: String,
    actual_value: u64,
    registry: &mut EscrowRegistry,
    ctx: &mut TxContext
) {
    assert!(table::contains(&registry.escrows, event_id), EEscrowNotFound);
    let escrow = table::borrow(&registry.escrows, event_id);
    assert!(tx_context::sender(ctx) == escrow.organizer, ENotAuthorized);
    
    if (!table::contains(&registry.custom_metrics, event_id)) {
        table::add(&mut registry.custom_metrics, event_id, table::new(ctx));
    };
    
    let metrics = table::borrow_mut(&mut registry.custom_metrics, event_id);
    if (table::contains(metrics, metric_name)) {
        *table::borrow_mut(metrics, metric_name) = actual_value;
    } else {
        table::add(metrics, metric_name, actual_value);
    };
}

public fun check_custom_benchmarks_status(
    event_id: ID,
    conditions: SponsorConditions,
    registry: &EscrowRegistry
): bool {
    evaluate_custom_benchmarks(event_id, conditions, registry)
}

// Get escrow details
public fun get_escrow_details(
    event_id: ID,
    registry: &EscrowRegistry
): (address, address, u64, bool, u64) {
    assert!(table::contains(&registry.escrows, event_id), EEscrowNotFound);
    
    let escrow = table::borrow(&registry.escrows, event_id);
    (
        escrow.organizer,
        escrow.sponsor,
        balance::value(&escrow.balance),
        escrow.settled,
        escrow.settlement_time
    )
}

// Get settlement result
public fun get_settlement_result(
    event_id: ID,
    registry: &EscrowRegistry
): SettlementResult {
    assert!(table::contains(&registry.escrows, event_id), EEscrowNotFound);
    
    let escrow = table::borrow(&registry.escrows, event_id);
    escrow.settlement_result
}

// Check if conditions are currently met
public fun check_conditions_status(
    event_id: ID,
    registry: &EscrowRegistry,
    attendance_registry: &AttendanceRegistry,
    rating_registry: &RatingRegistry,
): (bool, u64, u64, u64) {
    assert!(table::contains(&registry.escrows, event_id), EEscrowNotFound);
    
    let escrow = table::borrow(&registry.escrows, event_id);
    let (min_attendees, min_completion_rate, min_avg_rating, _) = event_management::get_condition_details(&escrow.conditions);

    let (checked_in, _, completion_rate) = 
        attendance_verification::get_event_stats(event_id, attendance_registry);
    let avg_rating = rating_reputation::get_event_average_rating(event_id, rating_registry);
    
    let conditions_met = 
        checked_in >= min_attendees &&
        completion_rate >= min_completion_rate &&
        avg_rating >= min_avg_rating;
    
    (conditions_met, checked_in, completion_rate, avg_rating)
}

// Get global statistics
public fun get_global_stats(registry: &EscrowRegistry): (u64, u64, u64) {
    (registry.total_escrowed, registry.total_released, registry.total_refunded)
}

fun evaluate_custom_benchmarks(
    event_id: ID,
    conditions: SponsorConditions,
    registry: &EscrowRegistry
): bool {
    let custom_benchmarks = event_management::get_custom_benchmarks(&conditions);
    let benchmarks_count = vector::length(custom_benchmarks);
    
    // If no custom benchmarks, return true
    if (benchmarks_count == 0) {
        return true
    };
    
    // Check if we have metrics data for this event
    if (!table::contains(&registry.custom_metrics, event_id)) {
        return false
    };

    let metrics = table::borrow(&registry.custom_metrics, event_id);
    
    // Evaluate each custom benchmark
    let mut i = 0;
    while (i < benchmarks_count) {
        let benchmark = vector::borrow(custom_benchmarks, i);
        let metric_name = event_management::get_benchmark_metric_name(benchmark);
        let target_value = event_management::get_benchmark_target_value(benchmark);
        let comparison_type = event_management::get_benchmark_comparison_type(benchmark);
        
        // Check if we have data for this metric
        if (!table::contains(metrics, metric_name)) {
            return false // Missing data means condition not met
        };
        
        let actual_value = *table::borrow(metrics, metric_name);
        
        // Evaluate based on comparison type
        let condition_met = if (comparison_type == 0) {
            actual_value >= target_value // >=
        } else if (comparison_type == 1) {
            actual_value <= target_value // <=
        } else if (comparison_type == 2) {
            actual_value == target_value // ==
        } else {
            false // Invalid comparison type
        };
        
        if (!condition_met) {
            return false // Any failed condition means overall failure
        };
        
        i = i + 1;
    };
    
    true // All conditions met
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}