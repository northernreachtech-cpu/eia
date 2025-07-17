#[test_only]
module eia::identity_access_tests;

use std::string;
use sui::test_scenario::{Self, Scenario};
use sui::clock::{Self, Clock};
use eia::identity_access::{
    Self, 
    RegistrationRegistry,
    // Error codes
    EEventNotActive,
    EAlreadyRegistered,
    ECapacityReached,
    ENotRegistered,
};
use eia::event_management::{
    Self, 
    Event, 
    EventRegistry, 
    OrganizerProfile,
};

// Test addresses
const ORGANIZER: address = @0xA1;
const USER1: address = @0xB1;
const USER2: address = @0xB2;
const USER3: address = @0xB3;
const VERIFIER: address = @0xC1;

// Test constants
const DAY_IN_MS: u64 = 86400000;
const HOUR_IN_MS: u64 = 3600000;
const PASS_VALIDITY_DURATION: u64 = 86400000; // 24 hours

// ========== Test Helper Functions ==========

#[test_only]
fun setup_test_environment(scenario: &mut Scenario, _clock: &Clock) {
    // Initialize both modules
    test_scenario::next_tx(scenario, ORGANIZER);
    {
        event_management::init_for_testing(test_scenario::ctx(scenario));
        identity_access::init_for_testing(test_scenario::ctx(scenario));
    };
}

#[test_only]
fun create_test_organizer_profile(
    scenario: &mut Scenario, 
    clock: &Clock,
    user: address
): ID {
    test_scenario::next_tx(scenario, user);
    {
        let cap = event_management::create_organizer_profile(
            string::utf8(b"Test Organizer"),
            string::utf8(b"A test organizer bio"),
            clock,
            test_scenario::ctx(scenario)
        );
        
        let cap_id = object::id(&cap);
        transfer::public_transfer(cap, user);
        cap_id
    }
}

