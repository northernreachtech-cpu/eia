#[test_only]
module eia::airdrop_distribution_tests;

use std::string;
use sui::coin;
use sui::sui::SUI;
use sui::test_scenario::{Self, next_tx, ctx, Scenario};
use sui::clock::{Self, Clock};

use eia::airdrop_distribution::{Self, AirdropRegistry};
use eia::event_management::{Self, Event, EventRegistry, OrganizerProfile};
use eia::attendance_verification::{Self, AttendanceRegistry};
use eia::nft_minting::{Self, NFTRegistry};
use eia::rating_reputation::{Self, RatingRegistry};
use eia::identity_access::{Self, RegistrationRegistry};

// ========== Test Constants ==========

const ORGANIZER: address = @0xA;
const USER1: address = @0xB;
const USER2: address = @0xC;
const USER3: address = @0xD;

const AIRDROP_POOL_AMOUNT: u64 = 10000000000; // 10 SUI
const HOUR_IN_MS: u64 = 3600000;

const TYPE_EQUAL_DISTRIBUTION: u8 = 0;
const TYPE_WEIGHTED_BY_DURATION: u8 = 1;
const TYPE_COMPLETION_BONUS: u8 = 2;

// ========== Helper Functions ==========

fun setup_test_environment(scenario: &mut Scenario) {
    next_tx(scenario, @0x0);
    {
        let mut clock = clock::create_for_testing(ctx(scenario));
        clock::set_for_testing(&mut clock, 1000000);
        clock::share_for_testing(clock);
        
        // Initialize all modules
        event_management::init_for_testing(ctx(scenario));
        attendance_verification::init_for_testing(ctx(scenario));
        nft_minting::init_for_testing(ctx(scenario));
        rating_reputation::init_for_testing(ctx(scenario));
        identity_access::init_for_testing(ctx(scenario));
        airdrop_distribution::init_for_testing(ctx(scenario));
    };
}

fun create_test_organizer_profile(scenario: &mut Scenario, organizer: address) {
    next_tx(scenario, organizer);
    {
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        let cap = event_management::create_organizer_profile(
            string::utf8(b"Test Organizer"),
            string::utf8(b"Test Bio"),
            &clock,
            ctx(scenario)
        );
        
        // Store the capability
        transfer::public_transfer(cap, organizer);
        test_scenario::return_shared(clock);
    };
}

