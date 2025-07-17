module eia::airdrop_distribution;

use std::string::String;
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::balance::{Self, Balance};
use sui::table::{Self, Table};
use sui::event;
use sui::clock::{Self, Clock};
use eia::event_management::{Self, Event};
use eia::nft_minting::{Self, NFTRegistry};
use eia::attendance_verification::{Self, AttendanceRegistry};
use eia::rating_reputation::{Self, RatingRegistry};

// Error codes
const ENotOrganizer: u64 = 1;
const EInsufficientFunds: u64 = 2;
const EAirdropNotFound: u64 = 3;
const ENotEligible: u64 = 4;
const EAlreadyClaimed: u64 = 5;
const EAirdropExpired: u64 = 6;
const EInvalidDistribution: u64 = 7;
const EAirdropNotActive: u64 = 8;

// Airdrop types
const TYPE_EQUAL_DISTRIBUTION: u8 = 0;
const TYPE_WEIGHTED_BY_DURATION: u8 = 1;
const TYPE_COMPLETION_BONUS: u8 = 2;

// Airdrop registry
public struct AirdropRegistry has key {
    id: UID,
    airdrops: Table<ID, Airdrop>, // airdrop_id -> airdrop
    event_airdrops: Table<ID, vector<ID>>, // event_id -> airdrop_ids
    user_claims: Table<address, vector<ClaimRecord>>,
    total_distributed: u64,
}

public struct Airdrop has store {
    id: ID,
    event_id: ID,
    organizer: address,
    name: String,
    description: String,
    pool: Balance<SUI>,
    distribution_type: u8,
    eligibility_criteria: EligibilityCriteria,
    per_user_amount: u64, // For equal distribution
    total_recipients: u64,
    claimed_count: u64,
    claims: Table<address, ClaimInfo>,
    created_at: u64,
    expires_at: u64,
    active: bool,
}

public struct EligibilityCriteria has store, drop, copy {
    require_attendance: bool,
    require_completion: bool,
    min_duration: u64, // Minimum attendance duration
    require_rating_submitted: bool,
}

public struct ClaimInfo has store, drop, copy {
    amount: u64,
    claimed_at: u64,
    transaction_id: ID,
}

public struct ClaimRecord has store, drop, copy {
    airdrop_id: ID,
    event_id: ID,
    amount: u64,
    claimed_at: u64,
}

// Events
public struct AirdropCreated has copy, drop {
    airdrop_id: ID,
    event_id: ID,
    total_amount: u64,
    distribution_type: u8,
    expires_at: u64,
}

public struct AirdropClaimed has copy, drop {
    airdrop_id: ID,
    claimer: address,
    amount: u64,
    claimed_at: u64,
}

public struct AirdropCompleted has copy, drop {
    airdrop_id: ID,
    total_claimed: u64,
    recipients: u64,
}

// Initialize the module
fun init(ctx: &mut TxContext) {
    let registry = AirdropRegistry {
        id: object::new(ctx),
        airdrops: table::new(ctx),
        event_airdrops: table::new(ctx),
        user_claims: table::new(ctx),
        total_distributed: 0,
    };
    transfer::share_object(registry);
}