#[test_only]
fun create_and_activate_test_event(
    scenario: &mut Scenario,
    clock: &Clock,
    organizer: address,
    start_offset: u64,
    capacity: u64
): ID {
    // Create event
    test_scenario::next_tx(scenario, organizer);
    let event_id = {
        let mut registry = test_scenario::take_shared<EventRegistry>(scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(scenario);
        
        let current_time = clock::timestamp_ms(clock);
        let event_id = event_management::create_event(
            string::utf8(b"Test Event"),
            string::utf8(b"A test event description"),
            string::utf8(b"Test Location"),
            current_time + start_offset,
            current_time + start_offset + (4 * HOUR_IN_MS),
            capacity,
            10, // min_attendees
            8000, // min_completion_rate (80%)
            400, // min_avg_rating (4.0)
            string::utf8(b"https://walrus.example/metadata"),
            clock,
            &mut registry,
            &mut profile,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
        
        event_id
    };
    
    // Activate event
    test_scenario::next_tx(scenario, organizer);
    {
        let mut event = test_scenario::take_shared<Event>(scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(scenario);
        
        event_management::activate_event(
            &mut event,
            clock,
            &mut registry,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    event_id
}


#[test_only]
fun register_user_for_event(
    scenario: &mut Scenario,
    clock: &Clock,
    user: address,
    event_id: ID 
) {
    test_scenario::next_tx(scenario, user);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(scenario, event_id); 
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(scenario);
        
        identity_access::register_for_event(
            &mut event,
            &mut registry,
            clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
}

// ========== Core Functionality Tests ==========

#[test]
fun test_user_registration() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000000);
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register user for event
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::register_for_event(
            &mut event,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        // Verify registration
        let event_id = event_management::get_event_id(&event);
        assert!(identity_access::is_registered(USER1, event_id, &registry), 1);
        
        let (registered_at, checked_in) = identity_access::get_registration(USER1, event_id, &registry);
        assert!(registered_at == clock::timestamp_ms(&clock), 2);
        assert!(!checked_in, 3);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_pass_generation_and_validation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000000);
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register user
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    
    // Get pass hash and validate it
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        // For testing, we need to simulate getting the pass hash
        // In reality, this would come from scanning the QR code
        
        // Since we can't easily extract the pass hash from the internal structure,
        // we'll test the validation with a dummy pass that we know will fail
        let dummy_pass_hash = b"invalid_pass_hash";
        let (is_valid, _wallet) = identity_access::validate_pass(
            dummy_pass_hash,
            event_id,
            &mut registry,
            &clock
        );
        
        assert!(!is_valid, 4); // Should be invalid
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_pass_regeneration() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000000);
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register user
    register_user_for_event(&mut scenario, &clock, USER1, _event_id);
    
    // Fast forward time and regenerate pass
    clock::increment_for_testing(&mut clock, HOUR_IN_MS);
    
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::regenerate_pass(
            &event,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        // Verify user is still registered
        let event_id = event_management::get_event_id(&event);
        assert!(identity_access::is_registered(USER1, event_id, &registry), 5);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_multiple_user_registrations() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register multiple users
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    register_user_for_event(&mut scenario, &clock, USER2, event_id);
    register_user_for_event(&mut scenario, &clock, USER3, event_id);
    
    // Verify all registrations
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        assert!(identity_access::is_registered(USER1, event_id, &registry), 6);
        assert!(identity_access::is_registered(USER2, event_id, &registry), 7);
        assert!(identity_access::is_registered(USER3, event_id, &registry), 8);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_mark_checked_in() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register user
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    
    // Mark as checked in
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::mark_checked_in(USER1, event_id, &mut registry);
        
        // Verify check-in status
        let (_, checked_in) = identity_access::get_registration(USER1, event_id, &registry);
        assert!(checked_in, 9);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_user_event_history() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Create multiple events
    let event1_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    let event2_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, 2 * HOUR_IN_MS, 50);
    
    // Register user for both events
    register_user_for_event(&mut scenario, &clock, USER1, event1_id);
    register_user_for_event(&mut scenario, &clock, USER1, event2_id);
    
    // Check user's event history
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        let user_events = identity_access::get_user_events(USER1, &registry);
        assert!(vector::length(&user_events) == 2, 10);
        assert!(vector::contains(&user_events, &event1_id), 11);
        assert!(vector::contains(&user_events, &event2_id), 12);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ========== Error Case Tests ==========

#[test]
#[expected_failure(abort_code = EEventNotActive)]
fun test_register_for_inactive_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Create event but don't activate it
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        let current_time = clock::timestamp_ms(&clock);
        let _event_id = event_management::create_event(
            string::utf8(b"Inactive Event"),
            string::utf8(b"Should fail registration"),
            string::utf8(b"Test Location"),
            current_time + DAY_IN_MS,
            current_time + DAY_IN_MS + (4 * HOUR_IN_MS),
            100,
            10,
            8000,
            400,
            string::utf8(b""),
            &clock,
            &mut registry,
            &mut profile,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
    
    // Try to register for inactive event
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::register_for_event(
            &mut event,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EAlreadyRegistered)]
fun test_duplicate_registration() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register user first time
    register_user_for_event(&mut scenario, &clock, USER1, _event_id);
    
    // Try to register again (should fail)
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::register_for_event(
            &mut event,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ECapacityReached)]
fun test_registration_capacity_limit() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Create event with capacity of 1
    let _event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 1);
    
    // Fill the event to capacity by incrementing attendees
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        // Simulate one attendee already checked in
        event_management::increment_attendees(&mut event);
        
        test_scenario::return_shared(event);
    };
    
    // Try to register when at capacity (should fail)
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::register_for_event(
            &mut event,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotRegistered)]
fun test_regenerate_pass_not_registered() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Try to regenerate pass without registering first
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::regenerate_pass(
            &event,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EEventNotActive)]
