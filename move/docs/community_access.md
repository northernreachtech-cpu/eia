# EIA Community Access Contract Documentation

## Overview

The EIA Community Access contract enables event organizers to create token-gated communities based on event participation within the Ephemeral Identity & Attendance (EIA) Protocol. This contract manages community membership through NFT ownership verification, provides access control mechanisms, and facilitates ongoing engagement between event participants through exclusive community features.

## Module Information

- **Module**: `eia::community_access`
- **Network**: Sui Blockchain
- **Language**: Move
- **Dependencies**: `eia::event_management`, `eia::nft_minting`

## Core Data Structures

### CommunityRegistry
Central registry managing all communities and membership data.

```move
public struct CommunityRegistry has key {
    id: UID,
    communities: Table<ID, Community>,                    // community_id -> community
    event_communities: Table<ID, ID>,                     // event_id -> community_id
    user_memberships: Table<address, vector<Membership>>, // wallet -> memberships
}
```

### Community
Individual community with access rules and features.

```move
public struct Community has store {
    id: ID,                              // Unique community identifier
    event_id: ID,                        // Associated event
    name: String,                        // Community name
    description: String,                 // Community description
    organizer: address,                  // Community creator
    access_config: AccessConfiguration,  // Access rules
    members: Table<address, MemberInfo>, // Member data
    member_count: u64,                   // Total members
    created_at: u64,                     // Creation timestamp
    active: bool,                        // Community status
    metadata_uri: String,                // Link to community resources
    features: CommunityFeatures,         // Enabled features
}
```

### AccessConfiguration
Defines membership eligibility requirements.

```move
public struct AccessConfiguration has store, drop, copy {
    access_type: u8,                           // Required NFT type
    require_nft_held: bool,                    // Must currently hold NFT
    min_event_rating: u64,                     // Minimum rating given to event
    custom_requirements: vector<CustomRequirement>, // Additional requirements
    expiry_duration: u64,                      // Access duration (0 = permanent)
}
```

### CommunityFeatures
Available community functionality options.

```move
public struct CommunityFeatures has store, drop, copy {
    forum_enabled: bool,           // Discussion forums
    resource_sharing: bool,        // File and resource sharing
    event_calendar: bool,          // Community event calendar
    member_directory: bool,        // Member listing
    governance_enabled: bool,      // Community governance/voting
}
```

### MemberInfo
Individual member status and activity tracking.

```move
public struct MemberInfo has store, drop, copy {
    joined_at: u64,              // Join timestamp
    access_expires_at: u64,      // Expiration (0 = permanent)
    access_type_used: u8,        // NFT type used for access
    contribution_score: u64,     // Community contribution points
    last_active: u64,            // Last activity timestamp
}
```

### Membership
User's membership record.

```move
public struct Membership has store, drop, copy {
    community_id: ID,           // Community identifier
    event_id: ID,               // Original event
    joined_at: u64,             // Join timestamp
    expires_at: u64,            // Expiration timestamp
    active: bool,               // Membership status
}
```

### CommunityAccessPass
Verifiable access credential for community features.

```move
public struct CommunityAccessPass has key, store {
    id: UID,                    // Unique pass identifier
    community_id: ID,           // Associated community
    member: address,            // Pass holder
    issued_at: u64,             // Issue timestamp
    expires_at: u64,            // Expiration timestamp
}
```

### CustomRequirement
Additional eligibility criteria.

```move
public struct CustomRequirement has store, drop, copy {
    requirement_type: String,   // Requirement name
    value: u64,                 // Required value/threshold
}
```

## Access Types

| Type | Value | Description |
|------|-------|-------------|
| `ACCESS_TYPE_POA` | 0 | Requires Proof-of-Attendance NFT |
| `ACCESS_TYPE_COMPLETION` | 1 | Requires Completion NFT |
| `ACCESS_TYPE_BOTH` | 2 | Accepts either PoA or Completion NFT |

## Error Codes

| Error | Code | Description |
|-------|------|-------------|
| `ENotOrganizer` | 1 | Caller is not the event organizer |
| `ECommunityNotFound` | 2 | Community does not exist |
| `EAlreadyMember` | 3 | User is already a community member |
| `ENotEligible` | 4 | User does not meet access requirements |
| `EAccessDenied` | 5 | Access denied for this operation |
| `ECommunityNotActive` | 6 | Community is not active |
| `EAlreadyExists` | 7 | Community already exists for this event |

