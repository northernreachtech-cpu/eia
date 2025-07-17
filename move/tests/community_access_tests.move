#[test_only]
module eia::community_access_tests;

use std::string;
use sui::test_scenario::{Self, Scenario};
use sui::clock::{Self, Clock};
use eia::community_access::{
    Self,
    CommunityRegistry,
    CommunityAccessPass,
    // Error codes
    ENotOrganizer,
    ECommunityNotFound,
    ENotEligible,
    EAccessDenied,
    EAlreadyExists,
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
use eia::attendance_verification;
use eia::nft_minting::{
    Self,
    NFTRegistry,
};

// Access types constants
const ACCESS_TYPE_POA: u8 = 0;
const ACCESS_TYPE_COMPLETION: u8 = 1;
const ACCESS_TYPE_BOTH: u8 = 2;

// Test addresses
const ORGANIZER: address = @0xA1;
const USER1: address = @0xB1;
const USER2: address = @0xB2;

// Test constants
const DAY_IN_MS: u64 = 86400000;
const HOUR_IN_MS: u64 = 3600000;
const ACCESS_DURATION: u64 = 2592000000; // 30 days

// ========== Test Helper Functions ==========

#[test_only]
fun setup_test_environment(scenario: &mut Scenario) {
    // Initialize all modules
    test_scenario::next_tx(scenario, ORGANIZER);
    {
        event_management::init_for_testing(test_scenario::ctx(scenario));
        identity_access::init_for_testing(test_scenario::ctx(scenario));
        attendance_verification::init_for_testing(test_scenario::ctx(scenario));
        nft_minting::init_for_testing(test_scenario::ctx(scenario));
        community_access::init_for_testing(test_scenario::ctx(scenario));
        
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
    test_scenario::next_tx(scenario, organizer);
    let event_id = {
        let mut registry = test_scenario::take_shared<EventRegistry>(scenario);
        let mut profile = test_scenario::take_shared<OrganizerProfile>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        let current_time = clock::timestamp_ms(&clock);
        let event_id = event_management::create_event(
            string::utf8(b"Test Event"),                    // name
            string::utf8(b"A test event description"),     // description
            string::utf8(b"Test Location"),                // location
            current_time + start_offset,                   // start_time
            current_time + start_offset + (4 * HOUR_IN_MS), // end_time
            capacity,                                      // capacity
            50,                                           // min_attendees
            8000,                                         // min_completion_rate (80%)
            400,                                          // min_avg_rating (4.0/5)
            string::utf8(b"https://walrus.example/metadata"), // metadata_uri
            &clock,                                       // clock
            &mut registry,                               // registry
            &mut profile,                               // profile
            test_scenario::ctx(scenario)                // ctx
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(profile);
        test_scenario::return_shared(clock);
        event_id
    };

    test_scenario::next_tx(scenario, organizer);
    {
        let mut event = test_scenario::take_shared<Event>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        let mut registry = test_scenario::take_shared<EventRegistry>(scenario);
        
        event_management::activate_event(
            &mut event,
            &clock,
            &mut registry,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(registry);
    };
    event_id
}

#[test]
fun test_verify_access_valid() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Get NFT and join community
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    // Mint PoA NFT
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Request access
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify access with pass
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let pass = test_scenario::take_from_sender<CommunityAccessPass>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let is_valid = community_access::verify_access(&pass, &registry, &clock);
        assert!(is_valid == true, 19);
        
        test_scenario::return_to_sender(&scenario, pass);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_verify_access_expired() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Get NFT and join community with short expiry
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    // Mint PoA NFT
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    // Create community with short expiry (1 hour)
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        HOUR_IN_MS
    );
    
    // Request access
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Fast forward time beyond expiry
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, 2 * HOUR_IN_MS);
        test_scenario::return_shared(clock);
    };
    
    // Verify access is now invalid
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let pass = test_scenario::take_from_sender<CommunityAccessPass>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let is_valid = community_access::verify_access(&pass, &registry, &clock);
        assert!(is_valid == false, 20);
        
        test_scenario::return_to_sender(&scenario, pass);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_member_activity() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Get NFT and join community
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    // Mint PoA NFT
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Request access
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Get initial last_active time
    let initial_last_active = {
        test_scenario::next_tx(&mut scenario, @0x0);
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let (_joined_at, _expires_at, _contribution_score, last_active) = 
            community_access::get_member_info(community_id, USER1, &registry);
        test_scenario::return_shared(registry);
        last_active
    };
    
    // Fast forward time
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, HOUR_IN_MS);
        test_scenario::return_shared(clock);
    };
    
    // Update member activity
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        community_access::update_member_activity(
            community_id,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify last_active was updated
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let (_joined_at, _expires_at, _contribution_score, last_active) = 
            community_access::get_member_info(community_id, USER1, &registry);
        
        assert!(last_active > initial_last_active, 21);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_update_contribution_score() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Get NFT and join community
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    // Mint PoA NFT
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Request access
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Update contribution score (this would be called by other modules in practice)
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        community_access::update_contribution_score(
            community_id,
            USER1,
            100,
            &mut registry
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify contribution score was updated
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let (_joined_at, _expires_at, contribution_score, _last_active) = 
            community_access::get_member_info(community_id, USER1, &registry);
        
        assert!(contribution_score == 100, 22);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_remove_member() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Get NFT and join community
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    // Mint PoA NFT
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Request access
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify member is in community
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        assert!(community_access::is_member(community_id, USER1, &registry), 23);
        test_scenario::return_shared(registry);
    };
    
    // Remove member
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        community_access::remove_member(
            community_id,
            USER1,
            string::utf8(b"Violation of community guidelines"),
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Verify member was removed
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        assert!(!community_access::is_member(community_id, USER1, &registry), 24);
        
        let (_name, _description, member_count, _active, _access_type) = 
            community_access::get_community_details(community_id, &registry);
        assert!(member_count == 0, 25);
        
        let memberships = community_access::get_user_memberships(USER1, &registry);
        assert!(vector::length(&memberships) == 1, 26); // Still exists but marked inactive
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotOrganizer)]
fun test_remove_member_not_organizer() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Get NFT and join community
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    // Mint PoA NFT
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Request access
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Try to remove member as non-organizer (should fail)
    test_scenario::next_tx(&mut scenario, USER2);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        community_access::remove_member(
            community_id,
            USER1,
            string::utf8(b"Unauthorized removal"),
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_access_both_types() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Get only PoA NFT for USER1
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    // Mint PoA NFT for USER1
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    // Get completion NFT for USER2
    register_user_for_event(&mut scenario, event_id, USER2);
    check_in_user(&mut scenario, event_id, USER2);
    check_out_user_and_mint_nfts(&mut scenario, event_id, USER2);
    
    // Create community requiring BOTH types (either PoA or Completion)
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_BOTH,
        false,
        ACCESS_DURATION
    );
    
    // USER1 should be able to access with PoA NFT
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // USER2 should be able to access with completion NFT
    test_scenario::next_tx(&mut scenario, USER2);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER2);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify both users are members
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        assert!(community_access::is_member(community_id, USER1, &registry), 27);
        assert!(community_access::is_member(community_id, USER2, &registry), 28);
        
        let (_name, _description, member_count, _active, _access_type) = 
            community_access::get_community_details(community_id, &registry);
        assert!(member_count == 2, 29);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_community_features() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Test community features
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        let features = community_access::get_community_features(community_id, &registry);
        
        assert!(community_access::get_forum_enabled(&features) == true, 30);
        assert!(community_access::get_resource_sharing_enabled(&features) == true, 31);
        assert!(community_access::get_event_calendar_enabled(&features) == true, 32);
        assert!(community_access::get_member_directory_enabled(&features) == true, 33);
        assert!(community_access::get_governance_enabled(&features) == false, 34);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_access_configuration() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_COMPLETION,
        true, // require_nft_held
        ACCESS_DURATION
    );
    
    // Test access configuration
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        let (access_type, require_nft_held, min_event_rating, expiry_duration) = 
            community_access::get_access_configuration(community_id, &registry);
        
        assert!(access_type == ACCESS_TYPE_COMPLETION, 35);
        assert!(require_nft_held == true, 36);
        assert!(min_event_rating == 0, 37);
        assert!(expiry_duration == ACCESS_DURATION, 38);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_permanent_access() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Get NFT and join community with permanent access
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    // Mint PoA NFT
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    // Create community with permanent access (0 expiry)
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        0 // permanent access
    );
    
    // Request access
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Fast forward time significantly
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, 365 * DAY_IN_MS); // 1 year
        test_scenario::return_shared(clock);
    };
    
    // Verify access is still valid (permanent)
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let pass = test_scenario::take_from_sender<CommunityAccessPass>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let is_valid = community_access::verify_access(&pass, &registry, &clock);
        assert!(is_valid == true, 39);
        
        // Check that expires_at is 0 (permanent)
        let (_joined_at, expires_at, _contribution_score, _last_active) = 
            community_access::get_member_info(community_id, USER1, &registry);
        assert!(expires_at == 0, 40);
        
        test_scenario::return_to_sender(&scenario, pass);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_multiple_communities_same_user_fixed() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Create two different events
    let event_id1 = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    let event_id2 = create_and_activate_test_event(&mut scenario, ORGANIZER, 2 * HOUR_IN_MS, 50);
    
    // === IMPORTANT: Add time gap between events ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, HOUR_IN_MS); // Move time forward
        test_scenario::return_shared(clock);
    };
    
    // === First Event Flow ===
    register_user_for_event(&mut scenario, event_id1, USER1);
    check_in_user(&mut scenario, event_id1, USER1);
    
    // Mint PoA NFT for first event
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id1,
            string::utf8(b"Test Event 1"),
            string::utf8(b"https://walrus.example/test1.png"),
            string::utf8(b"Test Location 1"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    // === Time gap before second event ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        clock::increment_for_testing(&mut clock, HOUR_IN_MS); // Move time forward again
        test_scenario::return_shared(clock);
    };
    
    // === Second Event Flow ===
    register_user_for_event(&mut scenario, event_id2, USER1);
    check_in_user(&mut scenario, event_id2, USER1);
    check_out_user_and_mint_nfts(&mut scenario, event_id2, USER1);
    
    // === Create Communities ===
    let community_id1 = create_test_community(
        &mut scenario,
        event_id1,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    let community_id2 = create_test_community(
        &mut scenario,
        event_id2,
        ORGANIZER,
        ACCESS_TYPE_COMPLETION,
        false,
        ACCESS_DURATION
    );
    
    // Join both communities
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass1 = community_access::request_access(
            community_id1,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass1, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass2 = community_access::request_access(
            community_id2,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass2, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify user is member of both communities
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        assert!(community_access::is_member(community_id1, USER1, &registry), 41);
        assert!(community_access::is_member(community_id2, USER1, &registry), 42);
        
        let memberships = community_access::get_user_memberships(USER1, &registry);
        assert!(vector::length(&memberships) == 2, 43);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Error Condition Tests ==========

#[test]
#[expected_failure(abort_code = ECommunityNotFound)]
fun test_access_nonexistent_community() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let fake_community_id = object::id_from_address(@0xDEADBEEF);
    
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            fake_community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EAccessDenied)]
fun test_update_activity_non_member() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Try to update activity as non-member
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        community_access::update_member_activity(
            community_id,
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
#[expected_failure(abort_code = EAccessDenied)]
fun test_update_contribution_score_non_member() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Try to update contribution score for non-member
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        community_access::update_contribution_score(
            community_id,
            USER1,
            100,
            &mut registry
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EAccessDenied)]
fun test_remove_nonexistent_member() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Try to remove non-member
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        community_access::remove_member(
            community_id,
            USER1,
            string::utf8(b"Not a member"),
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ECommunityNotFound)]
fun test_get_member_info_nonexistent_community() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    let fake_community_id = object::id_from_address(@0xDEADBEEF);
    
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        let (_joined_at, _expires_at, _contribution_score, _last_active) = 
            community_access::get_member_info(fake_community_id, USER1, &registry);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = EAccessDenied)]
