module eia::community_access;

use std::string::String;
use sui::table::{Self, Table};
use sui::event;
use sui::clock::{Self, Clock};
use eia::event_management::{Self, Event};
use eia::nft_minting::{Self, NFTRegistry};

// Error codes
const ENotOrganizer: u64 = 1;
const ECommunityNotFound: u64 = 2;
const EAlreadyMember: u64 = 3;
const ENotEligible: u64 = 4;
const EAccessDenied: u64 = 5;
const ECommunityNotActive: u64 = 6;
const EAlreadyExists: u64 = 7;

// Access types
const ACCESS_TYPE_POA: u8 = 0; // Proof of Attendance
const ACCESS_TYPE_COMPLETION: u8 = 1; // Completion NFT
const ACCESS_TYPE_BOTH: u8 = 2; // Either PoA or Completion

// Community registry
public struct CommunityRegistry has key {
    id: UID,
    communities: Table<ID, Community>,
    event_communities: Table<ID, ID>, // event_id -> community_id
    user_memberships: Table<address, vector<Membership>>,
}

public struct Community has store {
    id: ID,
    event_id: ID,
    name: String,
    description: String,
    organizer: address,
    access_config: AccessConfiguration,
    members: Table<address, MemberInfo>,
    member_count: u64,
    created_at: u64,
    active: bool,
    metadata_uri: String, // Link to community resources
    features: CommunityFeatures,
}

public struct AccessConfiguration has store, drop, copy {
    access_type: u8,
    require_nft_held: bool, // Must currently hold NFT
    min_event_rating: u64, // Minimum rating given to event
    custom_requirements: vector<CustomRequirement>,
    expiry_duration: u64, // 0 for permanent access
}

public struct CustomRequirement has store, drop, copy {
    requirement_type: String,
    value: u64,
}

public struct CommunityFeatures has store, drop, copy {
    forum_enabled: bool,
    resource_sharing: bool,
    event_calendar: bool,
    member_directory: bool,
    governance_enabled: bool,
}

public struct MemberInfo has store, drop, copy {
    joined_at: u64,
    access_expires_at: u64, // 0 for permanent
    access_type_used: u8,
    contribution_score: u64,
    last_active: u64,
}

public struct Membership has store, drop, copy {
    community_id: ID,
    event_id: ID,
    joined_at: u64,
    expires_at: u64,
    active: bool,
}

// Access pass for verification
public struct CommunityAccessPass has key, store {
    id: UID,
    community_id: ID,
    member: address,
    issued_at: u64,
    expires_at: u64,
}

// Events
public struct CommunityCreated has copy, drop {
    community_id: ID,
    event_id: ID,
    name: String,
    access_type: u8,
}

public struct MemberJoined has copy, drop {
    community_id: ID,
    member: address,
    joined_at: u64,
    access_type_used: u8,
}

public struct AccessGranted has copy, drop {
    community_id: ID,
    member: address,
    pass_id: ID,
    expires_at: u64,
}

public struct MemberRemoved has copy, drop {
    community_id: ID,
    member: address,
    reason: String,
}

// Initialize the module
fun init(ctx: &mut TxContext) {
    let registry = CommunityRegistry {
        id: object::new(ctx),
        communities: table::new(ctx),
        event_communities: table::new(ctx),
        user_memberships: table::new(ctx),
    };
    transfer::share_object(registry);
}

// Create a token-gated community
public fun create_community(
    event: &Event,
    name: String,
    description: String,
    access_type: u8,
    require_nft_held: bool,
    min_event_rating: u64,
    expiry_duration: u64,
    metadata_uri: String,
    forum_enabled: bool,
    resource_sharing: bool,
    event_calendar: bool,
    member_directory: bool,
    governance_enabled: bool,
    registry: &mut CommunityRegistry,
    clock: &Clock,
    ctx: &mut TxContext
): ID {
    let organizer = tx_context::sender(ctx);
    let event_id = event_management::get_event_id(event);
    
    // Verify sender is event organizer
    assert!(event_management::get_event_organizer(event) == organizer, ENotOrganizer);
    
    // Check if community already exists for this event
    assert!(!table::contains(&registry.event_communities, event_id), EAlreadyExists);
    
    let community_id_obj = object::new(ctx);
    let community_id = object::uid_to_inner(&community_id_obj);
    
    let community = Community {
        id: community_id,
        event_id,
        name,
        description,
        organizer,
        access_config: AccessConfiguration {
            access_type,
            require_nft_held,
            min_event_rating,
            custom_requirements: vector::empty(),
            expiry_duration,
        },
        members: table::new(ctx),
        member_count: 0,
        created_at: clock::timestamp_ms(clock),
        active: true,
        metadata_uri,
        features: CommunityFeatures {
            forum_enabled,
            resource_sharing,
            event_calendar,
            member_directory,
            governance_enabled,
        },
    };
    
    table::add(&mut registry.communities, community_id, community);
    table::add(&mut registry.event_communities, event_id, community_id);
    
    event::emit(CommunityCreated {
        community_id,
        event_id,
        name,
        access_type,
    });
    
    object::delete(community_id_obj);
    community_id
}

