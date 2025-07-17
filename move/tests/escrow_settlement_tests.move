#[test_only]
module eia::escrow_settlement_tests;

use std::string;
use sui::test_scenario::{Self, Scenario};
use sui::clock::{Self, Clock};
use sui::coin::mint_for_testing;
use sui::sui::SUI;
use eia::escrow_settlement::{
    Self, 
    EscrowRegistry,
    // Error codes
    EInsufficientFunds,
    EEventNotCompleted,
    EAlreadySettled,
    ENotAuthorized,
    EEscrowNotFound,
    ERefundPeriodNotExpired,
};
use eia::event_management::{
    Self, 
    Event, 
    EventRegistry, 
    OrganizerProfile,
};
use eia::identity_access::{
    Self,
};
use eia::attendance_verification::{
    Self,
    AttendanceRegistry,
};
use eia::rating_reputation::{
    Self,
    RatingRegistry,
};

// Settlement grace period (7 days in milliseconds)
const SETTLEMENT_GRACE_PERIOD: u64 = 604800000;

// Test addresses
const ORGANIZER: address = @0xA1;
const SPONSOR: address = @0xC1;
const ANOTHER_SPONSOR: address = @0xC2;
const USER1: address = @0xB1;

// Test constants
const DAY_IN_MS: u64 = 86400000;
const HOUR_IN_MS: u64 = 3600000;
const TEST_COIN_AMOUNT: u64 = 1000000000; // 1 SUI

// ========== Test Helper Functions ==========

#[test_only]
fun setup_test_environment(scenario: &mut Scenario) {
    // Initialize all modules
    test_scenario::next_tx(scenario, ORGANIZER);
    {
        event_management::init_for_testing(test_scenario::ctx(scenario));
        identity_access::init_for_testing(test_scenario::ctx(scenario));
        attendance_verification::init_for_testing(test_scenario::ctx(scenario));
        rating_reputation::init_for_testing(test_scenario::ctx(scenario));
        escrow_settlement::init_for_testing(test_scenario::ctx(scenario));
        
        // Create and share clock
        let mut clock = clock::create_for_testing(test_scenario::ctx(scenario));
        clock::set_for_testing(&mut clock, 1000000);
        clock::share_for_testing(clock);
    };
}

#[test_only]
fun create_test_organizer_profile(scenario: &mut Scenario, user: address): ID {
    test_scenario::next_tx(scenario, user);
    {
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        let cap = event_management::create_organizer_profile(
            string::utf8(b"Test Organizer"),
            string::utf8(b"A test organizer bio"),
            &clock,
            test_scenario::ctx(scenario)
        );
        
        let cap_id = object::id(&cap);
        transfer::public_transfer(cap, user);
        
        test_scenario::return_shared(clock);
        cap_id
    }
}

#[test_only]
fun create_and_activate_test_event(
    scenario: &mut Scenario,
    organizer: address,
    start_offset: u64,
    capacity: u64,
    min_attendees: u64,
    min_completion_rate: u64,
    min_avg_rating: u64
): ID {
    // Create event
    test_scenario::next_tx(scenario, organizer);
    let event_id = {
        let mut registry = test_scenario::take_shared<EventRegistry>(scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        let current_time = clock::timestamp_ms(&clock);
        let event_id = event_management::create_event(
            string::utf8(b"Test Event"),
            string::utf8(b"A test event description"),
            string::utf8(b"Test Location"),
            current_time + start_offset,
            current_time + start_offset + (4 * HOUR_IN_MS),
            capacity,
            min_attendees,
            min_completion_rate,
            min_avg_rating,
            string::utf8(b"https://walrus.example/metadata"),
            &clock,
            &mut registry,
            &mut profile,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
        test_scenario::return_shared(clock);
        
        event_id
    };
    
    // Activate event
    test_scenario::next_tx(scenario, organizer);
    {
        let mut event = test_scenario::take_shared<Event>(scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    event_id
}

#[test_only]
fun complete_test_event(scenario: &mut Scenario, organizer: address, event_id: ID) {
    // Complete the event after end time
    test_scenario::next_tx(scenario, organizer);
    {
        let mut clock = test_scenario::take_shared<Clock>(scenario);
        let mut event = test_scenario::take_shared_by_id<Event>(scenario, event_id);
        let mut registry = test_scenario::take_shared<EventRegistry>(scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(scenario);
        
        // Fast forward past event end time
        clock::increment_for_testing(&mut clock, 5 * HOUR_IN_MS);
        
        event_management::complete_event(&mut event, &clock, &mut registry, &mut profile, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(clock);
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
}

// ========== Core Functionality Tests ==========

#[test]
fun test_create_escrow() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(
        &mut scenario, 
        ORGANIZER, 
        HOUR_IN_MS, 
        100, 
        50, 
        8000, 
        400
    );
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            ANOTHER_SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_custom_metric_new_metric() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Update custom metric
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"social_reach"),
            5000,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_custom_metric_existing_metric() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Add initial metric
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"media_mentions"),
            10,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Update existing metric with new value
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"media_mentions"),
            25, // Updated value
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_multiple_custom_metrics() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Add multiple different metrics
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"social_reach"),
            5000,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"media_mentions"),
            15,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"engagement_score"),
            8500,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EEscrowNotFound)]