fun test_get_member_info_non_member() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        let (_joined_at, _expires_at, _contribution_score, _last_active) = 
            community_access::get_member_info(community_id, USER1, &registry);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Integration Tests ==========

#[test]
fun test_full_community_lifecycle() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    
    // === Phase 1: Setup Event ===
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // === Phase 2: Users Attend Event ===
    // USER1 gets PoA only
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    // USER2 completes event
    register_user_for_event(&mut scenario, event_id, USER2);
    check_in_user(&mut scenario, event_id, USER2);
    check_out_user_and_mint_nfts(&mut scenario, event_id, USER2);
    
    // === Phase 3: Create Community ===
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_BOTH, // Either PoA or Completion
        false,
        ACCESS_DURATION
    );
    
    // === Phase 4: Users Join Community ===
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::next_tx(&mut scenario, USER2);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER2);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // === Phase 5: Community Activity ===
    // Add custom requirement
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        community_access::add_custom_requirement(
            community_id,
            string::utf8(b"participation_score"),
            10,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    // Update member activities and scores
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        community_access::update_member_activity(
            community_id,
            &mut registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        community_access::update_contribution_score(
            community_id,
            USER1,
            50,
            &mut registry
        );
        
        community_access::update_contribution_score(
            community_id,
            USER2,
            75,
            &mut registry
        );
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 6: Verify Final State ===
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        // Check community details
        let (_name, _description, member_count, active, access_type) = 
            community_access::get_community_details(community_id, &registry);
        assert!(member_count == 2, 44);
        assert!(active == true, 45);
        assert!(access_type == ACCESS_TYPE_BOTH, 46);
        
        // Check member info
        let (_joined_at1, _expires_at1, contribution_score1, _last_active1) = 
            community_access::get_member_info(community_id, USER1, &registry);
        assert!(contribution_score1 == 50, 47);
        
        let (_joined_at2, _expires_at2, contribution_score2, _last_active2) = 
            community_access::get_member_info(community_id, USER2, &registry);
        assert!(contribution_score2 == 75, 48);
        
        // Check memberships
        let memberships1 = community_access::get_user_memberships(USER1, &registry);
        let memberships2 = community_access::get_user_memberships(USER2, &registry);
        assert!(vector::length(&memberships1) == 1, 49);
        assert!(vector::length(&memberships2) == 1, 50);
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 7: Access Verification ===
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let pass = test_scenario::take_from_sender<CommunityAccessPass>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        assert!(community_access::verify_access(&pass, &registry, &clock), 51);
        
        test_scenario::return_to_sender(&scenario, pass);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::next_tx(&mut scenario, USER2);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let pass = test_scenario::take_from_sender<CommunityAccessPass>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        assert!(community_access::verify_access(&pass, &registry, &clock), 52);
        
        test_scenario::return_to_sender(&scenario, pass);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

// ========== Helper Function Tests ==========

#[test]
fun test_helper_functions() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        // Test is_member with non-member
        assert!(!community_access::is_member(community_id, USER1, &registry), 53);
        
        // Test get_user_memberships for user with no memberships
        let memberships = community_access::get_user_memberships(USER1, &registry);
        assert!(vector::length(&memberships) == 0, 54);
        
        // Test community organizer
        let organizer = community_access::get_community_organizer(community_id, &registry);
        assert!(organizer == ORGANIZER, 55);
        
        // Test community event ID
        let stored_event_id = community_access::get_community_event_id(community_id, &registry);
        assert!(stored_event_id == event_id, 56);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test_only]
fun register_user_for_event(
    scenario: &mut Scenario,
    event_id: ID,
    user: address
) {
    test_scenario::next_tx(scenario, user);
    {
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(scenario);
        let mut event = test_scenario::take_shared_by_id<Event>(scenario, event_id);
        let clock = test_scenario::take_shared<Clock>(scenario);

        identity_access::register_for_event(
            &mut event,
            &mut registry,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(event);
        test_scenario::return_shared(clock);
    };
}

#[test_only]
fun check_in_user(
    scenario: &mut Scenario,
    event_id: ID,
    user: address
) {
 // First verify registration exists
    test_scenario::next_tx(scenario, @0x0);
    {
        let registry = test_scenario::take_shared<RegistrationRegistry>(scenario);
        let is_registered = identity_access::is_registered(user, event_id, &registry);
        test_scenario::return_shared(registry);
        
        // If not registered, fail with clear error
        if (!is_registered) {
            // This will help us debug - which event/user combination failed
            if (user == USER1) {
                assert!(false, 1001); // USER1 not registered
            } else if (user == USER2) {
                assert!(false, 1002); // USER2 not registered  
            } else {
                assert!(false, 1000); // Other user not registered
            };
        };
    };
    
    // Now do the check-in
    test_scenario::next_tx(scenario, user);
    {
        let mut identity_registry = test_scenario::take_shared<RegistrationRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        // Mark as checked in
        identity_access::mark_checked_in(user, event_id, &mut identity_registry);
        
        // Create mock PoA capability
        let capability = attendance_verification::create_mock_poa_capability_for_testing(
            event_id,
            user,
            clock::timestamp_ms(&clock),
            test_scenario::ctx(scenario)
        );
        
        transfer::public_transfer(capability, user);
        
        test_scenario::return_shared(identity_registry);
        test_scenario::return_shared(clock);
    };
}

#[test_only]
fun check_out_user_and_mint_nfts(
    scenario: &mut Scenario,
    event_id: ID,
    user: address
) {
    test_scenario::next_tx(scenario, user);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        let current_time = clock::timestamp_ms(&clock);
        let check_in_time = if (current_time >= 3600000) {
            current_time - 3600000 // 1 hour ago if possible
        } else {
            current_time / 2 // Use half the current time to ensure it's earlier
        };
        let check_out_time = current_time;
        let attendance_duration = check_out_time - check_in_time;
        
        // Set event metadata for NFTs
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(scenario)
        );
        
        // Create mock completion capability
        let completion_capability = attendance_verification::create_mock_completion_capability_for_testing(
            event_id,
            user,
            check_in_time,
            check_out_time,
            attendance_duration,
            test_scenario::ctx(scenario)
        );
        
        // Mint completion NFT
        nft_minting::mint_nft_of_completion(
            completion_capability,
            &mut nft_registry,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
}

#[test_only]
fun create_test_community(
    scenario: &mut Scenario,
    event_id: ID,
    organizer: address,
    access_type: u8,
    require_nft_held: bool,
    expiry_duration: u64
): ID {
    test_scenario::next_tx(scenario, organizer);
    {
        let event = test_scenario::take_shared_by_id<Event>(scenario, event_id);
        let mut registry = test_scenario::take_shared<CommunityRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        let community_id = community_access::create_community(
            &event,
            string::utf8(b"Test Community"),
            string::utf8(b"A community for test event attendees"),
            access_type,
            require_nft_held,
            0, // min_event_rating
            expiry_duration,
            string::utf8(b"https://community.example.com/metadata"),
            true, // forum_enabled
            true, // resource_sharing
            true, // event_calendar
            true, // member_directory
            false, // governance_enabled
            &mut registry,
            &clock,
            test_scenario::ctx(scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
        community_id
    }
}

// ========== Core Functionality Tests ==========

#[test]
fun test_init_module() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    // Test module initialization
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        community_access::init_for_testing(test_scenario::ctx(&mut scenario));
    };
    
    // Verify CommunityRegistry was created and is accessible
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        // Test query for non-existent community
        let fake_community_id = object::id_from_address(@0xDEADBEEF);
        assert!(!community_access::is_member(fake_community_id, USER1, &registry), 1);
        
        let memberships = community_access::get_user_memberships(USER1, &registry);
        assert!(vector::length(&memberships) == 0, 2);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_create_community_success() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Verify community was created successfully
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        let (name, description, member_count, active, access_type) = 
            community_access::get_community_details(community_id, &registry);
        
        assert!(name == string::utf8(b"Test Community"), 3);
        assert!(description == string::utf8(b"A community for test event attendees"), 4);
        assert!(member_count == 0, 5);
        assert!(active == true, 6);
        assert!(access_type == ACCESS_TYPE_POA, 7);
        
        let organizer = community_access::get_community_organizer(community_id, &registry);
        assert!(organizer == ORGANIZER, 8);
        
        let stored_event_id = community_access::get_community_event_id(community_id, &registry);
        assert!(stored_event_id == event_id, 9);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotOrganizer)]
fun test_create_community_not_organizer() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let _event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Try to create community as non-organizer (should fail)
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        community_access::create_community(
            &event,
            string::utf8(b"Unauthorized Community"),
            string::utf8(b"This should fail"),
            ACCESS_TYPE_POA,
            false,
            0,
            ACCESS_DURATION,
            string::utf8(b"https://community.example.com/metadata"),
            true, true, true, true, false,
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
#[expected_failure(abort_code = EAlreadyExists)]
fun test_create_duplicate_community() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create first community
    create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Try to create second community for same event (should fail)
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared<Event>(&scenario);
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        community_access::create_community(
            &event,
            string::utf8(b"Duplicate Community"),
            string::utf8(b"This should fail"),
            ACCESS_TYPE_COMPLETION,
            false,
            0,
            ACCESS_DURATION,
            string::utf8(b"https://community.example.com/metadata2"),
            true, true, true, true, false,
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
fun test_add_custom_requirement() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Add custom requirement
    test_scenario::next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        community_access::add_custom_requirement(
            community_id,
            string::utf8(b"min_events_attended"),
            5,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotOrganizer)]
fun test_add_custom_requirement_not_organizer() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Try to add custom requirement as non-organizer (should fail)
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        community_access::add_custom_requirement(
            community_id,
            string::utf8(b"unauthorized_requirement"),
            10,
            &mut registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_request_access_with_poa_nft() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register and check in user to get PoA NFT
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    
    // Mint PoA NFT
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let capability = test_scenario::take_from_sender<attendance_verification::MintPoACapability>(&scenario);
        
        // Set event metadata first
        nft_minting::set_event_metadata(
            event_id,
            string::utf8(b"Test Event"),
            string::utf8(b"https://walrus.example/test.png"),
            string::utf8(b"Test Location"),
            ORGANIZER,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        nft_minting::mint_proof_of_attendance(
            capability,
            &mut nft_registry,
            test_scenario::ctx(&mut scenario)
        );
        
        test_scenario::return_shared(nft_registry);
    };
    
    // Create community requiring PoA NFT
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Request access to community
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify membership
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        assert!(community_access::is_member(community_id, USER1, &registry), 10);
        
        let (_name, _description, member_count, _active, _access_type) = 
            community_access::get_community_details(community_id, &registry);
        assert!(member_count == 1, 11);
        
        let (joined_at, expires_at, contribution_score, last_active) = 
            community_access::get_member_info(community_id, USER1, &registry);
        assert!(joined_at > 0, 12);
        assert!(expires_at > joined_at, 13);
        assert!(contribution_score == 0, 14);
        assert!(last_active == joined_at, 15);
        
        let memberships = community_access::get_user_memberships(USER1, &registry);
        assert!(vector::length(&memberships) == 1, 16);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_request_access_with_completion_nft() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100); // Declare event_id here
    
    // Complete full event flow to get completion NFT
    register_user_for_event(&mut scenario, event_id, USER1);
    check_in_user(&mut scenario, event_id, USER1);
    check_out_user_and_mint_nfts(&mut scenario, event_id, USER1);
    
    // Create community requiring completion NFT
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_COMPLETION,
        false,
        ACCESS_DURATION
    );
    
    // Request access to community
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    // Verify membership
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        
        assert!(community_access::is_member(community_id, USER1, &registry), 17);
        
        let (_name, _description, member_count, _active, _access_type) = 
            community_access::get_community_details(community_id, &registry);
        assert!(member_count == 1, 18);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = ENotEligible)]
fun test_request_access_without_nft() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create community requiring PoA NFT
    let community_id = create_test_community(
        &mut scenario,
        event_id,
        ORGANIZER,
        ACCESS_TYPE_POA,
        false,
        ACCESS_DURATION
    );
    
    // Try to request access without any NFT (should fail)
    test_scenario::next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<CommunityRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        let pass = community_access::request_access(
            community_id,
            &mut registry,
            &nft_registry,
            &clock,
            test_scenario::ctx(&mut scenario)
        );
        
        transfer::public_transfer(pass, USER1);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}