// Add custom requirement to community
public fun add_custom_requirement(
    community_id: ID,
    requirement_type: String,
    value: u64,
    registry: &mut CommunityRegistry,
    ctx: &mut TxContext
) {
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow_mut(&mut registry.communities, community_id);
    assert!(community.organizer == tx_context::sender(ctx), ENotOrganizer);
    
    let requirement = CustomRequirement {
        requirement_type,
        value,
    };
    
    vector::push_back(&mut community.access_config.custom_requirements, requirement);
}

// Request community access
public fun request_access(
    community_id: ID,
    registry: &mut CommunityRegistry,
    nft_registry: &NFTRegistry,
    clock: &Clock,
    ctx: &mut TxContext
): CommunityAccessPass {
    let member = tx_context::sender(ctx);
    
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow_mut(&mut registry.communities, community_id);
    assert!(community.active, ECommunityNotActive);
    
    // Check if already a member
    assert!(!table::contains(&community.members, member), EAlreadyMember);
    
    // Verify NFT ownership and eligibility
    let eligible = verify_nft_eligibility(
        member,
        community.event_id,
        &community.access_config,
        nft_registry
    );
    assert!(eligible, ENotEligible);
    
    let current_time = clock::timestamp_ms(clock);
    let expires_at = if (community.access_config.expiry_duration > 0) {
        current_time + community.access_config.expiry_duration
    } else {
        0 // Permanent access
    };
    
    // Add member
    let member_info = MemberInfo {
        joined_at: current_time,
        access_expires_at: expires_at,
        access_type_used: community.access_config.access_type,
        contribution_score: 0,
        last_active: current_time,
    };
    
    table::add(&mut community.members, member, member_info);
    community.member_count = community.member_count + 1;
    
    // Update user memberships
    if (!table::contains(&registry.user_memberships, member)) {
        table::add(&mut registry.user_memberships, member, vector::empty());
    };
    let memberships = table::borrow_mut(&mut registry.user_memberships, member);
    vector::push_back(memberships, Membership {
        community_id,
        event_id: community.event_id,
        joined_at: current_time,
        expires_at,
        active: true,
    });
    
    // Create access pass
    let pass = CommunityAccessPass {
        id: object::new(ctx),
        community_id,
        member,
        issued_at: current_time,
        expires_at,
    };
    
    let pass_id = object::id(&pass);
    
    event::emit(MemberJoined {
        community_id,
        member,
        joined_at: current_time,
        access_type_used: community.access_config.access_type,
    });
    
    event::emit(AccessGranted {
        community_id,
        member,
        pass_id,
        expires_at,
    });
    
    pass
}

// Verify access (for gated content)
public fun verify_access(
    pass: &CommunityAccessPass,
    registry: &CommunityRegistry,
    clock: &Clock,
): bool {
    let community_id = pass.community_id;
    let member = pass.member;
    
    if (!table::contains(&registry.communities, community_id)) {
        return false
    };
    
    let community = table::borrow(&registry.communities, community_id);
    
    if (!community.active || !table::contains(&community.members, member)) {
        return false
    };
    
    let member_info = table::borrow(&community.members, member);
    let current_time = clock::timestamp_ms(clock);
    
    // Check expiry
    if (member_info.access_expires_at > 0 && current_time > member_info.access_expires_at) {
        return false
    };
    
    true
}

// Update member activity
public fun update_member_activity(
    community_id: ID,
    registry: &mut CommunityRegistry,
    clock: &Clock,
    ctx: &mut TxContext
) {
    let member = tx_context::sender(ctx);
    
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow_mut(&mut registry.communities, community_id);
    assert!(table::contains(&community.members, member), EAccessDenied);
    
    let member_info = table::borrow_mut(&mut community.members, member);
    member_info.last_active = clock::timestamp_ms(clock);
}

// Update contribution score (called by other modules)
public fun update_contribution_score(
    community_id: ID,
    member: address,
    points: u64,
    registry: &mut CommunityRegistry,
) {
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow_mut(&mut registry.communities, community_id);
    assert!(table::contains(&community.members, member), EAccessDenied);
    
    let member_info = table::borrow_mut(&mut community.members, member);
    member_info.contribution_score = member_info.contribution_score + points;
}