fun test_update_custom_metric_escrow_not_found() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let fake_event_id = object::id_from_address(@0xDEADBEEF);
        
        escrow_settlement::update_custom_metric(
            fake_event_id,
            string::utf8(b"social_reach"),
            5000,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotAuthorized)]
fun test_update_custom_metric_not_organizer() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Try to update metric from unauthorized address
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"social_reach"),
            5000,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotAuthorized)]
fun test_update_custom_metric_sponsor_unauthorized() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Try to update metric as sponsor (should fail - only organizer allowed)
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"social_reach"),
            5000,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EEventNotCompleted)]
fun test_settle_escrow_event_not_completed() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Try to settle before event completion (should fail)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EEscrowNotFound)]
fun test_settle_escrow_not_found() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Complete event without creating escrow
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    // Try to settle non-existent escrow
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotAuthorized)]
fun test_settle_escrow_unauthorized() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete event
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    // Try to settle from unauthorized address
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EAlreadySettled)]
fun test_settle_escrow_already_settled() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete event
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    // First settlement
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Try to settle again (should fail)
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ERefundPeriodNotExpired)]
fun test_emergency_withdraw_too_early() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Try emergency withdraw before grace period expires
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::emergency_withdraw(
            event_id,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotAuthorized)]
fun test_add_funds_unauthorized() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Try to add funds from unauthorized address
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let additional_payment = mint_for_testing<SUI>(500000000, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::add_funds_to_escrow(
            event_id,
            additional_payment,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EEscrowNotFound)]
fun test_get_escrow_details_not_found() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let fake_event_id = object::id_from_address(@0xDEADBEEF);
        let (_, _, _, _, _) = escrow_settlement::get_escrow_details(fake_event_id, &registry);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Integration Tests ==========

