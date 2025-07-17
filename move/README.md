# EIA Protocol - Frontend Integration Guide

## Getting Started with Move Module Integration

This guide helps frontend developers understand which Move modules to integrate first and in what order to build a functional EIA Protocol application.

## Integration Priority Order

### Phase 1: Core Event Management (Start Here)
**Modules to integrate:**
1. `event_management`
2. `identity_access`

**Why start here:**
- These two modules form the foundation of the entire protocol
- You can build a basic event creation and registration flow
- No dependencies on other modules for basic functionality

**Key features to implement:**
- Organizer onboarding (profile creation)
- Event creation and management
- Event discovery and browsing
- User registration for events
- QR code generation for event passes

### Phase 2: Event Attendance
**Modules to integrate:**
3. `attendance_verification`
4. `nft_minting`

**Why this order:**
- Attendance verification directly depends on identity_access
- NFT minting is triggered by attendance actions
- These complete the core event experience

**Key features to implement:**
- QR code scanning interface
- Check-in/check-out flows
- Real-time attendance tracking
- NFT gallery for attendees
- Attendance certificates

### Phase 3: Post-Event Features
**Modules to integrate:**
5. `rating_reputation`
6. `escrow_settlement`

**Why this order:**
- Ratings can only happen after event completion
- Escrow settlement depends on ratings and attendance data
- These modules handle post-event workflows

**Key features to implement:**
- Event rating interface
- Organizer reputation display
- Sponsor dashboard
- Settlement status tracking
- Performance metrics visualization

### Phase 4: Engagement & Rewards
**Modules to integrate:**
7. `airdrop_distribution`
8. `community_access`

**Why save for last:**
- These are value-add features, not core functionality
- They depend on NFT ownership from earlier phases
- Can be rolled out as engagement features

**Key features to implement:**
- Airdrop claiming interface
- Reward distribution tracking
- Token-gated community spaces
- Member directories
- Community features

## Recommended Development Approach

### 1. Start with Read Operations
Begin by implementing read-only features:
- Event browsing
- Organizer profiles
- Registration status checks

### 2. Add Write Operations
Then add interactive features:
- Event creation
- Registration
- Check-in/out

### 3. Implement Real-time Updates
Add websocket or polling for:
- Attendance counts
- Registration status
- Airdrop availability

## Module Dependencies Chart

```
event_management (standalone)
    ↓
identity_access (depends on: event_management)
    ↓
attendance_verification (depends on: event_management, identity_access)
    ↓                      ↓
nft_minting              rating_reputation
    ↓                      ↓
community_access      escrow_settlement
                          ↓
                   airdrop_distribution
```

## Critical Integration Points

### 1. Shared Objects You'll Query Often
- `EventRegistry` - All events and discovery
- `RegistrationRegistry` - User registrations
- `AttendanceRegistry` - Check-in status
- `NFTRegistry` - Minted tokens

### 2. User Flow Dependencies
- **Registration** → **Check-in** → **NFT Minting** → **Rating**
- **Event Creation** → **Escrow Setup** → **Settlement**
- **NFT Ownership** → **Community Access** → **Airdrop Eligibility**

### 3. Time-Sensitive Operations
- Pass generation (24-hour expiry)
- Rating periods (7 days post-event)
- Airdrop claiming windows
- Event state transitions