// Remove member (organizer action)
public fun remove_member(
    community_id: ID,
    member_to_remove: address,
    reason: String,
    registry: &mut CommunityRegistry,
    ctx: &mut TxContext
) {
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow_mut(&mut registry.communities, community_id);
    assert!(community.organizer == tx_context::sender(ctx), ENotOrganizer);
    assert!(table::contains(&community.members, member_to_remove), EAccessDenied);
    
    table::remove(&mut community.members, member_to_remove);
    community.member_count = community.member_count - 1;
    
    // Update user memberships
    if (table::contains(&registry.user_memberships, member_to_remove)) {
        let memberships = table::borrow_mut(&mut registry.user_memberships, member_to_remove);
        let mut  i = 0;
        let len = vector::length(memberships);
        while (i < len) {
            let membership = vector::borrow_mut(memberships, i);
            if (membership.community_id == community_id) {
                membership.active = false;
                break
            };
            i = i + 1;
        };
    };
    
    event::emit(MemberRemoved {
        community_id,
        member: member_to_remove,
        reason,
    });
}

// Helper function to verify NFT eligibility
fun verify_nft_eligibility(
    user: address,
    event_id: ID,
    config: &AccessConfiguration,
    nft_registry: &NFTRegistry,
): bool {
    if (config.access_type == ACCESS_TYPE_POA) {
        nft_minting::has_proof_of_attendance(user, event_id, nft_registry)
    } else if (config.access_type == ACCESS_TYPE_COMPLETION) {
        nft_minting::has_completion_nft(user, event_id, nft_registry)
    } else if (config.access_type == ACCESS_TYPE_BOTH) {
        nft_minting::has_proof_of_attendance(user, event_id, nft_registry) ||
        nft_minting::has_completion_nft(user, event_id, nft_registry)
    } else {
        // Reject any other access type
        false
    }
}

// Get community details
public fun get_community_details(
    community_id: ID,
    registry: &CommunityRegistry
): (String, String, u64, bool, u8) {
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow(&registry.communities, community_id);
    (
        community.name,
        community.description,
        community.member_count,
        community.active,
        community.access_config.access_type
    )
}

// Get member info
public fun get_member_info(
    community_id: ID,
    member: address,
    registry: &CommunityRegistry
): (u64, u64, u64, u64) {
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow(&registry.communities, community_id);
    assert!(table::contains(&community.members, member), EAccessDenied);
    
    let info = table::borrow(&community.members, member);
    (
        info.joined_at,
        info.access_expires_at,
        info.contribution_score,
        info.last_active
    )
}

// Get user memberships
public fun get_user_memberships(
    user: address,
    registry: &CommunityRegistry
): vector<Membership> {
    if (!table::contains(&registry.user_memberships, user)) {
        return vector::empty()
    };
    
    *table::borrow(&registry.user_memberships, user)
}

// Check if user is member
public fun is_member(
    community_id: ID,
    user: address,
    registry: &CommunityRegistry
): bool {
    if (!table::contains(&registry.communities, community_id)) {
        return false
    };
    
    let community = table::borrow(&registry.communities, community_id);
    table::contains(&community.members, user)
}

// Get community features
public fun get_community_features(
    community_id: ID,
    registry: &CommunityRegistry
): CommunityFeatures {
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow(&registry.communities, community_id);
    community.features
}

public fun get_forum_enabled(features: &CommunityFeatures): bool {
    features.forum_enabled
}

public fun get_resource_sharing_enabled(features: &CommunityFeatures): bool {
    features.resource_sharing
}

public fun get_event_calendar_enabled(features: &CommunityFeatures): bool {
    features.event_calendar
}

public fun get_member_directory_enabled(features: &CommunityFeatures): bool {
    features.member_directory
}

public fun get_governance_enabled(features: &CommunityFeatures): bool {
    features.governance_enabled
}

public fun get_access_configuration(
    community_id: ID,
    registry: &CommunityRegistry
): (u8, bool, u64, u64) {
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow(&registry.communities, community_id);
    let config = &community.access_config;
    (
        config.access_type,
        config.require_nft_held,
        config.min_event_rating,
        config.expiry_duration
    )
}

public fun get_community_organizer(
    community_id: ID,
    registry: &CommunityRegistry
): address {
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow(&registry.communities, community_id);
    community.organizer
}

public fun get_community_event_id(
    community_id: ID,
    registry: &CommunityRegistry
): ID {
    assert!(table::contains(&registry.communities, community_id), ECommunityNotFound);
    
    let community = table::borrow(&registry.communities, community_id);
    community.event_id
}

// Test helper function
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}