// Create a new airdrop
public fun create_airdrop(
    event: &Event,
    name: String,
    description: String,
    payment: Coin<SUI>,
    distribution_type: u8,
    require_attendance: bool,
    require_completion: bool,
    min_duration: u64,
    require_rating_submitted: bool,
    validity_days: u64,
    registry: &mut AirdropRegistry,
    attendance_registry: &AttendanceRegistry,
    clock: &Clock,
    ctx: &mut TxContext
): ID {
    let organizer = tx_context::sender(ctx);
    let event_id = event_management::get_event_id(event);
    
    // Verify sender is event organizer
    assert!(event_management::get_event_organizer(event) == organizer, ENotOrganizer);
    
    let amount = coin::value(&payment);
    assert!(amount > 0, EInsufficientFunds);
    
    let current_time = clock::timestamp_ms(clock);
    let expires_at = current_time + (validity_days * 86400000); // Convert days to milliseconds
    
    // Calculate eligible recipients based on criteria
    let (_, checked_out, _) = attendance_verification::get_event_stats(event_id, attendance_registry);
    let estimated_recipients = if (require_completion) { checked_out } else { event_management::get_current_attendees(event) };
    
    assert!(estimated_recipients > 0, EInvalidDistribution);
    
    let per_user_amount = if (distribution_type == TYPE_EQUAL_DISTRIBUTION) {
        amount / estimated_recipients
    } else {
        0 // Will be calculated based on individual criteria
    };
    
    let airdrop_id = object::new(ctx);
    let id = object::uid_to_inner(&airdrop_id);
    object::delete(airdrop_id); 
    
    let airdrop = Airdrop {
        id,
        event_id,
        organizer,
        name,
        description,
        pool: coin::into_balance(payment),
        distribution_type,
        eligibility_criteria: EligibilityCriteria {
            require_attendance,
            require_completion,
            min_duration,
            require_rating_submitted,
        },
        per_user_amount,
        total_recipients: estimated_recipients,
        claimed_count: 0,
        claims: table::new(ctx),
        created_at: current_time,
        expires_at,
        active: true,
    };
    
    // Store airdrop
    table::add(&mut registry.airdrops, id, airdrop);
    
    // Link to event
    if (!table::contains(&registry.event_airdrops, event_id)) {
        table::add(&mut registry.event_airdrops, event_id, vector::empty());
    };
    let event_airdrops = table::borrow_mut(&mut registry.event_airdrops, event_id);
    vector::push_back(event_airdrops, id);
    
    event::emit(AirdropCreated {
        airdrop_id: id,
        event_id,
        total_amount: amount,
        distribution_type,
        expires_at,
    });
    
    id
}

// Claim airdrop rewards
#[allow(lint(self_transfer))]
public fun claim_airdrop(
    airdrop_id: ID,
    registry: &mut AirdropRegistry,
    attendance_registry: &AttendanceRegistry,
    nft_registry: &NFTRegistry,
    rating_registry: &RatingRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let claimer = tx_context::sender(ctx);
    let current_time = clock::timestamp_ms(clock);
    
    // Verify airdrop exists
    assert!(table::contains(&registry.airdrops, airdrop_id), EAirdropNotFound);
    
    let airdrop = table::borrow_mut(&mut registry.airdrops, airdrop_id);
    
    // Check if active and not expired
    assert!(airdrop.active, EAirdropNotActive);
    assert!(current_time <= airdrop.expires_at, EAirdropExpired);
    
    // Check if already claimed
    assert!(!table::contains(&airdrop.claims, claimer), EAlreadyClaimed);
    
    // Verify eligibility
    let eligible = verify_eligibility(
        claimer,
        airdrop.event_id,
        &airdrop.eligibility_criteria,
        attendance_registry,
        nft_registry,
        rating_registry
    );
    assert!(eligible, ENotEligible);
    
    // Calculate claim amount
    let claim_amount = calculate_claim_amount(
        claimer,
        airdrop,
        attendance_registry
    );
    
    assert!(claim_amount > 0 && balance::value(&airdrop.pool) >= claim_amount, EInsufficientFunds);
    
    // Process claim
    let payment = coin::from_balance(
        balance::split(&mut airdrop.pool, claim_amount),
        ctx
    );
    
    let tx_id = object::id(&payment);
    
    // Record claim
    let claim_info = ClaimInfo {
        amount: claim_amount,
        claimed_at: current_time,
        transaction_id: tx_id,
    };
    table::add(&mut airdrop.claims, claimer, claim_info);
    airdrop.claimed_count = airdrop.claimed_count + 1;
    
    // Update user claims
    if (!table::contains(&registry.user_claims, claimer)) {
        table::add(&mut registry.user_claims, claimer, vector::empty());
    };
    let user_claims = table::borrow_mut(&mut registry.user_claims, claimer);
    vector::push_back(user_claims, ClaimRecord {
        airdrop_id,
        event_id: airdrop.event_id,
        amount: claim_amount,
        claimed_at: current_time,
    });
    
    // Update global stats
    registry.total_distributed = registry.total_distributed + claim_amount;
    
    // Transfer payment
    transfer::public_transfer(payment, claimer);
    
    event::emit(AirdropClaimed {
        airdrop_id,
        claimer,
        amount: claim_amount,
        claimed_at: current_time,
    });
    
    // Check if airdrop is complete
    if (airdrop.claimed_count >= airdrop.total_recipients || balance::value(&airdrop.pool) < airdrop.per_user_amount) {
        airdrop.active = false;
        
        event::emit(AirdropCompleted {
            airdrop_id,
            total_claimed: registry.total_distributed,
            recipients: airdrop.claimed_count,
        });
    };
}

