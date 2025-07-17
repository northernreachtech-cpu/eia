#[test_only]
module eia::event_management_tests;

use std::string;
use sui::test_scenario::{Self, Scenario};
use sui::clock::{Self, Clock};
use eia::event_management::{
    Self, 
    Event, 
    EventRegistry, 
    OrganizerProfile, 
    // Error codes
    ENotOrganizer,
    EEventNotActive,
    EEventAlreadyCompleted,
    EInvalidCapacity,
    EInvalidTimestamp,
};

// Event states
const STATE_CREATED: u8 = 0;
const STATE_ACTIVE: u8 = 1;
const STATE_COMPLETED: u8 = 2;
const STATE_SETTLED: u8 = 3;

// Test addresses
const ORGANIZER: address = @0xA1;
const ANOTHER_ORGANIZER: address = @0xD4;

// Test constants
const DAY_IN_MS: u64 = 86400000;
const HOUR_IN_MS: u64 = 3600000;

// ========== Test Helper Functions ==========

#[test_only]
fun setup_test(scenario: &mut Scenario, _clock: &mut Clock) {
    // Initialize the module (creates EventRegistry)
    test_scenario::next_tx(scenario, ORGANIZER);
    {
        event_management::init_for_testing(test_scenario::ctx(scenario));
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
fun create_test_event(
    scenario: &mut Scenario,
    clock: &Clock,
    organizer: address,
    start_offset: u64,
    capacity: u64
): ID {
    test_scenario::next_tx(scenario, organizer);
    {
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
    }
}

// ========== Core Functionality Tests ==========

#[test]
fun test_create_organizer_profile() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    
    // Create organizer profile
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let cap = event_management::create_organizer_profile(
            string::utf8(b"Alice Events"),
            string::utf8(b"Professional event organizer"),
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        // Verify capability was created
        assert!(object::id(&cap) != object::id_from_address(@0x0), 0);
        transfer::public_transfer(cap, ORGANIZER);
    };
    
    // Verify profile exists and has correct initial values
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let (total_events, successful_events, attendees_served, avg_rating) = 
            event_management::get_organizer_stats(&profile);
        
        assert!(total_events == 0, 1);
        assert!(successful_events == 0, 2);
        assert!(attendees_served == 0, 3);
        assert!(avg_rating == 0, 4);
        
        test_scenario::return_shared(profile);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_create_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000000);
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Create event
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        let _event_id = event_management::create_event(
            string::utf8(b"Sui Developer Conference"),
            string::utf8(b"Annual conference for Sui developers"),
            string::utf8(b"San Francisco, CA"),
            clock::timestamp_ms(&clock) + DAY_IN_MS,
            clock::timestamp_ms(&clock) + DAY_IN_MS + (8 * HOUR_IN_MS),
            500,
            50,
            7500, // 75% completion rate
            450, // 4.5 rating
            string::utf8(b"https://walrus.example/sdc-metadata"),
            &clock,
            &mut registry,
            &mut profile,
            test_scenario::ctx(&mut scenario)
        );
        
        // Verify profile was updated
        let (total_events, _, _, _) = event_management::get_organizer_stats(&profile);
        assert!(total_events == 1, 5);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
    
    // Verify event was created with correct state
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared<Event>(&scenario);
        
        assert!(event_management::get_event_state(&event) == STATE_CREATED, 6);
        assert!(event_management::get_event_capacity(&event) == 500, 7);
        assert!(event_management::get_current_attendees(&event) == 0, 8);
        assert!(!event_management::is_event_active(&event), 9);
        
        test_scenario::return_shared(event);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_add_custom_benchmark() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, DAY_IN_MS, 100);
    
    // Add custom benchmark
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        event_management::add_custom_benchmark(
            &mut event,
            string::utf8(b"social_media_mentions"),
            1000,
            0, // >= comparison
            test_scenario::ctx(&mut scenario)
        );
        
        let (_, _, _, custom_benchmarks_len) = event_management::get_event_sponsor_conditions(&event);
        assert!(custom_benchmarks_len == 1, 10);
        
        test_scenario::return_shared(event);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_activate_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, DAY_IN_MS, 100);
    
    // Activate event
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(
            &mut event,
            &clock,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        assert!(event_management::is_event_active(&event), 11);
        assert!(event_management::get_event_state(&event) == STATE_ACTIVE, 12);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_update_event_details() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, DAY_IN_MS, 100);
    
    // Update event details
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        event_management::update_event_details(
            &mut event,
            string::utf8(b"Updated Event Name"),
            string::utf8(b"Updated description"),
            string::utf8(b"New Location"),
            string::utf8(b"https://walrus.example/new-metadata"),
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_complete_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Activate event first
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
        
        // Simulate some attendees
        event_management::increment_attendees(&mut event);
        event_management::increment_attendees(&mut event);
        event_management::increment_attendees(&mut event);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    // Fast forward time to after event end
    clock::increment_for_testing(&mut clock, HOUR_IN_MS + (5 * HOUR_IN_MS));
    
    // Complete event
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
        
        assert!(event_management::is_event_completed(&event), 13);
        assert!(event_management::get_event_state(&event) == STATE_COMPLETED, 14);
        
        // Check profile was updated
        let (_, _, attendees_served, _) = event_management::get_organizer_stats(&profile);
        assert!(attendees_served == 3, 15);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_mark_event_settled() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Complete the flow: create -> activate -> complete
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::increment_for_testing(&mut clock, HOUR_IN_MS + (5 * HOUR_IN_MS));
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::complete_event(&mut event, &clock, &mut registry, &mut profile, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
    
    // Mark as settled with success
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::mark_event_settled(&mut event, true, &mut profile);
        
        assert!(event_management::get_event_state(&event) == STATE_SETTLED, 16);
        
        let (_, successful_events, _, _) = event_management::get_organizer_stats(&profile);
        assert!(successful_events == 1, 17);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(profile);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ========== Error Case Tests ==========

#[test]
#[expected_failure(abort_code = ENotOrganizer)]
fun test_create_event_not_organizer() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Try to create event with different address than profile owner
    test_scenario::next_tx(&mut scenario, ANOTHER_ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::create_event(
            string::utf8(b"Unauthorized Event"),
            string::utf8(b"Should fail"),
            string::utf8(b"Nowhere"),
            clock::timestamp_ms(&clock) + DAY_IN_MS,
            clock::timestamp_ms(&clock) + DAY_IN_MS + HOUR_IN_MS,
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
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EInvalidCapacity)]
fun test_create_event_zero_capacity() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::create_event(
            string::utf8(b"Zero Capacity Event"),
            string::utf8(b"Should fail"),
            string::utf8(b"Nowhere"),
            clock::timestamp_ms(&clock) + DAY_IN_MS,
            clock::timestamp_ms(&clock) + DAY_IN_MS + HOUR_IN_MS,
            0, // Zero capacity
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
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EInvalidTimestamp)]
fun test_create_event_past_start_time() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000000);
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::create_event(
            string::utf8(b"Past Event"),
            string::utf8(b"Should fail"),
            string::utf8(b"Nowhere"),
            500000, // Past timestamp
            2000000,
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
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EInvalidTimestamp)]
fun test_create_event_end_before_start() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        let start_time = clock::timestamp_ms(&clock) + DAY_IN_MS;
        
        event_management::create_event(
            string::utf8(b"Invalid Duration Event"),
            string::utf8(b"Should fail"),
            string::utf8(b"Nowhere"),
            start_time,
            start_time - HOUR_IN_MS, // End before start
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
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EEventNotActive)]
fun test_update_details_after_activation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, DAY_IN_MS, 100);
    
    // Activate event
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    // Try to update after activation
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        event_management::update_event_details(
            &mut event,
            string::utf8(b"Should Fail"),
            string::utf8(b"Should Fail"),
            string::utf8(b"Should Fail"),
            string::utf8(b"Should Fail"),
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EEventNotActive)]
fun test_complete_non_active_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Fast forward time but don't activate
    clock::increment_for_testing(&mut clock, HOUR_IN_MS + (5 * HOUR_IN_MS));
    
    // Try to complete without activation
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
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EEventAlreadyCompleted)]
fun test_complete_before_end_time() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 100);
    
    // Activate event
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    // Try to complete before end time
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
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EInvalidCapacity)]
fun test_increment_attendees_over_capacity() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, DAY_IN_MS, 2); // Small capacity
    
    // Activate event
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
        
        // Fill to capacity
        event_management::increment_attendees(&mut event);
        event_management::increment_attendees(&mut event);
        
        // This should fail
        event_management::increment_attendees(&mut event);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ========== Integration Tests ==========