## Public Functions

### Community Creation and Management

#### `create_community`
Creates a new token-gated community for an event.

```move
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
): ID
```

**Parameters:**
- `event`: Reference to the event object
- `name`: Community name
- `description`: Community description
- `access_type`: Required NFT type (0=PoA, 1=Completion, 2=Both)
- `require_nft_held`: Whether NFT must be currently held
- `min_event_rating`: Minimum rating user gave to event
- `expiry_duration`: Access duration in milliseconds (0 = permanent)
- `metadata_uri`: Link to community resources/content
- `forum_enabled`: Enable discussion forums
- `resource_sharing`: Enable file/resource sharing
- `event_calendar`: Enable community event calendar
- `member_directory`: Enable member directory
- `governance_enabled`: Enable community governance features
- `registry`: Mutable reference to community registry
- `clock`: System clock reference
- `ctx`: Transaction context

**Returns:** `ID` - The created community's identifier

**Authorization:** Only event organizer can create communities

**Validation:**
- Only one community per event allowed
- Caller must be event organizer
- Event must exist and be valid

**Frontend Usage:**
```typescript
const tx = new Transaction();
const communityId = tx.moveCall({
    target: `${PACKAGE_ID}::community_access::create_community`,
    arguments: [
        tx.object(EVENT_ID),
        tx.pure.string("Tech Conference Alumni"),
        tx.pure.string("Exclusive community for conference attendees"),
        tx.pure.u8(2), // Accept both PoA and Completion NFTs
        tx.pure.bool(true), // Must currently hold NFT
        tx.pure.u64(400), // Minimum 4.0 rating given to event
        tx.pure.u64(0), // Permanent access
        tx.pure.string("https://walrus.example/community-resources"),
        tx.pure.bool(true), // Forum enabled
        tx.pure.bool(true), // Resource sharing enabled
        tx.pure.bool(true), // Event calendar enabled
        tx.pure.bool(true), // Member directory enabled
        tx.pure.bool(false), // Governance disabled
        tx.object(COMMUNITY_REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});
```

#### `add_custom_requirement`
Adds custom eligibility requirements to a community.

```move
public fun add_custom_requirement(
    community_id: ID,
    requirement_type: String,
    value: u64,
    registry: &mut CommunityRegistry,
    ctx: &mut TxContext
)
```

**Authorization:** Only community organizer can add requirements

**Example Custom Requirements:**
- "min_attendance_duration": Minimum event attendance time
- "min_contribution_score": Minimum community contribution points
- "max_members": Maximum community size
- "referral_required": Requires existing member referral

### Access Management

#### `request_access`
Requests membership in a community (user-initiated).

```move
public fun request_access(
    community_id: ID,
    registry: &mut CommunityRegistry,
    nft_registry: &NFTRegistry,
    clock: &Clock,
    ctx: &mut TxContext
): CommunityAccessPass
```

**Returns:** `CommunityAccessPass` - Access credential for community features

**Validation Process:**
1. **Community Verification**: Ensures community exists and is active
2. **Duplicate Check**: Prevents multiple memberships
3. **NFT Verification**: Validates required NFT ownership
4. **Custom Requirements**: Checks additional eligibility criteria
5. **Access Pass Generation**: Creates verifiable access credential

**Frontend Usage:**
```typescript
const tx = new Transaction();
const [accessPass] = tx.moveCall({
    target: `${PACKAGE_ID}::community_access::request_access`,
    arguments: [
        tx.pure.id(communityId),
        tx.object(COMMUNITY_REGISTRY_ID),
        tx.object(NFT_REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});

tx.transferObjects([accessPass], tx.pure.address(userWallet));
```

#### `verify_access`
Verifies a user's access pass for community features.

```move
public fun verify_access(
    pass: &CommunityAccessPass,
    registry: &CommunityRegistry,
    clock: &Clock,
): bool
```

**Returns:** `bool` - Whether access is currently valid

#### `update_member_activity`
Updates member's last activity timestamp.

```move
public fun update_member_activity(
    community_id: ID,
    registry: &mut CommunityRegistry,
    clock: &Clock,
    ctx: &mut TxContext
)
```