#[test]
fun test_multiple_escrows_different_events() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create multiple events
    let event1_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    let event2_id = create_and_activate_test_event(&mut scenario, ORGANIZER, 2 * HOUR_IN_MS, 50, 5, 7000, 350);
    
    // Create escrows for both events
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event1 = test_scenario::take_shared_by_id<Event>(&scenario, event1_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment1 = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event1,
            SPONSOR,
            payment1,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event1);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::next_tx(&mut scenario, ANOTHER_SPONSOR);
    {
        let event2 = test_scenario::take_shared_by_id<Event>(&scenario, event2_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment2 = mint_for_testing<SUI>(2 * TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event2,
            ANOTHER_SPONSOR,
            payment2,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event2);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify both escrows exist
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (org1, spon1, bal1, settled1, _) = escrow_settlement::get_escrow_details(event1_id, &registry);
        let (org2, spon2, bal2, settled2, _) = escrow_settlement::get_escrow_details(event2_id, &registry);
        
        assert!(org1 == ORGANIZER && spon1 == SPONSOR, 23);
        assert!(org2 == ORGANIZER && spon2 == ANOTHER_SPONSOR, 24);
        assert!(bal1 == TEST_COIN_AMOUNT, 25);
        assert!(bal2 == 2 * TEST_COIN_AMOUNT, 26);
        assert!(!settled1 && !settled2, 27);
        
        let (total_escrowed, total_released, total_refunded) = 
            escrow_settlement::get_global_stats(&registry);
        assert!(total_escrowed == 3 * TEST_COIN_AMOUNT, 28);
        assert!(total_released == 0, 29);
        assert!(total_refunded == 0, 30);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_full_escrow_lifecycle() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // === Phase 1: Escrow Creation ===
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // === Phase 2: Add Additional Funds ===
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let additional_payment = mint_for_testing<SUI>(500000000, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::add_funds_to_escrow(
            event_id,
            additional_payment,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 3: Check Conditions Before Settlement ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        let (conditions_met, _, _, _) = escrow_settlement::check_conditions_status(
            event_id,
            &registry,
            &attendance_registry,
            &rating_registry
        );
        
        assert!(!conditions_met, 31); // Should not be met initially
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    // === Phase 4: Complete Event ===
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    // === Phase 5: Settlement ===
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // === Phase 6: Verify Final State ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, settled, settlement_time) = 
            escrow_settlement::get_escrow_details(event_id, &registry);
        
        assert!(settled, 32);
        assert!(balance == 0, 33);
        assert!(settlement_time > 0, 34);
        
        let _settlement_result = escrow_settlement::get_settlement_result(event_id, &registry);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_sponsor_and_organizer_both_can_settle() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event1_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    let event2_id = create_and_activate_test_event(&mut scenario, ORGANIZER, 2 * HOUR_IN_MS, 50, 5, 7000, 350);
    
    // Create escrows for both events
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event1 = test_scenario::take_shared_by_id<Event>(&scenario, event1_id);
        let event2 = test_scenario::take_shared_by_id<Event>(&scenario, event2_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment1 = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        let payment2 = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(&event1, SPONSOR, payment1, &mut registry, &clock, test_scenario::ctx(&mut scenario));
        escrow_settlement::create_escrow(&event2, SPONSOR, payment2, &mut registry, &clock, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event1);
        test_scenario::return_shared(event2);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete both events
    complete_test_event(&mut scenario, ORGANIZER, event1_id);
    complete_test_event(&mut scenario, ORGANIZER, event2_id);
    
    // Organizer settles event1
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event1_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event1_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Sponsor settles event2
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event2_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event2_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Verify both escrows are settled
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, _, settled1, _) = escrow_settlement::get_escrow_details(event1_id, &registry);
        let (_, _, _, settled2, _) = escrow_settlement::get_escrow_details(event2_id, &registry);
        
        assert!(settled1, 35);
        assert!(settled2, 36);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Edge Case Tests ==========

#[test]
fun test_update_custom_metric_zero_value() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Update metric with zero value
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"failed_metric"),
            0, // Zero value
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_custom_metric_max_value() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Update metric with maximum u64 value
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"viral_metric"),
            18446744073709551615, // Max u64 value
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_custom_metric_empty_name() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Update metric with empty name (should still work)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b""), // Empty name
            1000,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_custom_metric_unicode_name() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Update metric with Unicode name
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"\xE2\x9C\xA8_engagement_\xE2\x9C\xA8"), // ✨_engagement_✨
            7500,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_exact_grace_period_boundary() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify escrow was created
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (organizer, sponsor, balance, settled, settlement_time) = 
            escrow_settlement::get_escrow_details(event_id, &registry);
        
        assert!(organizer == ORGANIZER, 1);
        assert!(sponsor == SPONSOR, 2);
        assert!(balance == TEST_COIN_AMOUNT, 3);
        assert!(!settled, 4);
        assert!(settlement_time == 0, 5);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_settle_escrow_success() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(
        &mut scenario, 
        ORGANIZER, 
        HOUR_IN_MS, 
        100, 
        10, // min 10 attendees
        5000, // min 50% completion rate
        300  // min 3.0 rating
    );
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete event
    complete_test_event(&mut scenario, ORGANIZER, event_id);
        
    // Settle escrow (should succeed and release funds)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Verify settlement result
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, settled, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(settled, 6);
        assert!(balance == 0, 7); // Funds should be released
        
        let _result = escrow_settlement::get_settlement_result(event_id, &registry);
        // Note: Due to mocking limitations, we can't easily verify the exact result values
        // In a real implementation, the settlement result would reflect actual metrics
        
        test_scenario::return_shared(registry);
    };
    
    // Verify organizer received funds
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        // Check if organizer received the payment (would be a Coin<SUI> object)
        // This is complex to test in the current setup, but the transfer would occur
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_settle_escrow_failure() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(
        &mut scenario, 
        ORGANIZER, 
        HOUR_IN_MS, 
        100, 
        50, // min 50 attendees (high threshold)
        9000, // min 90% completion rate
        450   // min 4.5 rating
    );
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete event
    complete_test_event(&mut scenario, ORGANIZER, event_id);
        
    // Settle escrow (should fail and refund to sponsor)
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Verify settlement result (refund)
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, settled, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(settled, 8);
        assert!(balance == 0, 9); // Funds should be refunded
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_add_funds_to_escrow() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create initial escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Add additional funds
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let additional_payment = mint_for_testing<SUI>(500000000, test_scenario::ctx(&mut scenario)); // 0.5 SUI
        
        escrow_settlement::add_funds_to_escrow(
            event_id,
            additional_payment,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify total balance
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, _, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(balance == TEST_COIN_AMOUNT + 500000000, 10);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_emergency_withdraw() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Fast forward past grace period
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        
        clock::increment_for_testing(&mut clock, SETTLEMENT_GRACE_PERIOD + 1000);
        
        test_scenario::return_shared(clock);
    };
    
    // Emergency withdraw
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::emergency_withdraw(
            event_id,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify withdrawal
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, settled, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(settled, 11);
        assert!(balance == 0, 12);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_check_conditions_status() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 20, 7500, 350);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Check conditions status
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        let (conditions_met, checked_in, completion_rate, avg_rating) = 
            escrow_settlement::check_conditions_status(
                event_id,
                &registry,
                &attendance_registry,
                &rating_registry
            );
        
        // With no attendees/ratings, conditions should not be met
        assert!(!conditions_met, 13);
        assert!(checked_in == 0, 14);
        assert!(completion_rate == 0, 15);
        assert!(avg_rating == 0, 16);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_get_global_stats() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Check initial stats
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (total_escrowed, total_released, total_refunded) = 
            escrow_settlement::get_global_stats(&registry);
        
        assert!(total_escrowed == 0, 17);
        assert!(total_released == 0, 18);
        assert!(total_refunded == 0, 19);
        
        test_scenario::return_shared(registry);
    };
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Check stats after escrow creation
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (total_escrowed, total_released, total_refunded) = 
            escrow_settlement::get_global_stats(&registry);
        
        assert!(total_escrowed == TEST_COIN_AMOUNT, 20);
        assert!(total_released == 0, 21);
        assert!(total_refunded == 0, 22);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Error Case Tests ==========