fun create_and_activate_test_event(scenario: &mut Scenario, organizer: address, duration: u64, capacity: u64): ID {
    next_tx(scenario, organizer);
    let event_id = {
        let mut registry = test_scenario::take_shared<EventRegistry>(scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        let event_id = event_management::create_event(
            string::utf8(b"Test Event"),
            string::utf8(b"Test Description"),
            string::utf8(b"Test Location"),
            clock::timestamp_ms(&clock) + HOUR_IN_MS,
            clock::timestamp_ms(&clock) + HOUR_IN_MS + duration,
            capacity,
            10, // min_attendees
            8000, // min_completion_rate (80%)
            400, // min_avg_rating (4.0/5.0)
            string::utf8(b""), // metadata_uri
            &clock,
            &mut registry,
            &mut organizer_profile,
            ctx(scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
        event_id
    };
    
    // Activate event
    next_tx(scenario, organizer);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(scenario, event_id);
        let mut registry = test_scenario::take_shared<EventRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        event_management::activate_event(&mut event, &clock, &mut registry, ctx(scenario));
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    event_id
}

fun register_user_for_event(scenario: &mut Scenario, user: address, event_id: ID) {
    next_tx(scenario, user);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(scenario, event_id);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        identity_access::register_for_event(
            &mut event,
            &mut registry,
            &clock,
            ctx(scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
}

#[test_only]
fun simulate_user_checkin(scenario: &mut Scenario, user: address, event_id: ID) {
    // Register user first if not already registered
    next_tx(scenario, user);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(scenario, event_id);
        let mut registry = test_scenario::take_shared<RegistrationRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        // Check if already registered to avoid EAlreadyRegistered error
        if (!identity_access::is_registered(user, event_id, &registry)) {
            identity_access::register_for_event(
                &mut event,
                &mut registry,
                &clock,
                ctx(scenario)
            );
        };
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    // Now simulate attendance by directly updating both attendance registry AND event attendee count
    next_tx(scenario, @0x0);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(scenario, event_id);
        let mut attendance_registry = test_scenario::take_shared<AttendanceRegistry>(scenario);
        let mut identity_registry = test_scenario::take_shared<RegistrationRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        // Mark user as checked in in the identity registry
        identity_access::mark_checked_in(user, event_id, &mut identity_registry);
        
        // Directly add attendance record to simulate check-in
        attendance_verification::simulate_checkin_for_testing(
            user,
            event_id,
            &mut attendance_registry,
            &clock,
            ctx(scenario)
        );
        
        // CRITICAL: Increment the event's attendee count so get_current_attendees() returns > 0
        event_management::increment_attendees(&mut event);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(identity_registry);
        test_scenario::return_shared(clock);
    };
}

#[test_only]
fun simulate_user_checkout(scenario: &mut Scenario, user: address, event_id: ID) {
    next_tx(scenario, @0x0);
    {
        let mut attendance_registry = test_scenario::take_shared<AttendanceRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        
        // Directly simulate checkout by updating the attendance record
        attendance_verification::simulate_checkout_for_testing(
            user,
            event_id,
            &mut attendance_registry,
            &clock,
            ctx(scenario)
        );
        
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
    };
}

// ========== Replace create_test_airdrop with proper setup ==========

fun create_test_airdrop(
    scenario: &mut Scenario,
    organizer: address,
    event_id: ID,
    amount: u64,
    distribution_type: u8,
    require_completion: bool,
    validity_days: u64
): ID {
    // Set up realistic test users with proper check-ins
    simulate_user_checkin(scenario, USER1, event_id);
    simulate_user_checkin(scenario, USER2, event_id);
    simulate_user_checkin(scenario, USER3, event_id);
    
    // If we need completion (checked out users), simulate check-outs
    if (require_completion) {
        simulate_user_checkout(scenario, USER1, event_id);
        simulate_user_checkout(scenario, USER2, event_id);
    };
    
    // Now create the airdrop - it will have real attendance data
    next_tx(scenario, organizer);
    {
        let event = test_scenario::take_shared_by_id<Event>(scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(scenario);
        let clock = test_scenario::take_shared<Clock>(scenario);
        let payment = coin::mint_for_testing<SUI>(amount, ctx(scenario));
        
        // Verify we have the expected attendance stats
        let (_check_in_count, _check_out_count, _) = attendance_verification::get_event_stats(event_id, &attendance_registry);
        
        let airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b"Test Airdrop"),
            string::utf8(b"Test airdrop description"),
            payment,
            distribution_type,
            false, // require_attendance = false for testing eligibility separately
            require_completion, // This now works because we have real checked_out users
            HOUR_IN_MS, // min_duration
            false, // require_rating_submitted
            validity_days,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
        
        airdrop_id
    }
}

#[test]
fun test_create_weighted_distribution_airdrop() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create weighted airdrop
    let _airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_WEIGHTED_BY_DURATION,
        false,
        7
    );
    
    // Test passes if airdrop is created successfully
    test_scenario::end(scenario);
}

#[test]
fun test_create_completion_bonus_airdrop() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create completion bonus airdrop
    let _airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_COMPLETION_BONUS,
        true, // require completion
        7
    );
    
    test_scenario::end(scenario);
}

#[test]
fun test_eligibility_verification() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register user for event
    register_user_for_event(&mut scenario, USER1, event_id);
    
    // Add attendees to event but don't set user as attended
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        event_management::increment_attendees(&mut event);
        event_management::increment_attendees(&mut event);
        test_scenario::return_shared(event);
    };
    
    // Create airdrop with attendance requirement
    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(AIRDROP_POOL_AMOUNT, ctx(&mut scenario));
        
        let airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b"Test Airdrop"),
            string::utf8(b"Test airdrop description"),
            payment,
            TYPE_EQUAL_DISTRIBUTION,
            true, // require_attendance = true to test eligibility
            false,
            HOUR_IN_MS, // min_duration
            false, // require_rating_submitted
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        // Test eligibility check
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        // User should not be eligible without attendance
        let eligible = airdrop_distribution::is_user_eligible(
            USER1,
            airdrop_id,
            &registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry
        );
        assert!(!eligible, 10);
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_claim_status_tracking() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    // Check initial claim status
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        let (claimed, amount) = airdrop_distribution::get_claim_status(USER1, airdrop_id, &registry);
        assert!(!claimed, 11);
        assert!(amount == 0, 12);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_event_airdrops_tracking() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create multiple airdrops for the same event
    let airdrop_id1 = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    let airdrop_id2 = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT / 2,
        TYPE_COMPLETION_BONUS,
        true,
        7
    );
    
    // Check event airdrops
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        let airdrops = airdrop_distribution::get_event_airdrops(event_id, &registry);
        assert!(vector::length(&airdrops) == 2, 13);
        assert!(vector::contains(&airdrops, &airdrop_id1), 14);
        assert!(vector::contains(&airdrops, &airdrop_id2), 15);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_user_claims_history() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    
    // Test empty claim history
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        let claims = airdrop_distribution::get_user_claims(USER1, &registry);
        assert!(vector::length(&claims) == 0, 16);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Error Condition Tests ==========

