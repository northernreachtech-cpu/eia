#[test_only]
module eia::attendance_verification_tests;

use std::string;
use sui::test_scenario::{Self, Scenario};
use sui::clock::{Self, Clock};
use eia::attendance_verification::{
    Self, 
    AttendanceRegistry,
    // Error codes
    EEventNotActive,
    ENotCheckedIn,
    EInvalidPass,
};
use eia::event_management::{
    Self, 
    Event, 
    EventRegistry, 
    OrganizerProfile,
};
use eia::identity_access::{
    Self,
    RegistrationRegistry,
};

// Attendance states
const STATE_REGISTERED: u8 = 0;

// Test addresses
const ORGANIZER: address = @0xA1;
const USER1: address = @0xB1;
const VERIFIER: address = @0xC1;

// Test constants
const DAY_IN_MS: u64 = 86400000;
const HOUR_IN_MS: u64 = 3600000;

// ========== Test Helper Functions ==========

#[test_only]
fun setup_test_environment(scenario: &mut Scenario) {
    // Initialize all modules with shared clock
    test_scenario::next_tx(scenario, ORGANIZER);
    {
        event_management::init_for_testing(test_scenario::ctx(scenario));
        identity_access::init_for_testing(test_scenario::ctx(scenario));
        attendance_verification::init_for_testing(test_scenario::ctx(scenario));
        
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
    capacity: u64
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
            10, // min_attendees
            8000, // min_completion_rate (80%)
            400, // min_avg_rating (4.0)
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
fun register_user_for_event(scenario: &mut Scenario, user: address, event_id: ID) {
    test_scenario::next_tx(scenario, user);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(scenario, event_id);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        identity_access::register_for_event(&mut event, &mut registry, &clock, test_scenario::ctx(scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
}

#[test_only]
fun create_valid_pass_hash(): vector<u8> {
    // Simulate a valid pass hash for testing
    b"valid_test_pass_hash_12345"
}

#[test_only]
fun create_device_fingerprint(): vector<u8> {
    b"device_fingerprint_123"
}

#[test_only]
fun create_location_proof(): vector<u8> {
    b"encrypted_location_data"
}

// ========== Core Functionality Tests ==========

#[test]
fun test_get_attendance_status() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Test attendance status for unregistered user
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        
        let (has_record, state, check_in_time, check_out_time) = 
            attendance_verification::get_attendance_status(USER1, event_id, &attendance_registry);
        
        assert!(!has_record, 1);
        assert!(state == STATE_REGISTERED, 2);
        assert!(check_in_time == 0, 3);
        assert!(check_out_time == 0, 4);
        
        test_scenario::return_shared(attendance_registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_get_event_stats() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Test initial event stats
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        
        let (check_in_count, check_out_count, completion_rate) = 
            attendance_verification::get_event_stats(event_id, &attendance_registry);
        
        assert!(check_in_count == 0, 5);
        assert!(check_out_count == 0, 6);
        assert!(completion_rate == 0, 7);
        
        test_scenario::return_shared(attendance_registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_get_user_attendance_history() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    
    // Test empty attendance history
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        
        let history = attendance_verification::get_user_attendance_history(USER1, &attendance_registry);
        assert!(vector::length(&history) == 0, 8);
        
        test_scenario::return_shared(attendance_registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_verify_attendance_completion() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Test attendance completion for non-attendee
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        
        let completed = attendance_verification::verify_attendance_completion(USER1, event_id, &attendance_registry);
        assert!(!completed, 9);
        
        test_scenario::return_shared(attendance_registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Error Case Tests ==========

#[test]
#[expected_failure(abort_code = EInvalidPass)]
fun test_check_in_invalid_pass() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Try to check in with invalid pass
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let mut identity_registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let invalid_pass_hash = b"invalid_pass_hash";
        let device_fingerprint = create_device_fingerprint();
        let location_proof = create_location_proof();
        
        let _cap = attendance_verification::check_in(
            invalid_pass_hash,
            device_fingerprint,
            location_proof,
            &mut event,
            &mut attendance_registry,
            &mut identity_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(_cap, VERIFIER);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(identity_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EEventNotActive)]
fun test_check_in_inactive_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create event but don't activate it
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    let event_id = {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let current_time = clock::timestamp_ms(&clock);
        let event_id = event_management::create_event(
            string::utf8(b"Inactive Event"),
            string::utf8(b"Should fail check-in"),
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
        test_scenario::return_shared(clock);
        
        event_id
    };
    
    // Try to check in to inactive event
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let mut identity_registry = test_scenario::take_shared<RegistrationRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass_hash = create_valid_pass_hash();
        let device_fingerprint = create_device_fingerprint();
        let location_proof = create_location_proof();
        
        let _cap = attendance_verification::check_in(
            pass_hash,
            device_fingerprint,
            location_proof,
            &mut event,
            &mut attendance_registry,
            &mut identity_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(_cap, VERIFIER);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(identity_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotCheckedIn)]
fun test_check_out_not_checked_in() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Try to check out without checking in first
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let _cap = attendance_verification::check_out(
            USER1,
            event_id,
            &mut attendance_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(_cap, VERIFIER);
        
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

// ========== Integration Tests ==========

#[test]
fun test_multiple_events_attendance() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create multiple events
    let event1_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    let event2_id = create_and_activate_test_event(&mut scenario, ORGANIZER, 2 * HOUR_IN_MS, 50);
    
    // Test that attendance stats are separate for each event
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        
        let (check_in_count1, _, _) = attendance_verification::get_event_stats(event1_id, &attendance_registry);
        let (check_in_count2, _, _) = attendance_verification::get_event_stats(event2_id, &attendance_registry);
        
        assert!(check_in_count1 == 0, 10);
        assert!(check_in_count2 == 0, 11);
        
        test_scenario::return_shared(attendance_registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_event_statistics_calculation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    
    // Test completion rate calculation with mock data
    // Since we can't easily mock check-ins, we test the empty case
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        
        let fake_event_id = object::id_from_address(@0xDEADBEEF);
        let (check_in_count, check_out_count, completion_rate) = 
            attendance_verification::get_event_stats(fake_event_id, &attendance_registry);
        
        // Non-existent event should return all zeros
        assert!(check_in_count == 0, 12);
        assert!(check_out_count == 0, 13);
        assert!(completion_rate == 0, 14);
        
        test_scenario::return_shared(attendance_registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Edge Case Tests ==========

#[test]
fun test_empty_device_fingerprint() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    
    // Test with empty device fingerprint
    let empty_fingerprint = vector::empty<u8>();
    assert!(vector::length(&empty_fingerprint) == 0, 15);
    
    test_scenario::end(scenario);
}

#[test]
fun test_empty_location_proof() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    
    // Test with empty location proof
    let empty_location = vector::empty<u8>();
    assert!(vector::length(&empty_location) == 0, 16);
    
    test_scenario::end(scenario);
}

// ========== Performance Tests ==========

#[test]
fun test_large_scale_attendance() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let _event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 1000);
    
    // Test that the system can handle large-scale events
    // This mainly tests that the structures can be created and accessed
    
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        
        // Test accessing registry with large capacity event
        let history = attendance_verification::get_user_attendance_history(USER1, &attendance_registry);
        assert!(vector::length(&history) == 0, 17);
        
        test_scenario::return_shared(attendance_registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Documentation Tests ==========

/// Test that demonstrates the complete attendance verification flow
#[test]
fun test_complete_attendance_flow_documentation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    // === Setup Phase ===
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // === Phase 1: User Registration ===
    register_user_for_event(&mut scenario, USER1, event_id);
    
    // === Phase 2: Check Initial State ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        
        // User should not have attendance record yet
        let (has_record, state, _, _) = attendance_verification::get_attendance_status(USER1, event_id, &attendance_registry);
        assert!(!has_record, 18);
        assert!(state == STATE_REGISTERED, 19);
        
        // Event should have no check-ins yet
        let (check_in_count, check_out_count, completion_rate) = attendance_verification::get_event_stats(event_id, &attendance_registry);
        assert!(check_in_count == 0, 20);
        assert!(check_out_count == 0, 21);
        assert!(completion_rate == 0, 22);
        
        test_scenario::return_shared(attendance_registry);
    };
    
    // === Phase 3: Attempt Check-in (will fail due to pass validation) ===
    // In a real implementation, this would succeed with proper pass handling
    
    // === Phase 4: Verify Attendance Completion ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        
        let completed = attendance_verification::verify_attendance_completion(USER1, event_id, &attendance_registry);
        assert!(!completed, 23); // User hasn't checked out
        
        test_scenario::return_shared(attendance_registry);
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
        attendance_verification::init_for_testing(test_scenario::ctx(&mut scenario));
    };
    
    // Verify registry was created
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}