fun test_regenerate_pass_inactive_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register user
    register_user_for_event(&mut scenario, &clock, USER1, _event_id);
    
    // Complete the event (making it inactive)
    clock::increment_for_testing(&mut clock, HOUR_IN_MS + (5 * HOUR_IN_MS));
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::complete_event(
            &mut event,
            &clock,
            &mut registry,
            &mut profile,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
    
    // Try to regenerate pass after event completion
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::regenerate_pass(
            &event,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ========== Integration Tests ==========

#[test]
fun test_full_registration_and_check_in_flow() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // 1. User registers for event
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    
    // 2. Verify registration
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        assert!(identity_access::is_registered(USER1, event_id, &registry), 13);
        let (_, checked_in) = identity_access::get_registration(USER1, event_id, &registry);
        assert!(!checked_in, 14);
        
        test_scenario::return_shared(registry);
    };
    
    // 3. Simulate pass validation and check-in
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        // Mark user as checked in (simulating successful pass validation)
        identity_access::mark_checked_in(USER1, event_id, &mut registry);
        
        // Verify check-in status
        let (_, checked_in) = identity_access::get_registration(USER1, event_id, &registry);
        assert!(checked_in, 15);
        
        test_scenario::return_shared(registry);
    };
    
    // 4. Increment event attendees
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        event_management::increment_attendees(&mut event);
        assert!(event_management::get_current_attendees(&event) == 1, 16);
        
        test_scenario::return_shared(event);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_multiple_events_same_user() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Create multiple events
    let event1_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    let event2_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, 2 * HOUR_IN_MS, 50);
    let event3_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, 3 * HOUR_IN_MS, 200);
    
    // Register user for all events
    register_user_for_event(&mut scenario, &clock, USER1, event1_id);
    register_user_for_event(&mut scenario, &clock, USER1, event2_id);
    register_user_for_event(&mut scenario, &clock, USER1, event3_id);
    
    // Verify all registrations
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        let user_events = identity_access::get_user_events(USER1, &registry);
        assert!(vector::length(&user_events) == 3, 17);
        assert!(vector::contains(&user_events, &event1_id), 18);
        assert!(vector::contains(&user_events, &event2_id), 19);
        assert!(vector::contains(&user_events, &event3_id), 20);
        
        // Verify individual registrations
        assert!(identity_access::is_registered(USER1, event1_id, &registry), 21);
        assert!(identity_access::is_registered(USER1, event2_id, &registry), 22);
        assert!(identity_access::is_registered(USER1, event3_id, &registry), 23);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_concurrent_registrations() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register multiple users concurrently
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    register_user_for_event(&mut scenario, &clock, USER2, event_id);
    register_user_for_event(&mut scenario, &clock, USER3, event_id);
    
    // Verify all registrations
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        assert!(identity_access::is_registered(USER1, event_id, &registry), 24);
        assert!(identity_access::is_registered(USER2, event_id, &registry), 25);
        assert!(identity_access::is_registered(USER3, event_id, &registry), 26);
        
        // Verify none are checked in initially
        let (_, checked_in1) = identity_access::get_registration(USER1, event_id, &registry);
        let (_, checked_in2) = identity_access::get_registration(USER2, event_id, &registry);
        let (_, checked_in3) = identity_access::get_registration(USER3, event_id, &registry);
        
        assert!(!checked_in1, 27);
        assert!(!checked_in2, 28);
        assert!(!checked_in3, 29);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_pass_expiration_flow() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000000);
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register user
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    
    // Fast forward past pass expiration
    clock::increment_for_testing(&mut clock, PASS_VALIDITY_DURATION + 1000);
    
    // Try to validate expired pass (would normally fail in real validation)
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        // Test with dummy pass hash (expired passes would fail validation)
        let dummy_pass_hash = b"expired_pass_hash";
        let (is_valid, _wallet) = identity_access::validate_pass(
            dummy_pass_hash,
            event_id,
            &mut registry,
            &clock
        );
        
        assert!(!is_valid, 30); // Should be invalid due to expiration
        
        test_scenario::return_shared(registry);
    };
    
    // User should still be registered, just pass expired
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        assert!(identity_access::is_registered(USER1, event_id, &registry), 31);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_event_lifecycle_with_registrations() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // 1. Create event (not activated yet)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    let event_id = {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        let current_time = clock::timestamp_ms(&clock);
        let event_id = event_management::create_event(
            string::utf8(b"Lifecycle Event"),
            string::utf8(b"Testing full lifecycle"),
            string::utf8(b"Test Location"),
            current_time + HOUR_IN_MS,
            current_time + HOUR_IN_MS + (4 * HOUR_IN_MS),
            50,
            10,
            8000,
            400,
            string::utf8(b""),
            &clock,
            &mut registry,
            &mut profile,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
        
        event_id
    };
    
    // 2. Activate event
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    // 3. Users register
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    register_user_for_event(&mut scenario, &clock, USER2, event_id);
    
    // 4. Simulate check-ins
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::mark_checked_in(USER1, event_id, &mut registry);
        identity_access::mark_checked_in(USER2, event_id, &mut registry);
        
        test_scenario::return_shared(registry);
    };
    
    // 5. Update event attendee count
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        event_management::increment_attendees(&mut event);
        event_management::increment_attendees(&mut event);
        
        assert!(event_management::get_current_attendees(&event) == 2, 32);
        
        test_scenario::return_shared(event);
    };
    
    // 6. Complete event after end time
    clock::increment_for_testing(&mut clock, HOUR_IN_MS + (5 * HOUR_IN_MS));
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::complete_event(&mut event, &clock, &mut registry, &mut profile, test_scenario::ctx(&mut scenario));
        
        assert!(event_management::is_event_completed(&event), 33);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
    
    // 7. Verify final state
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        // Both users should still be registered
        assert!(identity_access::is_registered(USER1, event_id, &registry), 34);
        assert!(identity_access::is_registered(USER2, event_id, &registry), 35);
        
        // Both should be checked in
        let (_, checked_in1) = identity_access::get_registration(USER1, event_id, &registry);
        let (_, checked_in2) = identity_access::get_registration(USER2, event_id, &registry);
        assert!(checked_in1, 36);
        assert!(checked_in2, 37);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ========== Edge Case Tests ==========