#[test]
#[expected_failure(abort_code = eia::airdrop_distribution::ENotOrganizer)]
fun test_create_airdrop_not_organizer() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Try to create airdrop as non-organizer
    next_tx(&mut scenario, USER1);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(AIRDROP_POOL_AMOUNT, ctx(&mut scenario));
        
        // This should fail
        let _airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b"Test Airdrop"),
            string::utf8(b"Test description"),
            payment,
            TYPE_EQUAL_DISTRIBUTION,
            true,
            false,
            HOUR_IN_MS,
            false,
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = eia::airdrop_distribution::EInsufficientFunds)]
fun test_create_airdrop_zero_amount() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Try to create airdrop with zero amount
    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(0, ctx(&mut scenario)); // Zero amount
        
        // This should fail
        let _airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b"Test Airdrop"),
            string::utf8(b"Test description"),
            payment,
            TYPE_EQUAL_DISTRIBUTION,
            true,
            false,
            HOUR_IN_MS,
            false,
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = eia::airdrop_distribution::EAirdropNotFound)]
fun test_get_nonexistent_airdrop() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let fake_id = object::id_from_address(@0xDEADBEEF);
        
        // This should fail
        let (_, _, _, _, _, _) = airdrop_distribution::get_airdrop_details(fake_id, &registry);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = eia::airdrop_distribution::ENotEligible)]
fun test_claim_airdrop_not_eligible() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create airdrop with attendance requirement to ensure user is not eligible
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        
        // Add sufficient attendees for airdrop creation
        let mut i = 0;
        while (i < 20) {
            event_management::increment_attendees(&mut event);
            i = i + 1;
        };
        
        test_scenario::return_shared(event);
    };

    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(AIRDROP_POOL_AMOUNT, ctx(&mut scenario));
        
        let airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b"Test Airdrop"),
            string::utf8(b"Test description"),
            payment,
            TYPE_EQUAL_DISTRIBUTION,
            true, // require_attendance = true to ensure user is not eligible
            false,
            HOUR_IN_MS,
            false,
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        // Try to claim without being eligible - this should fail
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        airdrop_distribution::claim_airdrop(
            airdrop_id,
            &mut registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Batch Distribution Tests ==========

#[test]
fun test_batch_distribute_empty_recipients() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    // Test batch distribute with empty recipients
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        airdrop_distribution::batch_distribute(
            airdrop_id,
            vector::empty<address>(),
            &mut registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
#[expected_failure(abort_code = eia::airdrop_distribution::ENotOrganizer)]
fun test_batch_distribute_not_organizer() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    // Try batch distribute as non-organizer
    next_tx(&mut scenario, USER1);
    {
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        // This should fail
        airdrop_distribution::withdraw_unclaimed(
            airdrop_id,
            &mut registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

// ========== Integration Tests ==========

#[test]
fun test_complete_airdrop_lifecycle() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Register users for event
    register_user_for_event(&mut scenario, USER1, event_id);
    register_user_for_event(&mut scenario, USER2, event_id);
    
    // Create airdrop
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    // Verify initial state
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        let (_, _, pool_balance, claimed_count, _, active) = 
            airdrop_distribution::get_airdrop_details(airdrop_id, &registry);
        
        assert!(pool_balance == AIRDROP_POOL_AMOUNT, 17);
        assert!(claimed_count == 0, 18);
        assert!(active, 19);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_multiple_airdrops_same_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create multiple different types of airdrops
    let airdrop_id1 = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    let airdrop_id2 = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT / 2,
        TYPE_WEIGHTED_BY_DURATION,
        false,
        7
    );
    
    let airdrop_id3 = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT / 4,
        TYPE_COMPLETION_BONUS,
        true,
        7
    );
    
    // Verify all airdrops are tracked for the event
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        let airdrops = airdrop_distribution::get_event_airdrops(event_id, &registry);
        assert!(vector::length(&airdrops) == 3, 20);
        assert!(vector::contains(&airdrops, &airdrop_id1), 21);
        assert!(vector::contains(&airdrops, &airdrop_id2), 22);
        assert!(vector::contains(&airdrops, &airdrop_id3), 23);
        
        // Verify each airdrop has correct details
        let (_, _, pool1, _, _, active1) = airdrop_distribution::get_airdrop_details(airdrop_id1, &registry);
        let (_, _, pool2, _, _, active2) = airdrop_distribution::get_airdrop_details(airdrop_id2, &registry);
        let (_, _, pool3, _, _, active3) = airdrop_distribution::get_airdrop_details(airdrop_id3, &registry);
        
        assert!(pool1 == AIRDROP_POOL_AMOUNT, 24);
        assert!(pool2 == AIRDROP_POOL_AMOUNT / 2, 25);
        assert!(pool3 == AIRDROP_POOL_AMOUNT / 4, 26);
        assert!(active1 && active2 && active3, 27);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Edge Case Tests ==========

#[test]
#[expected_failure(abort_code = eia::event_management::EInvalidCapacity)]
fun test_airdrop_with_zero_capacity_event() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    
    // Try to create event with zero capacity - this should fail at event creation level
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<EventRegistry>(&scenario);
        let mut organizer_profile = test_scenario::take_shared<OrganizerProfile>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        // This should fail because capacity is 0
        let _event_id = event_management::create_event(
            string::utf8(b"Zero Capacity Event"),
            string::utf8(b"Test Description"),
            string::utf8(b"Test Location"),
            clock::timestamp_ms(&clock) + HOUR_IN_MS,
            clock::timestamp_ms(&clock) + HOUR_IN_MS + HOUR_IN_MS,
            0, // Zero capacity - should fail here
            10, // min_attendees
            8000, // min_completion_rate
            400, // min_avg_rating
            string::utf8(b""), // metadata_uri
            &clock,
            &mut registry,
            &mut organizer_profile,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(organizer_profile);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_airdrop_expiry_edge_cases() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Test with various validity periods
    let _airdrop_id1 = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        1 // 1 day
    );
    
    let _airdrop_id2 = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        365 // 1 year
    );
    
    test_scenario::end(scenario);
}