#[test]
fun test_full_event_lifecycle() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    
    // 1. Create organizer profile
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // 2. Create event
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, DAY_IN_MS, 100);
    
    // 3. Add custom benchmarks
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        event_management::add_custom_benchmark(
            &mut event,
            string::utf8(b"social_reach"),
            5000,
            0, // >=
            test_scenario::ctx(&mut scenario)
        );
        
        event_management::add_custom_benchmark(
            &mut event,
            string::utf8(b"media_coverage"),
            3,
            0, // >=
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
    };
    
    // 4. Activate event
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    // 5. Simulate attendees checking in
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        let mut i = 0;
        while (i < 50) {
            event_management::increment_attendees(&mut event);
            i = i + 1;
        };
        
        assert!(event_management::get_current_attendees(&event) == 50, 18);
        
        test_scenario::return_shared(event);
    };
    
    // 6. Fast forward to after event
    clock::increment_for_testing(&mut clock, DAY_IN_MS + (5 * HOUR_IN_MS));
    
    // 7. Complete event
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
    
    // 8. Update organizer rating
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        // Simulate 10 ratings averaging 4.5
        event_management::update_organizer_rating(&mut profile, 4500, 10);
        
        let (_, _, _, avg_rating) = event_management::get_organizer_stats(&profile);
        assert!(avg_rating == 450, 19);
        
        test_scenario::return_shared(profile);
    };
    
    // 9. Mark as settled successfully
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::mark_event_settled(&mut event, true, &mut profile);
        
        assert!(event_management::get_event_state(&event) == STATE_SETTLED, 20);
        
        let (total_events, successful_events, attendees_served, _) = 
            event_management::get_organizer_stats(&profile);
        assert!(total_events == 1, 21);
        assert!(successful_events == 1, 22);
        assert!(attendees_served == 50, 23);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(profile);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_multiple_organizers() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

    setup_test(&mut scenario, &mut clock);

    // Create ORGANIZER profile
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);

    // Create ORGANIZER event
    let event1_id = create_test_event(&mut scenario, &clock, ORGANIZER, DAY_IN_MS, 100);

    // Create ANOTHER_ORGANIZER profile
    create_test_organizer_profile(&mut scenario, &clock, ANOTHER_ORGANIZER);

    // Create ANOTHER_ORGANIZER event
    let event2_id = create_test_event(&mut scenario, &clock, ANOTHER_ORGANIZER, 2 * DAY_IN_MS, 200);

    // Activate ORGANIZER's event
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);

        if (object::id(&event) == event1_id) {
            event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
            assert!(event_management::is_event_active(&event), 24);
        };

        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };

    // Activate ANOTHER_ORGANIZER's event
    test_scenario::next_tx(&mut scenario, ANOTHER_ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);

        if (object::id(&event) == event2_id) {
            event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
            assert!(event_management::is_event_active(&event), 25);
        };

        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };

    // Verify registry has both events
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<EventRegistry>(&scenario);
        assert!(event_management::event_exists(&registry, event1_id), 1000);
        assert!(event_management::event_exists(&registry, event2_id), 1001);
        test_scenario::return_shared(registry);
    };

    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_event_state_transitions() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Create event - should be in CREATED state
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, HOUR_IN_MS, 50);
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared<Event>(&scenario);
        assert!(event_management::get_event_state(&event) == STATE_CREATED, 25);
        test_scenario::return_shared(event);
    };
    
    // Activate - should be in ACTIVE state
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
        assert!(event_management::get_event_state(&event) == STATE_ACTIVE, 26);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    // Fast forward and complete - should be in COMPLETED state
    clock::increment_for_testing(&mut clock, HOUR_IN_MS + (5 * HOUR_IN_MS));
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::complete_event(&mut event, &clock, &mut registry, &mut profile, test_scenario::ctx(&mut scenario));
        assert!(event_management::get_event_state(&event) == STATE_COMPLETED, 27);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
    
    // Settle - should be in SETTLED state
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        event_management::mark_event_settled(&mut event, false, &mut profile);
        assert!(event_management::get_event_state(&event) == STATE_SETTLED, 28);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(profile);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_sponsor_conditions() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Create event with specific sponsor conditions
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        let _event_id = event_management::create_event(
            string::utf8(b"High Stakes Event"),
            string::utf8(b"Event with strict sponsor conditions"),
            string::utf8(b"Premium Venue"),
            clock::timestamp_ms(&clock) + DAY_IN_MS,
            clock::timestamp_ms(&clock) + DAY_IN_MS + (6 * HOUR_IN_MS),
            1000,
            500,  // min 500 attendees
            9000, // min 90% completion rate
            480,  // min 4.8 rating
            string::utf8(b"https://walrus.example/premium-event"),
            &clock,
            &mut registry,
            &mut profile,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
    
    // Add multiple custom benchmarks
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        // Add various custom benchmarks
        event_management::add_custom_benchmark(
            &mut event,
            string::utf8(b"vip_attendees"),
            50,
            0, // >= 50 VIP attendees
            test_scenario::ctx(&mut scenario)
        );
        
        event_management::add_custom_benchmark(
            &mut event,
            string::utf8(b"sponsor_mentions"),
            100,
            0, // >= 100 sponsor mentions
            test_scenario::ctx(&mut scenario)
        );
        
        event_management::add_custom_benchmark(
            &mut event,
            string::utf8(b"carbon_footprint"),
            1000,
            1, // <= 1000 kg CO2 (comparison type 1)
            test_scenario::ctx(&mut scenario)
        );
        
        let (min_attendees, min_completion_rate, min_avg_rating, custom_benchmarks_len) = event_management::get_event_sponsor_conditions(&event);
        assert!(min_attendees == 500, 29);
        assert!(min_completion_rate == 9000, 30);
        assert!(min_avg_rating == 480, 31);
        assert!(custom_benchmarks_len == 3, 32);
        
        test_scenario::return_shared(event);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_capacity_limits() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Create small capacity event
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, DAY_IN_MS, 5);
    
    // Activate event
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, test_scenario::ctx(&mut scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
    };
    
    // Fill to capacity
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        // Add exactly 5 attendees
        let mut i = 0;
        while (i < 5) {
            event_management::increment_attendees(&mut event);
            i = i + 1;
        };
        
        assert!(event_management::get_current_attendees(&event) == 5, 33);
        assert!(event_management::get_current_attendees(&event) == event_management::get_event_capacity(&event), 34);
        
        test_scenario::return_shared(event);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