// Batch claim for multiple eligible users (organizer initiated)
public fun batch_distribute(
    airdrop_id: ID,
    recipients: vector<address>,
    registry: &mut AirdropRegistry,
    attendance_registry: &AttendanceRegistry,
    nft_registry: &NFTRegistry,
    rating_registry: &RatingRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(table::contains(&registry.airdrops, airdrop_id), EAirdropNotFound);
    
    let airdrop = table::borrow_mut(&mut registry.airdrops, airdrop_id);
    assert!(tx_context::sender(ctx) == airdrop.organizer, ENotOrganizer);
    assert!(airdrop.active, EAirdropNotActive);
    
    let current_time = clock::timestamp_ms(clock);
    assert!(current_time <= airdrop.expires_at, EAirdropExpired);
    
    let mut i = 0;
    let len = vector::length(&recipients);
    
    while (i < len && balance::value(&airdrop.pool) > 0) {
        let recipient = *vector::borrow(&recipients, i);
        
        // Skip if already claimed or not eligible
        if (!table::contains(&airdrop.claims, recipient)) {
            let eligible = verify_eligibility(
                recipient,
                airdrop.event_id,
                &airdrop.eligibility_criteria,
                attendance_registry,
                nft_registry,
                rating_registry,
            );
            
            if (eligible) {
                let claim_amount = calculate_claim_amount(
                    recipient,
                    airdrop,
                    attendance_registry
                );
                
                if (claim_amount > 0 && balance::value(&airdrop.pool) >= claim_amount) {
                    let payment = coin::from_balance(
                        balance::split(&mut airdrop.pool, claim_amount),
                        ctx
                    );
                    
                    let tx_id = object::id(&payment);
                    
                    // Record claim
                    table::add(&mut airdrop.claims, recipient, ClaimInfo {
                        amount: claim_amount,
                        claimed_at: current_time,
                        transaction_id: tx_id,
                    });
                    
                    airdrop.claimed_count = airdrop.claimed_count + 1;
                    registry.total_distributed = registry.total_distributed + claim_amount;
                    
                    transfer::public_transfer(payment, recipient);
                    
                    event::emit(AirdropClaimed {
                        airdrop_id,
                        claimer: recipient,
                        amount: claim_amount,
                        claimed_at: current_time,
                    });
                };
            };
        };
        
        i = i + 1;
    };
}

// Withdraw unclaimed funds after expiry
public fun withdraw_unclaimed(
    airdrop_id: ID,
    registry: &mut AirdropRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    assert!(table::contains(&registry.airdrops, airdrop_id), EAirdropNotFound);
    
    let airdrop = table::borrow_mut(&mut registry.airdrops, airdrop_id);
    assert!(tx_context::sender(ctx) == airdrop.organizer, ENotOrganizer);
    assert!(clock::timestamp_ms(clock) > airdrop.expires_at, EAirdropNotActive);
    
    let remaining = balance::value(&airdrop.pool);
    if (remaining > 0) {
        let payment = coin::from_balance(
            balance::withdraw_all(&mut airdrop.pool),
            ctx
        );
        transfer::public_transfer(payment, airdrop.organizer);
    };
    
    airdrop.active = false;
}

// Helper function to verify eligibility
fun verify_eligibility(
    user: address,
    event_id: ID,
    criteria: &EligibilityCriteria,
    attendance_registry: &AttendanceRegistry,
    nft_registry: &NFTRegistry,
    rating_registry: &RatingRegistry,
): bool {
    // Check attendance requirement
    if (criteria.require_attendance) {
        let (attended, state, check_in_time, check_out_time) = 
            attendance_verification::get_attendance_status(user, event_id, attendance_registry);
        
        if (!attended) {
            return false
        };
        
        // Check completion requirement
        if (criteria.require_completion && state != 2) { // STATE_CHECKED_OUT = 2
            return false
        };
        
        // Check minimum duration
        if (criteria.min_duration > 0 && check_out_time > check_in_time) {
            let duration = check_out_time - check_in_time;
            if (duration < criteria.min_duration) {
                return false
            };
        };
    };
    
    // Check NFT requirements
    if (criteria.require_completion) {
        if (!nft_minting::has_completion_nft(user, event_id, nft_registry)) {
            return false
        };
    };
    
    // Check rating requirement using the rating contract
    if (criteria.require_rating_submitted) {        
        // Verify user has submitted a rating for this event
        if (!rating_reputation::has_user_rated(user, event_id, rating_registry)) {
            return false
        };
    };
    
    true
}