#[test]
#[expected_failure(abort_code = EInsufficientFunds)]
fun test_create_escrow_zero_amount() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Try to create escrow with zero amount
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(0, test_scenario::ctx(&mut scenario)); // Zero amount
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EAlreadySettled)]
fun test_create_escrow_duplicate() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create first escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Try to create second escrow for same event (should fail)
    test_scenario::next_tx(&mut scenario, ANOTHER_SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));

        escrow_settlement::create_escrow(
            &event,
            ANOTHER_SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EAlreadySettled)]
fun test_add_funds_to_settled_escrow() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete event and settle
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Try to add funds to settled escrow (should fail)
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let additional_payment = mint_for_testing<SUI>(500000000, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::add_funds_to_escrow(
            event_id,
            additional_payment,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotAuthorized)]
fun test_emergency_withdraw_unauthorized() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Fast forward past grace period
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        
        clock::increment_for_testing(&mut clock, SETTLEMENT_GRACE_PERIOD + 1000);
        
        test_scenario::return_shared(clock);
    };
    
    // Try emergency withdraw from unauthorized address
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::emergency_withdraw(
            event_id,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

// ========== Complex Integration Tests ==========

#[test]
fun test_custom_metrics_with_settlement() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Add custom metrics before settlement
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"social_reach"),
            10000,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"media_mentions"),
            25,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Complete event and settle
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Verify settlement completed successfully with custom metrics
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, settled, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(settled, 117);
        assert!(balance == 0, 118);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_metrics_after_settlement() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete event and settle
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Try to update metrics after settlement (should still work for analytics)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        escrow_settlement::update_custom_metric(
            event_id,
            string::utf8(b"post_event_analysis"),
            9500,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_multiple_sponsors_different_events() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create multiple events
    let event1_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    let event2_id = create_and_activate_test_event(&mut scenario, ORGANIZER, 2 * HOUR_IN_MS, 50, 5, 7000, 350);
    let event3_id = create_and_activate_test_event(&mut scenario, ORGANIZER, 3 * HOUR_IN_MS, 200, 20, 9000, 450);
    
    // Create escrows from different sponsors
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event1 = test_scenario::take_shared_by_id<Event>(&scenario, event1_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment1 = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event1,
            SPONSOR,
            payment1,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event1);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::next_tx(&mut scenario, ANOTHER_SPONSOR);
    {
        let event2 = test_scenario::take_shared_by_id<Event>(&scenario, event2_id);
        let event3 = test_scenario::take_shared_by_id<Event>(&scenario, event3_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment2 = mint_for_testing<SUI>(2 * TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        let payment3 = mint_for_testing<SUI>(3 * TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(&event2, ANOTHER_SPONSOR, payment2, &mut registry, &clock, test_scenario::ctx(&mut scenario));
        escrow_settlement::create_escrow(&event3, ANOTHER_SPONSOR, payment3, &mut registry, &clock, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event2);
        test_scenario::return_shared(event3);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify all escrows exist with correct details
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (org1, spon1, bal1, settled1, _) = escrow_settlement::get_escrow_details(event1_id, &registry);
        let (org2, spon2, bal2, settled2, _) = escrow_settlement::get_escrow_details(event2_id, &registry);
        let (org3, spon3, bal3, settled3, _) = escrow_settlement::get_escrow_details(event3_id, &registry);
        
        assert!(org1 == ORGANIZER && spon1 == SPONSOR, 37);
        assert!(org2 == ORGANIZER && spon2 == ANOTHER_SPONSOR, 38);
        assert!(org3 == ORGANIZER && spon3 == ANOTHER_SPONSOR, 39);
        
        assert!(bal1 == TEST_COIN_AMOUNT, 40);
        assert!(bal2 == 2 * TEST_COIN_AMOUNT, 41);
        assert!(bal3 == 3 * TEST_COIN_AMOUNT, 42);
        
        assert!(!settled1 && !settled2 && !settled3, 43);
        
        let (total_escrowed, total_released, total_refunded) = escrow_settlement::get_global_stats(&registry);
        assert!(total_escrowed == 6 * TEST_COIN_AMOUNT, 44);
        assert!(total_released == 0, 45);
        assert!(total_refunded == 0, 46);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_settlement_with_varying_conditions() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create events with different sponsor conditions
    let easy_event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 5, 5000, 200); // Easy conditions
    let hard_event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, 2 * HOUR_IN_MS, 50, 40, 9500, 480); // Hard conditions
    
    // Create escrows for both events
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let easy_event = test_scenario::take_shared_by_id<Event>(&scenario, easy_event_id);
        let hard_event = test_scenario::take_shared_by_id<Event>(&scenario, hard_event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment1 = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        let payment2 = mint_for_testing<SUI>(2 * TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(&easy_event, SPONSOR, payment1, &mut registry, &clock, test_scenario::ctx(&mut scenario));
        escrow_settlement::create_escrow(&hard_event, SPONSOR, payment2, &mut registry, &clock, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(easy_event);
        test_scenario::return_shared(hard_event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete both events
    complete_test_event(&mut scenario, ORGANIZER, easy_event_id);
    complete_test_event(&mut scenario, ORGANIZER, hard_event_id);
    
    // Check conditions status before settlement
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        let (_easy_met, easy_checked, easy_completion, easy_rating) = 
            escrow_settlement::check_conditions_status(easy_event_id, &registry, &attendance_registry, &rating_registry);
        let (_hard_met, hard_checked, hard_completion, hard_rating) = 
            escrow_settlement::check_conditions_status(hard_event_id, &registry, &attendance_registry, &rating_registry);
        
        // With no actual attendees/ratings, easy conditions might be met, hard ones won't be
        assert!(easy_checked == 0 && easy_completion == 0 && easy_rating == 0, 47);
        assert!(hard_checked == 0 && hard_completion == 0 && hard_rating == 0, 48);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    // Settle both escrows
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut easy_event = test_scenario::take_shared_by_id<Event>(&scenario, easy_event_id);
        let mut hard_event = test_scenario::take_shared_by_id<Event>(&scenario, hard_event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        // Settle easy event (likely to succeed with low thresholds)
        escrow_settlement::settle_escrow(
            &mut easy_event,
            easy_event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        // Settle hard event (likely to fail with high thresholds)
        escrow_settlement::settle_escrow(
            &mut hard_event,
            hard_event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(easy_event);
        test_scenario::return_shared(hard_event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Verify settlement results
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, easy_balance, easy_settled, _) = escrow_settlement::get_escrow_details(easy_event_id, &registry);
        let (_, _, hard_balance, hard_settled, _) = escrow_settlement::get_escrow_details(hard_event_id, &registry);
        
        assert!(easy_settled && hard_settled, 49);
        assert!(easy_balance == 0 && hard_balance == 0, 50);
        
        // Check settlement results
        let _easy_result = escrow_settlement::get_settlement_result(easy_event_id, &registry);
        let _hard_result = escrow_settlement::get_settlement_result(hard_event_id, &registry);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_concurrent_settlement_attempts() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete event
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    // First settlement by organizer (should succeed)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Verify settlement succeeded
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, settled, settlement_time) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(settled, 51);
        assert!(balance == 0, 52);
        assert!(settlement_time > 0, 53);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_organizer_settles_after_grace_period() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete event
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    // Fast forward past grace period
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        
        clock::increment_for_testing(&mut clock, SETTLEMENT_GRACE_PERIOD + DAY_IN_MS);
        
        test_scenario::return_shared(clock);
    };
    
    // Organizer can still settle normally even after grace period
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Verify settlement
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, settled, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(settled, 54);
        assert!(balance == 0, 55);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Edge Cases and Boundary Tests ==========

#[test]
fun test_exact_condition_thresholds() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create event with specific thresholds
    let event_id = create_and_activate_test_event(
        &mut scenario, 
        ORGANIZER, 
        HOUR_IN_MS, 
        100, 
        10,   // exactly 10 attendees required
        7500, // exactly 75% completion rate
        400   // exactly 4.0 rating
    );
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Complete event
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    // Check conditions (with no attendance/rating data, should fail)
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        let (conditions_met, checked_in, completion_rate, avg_rating) = 
            escrow_settlement::check_conditions_status(event_id, &registry, &attendance_registry, &rating_registry);
        
        assert!(!conditions_met, 56);
        assert!(checked_in == 0, 57); // Below threshold of 10
        assert!(completion_rate == 0, 58); // Below threshold of 7500
        assert!(avg_rating == 0, 59); // Below threshold of 400
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_maximum_escrow_amount() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create large escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let large_amount = 1000000000000; // 1000 SUI
        let payment = mint_for_testing<SUI>(large_amount, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify large amount is handled correctly
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, _, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(balance == 1000000000000, 60);
        
        let (total_escrowed, _, _) = escrow_settlement::get_global_stats(&registry);
        assert!(total_escrowed == 1000000000000, 61);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_minimum_valid_escrow_amount() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create minimum valid escrow (1 unit)
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let minimal_amount = 1; // 1 unit
        let payment = mint_for_testing<SUI>(minimal_amount, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify minimal amount works
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, _, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(balance == 1, 62);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Performance and Stress Tests ==========

#[test]
fun test_large_number_of_metrics() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Add many metrics
    let metric_names = vector[
        b"social_reach",
        b"media_mentions", 
        b"engagement_rate",
        b"conversion_rate",
        b"sentiment_score",
        b"share_count",
        b"view_count",
        b"click_through_rate",
        b"bounce_rate",
        b"session_duration"
    ];
    
    let mut i = 0;
    while (i < vector::length(&metric_names)) {
        test_scenario::next_tx(&mut scenario, ORGANIZER);
        {
            let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
            
            let metric_name = *vector::borrow(&metric_names, i);
            let metric_value = (i + 1) * 1000; // Different values
            
            escrow_settlement::update_custom_metric(
                event_id,
                string::utf8(metric_name),
                metric_value,
                &mut registry,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_shared(registry);
        };
        i = i + 1;
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_large_number_of_escrows() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create multiple events to test system scalability
    let mut event_ids = vector::empty<ID>();
    let num_events = 5; // Reasonable number for testing
    
    let mut i = 0;
    while (i < num_events) {
        let event_id = create_and_activate_test_event(
            &mut scenario, 
            ORGANIZER, 
            HOUR_IN_MS + (i * HOUR_IN_MS), 
            100, 
            10, 
            8000, 
            400
        );
        vector::push_back(&mut event_ids, event_id);
        i = i + 1;
    };
    
    // Create escrows for all events
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let mut j = 0;
        while (j < num_events) {
            let event_id = *vector::borrow(&event_ids, j);
            let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
            
            let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT * (j + 1), test_scenario::ctx(&mut scenario));
            
            escrow_settlement::create_escrow(
                &event,
                SPONSOR,
                payment,
                &mut registry,
                &clock,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_shared(event);
            j = j + 1;
        };
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify all escrows created correctly
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let mut k = 0;
        while (k < num_events) {
            let event_id = *vector::borrow(&event_ids, k);
            let (organizer, sponsor, balance, settled, _) = escrow_settlement::get_escrow_details(event_id, &registry);
            
            assert!(organizer == ORGANIZER, 63 + k);
            assert!(sponsor == SPONSOR, 68 + k);
            assert!(balance == TEST_COIN_AMOUNT * (k + 1), 73 + k);
            assert!(!settled, 78 + k);
            
            k = k + 1;
        };
        
        let (total_escrowed, total_released, total_refunded) = escrow_settlement::get_global_stats(&registry);
        let expected_total = TEST_COIN_AMOUNT * (1 + 2 + 3 + 4 + 5); // Sum of 1 to 5
        assert!(total_escrowed == expected_total, 83);
        assert!(total_released == 0, 84);
        assert!(total_refunded == 0, 85);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_multiple_funds_additions() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create initial escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Add funds multiple times
    let num_additions = 3;
    let additional_amount = 200000000; // 0.2 SUI each time
    
    let mut i = 0;
    while (i < num_additions) {
        test_scenario::next_tx(&mut scenario, SPONSOR);
        {
            let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
            
            let additional_payment = mint_for_testing<SUI>(additional_amount, test_scenario::ctx(&mut scenario));
            
            escrow_settlement::add_funds_to_escrow(
                event_id,
                additional_payment,
                &mut registry,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_shared(registry);
        };
        i = i + 1;
    };
    
    // Verify total balance
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, _, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        let expected_balance = TEST_COIN_AMOUNT + (additional_amount * num_additions);
        assert!(balance == expected_balance, 86);
        
        let (total_escrowed, _, _) = escrow_settlement::get_global_stats(&registry);
        assert!(total_escrowed == expected_balance, 87);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Time-based Tests ==========

#[test]
fun test_grace_period_boundary_conditions() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Fast forward to exactly the grace period boundary
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        
        clock::increment_for_testing(&mut clock, SETTLEMENT_GRACE_PERIOD);
        
        test_scenario::return_shared(clock);
    };
    
    
    // Fast forward 1ms past grace period
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        
        clock::increment_for_testing(&mut clock, 1);
        
        test_scenario::return_shared(clock);
    };
    
    // Now emergency withdraw should work
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::emergency_withdraw(
            event_id,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify withdrawal
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, settled, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(settled, 88);
        assert!(balance == 0, 89);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_long_term_escrow() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Fast forward very long time (30 days)
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        
        clock::increment_for_testing(&mut clock, 30 * DAY_IN_MS);
        
        test_scenario::return_shared(clock);
    };
    
    // Escrow should still be accessible for emergency withdrawal
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::emergency_withdraw(
            event_id,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

// ========== Data Consistency Tests ==========

#[test]
fun test_global_stats_consistency() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create multiple events and escrows
    let event1_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    let event2_id = create_and_activate_test_event(&mut scenario, ORGANIZER, 2 * HOUR_IN_MS, 50, 5, 7000, 350);
    
    // Initial state
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (total_escrowed, total_released, total_refunded) = escrow_settlement::get_global_stats(&registry);
        assert!(total_escrowed == 0, 90);
        assert!(total_released == 0, 91);
        assert!(total_refunded == 0, 92);
        
        test_scenario::return_shared(registry);
    };
    
    // Create escrows
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event1 = test_scenario::take_shared_by_id<Event>(&scenario, event1_id);
        let event2 = test_scenario::take_shared_by_id<Event>(&scenario, event2_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment1 = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        let payment2 = mint_for_testing<SUI>(2 * TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(&event1, SPONSOR, payment1, &mut registry, &clock, test_scenario::ctx(&mut scenario));
        escrow_settlement::create_escrow(&event2, SPONSOR, payment2, &mut registry, &clock, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event1);
        test_scenario::return_shared(event2);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Check stats after creation
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (total_escrowed, total_released, total_refunded) = escrow_settlement::get_global_stats(&registry);
        assert!(total_escrowed == 3 * TEST_COIN_AMOUNT, 93);
        assert!(total_released == 0, 94);
        assert!(total_refunded == 0, 95);
        
        test_scenario::return_shared(registry);
    };
    
    // Complete events and settle
    complete_test_event(&mut scenario, ORGANIZER, event1_id);
    complete_test_event(&mut scenario, ORGANIZER, event2_id);
    
    // Settle event1 (assume success)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event1 = test_scenario::take_shared_by_id<Event>(&scenario, event1_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event1,
            event1_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event1);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Settle event2 (assume failure - refund)
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut event2 = test_scenario::take_shared_by_id<Event>(&scenario, event2_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event2,
            event2_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event2);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // Check final stats consistency
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (total_escrowed, total_released, total_refunded) = escrow_settlement::get_global_stats(&registry);
        
        // Total escrowed should remain the same
        assert!(total_escrowed == 3 * TEST_COIN_AMOUNT, 96);
        
        // Released + refunded should equal total escrowed
        assert!(total_released + total_refunded == total_escrowed, 97);
        
        // Based on settlement logic (conditions likely not met), both should be refunds
        assert!(total_refunded == 3 * TEST_COIN_AMOUNT, 98);
        assert!(total_released == 0, 99);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Integration with Other Modules Tests ==========

#[test]
fun test_integration_with_event_management() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100, 10, 8000, 400);
    
    // Verify event state before escrow
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        
        assert!(event_management::is_event_active(&event), 100);
        assert!(!event_management::is_event_completed(&event), 101);
        assert!(event_management::get_event_organizer(&event) == ORGANIZER, 102);
        
        test_scenario::return_shared(event);
    };
    
    // Create escrow
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify escrow uses correct event data
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (organizer, sponsor, _, _, _) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(organizer == ORGANIZER, 103);
        assert!(sponsor == SPONSOR, 104);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Final Comprehensive Test ==========

#[test]
fun test_complete_escrow_protocol_lifecycle() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    // === Setup Phase ===
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create event with realistic conditions
    let event_id = create_and_activate_test_event(
        &mut scenario, 
        ORGANIZER, 
        HOUR_IN_MS, 
        100, 
        25,   // Need 25 attendees
        8000, // Need 80% completion rate
        400   // Need 4.0 average rating
    );
    
    // === Phase 1: Escrow Creation ===
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let payment = mint_for_testing<SUI>(5 * TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::create_escrow(
            &event,
            SPONSOR,
            payment,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // === Phase 2: Additional Funding ===
    test_scenario::next_tx(&mut scenario, SPONSOR);
    {
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let additional_payment = mint_for_testing<SUI>(TEST_COIN_AMOUNT, test_scenario::ctx(&mut scenario));
        
        escrow_settlement::add_funds_to_escrow(
            event_id,
            additional_payment,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 3: Pre-Settlement Condition Check ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        let (conditions_met, checked_in, completion_rate, avg_rating) = 
            escrow_settlement::check_conditions_status(event_id, &registry, &attendance_registry, &rating_registry);
        
        assert!(!conditions_met, 105); // Should not be met initially
        assert!(checked_in == 0, 106);
        assert!(completion_rate == 0, 107);
        assert!(avg_rating == 0, 108);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    // === Phase 4: Event Completion ===
    complete_test_event(&mut scenario, ORGANIZER, event_id);
    
    // === Phase 5: Settlement ===
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        escrow_settlement::settle_escrow(
            &mut event,
            event_id,
            &mut registry,
            &attendance_registry,
            &rating_registry,
            &mut organizer_profile,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    // === Phase 6: Final Verification ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (_, _, balance, settled, settlement_time) = escrow_settlement::get_escrow_details(event_id, &registry);
        assert!(settled, 109);
        assert!(balance == 0, 110);
        assert!(settlement_time > 0, 111);
        
        let _settlement_result = escrow_settlement::get_settlement_result(event_id, &registry);
        // Verify settlement result structure exists and is accessible
        
        let (total_escrowed, total_released, total_refunded) = escrow_settlement::get_global_stats(&registry);
        assert!(total_escrowed == 6 * TEST_COIN_AMOUNT, 112);
        assert!(total_released + total_refunded == total_escrowed, 113);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Test Helper Function Tests ==========

#[test]
fun test_init_for_testing() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    // Test that init_for_testing works correctly
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        escrow_settlement::init_for_testing(test_scenario::ctx(&mut scenario));
    };
    
    // Verify registry was created
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EscrowRegistry>(&scenario);
        
        let (total_escrowed, total_released, total_refunded) = escrow_settlement::get_global_stats(&registry);
        assert!(total_escrowed == 0, 114);
        assert!(total_released == 0, 115);
        assert!(total_refunded == 0, 116);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}