#### `update_contribution_score`
Updates member's community contribution score.

```move
public fun update_contribution_score(
    community_id: ID,
    member: address,
    points: u64,
    registry: &mut CommunityRegistry,
)
```

**Note:** Typically called by other contracts or community management systems

### Member Management

#### `remove_member`
Removes a member from the community (organizer action).

```move
public fun remove_member(
    community_id: ID,
    member_to_remove: address,
    reason: String,
    registry: &mut CommunityRegistry,
    ctx: &mut TxContext
)
```

**Authorization:** Only community organizer can remove members

### Query Functions (Read-Only)

#### `get_community_details`
Gets basic community information.

```move
public fun get_community_details(
    community_id: ID,
    registry: &CommunityRegistry
): (String, String, u64, bool, u8)
```

**Returns:** `(String, String, u64, bool, u8)` - Name, description, member count, active status, access type

#### `get_member_info`
Gets detailed member information.

```move
public fun get_member_info(
    community_id: ID,
    member: address,
    registry: &CommunityRegistry
): (u64, u64, u64, u64)
```

**Returns:** `(u64, u64, u64, u64)` - Join timestamp, expiration, contribution score, last active

#### `get_user_memberships`
Gets all communities a user belongs to.

```move
public fun get_user_memberships(
    user: address,
    registry: &CommunityRegistry
): vector<Membership>
```

#### `is_member`
Checks if a user is a community member.

```move
public fun is_member(
    community_id: ID,
    user: address,
    registry: &CommunityRegistry
): bool
```

#### `get_community_features`
Gets enabled community features.

```move
public fun get_community_features(
    community_id: ID,
    registry: &CommunityRegistry
): CommunityFeatures
```

#### Feature Access Functions
Individual feature checking functions:

```move
public fun get_forum_enabled(features: &CommunityFeatures): bool
public fun get_resource_sharing_enabled(features: &CommunityFeatures): bool
public fun get_event_calendar_enabled(features: &CommunityFeatures): bool
public fun get_member_directory_enabled(features: &CommunityFeatures): bool
public fun get_governance_enabled(features: &CommunityFeatures): bool
```

#### `get_access_configuration`
Gets community access requirements.

```move
public fun get_access_configuration(
    community_id: ID,
    registry: &CommunityRegistry
): (u8, bool, u64, u64)
```

**Returns:** `(u8, bool, u64, u64)` - Access type, require NFT held, min rating, expiry duration

#### `get_community_organizer`
Gets community organizer address.

```move
public fun get_community_organizer(
    community_id: ID,
    registry: &CommunityRegistry
): address
```

#### `get_community_event_id`
Gets the event ID associated with a community.

```move
public fun get_community_event_id(
    community_id: ID,
    registry: &CommunityRegistry
): ID
```

## Events Emitted

### CommunityCreated
```move
public struct CommunityCreated has copy, drop {
    community_id: ID,
    event_id: ID,
    name: String,
    access_type: u8,
}
```

### MemberJoined
```move
public struct MemberJoined has copy, drop {
    community_id: ID,
    member: address,
    joined_at: u64,
    access_type_used: u8,
}
```

### AccessGranted
```move
public struct AccessGranted has copy, drop {
    community_id: ID,
    member: address,
    pass_id: ID,
    expires_at: u64,
}
```

### MemberRemoved
```move
public struct MemberRemoved has copy, drop {
    community_id: ID,
    member: address,
    reason: String,
}
```

## Frontend Integration Examples

### Create Community
```typescript
const tx = new Transaction();
const communityId = tx.moveCall({
    target: `${PACKAGE_ID}::community_access::create_community`,
    arguments: [
        tx.object(eventId),
        tx.pure.string(name),
        tx.pure.string(description),
        tx.pure.u8(accessType),
        tx.pure.bool(requireNftHeld),
        tx.pure.u64(minRating * 100),
        tx.pure.u64(expiryDuration),
        tx.pure.string(metadataUri),
        tx.pure.bool(enableForum),
        tx.pure.bool(enableResources),
        tx.pure.bool(enableCalendar),
        tx.pure.bool(enableDirectory),
        tx.pure.bool(enableGovernance),
        tx.object(COMMUNITY_REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});
```