public fun is_user_eligible(
    user: address,
    airdrop_id: ID,
    registry: &AirdropRegistry,
    attendance_registry: &AttendanceRegistry,
    nft_registry: &NFTRegistry,
    rating_registry: &RatingRegistry,
): bool {
    assert!(table::contains(&registry.airdrops, airdrop_id), EAirdropNotFound);
    let airdrop = table::borrow(&registry.airdrops, airdrop_id);
    
    verify_eligibility(
        user,
        airdrop.event_id,
        &airdrop.eligibility_criteria,
        attendance_registry,
        nft_registry,
        rating_registry
    )
}

// Calculate claim amount based on distribution type
fun calculate_claim_amount(
    user: address,
    airdrop: &Airdrop,
    attendance_registry: &AttendanceRegistry,
): u64 {
    if (airdrop.distribution_type == TYPE_EQUAL_DISTRIBUTION) {
        return airdrop.per_user_amount
    } else if (airdrop.distribution_type == TYPE_WEIGHTED_BY_DURATION) {
        // Calculate based on attendance duration
        let (_, _, check_in_time, check_out_time) = 
            attendance_verification::get_attendance_status(user, airdrop.event_id, attendance_registry);
        
        if (check_out_time > check_in_time) {
            let duration = check_out_time - check_in_time;
            let base_amount = balance::value(&airdrop.pool) / airdrop.total_recipients;
            // Weight by duration (simplified - could be more sophisticated)
            let weight = (duration / 3600000) + 1; // Hours + 1
            return base_amount * weight
        };
        
        return airdrop.per_user_amount
    } else if (airdrop.distribution_type == TYPE_COMPLETION_BONUS) {
        // Bonus for completion
        let (_, state, _, _) = 
            attendance_verification::get_attendance_status(user, airdrop.event_id, attendance_registry);
        
        if (state == 2) { // STATE_CHECKED_OUT
            return airdrop.per_user_amount * 2 // Double reward for completion
        };
        
        return airdrop.per_user_amount
    };
    
    airdrop.per_user_amount
}

// Get airdrop details
public fun get_airdrop_details(
    airdrop_id: ID,
    registry: &AirdropRegistry
): (ID, String, u64, u64, u64, bool) {
    assert!(table::contains(&registry.airdrops, airdrop_id), EAirdropNotFound);
    
    let airdrop = table::borrow(&registry.airdrops, airdrop_id);
    (
        airdrop.event_id,
        airdrop.name,
        balance::value(&airdrop.pool),
        airdrop.claimed_count,
        airdrop.expires_at,
        airdrop.active
    )
}

// Get user's claim status
public fun get_claim_status(
    user: address,
    airdrop_id: ID,
    registry: &AirdropRegistry
): (bool, u64) {
    assert!(table::contains(&registry.airdrops, airdrop_id), EAirdropNotFound);
    
    let airdrop = table::borrow(&registry.airdrops, airdrop_id);
    
    if (table::contains(&airdrop.claims, user)) {
        let claim = table::borrow(&airdrop.claims, user);
        (true, claim.amount)
    } else {
        (false, 0)
    }
}

// Get airdrops for an event
public fun get_event_airdrops(
    event_id: ID,
    registry: &AirdropRegistry
): vector<ID> {
    if (!table::contains(&registry.event_airdrops, event_id)) {
        return vector::empty()
    };
    
    *table::borrow(&registry.event_airdrops, event_id)
}

// Get user's claim history
public fun get_user_claims(
    user: address,
    registry: &AirdropRegistry
): vector<ClaimRecord> {
    if (!table::contains(&registry.user_claims, user)) {
        return vector::empty()
    };
    
    *table::borrow(&registry.user_claims, user)
}


#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}