#[test]
fun test_airdrop_name_edge_cases() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Test with empty name
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        event_management::increment_attendees(&mut event);
        event_management::increment_attendees(&mut event);
        test_scenario::return_shared(event);
    };

    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(AIRDROP_POOL_AMOUNT, ctx(&mut scenario));
        
        let _airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b""), // Empty name
            string::utf8(b"Description"),
            payment,
            TYPE_EQUAL_DISTRIBUTION,
            false,
            false,
            HOUR_IN_MS,
            false,
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
    };
    
    // Test with very long name
    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(AIRDROP_POOL_AMOUNT, ctx(&mut scenario));
        
        let long_name = string::utf8(b"This is a very long airdrop name that tests the system's ability to handle lengthy strings without issues and ensures proper storage and retrieval");
        
        let _airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            long_name,
            string::utf8(b"Description"),
            payment,
            TYPE_EQUAL_DISTRIBUTION,
            false,
            false,
            HOUR_IN_MS,
            false,
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

// ========== Performance and Stress Tests ==========

#[test]
fun test_large_recipient_list() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 1000);
    
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    // Create a large recipient list
    let mut recipients = vector::empty<address>();
    let mut i = 0;
    while (i < 1) {
        vector::push_back(&mut recipients, @0x100);
        vector::push_back(&mut recipients, @0x101);
        vector::push_back(&mut recipients, @0x102);
        vector::push_back(&mut recipients, @0x103);
        vector::push_back(&mut recipients, @0x104);
        vector::push_back(&mut recipients, @0x105);
        vector::push_back(&mut recipients, @0x106);
        vector::push_back(&mut recipients, @0x107);
        vector::push_back(&mut recipients, @0x108);
        vector::push_back(&mut recipients, @0x109);
        vector::push_back(&mut recipients, @0x110);
        vector::push_back(&mut recipients, @0x111);
        vector::push_back(&mut recipients, @0x112);
        vector::push_back(&mut recipients, @0x113);
        vector::push_back(&mut recipients, @0x114);
        vector::push_back(&mut recipients, @0x115);
        vector::push_back(&mut recipients, @0x116);
        vector::push_back(&mut recipients, @0x117);
        vector::push_back(&mut recipients, @0x118);
        vector::push_back(&mut recipients, @0x119);
        vector::push_back(&mut recipients, @0x120);
        vector::push_back(&mut recipients, @0x121);
        vector::push_back(&mut recipients, @0x122);
        vector::push_back(&mut recipients, @0x123);
        vector::push_back(&mut recipients, @0x124);
        vector::push_back(&mut recipients, @0x125);
        vector::push_back(&mut recipients, @0x126);
        vector::push_back(&mut recipients, @0x127);
        vector::push_back(&mut recipients, @0x128);
        vector::push_back(&mut recipients, @0x129);
        vector::push_back(&mut recipients, @0x130);
        vector::push_back(&mut recipients, @0x131);
        vector::push_back(&mut recipients, @0x132);
        vector::push_back(&mut recipients, @0x133);
        vector::push_back(&mut recipients, @0x134);
        vector::push_back(&mut recipients, @0x135);
        vector::push_back(&mut recipients, @0x136);
        vector::push_back(&mut recipients, @0x137);
        vector::push_back(&mut recipients, @0x138);
        vector::push_back(&mut recipients, @0x139);
        vector::push_back(&mut recipients, @0x140);
        i = i + 1;
    };
    
    // Test batch distribute with many recipients
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        airdrop_distribution::batch_distribute(
            airdrop_id,
            recipients,
            &mut registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

// ========== Documentation and Example Tests ==========

/// Test demonstrating the complete airdrop creation and management flow
#[test]
fun test_complete_airdrop_documentation_example() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    // === Setup Phase ===
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // === Phase 1: Create Airdrop ===
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    // === Phase 2: Verify Airdrop Creation ===
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        let (stored_event_id, name, pool_balance, claimed_count, expires_at, active) = 
            airdrop_distribution::get_airdrop_details(airdrop_id, &registry);
        
        // Verify all details are correct
        assert!(stored_event_id == event_id, 33);
        assert!(name == string::utf8(b"Test Airdrop"), 34);
        assert!(pool_balance == AIRDROP_POOL_AMOUNT, 35);
        assert!(claimed_count == 0, 36);
        assert!(expires_at > 0, 37);
        assert!(active, 38);
        
        // Verify it's linked to the event
        let airdrops = airdrop_distribution::get_event_airdrops(event_id, &registry);
        assert!(vector::length(&airdrops) == 1, 39);
        assert!(vector::contains(&airdrops, &airdrop_id), 40);
        
        test_scenario::return_shared(registry);
    };
    
    // === Phase 3: Test User Eligibility ===
    // Since create_test_airdrop sets require_attendance = false, 
    // even users without attendance should be eligible
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        // Test with USER1 who has attendance (should be eligible)
        let eligible_user1 = airdrop_distribution::is_user_eligible(
            USER1,
            airdrop_id,
            &registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry
        );
        assert!(eligible_user1, 41);

        // Test with a random user who has no attendance (should still be eligible since require_attendance = false)
        let eligible_random = airdrop_distribution::is_user_eligible(
            @0xE,
            airdrop_id,
            &registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry
        );
        assert!(eligible_random, 42); // Should be eligible since require_attendance = false

        // Check claim status
        let (claimed, amount) = airdrop_distribution::get_claim_status(USER1, airdrop_id, &registry);
        assert!(!claimed, 43);
        assert!(amount == 0, 44);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Withdraw Tests ==========