### Request Access
```typescript
const tx = new Transaction();
const [accessPass] = tx.moveCall({
    target: `${PACKAGE_ID}::community_access::request_access`,
    arguments: [
        tx.pure.id(communityId),
        tx.object(COMMUNITY_REGISTRY_ID),
        tx.object(NFT_REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});
tx.transferObjects([accessPass], tx.pure.address(userWallet));
```

### Query Community
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::community_access::get_community_details`,
    arguments: [
        tx.pure.id(communityId),
        tx.object(COMMUNITY_REGISTRY_ID),
    ],
});

const result = await client.devInspectTransactionBlock({
    transactionBlock: tx,
    sender: userWallet,
});
```

## Integration with Other Contracts

### NFT Minting Contract
- **Eligibility Verification**: Validates NFT ownership for community access
- **Token Gating**: Enforces NFT requirements for different access types
- **Ownership Validation**: Ensures users still hold required NFTs

### Event Management Contract
- **Event Association**: Links communities to specific events
- **Organizer Verification**: Validates community creator is event organizer
- **Event Completion**: Ensures communities can only be created for valid events

### Rating Reputation Contract
- **Rating Requirements**: Validates minimum event ratings for access
- **Quality Control**: Ensures only engaged participants can join communities
- **Community Standards**: Maintains community quality through rating thresholds

## Best Practices

### For Event Organizers
1. **Set Clear Access Requirements**: Define specific, achievable eligibility criteria
2. **Choose Appropriate Features**: Enable features that match community goals
3. **Monitor Community Health**: Track member activity and contribution scores
4. **Maintain Active Moderation**: Remove inactive or problematic members when necessary
5. **Provide Value**: Ensure community offers genuine benefits to members

### For Community Members
1. **Meet Requirements**: Ensure you have required NFTs before requesting access
2. **Stay Active**: Regular participation maintains community health
3. **Contribute Positively**: Build contribution score through helpful participation
4. **Respect Guidelines**: Follow community rules and standards
5. **Engage Meaningfully**: Use available features to build relationships

### For Frontend Developers
1. **Validate Eligibility**: Check requirements before allowing access requests
2. **Handle Access Passes**: Properly manage and verify community access credentials
3. **Real-Time Updates**: Subscribe to events for live community activity
4. **Feature Detection**: Check enabled features before displaying functionality
5. **Error Handling**: Implement comprehensive error handling for all operations

## Security Considerations

### Access Control
1. **NFT Verification**: Validates genuine NFT ownership for access
2. **Organizer Authority**: Only event organizers can create and manage communities
3. **Time-Based Access**: Supports expiring memberships for time-limited access
4. **Single Community**: Only one community per event prevents fragmentation

### Member Protection
1. **Removal Transparency**: Member removals require documented reasons
2. **Access Pass Integrity**: Cryptographic verification of access credentials
3. **Activity Tracking**: Monitors member engagement for community health
4. **Contribution Scoring**: Rewards positive community participation

## Limitations and Considerations

1. **Single Community Per Event**: Each event can only have one associated community
2. **NFT Dependency**: Access requires ownership of specific event NFTs
3. **Organizer Control**: Community organizers have significant control over membership
4. **Feature Immutability**: Community features cannot be changed after creation
5. **Permanent Decisions**: Some community actions (like member removal) are irreversible

## Future Enhancements

### Planned Features
1. **Governance Systems**: On-chain voting and decision-making mechanisms
2. **Multi-Event Communities**: Communities spanning multiple related events
3. **Reputation Systems**: Cross-community reputation and achievement tracking
4. **Tiered Access**: Different access levels within communities
5. **Automated Moderation**: Smart contract-based community moderation

### Integration Opportunities
1. **DeFi Integration**: Community treasury management and rewards
2. **Cross-Chain Communities**: Multi-blockchain community participation
3. **Social Features**: Enhanced social interaction and networking tools
4. **Content Management**: Decentralized content creation and curation
5. **Marketplace Integration**: Community-exclusive marketplace access

This contract provides a comprehensive foundation for building token-gated communities within the EIA Protocol, enabling lasting engagement between event participants while ensuring only genuine attendees gain access through verifiable NFT ownership and transparent eligibility criteria.