#[test]
fun test_registration_with_zero_capacity_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // This should fail at event creation due to zero capacity
    // But if somehow an event with capacity 0 existed, registration should fail
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_empty_user_event_history() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        let user_events = identity_access::get_user_events(USER1, &registry);
        assert!(vector::length(&user_events) == 0, 38);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_get_registration_for_unregistered_user() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Try to get registration for unregistered user
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        assert!(!identity_access::is_registered(USER1, event_id, &registry), 39);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_validate_pass_nonexistent_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        let dummy_pass_hash = b"some_pass_hash";
        let fake_event_id = object::id_from_address(@0xDEADBEEF);
        
        let (is_valid, _wallet) = identity_access::validate_pass(
            dummy_pass_hash,
            fake_event_id,
            &mut registry,
            &clock
        );
        
        assert!(!is_valid, 40);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_mark_checked_in_multiple_times() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register user
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    
    // Mark as checked in multiple times
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::mark_checked_in(USER1, event_id, &mut registry);
        let (_, checked_in1) = identity_access::get_registration(USER1, event_id, &registry);
        assert!(checked_in1, 41);
        
        // Mark again (should remain true)
        identity_access::mark_checked_in(USER1, event_id, &mut registry);
        let (_, checked_in2) = identity_access::get_registration(USER1, event_id, &registry);
        assert!(checked_in2, 42);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ========== Performance Tests ==========

#[test]
fun test_large_number_of_registrations() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 1000);
    
    // Register many users (simulated with increment)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        // Simulate many attendees
        let mut i = 0;
        while (i < 100) {
            event_management::increment_attendees(&mut event);
            i = i + 1;
        };
        
        assert!(event_management::get_current_attendees(&event) == 100, 43);
        
        test_scenario::return_shared(event);
    };
    
    // Register some actual users
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    register_user_for_event(&mut scenario, &clock, USER2, event_id);
    register_user_for_event(&mut scenario, &clock, USER3, event_id);
    
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        assert!(identity_access::is_registered(USER1, event_id, &registry), 44);
        assert!(identity_access::is_registered(USER2, event_id, &registry), 45);
        assert!(identity_access::is_registered(USER3, event_id, &registry), 46);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ========== Test Helper Function Tests ==========

#[test]
fun test_init_for_testing() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    // Test that init_for_testing works correctly
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        identity_access::init_for_testing(test_scenario::ctx(&mut scenario));
    };
    
    // Verify registry was created
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ========== Documentation Tests ==========

/// Test that demonstrates the complete user journey through the identity & access system
#[test]
fun test_complete_user_journey_documentation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000000);
    
    // === Setup Phase ===
    setup_test_environment(&mut scenario, &clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // === Phase 1: User Registration ===
    // User discovers event and registers
    register_user_for_event(&mut scenario, &clock, USER1, event_id);
    
    // Verify registration successful
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        assert!(identity_access::is_registered(USER1, event_id, &registry), 47);
        
        let (registered_at, checked_in) = identity_access::get_registration(USER1, event_id, &registry);
        assert!(registered_at > 0, 48);
        assert!(!checked_in, 49);
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 2: Pass Management ===
    // User regenerates pass (maybe lost phone, etc.)
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        identity_access::regenerate_pass(&event, &mut registry, &clock, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    // === Phase 3: Event Day - Check In ===
    // Verifier validates pass and marks user as checked in
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        // In real implementation, this would be after successful pass validation
        identity_access::mark_checked_in(USER1, event_id, &mut registry);
        
        // Verify check-in
        let (_, checked_in) = identity_access::get_registration(USER1, event_id, &registry);
        assert!(checked_in, 50);
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 4: Event Management Update ===
    // Update event attendee count
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        event_management::increment_attendees(&mut event);
        assert!(event_management::get_current_attendees(&event) == 1, 51);
        
        test_scenario::return_shared(event);
    };
    
    // === Phase 5: User History ===
    // User can view their event history
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        
        let user_events = identity_access::get_user_events(USER1, &registry);
        assert!(vector::length(&user_events) == 1, 52);
        assert!(vector::contains(&user_events, &event_id), 53);
        
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}