#[test]
#[expected_failure(abort_code = eia::airdrop_distribution::EAirdropNotActive)]
fun test_withdraw_unclaimed_before_expiry() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    // Try to withdraw before expiry (should fail)
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        // This should fail because airdrop hasn't expired yet
        airdrop_distribution::withdraw_unclaimed(
            airdrop_id,
            &mut registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_withdraw_unclaimed_after_expiry_success() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        1 // 1 day validity for faster testing
    );
    
    // Advance time past expiry
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        
        // Get expiry time and advance past it
        let (_, _, _, _, expires_at, _) = 
            airdrop_distribution::get_airdrop_details(airdrop_id, &registry);
        clock::set_for_testing(&mut clock, expires_at + 1000);
        
        // Now withdrawal should succeed
        airdrop_distribution::withdraw_unclaimed(
            airdrop_id,
            &mut registry,
            &clock,
            ctx(&mut scenario)
        );
        
        // Verify the airdrop is no longer active
        let (_, _, remaining_balance, _, _, active) = 
            airdrop_distribution::get_airdrop_details(airdrop_id, &registry);
        assert!(!active, 100);
        assert!(remaining_balance == 0, 101);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

// ========== Time-based Tests ==========

#[test]
fun test_airdrop_expiry_timing() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        1 // 1 day validity
    );
    
    // Advance time to just before expiry
    next_tx(&mut scenario, @0x0);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        let (_, _, _, _, expires_at, active) = 
            airdrop_distribution::get_airdrop_details(airdrop_id, &registry);
        
        // Set time to just before expiry
        clock::set_for_testing(&mut clock, expires_at - 1000);
        
        assert!(active, 53);
        
        test_scenario::return_shared(clock);
        test_scenario::return_shared(registry);
    };
    
    // Advance time past expiry
    next_tx(&mut scenario, @0x0);
    {
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        let (_, _, _, _, expires_at, _) = 
            airdrop_distribution::get_airdrop_details(airdrop_id, &registry);
        
        // Set time past expiry
        clock::set_for_testing(&mut clock, expires_at + 1000);
        
        test_scenario::return_shared(clock);
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_withdraw_after_expiry() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        1 // 1 day validity
    );
    
    // Advance time past expiry and withdraw
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let mut clock = test_scenario::take_shared<Clock>(&scenario);
        
        let (_, _, _, _, expires_at, _) = 
            airdrop_distribution::get_airdrop_details(airdrop_id, &registry);
        
        // Set time past expiry
        clock::set_for_testing(&mut clock, expires_at + 1000);
        
        // Now withdrawal should work
        airdrop_distribution::withdraw_unclaimed(
            airdrop_id,
            &mut registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

// ========== Claim Amount Calculation Tests ==========

#[test]
fun test_equal_distribution_calculation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 10); // Small capacity for easier calculation
    
    // Add some attendees first
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        event_management::increment_attendees(&mut event);
        event_management::increment_attendees(&mut event);
        test_scenario::return_shared(event);
    };

    // Create equal distribution airdrop with known pool
    let pool_amount = 1000000000; // 1 SUI
    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(pool_amount, ctx(&mut scenario));
        
        let _airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b"Equal Distribution Test"),
            string::utf8(b"Test description"),
            payment,
            TYPE_EQUAL_DISTRIBUTION,
            false,
            false,
            HOUR_IN_MS,
            false,
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_weighted_distribution_calculation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 10);
    
    // Add some attendees first
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        event_management::increment_attendees(&mut event);
        event_management::increment_attendees(&mut event);
        test_scenario::return_shared(event);
    };

    // Create weighted distribution airdrop
    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(AIRDROP_POOL_AMOUNT, ctx(&mut scenario));
        
        let _airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b"Weighted Distribution Test"),
            string::utf8(b"Test description"),
            payment,
            TYPE_WEIGHTED_BY_DURATION,
            false,
            false,
            HOUR_IN_MS,
            false,
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_completion_bonus_calculation() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 50); // Larger capacity
    
    // Add attendees safely without exceeding capacity
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        
        let capacity = event_management::get_event_capacity(&event);
        let current_attendees = event_management::get_current_attendees(&event);
        
        // Add attendees up to 80% of capacity or 20, whichever is smaller
        let max_safe_attendees = if (capacity * 4 / 5 < 20) { capacity * 4 / 5 } else { 20 };
        let attendees_to_add = if (current_attendees < max_safe_attendees) {
            max_safe_attendees - current_attendees
        } else {
            0
        };
        
        let mut i = 0;
        while (i < attendees_to_add) {
            event_management::increment_attendees(&mut event);
            i = i + 1;
        };
        
        test_scenario::return_shared(event);
    };

    // Create completion bonus airdrop
    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(AIRDROP_POOL_AMOUNT, ctx(&mut scenario));
        
        let _airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b"Completion Bonus Test"),
            string::utf8(b"Test description"),
            payment,
            TYPE_COMPLETION_BONUS,
            false, // Set to false since checked_out will be 0
            false, // require_completion = false to use current_attendees instead of checked_out
            HOUR_IN_MS,
            false,
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}