// ========== Edge Case Tests ==========

#[test]
fun test_minimum_valid_event_duration() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    // Create event with minimum valid duration (1ms)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        let start_time = clock::timestamp_ms(&clock) + DAY_IN_MS;
        
        let _event_id = event_management::create_event(
            string::utf8(b"Quick Event"),
            string::utf8(b"Very short event"),
            string::utf8(b"Flash Location"),
            start_time,
            start_time + 1, // Just 1ms duration
            10,
            1,
            5000,
            300,
            string::utf8(b""),
            &clock,
            &mut registry,
            &mut profile,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_maximum_custom_benchmarks() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    let _event_id = create_test_event(&mut scenario, &clock, ORGANIZER, DAY_IN_MS, 100);
    
    // Add many custom benchmarks
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared<Event>(&scenario);
        
        let mut i = 0;
        while (i < 10) {
            event_management::add_custom_benchmark(
                &mut event,
                string::utf8(b"benchmark_"),
                i * 100,
                (i % 3) as u8, // Vary comparison types
                test_scenario::ctx(&mut scenario)
            );
            i = i + 1;
        };
        
        let (_, _, _, custom_benchmarks_len) = event_management::get_event_sponsor_conditions(&event);
        assert!(custom_benchmarks_len == 10, 35);
        
        test_scenario::return_shared(event);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_rating_edge_cases() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));
    
    setup_test(&mut scenario, &mut clock);
    create_test_organizer_profile(&mut scenario, &clock, ORGANIZER);
    
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        
        // Test with zero ratings
        event_management::update_organizer_rating(&mut profile, 0, 0);
        let (_, _, _, rating) = event_management::get_organizer_stats(&profile);
        assert!(rating == 0, 36);
        
        // Test with single rating
        event_management::update_organizer_rating(&mut profile, 500, 1);
        let (_, _, _, rating) = event_management::get_organizer_stats(&profile);
        assert!(rating == 500, 37);
        
        // Test with many ratings
        event_management::update_organizer_rating(&mut profile, 45000, 100);
        let (_, _, _, rating) = event_management::get_organizer_stats(&profile);
        assert!(rating == 450, 38);
        
        test_scenario::return_shared(profile);
    };
    
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

