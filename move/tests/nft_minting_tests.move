#[test_only]
module eia::nft_minting_tests;

use std::string;
use sui::test_scenario::{Self, Scenario};
use sui::clock::{Self, Clock};
use eia::nft_minting::{
    Self, 
    NFTRegistry,
    ProofOfAttendance,
    NFTOfCompletion,
    // Error codes
    EInvalidCapability,
    EAlreadyMinted,
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
use eia::attendance_verification::{
    Self,
    MintPoACapability,
    MintCompletionCapability,
};

// Test addresses
const ORGANIZER: address = @0xA1;
const USER1: address = @0xB1;
const USER2: address = @0xB2;
const USER3: address = @0xB3;
const VERIFIER: address = @0xC1;

// Test constants
const HOUR_IN_MS: u64 = 3600000;

// ========== Test Helper Functions ==========

#[test_only]
fun setup_test_environment(scenario: &mut Scenario) {
    // Initialize all modules
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
    
    // Initialize NFT minting module
    test_scenario::next_tx(scenario, ORGANIZER);
    {
        nft_minting::init_for_testing(test_scenario::ctx(scenario));
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
fun create_mock_poa_capability(
    scenario: &mut Scenario,
    event_id: ID,
    wallet: address,
    check_in_time: u64
): MintPoACapability {
    test_scenario::next_tx(scenario, VERIFIER);
    {
        // Create a mock capability for testing
        // In real implementation, this would come from attendance_verification::check_in
        let ctx = test_scenario::ctx(scenario);
        attendance_verification::create_mock_poa_capability_for_testing(
            event_id,
            wallet,
            check_in_time,
            ctx
        )
    }
}

#[test_only]
fun create_mock_completion_capability(
    scenario: &mut Scenario,
    event_id: ID,
    wallet: address,
    check_in_time: u64,
    check_out_time: u64,
    attendance_duration: u64
): MintCompletionCapability {
    test_scenario::next_tx(scenario, VERIFIER);
    {
        // Create a mock capability for testing
        let ctx = test_scenario::ctx(scenario);
        attendance_verification::create_mock_completion_capability_for_testing(
            event_id,
            wallet,
            check_in_time,
            check_out_time,
            attendance_duration,
            ctx
        )
    }
}

// ========== Core Functionality Tests ==========

#[test]
fun test_init_module() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    let fake_event_id = object::id_from_address(@0xDEADBEEF);
    
    // Test module initialization
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        nft_minting::init_for_testing(test_scenario::ctx(&mut scenario));
    };
    
    // Verify NFTRegistry was created
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // Test queries for nonexistent event
        assert!(!nft_minting::has_proof_of_attendance(USER1, fake_event_id, &registry), 31);
        assert!(!nft_minting::has_completion_nft(USER1, fake_event_id, &registry), 32);
        
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(fake_event_id, &registry);
        assert!(total_poa == 0, 33);
        assert!(total_completions == 0, 34);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_nonexistent_user_queries() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let fake_user = @0xFADE;
    
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // Test queries for nonexistent user
        let (user_poa_tokens, user_completion_tokens) = nft_minting::get_user_nfts(fake_user, &registry);
        assert!(vector::length(&user_poa_tokens) == 0, 35);
        assert!(vector::length(&user_completion_tokens) == 0, 36);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_zero_duration_completion_nft() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Zero Duration Event"),
            string::utf8(b"https://walrus.example/zero.png"),
            string::utf8(b"Virtual"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Create completion capability with zero duration
    let check_in_time = 1000000;
    let check_out_time = check_in_time; // Same time = zero duration
    let attendance_duration = 0;
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER1, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        let nft_id = nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        // Should still create NFT even with zero duration
        assert!(nft_id != object::id_from_address(@0x0), 37);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_event_metadata() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let event_id = object::id_from_address(@0xDEADBEEF);
    
    // Set initial metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Original Event"),
            string::utf8(b"https://walrus.example/original.png"),
            string::utf8(b"Original Location"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Update metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Updated Event"),
            string::utf8(b"https://walrus.example/updated.png"),
            string::utf8(b"Updated Location"),
            USER1, // Different organizer
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify metadata can be updated (should work without error)
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 0, 38);
        assert!(total_completions == 0, 39);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Integration Tests ==========

#[test]
fun test_full_event_lifecycle_with_nfts() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // === Phase 1: Event Setup ===
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Full Lifecycle Event"),
            string::utf8(b"https://walrus.example/lifecycle.png"),
            string::utf8(b"Los Angeles"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 2: User Registration ===
    register_user_for_event(&mut scenario, USER1, event_id);
    register_user_for_event(&mut scenario, USER2, event_id);
    register_user_for_event(&mut scenario, USER3, event_id);
    
    // === Phase 3: Event Day - Check-ins ===
    let check_in_time = 1000000;
    
    // USER1 checks in only (gets PoA)
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // USER2 and USER3 complete the event (get both PoA and completion)
    let check_out_time = check_in_time + (2 * HOUR_IN_MS);
    let attendance_duration = check_out_time - check_in_time;
    
    // USER2 PoA
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER2, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // USER2 completion
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER2, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // USER3 PoA
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER3, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // USER3 completion
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER3, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 4: Verification ===
    // Verify all users received their NFTs
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let nft = test_scenario::take_from_sender<ProofOfAttendance>(&scenario);
        test_scenario::return_to_sender(&scenario, nft);
    };
    
    test_scenario::next_tx(&mut scenario, USER2);
    {
        let poa_nft = test_scenario::take_from_sender<ProofOfAttendance>(&scenario);
        let completion_nft = test_scenario::take_from_sender<NFTOfCompletion>(&scenario);
        test_scenario::return_to_sender(&scenario, poa_nft);
        test_scenario::return_to_sender(&scenario, completion_nft);
    };
    
    test_scenario::next_tx(&mut scenario, USER3);
    {
        let poa_nft = test_scenario::take_from_sender<ProofOfAttendance>(&scenario);
        let completion_nft = test_scenario::take_from_sender<NFTOfCompletion>(&scenario);
        test_scenario::return_to_sender(&scenario, poa_nft);
        test_scenario::return_to_sender(&scenario, completion_nft);
    };
    
    // === Phase 5: Final Registry State ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // Verify individual ownership
        assert!(nft_minting::has_proof_of_attendance(USER1, event_id, &registry), 40);
        assert!(!nft_minting::has_completion_nft(USER1, event_id, &registry), 41);
        
        assert!(nft_minting::has_proof_of_attendance(USER2, event_id, &registry), 42);
        assert!(nft_minting::has_completion_nft(USER2, event_id, &registry), 43);
        
        assert!(nft_minting::has_proof_of_attendance(USER3, event_id, &registry), 44);
        assert!(nft_minting::has_completion_nft(USER3, event_id, &registry), 45);
        
        // Verify aggregate statistics
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 3, 46); // All users got PoA
        assert!(total_completions == 2, 47); // USER2 and USER3 completed
        
        // Verify user NFT collections
        let (user1_poa, user1_completion) = nft_minting::get_user_nfts(USER1, &registry);
        let (user2_poa, user2_completion) = nft_minting::get_user_nfts(USER2, &registry);
        let (user3_poa, user3_completion) = nft_minting::get_user_nfts(USER3, &registry);
        
        assert!(vector::length(&user1_poa) == 1, 48);
        assert!(vector::length(&user1_completion) == 0, 49);
        
        assert!(vector::length(&user2_poa) == 1, 50);
        assert!(vector::length(&user2_completion) == 1, 51);
        
        assert!(vector::length(&user3_poa) == 1, 52);
        assert!(vector::length(&user3_completion) == 1, 53);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_multiple_events_same_user() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create multiple events
    let event1_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    let event2_id = create_and_activate_test_event(&mut scenario, ORGANIZER, 2 * HOUR_IN_MS, 50);
    
    // Set metadata for both events
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event1_id,
            string::utf8(b"Event One"),
            string::utf8(b"https://walrus.example/event1.png"),
            string::utf8(b"Location 1"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::set_event_metadata(
            event2_id,
            string::utf8(b"Event Two"),
            string::utf8(b"https://walrus.example/event2.png"),
            string::utf8(b"Location 2"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    let check_in_time = 1000000;
    let check_out_time = check_in_time + HOUR_IN_MS;
    let attendance_duration = check_out_time - check_in_time;
    
    // User attends both events and gets all NFTs
    // Event 1 - PoA only
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event1_id, USER1, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Event 2 - Both PoA and completion
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event2_id, USER1, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event2_id, 
            USER1, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify user has NFTs from both events
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // Check ownership for both events
        assert!(nft_minting::has_proof_of_attendance(USER1, event1_id, &registry), 54);
        assert!(!nft_minting::has_completion_nft(USER1, event1_id, &registry), 55);
        
        assert!(nft_minting::has_proof_of_attendance(USER1, event2_id, &registry), 56);
        assert!(nft_minting::has_completion_nft(USER1, event2_id, &registry), 57);
        
        // Check user's total NFT collection
        let (user_poa_tokens, user_completion_tokens) = nft_minting::get_user_nfts(USER1, &registry);
        assert!(vector::length(&user_poa_tokens) == 2, 58); // From both events
        assert!(vector::length(&user_completion_tokens) == 1, 59); // From event 2 only
        
        // Check individual event stats
        let (event1_poa, event1_completion) = nft_minting::get_event_nft_stats(event1_id, &registry);
        let (event2_poa, event2_completion) = nft_minting::get_event_nft_stats(event2_id, &registry);
        
        assert!(event1_poa == 1, 60);
        assert!(event1_completion == 0, 61);
        
        assert!(event2_poa == 1, 62);
        assert!(event2_completion == 1, 63);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Performance Tests ==========

#[test]
fun test_large_scale_nft_minting() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 1000);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Large Scale Event"),
            string::utf8(b"https://walrus.example/large.png"),
            string::utf8(b"Convention Center"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Simulate minting many NFTs (using a reasonable number for tests)
    let check_in_time = 1000000;
    let num_attendees = 10; // Reduced for test performance
    
    let mut i = 0;
    let addresses = vector[@0x1001, @0x1002, @0x1003, @0x1004, @0x1005, @0x1006, @0x1007, @0x1008, @0x1009, @0x1010];    while (i < num_attendees) {
        test_scenario::next_tx(&mut scenario, VERIFIER);
        {
            let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
            
            let user_address = *vector::borrow(&addresses, i);
            let capability = create_mock_poa_capability(&mut scenario, event_id, user_address, check_in_time);
            
            nft_minting::mint_proof_of_attendance(
                capability,
                &mut registry,
                test_scenario::ctx(&mut scenario)
            );
            
            test_scenario::return_shared(registry);
        };
        i = i + 1;
    };
    
    // Verify final state
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == num_attendees, 64);
        assert!(total_completions == 0, 65);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Edge Case and Stress Tests ==========

#[test]
fun test_extreme_timestamp_values() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Extreme Timestamp Event"),
            string::utf8(b"https://walrus.example/extreme.png"),
            string::utf8(b"Time Warp Zone"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Test with maximum timestamp values
    let max_timestamp = 18446744073709551615u64; // Max u64
    let check_in_time = max_timestamp - 1000;
    let check_out_time = max_timestamp;
    let attendance_duration = 1000;
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER1, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        let nft_id = nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        // Should handle extreme values without overflow
        assert!(nft_id != object::id_from_address(@0x0), 66);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_empty_string_metadata() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let event_id = object::id_from_address(@0xDEADBEEF);
    
    // Set event metadata with empty strings
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b""), // Empty event name
            string::utf8(b""), // Empty image URL
            string::utf8(b""), // Empty location
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Should work with empty strings
    let check_in_time = 1000000;
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        let nft_id = nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        assert!(nft_id != object::id_from_address(@0x0), 67);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Documentation Tests ==========

/// Test that demonstrates the complete NFT minting workflow for the EIA Protocol
#[test]
fun test_complete_nft_workflow_documentation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    // === Setup Phase ===
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // === Phase 1: Event Metadata Configuration ===
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"EIA Protocol Demo"),
            string::utf8(b"https://walrus.example/eia-demo.png"),
            string::utf8(b"Decentralized Venue"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 2: User Registration ===
    register_user_for_event(&mut scenario, USER1, event_id);
    
    // === Phase 3: Event Attendance - Check In ===
    let check_in_time = 1000000;
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        let poa_nft_id = nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        assert!(poa_nft_id != object::id_from_address(@0x0), 68);
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 4: Event Completion - Check Out ===
    let check_out_time = check_in_time + (3 * HOUR_IN_MS);
    let attendance_duration = check_out_time - check_in_time;
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER1, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        let completion_nft_id = nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        assert!(completion_nft_id != object::id_from_address(@0x0), 69);
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 5: NFT Ownership Verification ===
    test_scenario::next_tx(&mut scenario, USER1);
    {
        // User should now own both NFTs
        let poa_nft = test_scenario::take_from_sender<ProofOfAttendance>(&scenario);
        let completion_nft = test_scenario::take_from_sender<NFTOfCompletion>(&scenario);
        
        // Verify NFTs exist and have valid IDs
        assert!(object::id(&poa_nft) != object::id_from_address(@0x0), 70);
        assert!(object::id(&completion_nft) != object::id_from_address(@0x0), 71);
        
        test_scenario::return_to_sender(&scenario, poa_nft);
        test_scenario::return_to_sender(&scenario, completion_nft);
    };
    
    // === Phase 6: Registry State Verification ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // User should be recorded as having both NFT types
        assert!(nft_minting::has_proof_of_attendance(USER1, event_id, &registry), 72);
        assert!(nft_minting::has_completion_nft(USER1, event_id, &registry), 73);
        
        // Event should show 1 of each NFT minted
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 1, 74);
        assert!(total_completions == 1, 75);
        
        // User should have both NFTs in their collection
        let (user_poa_tokens, user_completion_tokens) = nft_minting::get_user_nfts(USER1, &registry);
        assert!(vector::length(&user_poa_tokens) == 1, 76);
        assert!(vector::length(&user_completion_tokens) == 1, 77);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Test Helper Function Tests ==========

#[test]
fun test_mock_capability_creation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let event_id = object::id_from_address(@0xDEADBEEF);
    let check_in_time = 1000000;
    let check_out_time = 1003600000;
    let attendance_duration = check_out_time - check_in_time;
    
    // Test PoA capability creation
    let poa_cap = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
    let (cap_event_id, cap_wallet, cap_check_in_time) = attendance_verification::get_poa_capability_data(&poa_cap);
    
    assert!(cap_event_id == event_id, 78);
    assert!(cap_wallet == USER1, 79);
    assert!(cap_check_in_time == check_in_time, 80);
    
    // Clean up capability
    let (_, _, _) = attendance_verification::consume_poa_capability(poa_cap);
    
    // Test completion capability creation
    let completion_cap = create_mock_completion_capability(
        &mut scenario, 
        event_id, 
        USER2, 
        check_in_time, 
        check_out_time, 
        attendance_duration
    );
    let (comp_event_id, comp_wallet, comp_check_in, comp_check_out, comp_duration) = 
        attendance_verification::get_completion_capability_data(&completion_cap);
    
    assert!(comp_event_id == event_id, 81);
    assert!(comp_wallet == USER2, 82);
    assert!(comp_check_in == check_in_time, 83);
    assert!(comp_check_out == check_out_time, 84);
    assert!(comp_duration == attendance_duration, 85);
    
    // Clean up capability
    let (_, _, _, _, _) = attendance_verification::consume_completion_capability(completion_cap);
    
    test_scenario::end(scenario);
}

// ========== Boundary Value Tests ==========

#[test]
fun test_minimum_timestamp_values() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Minimum Timestamp Event"),
            string::utf8(b"https://walrus.example/min.png"),
            string::utf8(b"Genesis Block"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Test with minimum timestamp values
    let min_check_in_time = 0u64;
    let min_check_out_time = 1u64;
    let min_attendance_duration = 1u64;
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER1, 
            min_check_in_time, 
            min_check_out_time, 
            min_attendance_duration
        );
        
        let nft_id = nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        // Should handle minimum values correctly
        assert!(nft_id != object::id_from_address(@0x0), 86);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_unicode_metadata() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let event_id = object::id_from_address(@0xDEADBEEF);
    
    // Set event metadata with Unicode characters
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"\xE2\x9C\xA8 Blockchain Conference \xE2\x9C\xA8"), // ✨ emoji
            string::utf8(b"https://walrus.example/\xE2\x9C\xA8.png"),
            string::utf8(b"T\xC3\xB4ky\xC3\xB4, Japan"), // Tôkyô with accents
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Should handle Unicode metadata correctly
    let check_in_time = 1000000;
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        let nft_id = nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        assert!(nft_id != object::id_from_address(@0x0), 87);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Concurrent Operations Tests ==========

#[test]
fun test_concurrent_nft_minting_different_users() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Concurrent Test Event"),
            string::utf8(b"https://walrus.example/concurrent.png"),
            string::utf8(b"Parallel Universe"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    let check_in_time = 1000000;
    
    // Simulate concurrent minting for different users (sequential in test but represents concurrent behavior)
    let users = vector[USER1, USER2, USER3];
    let mut i = 0;
    
    while (i < vector::length(&users)) {
        test_scenario::next_tx(&mut scenario, VERIFIER);
        {
            let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
            let user = *vector::borrow(&users, i);
            
            let capability = create_mock_poa_capability(&mut scenario, event_id, user, check_in_time + i);
            
            let nft_id = nft_minting::mint_proof_of_attendance(
                capability,
                &mut registry,
                test_scenario::ctx(&mut scenario)
            );
            
            assert!(nft_id != object::id_from_address(@0x0), 88 + i);
            
            test_scenario::return_shared(registry);
        };
        i = i + 1;
    };
    
    // Verify all users got their NFTs
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        assert!(nft_minting::has_proof_of_attendance(USER1, event_id, &registry), 91);
        assert!(nft_minting::has_proof_of_attendance(USER2, event_id, &registry), 92);
        assert!(nft_minting::has_proof_of_attendance(USER3, event_id, &registry), 93);
        
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 3, 94);
        assert!(total_completions == 0, 95);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_mixed_nft_types_same_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Mixed NFT Event"),
            string::utf8(b"https://walrus.example/mixed.png"),
            string::utf8(b"Hybrid Space"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    let check_in_time = 1000000;
    let check_out_time = check_in_time + (2 * HOUR_IN_MS);
    let attendance_duration = check_out_time - check_in_time;
    
    // Mint various combinations of NFTs for different users
    // USER1: PoA only
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // USER2: Completion only (unusual but possible in our model)
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER2, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // USER3: Both PoA and Completion
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let poa_capability = create_mock_poa_capability(&mut scenario, event_id, USER3, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            poa_capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let completion_capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER3, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            completion_capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify mixed NFT distribution
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // USER1: PoA only
        assert!(nft_minting::has_proof_of_attendance(USER1, event_id, &registry), 96);
        assert!(!nft_minting::has_completion_nft(USER1, event_id, &registry), 97);
        
        // USER2: Completion only
        assert!(!nft_minting::has_proof_of_attendance(USER2, event_id, &registry), 98);
        assert!(nft_minting::has_completion_nft(USER2, event_id, &registry), 99);
        
        // USER3: Both
        assert!(nft_minting::has_proof_of_attendance(USER3, event_id, &registry), 100);
        assert!(nft_minting::has_completion_nft(USER3, event_id, &registry), 101);
        
        // Verify total stats
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 2, 102); // USER1 and USER3
        assert!(total_completions == 2, 103); // USER2 and USER3
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Stress Tests ==========

#[test]
fun test_registry_state_consistency() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Consistency Test Event"),
            string::utf8(b"https://walrus.example/consistency.png"),
            string::utf8(b"Reliable Space"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    let check_in_time = 1000000;
    let check_out_time = check_in_time + HOUR_IN_MS;
    let attendance_duration = check_out_time - check_in_time;
    
    // Perform multiple operations and verify consistency at each step
    let (initial_poa, initial_completions) = {
        test_scenario::next_tx(&mut scenario, @0x0);
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let (poa, completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        test_scenario::return_shared(registry);
        (poa, completions)
    };

    assert!(initial_poa == 0, 104);
    assert!(initial_completions == 0, 105);
    
    // Mint PoA for USER1
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify consistency after first mint
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let (first_mint_poa, first_mint_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        let (user_poa_tokens, user_completion_tokens) = nft_minting::get_user_nfts(USER1, &registry);
        
        assert!(first_mint_poa == 1, 106);
        assert!(first_mint_completions == 0, 107);
        assert!(vector::length(&user_poa_tokens) == 1, 108);
        assert!(vector::length(&user_completion_tokens) == 0, 109);
        
        test_scenario::return_shared(registry);
    };
    
    // Mint completion for USER1
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER1, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify final consistency
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let (final_poa, final_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        let (final_user_poa, final_user_completions) = nft_minting::get_user_nfts(USER1, &registry);
        let has_poa = nft_minting::has_proof_of_attendance(USER1, event_id, &registry);
        let has_completion = nft_minting::has_completion_nft(USER1, event_id, &registry);
        
        assert!(final_poa == 1, 110); // Still 1 PoA
        assert!(final_completions == 1, 111); // Now 1 completion
        assert!(vector::length(&final_user_poa) == 1, 112); // User still has 1 PoA
        assert!(vector::length(&final_user_completions) == 1, 113); // User now has 1 completion
        assert!(has_poa, 114); // User has PoA
        assert!(has_completion, 115); // User has completion
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Final Comprehensive Test ==========

#[test]
fun test_complete_protocol_integration() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    // === Complete Protocol Setup ===
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // === Event Configuration ===
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"EIA Protocol Integration Test"),
            string::utf8(b"https://walrus.example/eia-integration.png"),
            string::utf8(b"Decentralized Conference Center"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // === User Registration Phase ===
    register_user_for_event(&mut scenario, USER1, event_id);
    register_user_for_event(&mut scenario, USER2, event_id);
    register_user_for_event(&mut scenario, USER3, event_id);
    
    // === Event Execution Phase ===
    let check_in_time = 1000000;
    let check_out_time = check_in_time + (4 * HOUR_IN_MS);
    let attendance_duration = check_out_time - check_in_time;
    
    // Scenario 1: USER1 checks in but leaves early (PoA only)
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Scenario 2: USER2 completes the full event (both NFTs)
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let poa_capability = create_mock_poa_capability(&mut scenario, event_id, USER2, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            poa_capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let completion_capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER2, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            completion_capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Scenario 3: USER3 also completes the event (both NFTs)
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let poa_capability = create_mock_poa_capability(&mut scenario, event_id, USER3, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            poa_capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let completion_capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER3, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            completion_capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // === Final Verification Phase ===
    // Verify NFT ownership for all users
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let poa_nft = test_scenario::take_from_sender<ProofOfAttendance>(&scenario);
        test_scenario::return_to_sender(&scenario, poa_nft);
    };
    
    test_scenario::next_tx(&mut scenario, USER2);
    {
        let poa_nft = test_scenario::take_from_sender<ProofOfAttendance>(&scenario);
        let completion_nft = test_scenario::take_from_sender<NFTOfCompletion>(&scenario);
        test_scenario::return_to_sender(&scenario, poa_nft);
        test_scenario::return_to_sender(&scenario, completion_nft);
    };
    
    test_scenario::next_tx(&mut scenario, USER3);
    {
        let poa_nft = test_scenario::take_from_sender<ProofOfAttendance>(&scenario);
        let completion_nft = test_scenario::take_from_sender<NFTOfCompletion>(&scenario);
        test_scenario::return_to_sender(&scenario, poa_nft);
        test_scenario::return_to_sender(&scenario, completion_nft);
    };
    
    // === Registry Final State Verification ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // Individual user verification
        assert!(nft_minting::has_proof_of_attendance(USER1, event_id, &registry), 116);
        assert!(!nft_minting::has_completion_nft(USER1, event_id, &registry), 117);
        
        assert!(nft_minting::has_proof_of_attendance(USER2, event_id, &registry), 118);
        assert!(nft_minting::has_completion_nft(USER2, event_id, &registry), 119);
        
        assert!(nft_minting::has_proof_of_attendance(USER3, event_id, &registry), 120);
        assert!(nft_minting::has_completion_nft(USER3, event_id, &registry), 121);
        
        // Aggregate statistics verification
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 3, 122); // All users got PoA
        assert!(total_completions == 2, 123); // USER2 and USER3 completed
        
        // User collection verification
        let (user1_poa, user1_completion) = nft_minting::get_user_nfts(USER1, &registry);
        let (user2_poa, user2_completion) = nft_minting::get_user_nfts(USER2, &registry);
        let (user3_poa, user3_completion) = nft_minting::get_user_nfts(USER3, &registry);
        
        assert!(vector::length(&user1_poa) == 1 && vector::length(&user1_completion) == 0, 124);
        assert!(vector::length(&user2_poa) == 1 && vector::length(&user2_completion) == 1, 125);
        assert!(vector::length(&user3_poa) == 1 && vector::length(&user3_completion) == 1, 126);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_set_event_metadata() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let event_id = object::id_from_address(@0xDEADBEEF);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://example.com/image.png"),
            string::utf8(b"San Francisco"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify metadata was set by checking NFT stats
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 0, 1);
        assert!(total_completions == 0, 2);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_mint_proof_of_attendance() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"DevCon 2025"),
            string::utf8(b"https://walrus.example/devcon.png"),
            string::utf8(b"San Francisco"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Create PoA capability and mint NFT
    let check_in_time = 1000000;
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        let nft_id = nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        // Verify NFT was created with correct ID
        assert!(nft_id != object::id_from_address(@0x0), 3);
        
        test_scenario::return_shared(registry);
    };
    
    // Verify NFT was transferred to user
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let nft = test_scenario::take_from_sender<ProofOfAttendance>(&scenario);
        
        // Access NFT properties using the module's getter functions if available
        // For now, we'll just verify it exists
        assert!(object::id(&nft) != object::id_from_address(@0x0), 4);
        
        test_scenario::return_to_sender(&scenario, nft);
    };
    
    // Verify registry was updated
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        assert!(nft_minting::has_proof_of_attendance(USER1, event_id, &registry), 5);
        
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 1, 6);
        assert!(total_completions == 0, 7);
        
        let (user_poa_tokens, user_completion_tokens) = nft_minting::get_user_nfts(USER1, &registry);
        assert!(vector::length(&user_poa_tokens) == 1, 8);
        assert!(vector::length(&user_completion_tokens) == 0, 9);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_mint_nft_of_completion() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Web3 Workshop"),
            string::utf8(b"https://walrus.example/workshop.png"),
            string::utf8(b"New York"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Create completion capability and mint NFT
    let check_in_time = 1000000;
    let check_out_time = 1003600000; // 1 hour later
    let attendance_duration = check_out_time - check_in_time;
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER2, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        let nft_id = nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        // Verify NFT was created
        assert!(nft_id != object::id_from_address(@0x0), 10);
        
        test_scenario::return_shared(registry);
    };
    
    // Verify NFT was transferred to user
    test_scenario::next_tx(&mut scenario, USER2);
    {
        let nft = test_scenario::take_from_sender<NFTOfCompletion>(&scenario);
        
        assert!(object::id(&nft) != object::id_from_address(@0x0), 11);
        
        test_scenario::return_to_sender(&scenario, nft);
    };
    
    // Verify registry was updated
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        assert!(nft_minting::has_completion_nft(USER2, event_id, &registry), 12);
        
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 0, 13);
        assert!(total_completions == 1, 14);
        
        let (user_poa_tokens, user_completion_tokens) = nft_minting::get_user_nfts(USER2, &registry);
        assert!(vector::length(&user_poa_tokens) == 0, 15);
        assert!(vector::length(&user_completion_tokens) == 1, 16);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_multiple_users_multiple_nfts() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Multi-User Event"),
            string::utf8(b"https://walrus.example/multi.png"),
            string::utf8(b"Boston"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    let check_in_time = 1000000;
    let check_out_time = 1003600000;
    let attendance_duration = check_out_time - check_in_time;
    
    // Mint PoA for USER1
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Mint completion NFT for USER2
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER2, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Mint both types for USER3
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // First PoA
        let poa_capability = create_mock_poa_capability(&mut scenario, event_id, USER3, check_in_time);
        nft_minting::mint_proof_of_attendance(
            poa_capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // Then completion
        let completion_capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER3, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        nft_minting::mint_nft_of_completion(
            completion_capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify final state
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        // Check individual user NFT ownership
        assert!(nft_minting::has_proof_of_attendance(USER1, event_id, &registry), 17);
        assert!(!nft_minting::has_completion_nft(USER1, event_id, &registry), 18);
        
        assert!(!nft_minting::has_proof_of_attendance(USER2, event_id, &registry), 19);
        assert!(nft_minting::has_completion_nft(USER2, event_id, &registry), 20);
        
        assert!(nft_minting::has_proof_of_attendance(USER3, event_id, &registry), 21);
        assert!(nft_minting::has_completion_nft(USER3, event_id, &registry), 22);
        
        // Check aggregate stats
        let (total_poa, total_completions) = nft_minting::get_event_nft_stats(event_id, &registry);
        assert!(total_poa == 2, 23); // USER1 and USER3
        assert!(total_completions == 2, 24); // USER2 and USER3
        
        // Check user NFT lists
        let (user1_poa, user1_completion) = nft_minting::get_user_nfts(USER1, &registry);
        let (user2_poa, user2_completion) = nft_minting::get_user_nfts(USER2, &registry);
        let (user3_poa, user3_completion) = nft_minting::get_user_nfts(USER3, &registry);
        
        assert!(vector::length(&user1_poa) == 1, 25);
        assert!(vector::length(&user1_completion) == 0, 26);
        
        assert!(vector::length(&user2_poa) == 0, 27);
        assert!(vector::length(&user2_completion) == 1, 28);
        
        assert!(vector::length(&user3_poa) == 1, 29);
        assert!(vector::length(&user3_completion) == 1, 30);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Error Case Tests ==========

#[test]
#[expected_failure(abort_code = EInvalidCapability)]
fun test_mint_poa_without_event_metadata() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let event_id = object::id_from_address(@0xDEADBEEF);
    let check_in_time = 1000000;
    
    // Try to mint PoA without setting event metadata first
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EInvalidCapability)]
fun test_mint_completion_without_event_metadata() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let event_id = object::id_from_address(@0xDEADBEEF);
    let check_in_time = 1000000;
    let check_out_time = 1003600000;
    let attendance_duration = check_out_time - check_in_time;
    
    // Try to mint completion NFT without setting event metadata first
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER1, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EAlreadyMinted)]
fun test_duplicate_poa_minting() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Duplicate Test"),
            string::utf8(b"https://walrus.example/dup.png"),
            string::utf8(b"Chicago"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    let check_in_time = 1000000;
    
    // Mint first PoA
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Try to mint second PoA for same user and event (should fail)
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_poa_capability(&mut scenario, event_id, USER1, check_in_time + 1000);
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EAlreadyMinted)]
fun test_duplicate_completion_minting() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Set event metadata
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Duplicate Completion Test"),
            string::utf8(b"https://walrus.example/dupcomp.png"),
            string::utf8(b"Seattle"),
            ORGANIZER,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    let check_in_time = 1000000;
    let check_out_time = 1003600000;
    let attendance_duration = check_out_time - check_in_time;
    
    // Mint first completion NFT
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER1, 
            check_in_time, 
            check_out_time, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Try to mint second completion NFT for same user and event (should fail)
    test_scenario::next_tx(&mut scenario, VERIFIER);
    {
        let mut registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        
        let capability = create_mock_completion_capability(
            &mut scenario, 
            event_id, 
            USER1, 
            check_in_time + 1000, 
            check_out_time + 1000, 
            attendance_duration
        );
        
        nft_minting::mint_nft_of_completion(
            capability,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}