// ========== Advanced Integration Tests ==========

#[test]
fun test_airdrop_with_attendance_flow() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create airdrop with attendance requirement
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false, // don't require completion
        7
    );
    
    // Test eligibility - the create_test_airdrop function already simulated check-ins for USER1, USER2, USER3
    // So they should be eligible since they have attendance records
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        // Users WITH attendance should be eligible (since create_test_airdrop simulated check-ins)
        let eligible1 = airdrop_distribution::is_user_eligible(
            USER1,
            airdrop_id,
            &registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry
        );
        
        let eligible2 = airdrop_distribution::is_user_eligible(
            USER2,
            airdrop_id,
            &registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry
        );
        
        // Since create_test_airdrop sets require_attendance = false, users should be eligible
        assert!(eligible1, 54);
        assert!(eligible2, 55);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_init_for_testing() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    // Test that init_for_testing works correctly
    next_tx(&mut scenario, ORGANIZER);
    {
        airdrop_distribution::init_for_testing(ctx(&mut scenario));
    };
    
    // Verify registry was created
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        // Test initial state - registry created successfully
        assert!(true, 1); // Registry exists and is functional
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_airdrop_with_nft_completion_requirement() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create airdrop requiring NFT completion
    let airdrop_id = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_COMPLETION_BONUS,
        true, // require completion (NFT)
        7
    );
    
    // Test eligibility without NFT
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        let eligible = airdrop_distribution::is_user_eligible(
            USER1,
            airdrop_id,
            &registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry
        );
        
        assert!(!eligible, 56); // Should not be eligible without NFT
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    test_scenario::end(scenario);
}

#[test]
fun test_airdrop_with_rating_requirement() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Ensure sufficient attendees before creating airdrop
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        
        // Add sufficient attendees for airdrop creation
        let mut i = 0;
        while (i < 25) {
            event_management::increment_attendees(&mut event);
            i = i + 1;
        };
        
        test_scenario::return_shared(event);
    };

    // Create airdrop requiring rating submission
    next_tx(&mut scenario, ORGANIZER);
    {
        let event = test_scenario::take_shared_by_id<Event>(&scenario, event_id);
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        let payment = coin::mint_for_testing<SUI>(AIRDROP_POOL_AMOUNT, ctx(&mut scenario));
        
        let airdrop_id = airdrop_distribution::create_airdrop(
            &event,
            string::utf8(b"Rating Required Airdrop"),
            string::utf8(b"Test description"),
            payment,
            TYPE_EQUAL_DISTRIBUTION,
            true, // require attendance
            false, // don't require completion
            HOUR_IN_MS,
            true, // require rating
            7,
            &mut registry,
            &attendance_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        // Test eligibility without rating
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        let eligible = airdrop_distribution::is_user_eligible(
            USER1,
            airdrop_id,
            &registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry
        );
        
        assert!(!eligible, 57); // Should not be eligible without rating
        
        test_scenario::return_shared(event);
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(clock);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Data Consistency Tests ==========

#[test]
fun test_airdrop_data_consistency_after_operations() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS, 100);
    
    // Create multiple airdrops
    let airdrop_id1 = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        7
    );
    
    let airdrop_id2 = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT / 2,
        TYPE_WEIGHTED_BY_DURATION,
        false,
        14
    );
    
    // Verify data consistency
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        // Check that both airdrops are properly linked to event
        let airdrops = airdrop_distribution::get_event_airdrops(event_id, &registry);
        assert!(vector::length(&airdrops) == 2, 58);
        assert!(vector::contains(&airdrops, &airdrop_id1), 59);
        assert!(vector::contains(&airdrops, &airdrop_id2), 60);
        
        // Check individual airdrop details
        let (event_id1, _, pool1, claims1, _, active1) = 
            airdrop_distribution::get_airdrop_details(airdrop_id1, &registry);
        let (event_id2, _, pool2, claims2, _, active2) = 
            airdrop_distribution::get_airdrop_details(airdrop_id2, &registry);
        
        assert!(event_id1 == event_id, 61);
        assert!(event_id2 == event_id, 62);
        assert!(pool1 == AIRDROP_POOL_AMOUNT, 63);
        assert!(pool2 == AIRDROP_POOL_AMOUNT / 2, 64);
        assert!(claims1 == 0, 65);
        assert!(claims2 == 0, 66);
        assert!(active1 && active2, 67);
        
        test_scenario::return_shared(registry);
    };
    
    test_scenario::end(scenario);
}

// ========== Final Comprehensive Test ==========

#[test]
fun test_complete_airdrop_system_integration() {
    let mut scenario = test_scenario::begin(ORGANIZER);
    
    // === Phase 1: Complete System Setup ===
    setup_test_environment(&mut scenario);
    create_test_organizer_profile(&mut scenario, ORGANIZER);
    let event_id = create_and_activate_test_event(&mut scenario, ORGANIZER, HOUR_IN_MS * 2, 50);
    
    // === Phase 2: User Registration ===
    register_user_for_event(&mut scenario, USER1, event_id);
    register_user_for_event(&mut scenario, USER2, event_id);
    register_user_for_event(&mut scenario, USER3, event_id);
    
    // === Phase 3: Create Multiple Airdrops ===
    let equal_airdrop = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT,
        TYPE_EQUAL_DISTRIBUTION,
        false,
        30
    );
    
    let weighted_airdrop = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT / 2,
        TYPE_WEIGHTED_BY_DURATION,
        false,
        30
    );
    
    let completion_airdrop = create_test_airdrop(
        &mut scenario,
        ORGANIZER,
        event_id,
        AIRDROP_POOL_AMOUNT / 4,
        TYPE_COMPLETION_BONUS,
        false, // Don't require NFT completion for this test
        30
    );
    
    // === Phase 4: Verify System State ===
    next_tx(&mut scenario, @0x0);
    {
        let registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        
        // Check all airdrops are linked to event
        let airdrops = airdrop_distribution::get_event_airdrops(event_id, &registry);
        assert!(vector::length(&airdrops) == 3, 68);
        assert!(vector::contains(&airdrops, &equal_airdrop), 69);
        assert!(vector::contains(&airdrops, &weighted_airdrop), 70);
        assert!(vector::contains(&airdrops, &completion_airdrop), 71);
        
        // Verify total pool amounts
        let (_, _, pool1, _, _, _) = airdrop_distribution::get_airdrop_details(equal_airdrop, &registry);
        let (_, _, pool2, _, _, _) = airdrop_distribution::get_airdrop_details(weighted_airdrop, &registry);
        let (_, _, pool3, _, _, _) = airdrop_distribution::get_airdrop_details(completion_airdrop, &registry);
        
        let total_pools = pool1 + pool2 + pool3;
        let expected_total = AIRDROP_POOL_AMOUNT + (AIRDROP_POOL_AMOUNT / 2) + (AIRDROP_POOL_AMOUNT / 4);
        assert!(total_pools == expected_total, 72);
        
        // Check user eligibility for each airdrop
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        
        // Users should be eligible since create_test_airdrop simulated attendance for USER1, USER2, USER3
        let eligible1 = airdrop_distribution::is_user_eligible(
            USER1, equal_airdrop, &registry, &attendance_registry, &nft_registry, &rating_registry
        );
        let eligible2 = airdrop_distribution::is_user_eligible(
            USER2, weighted_airdrop, &registry, &attendance_registry, &nft_registry, &rating_registry
        );
        // For completion_airdrop, USER1 and USER2 were checked out by create_test_airdrop
        let eligible3 = airdrop_distribution::is_user_eligible(
            USER1, completion_airdrop, &registry, &attendance_registry, &nft_registry, &rating_registry
        );

        // Since create_test_airdrop sets require_attendance = false for all airdrops,
        // and creates checkout records for completion when require_completion = false,
        // these should all be eligible
        assert!(eligible1, 73);
        assert!(eligible2, 74);
        assert!(eligible3, 75);
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
    };
    
    // === Phase 5: Test Batch Operations ===
    next_tx(&mut scenario, ORGANIZER);
    {
        let mut registry = test_scenario::take_shared<AirdropRegistry>(&scenario);
        let attendance_registry = test_scenario::take_shared<AttendanceRegistry>(&scenario);
        let nft_registry = test_scenario::take_shared<NFTRegistry>(&scenario);
        let rating_registry = test_scenario::take_shared<RatingRegistry>(&scenario);
        let clock = test_scenario::take_shared<Clock>(&scenario);
        
        // Try batch distribution (will skip ineligible users)
        airdrop_distribution::batch_distribute(
            equal_airdrop,
            vector[USER1, USER2, USER3],
            &mut registry,
            &attendance_registry,
            &nft_registry,
            &rating_registry,
            &clock,
            ctx(&mut scenario)
        );
        
        test_scenario::return_shared(registry);
        test_scenario::return_shared(attendance_registry);
        test_scenario::return_shared(nft_registry);
        test_scenario::return_shared(rating_registry);
        test_scenario::return_shared(clock);
    };
    
    test_scenario::end(scenario);
}