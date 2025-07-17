# EIA Identity Access Contract Documentation

## Overview

The EIA Identity Access contract manages ephemeral access passes and user registration for events within the Ephemeral Identity & Attendance (EIA) Protocol. This contract provides secure, time-limited access passes without storing persistent user identity data, ensuring privacy while enabling verifiable event attendance.

## Module Information

- **Module**: `eia::identity_access`
- **Network**: Sui Blockchain
- **Language**: Move
- **Dependencies**: `eia::event_management`

## Core Data Structures

### RegistrationRegistry
Central registry for managing all event registrations and pass mappings.

```move
public struct RegistrationRegistry has key {
    id: UID,
    event_registrations: Table<ID, EventRegistrations>,  // event_id -> registrations
    user_registrations: Table<address, vector<ID>>,      // wallet -> registered events
}
```

### EventRegistrations
Stores all registration data for a specific event.

```move
public struct EventRegistrations has store {
    registrations: Table<address, Registration>,         // wallet -> registration
    pass_mappings: Table<vector<u8>, PassInfo>,         // pass_hash -> pass info
    total_registered: u64,                              // Total registrations count
}
```

### Registration
Individual user registration record for an event.

```move
public struct Registration has store, drop, copy {
    wallet: address,           // User's wallet address
    registered_at: u64,        // Registration timestamp (ms)
    pass_hash: vector<u8>,     // Current pass hash
    checked_in: bool,          // Check-in status
}
```

### PassInfo
Ephemeral access pass information with time-based validity.

```move
public struct PassInfo has store, drop, copy {
    wallet: address,       // Pass owner's wallet
    event_id: ID,         // Associated event ID
    created_at: u64,      // Pass creation timestamp (ms)
    expires_at: u64,      // Pass expiration timestamp (ms)
    used: bool,           // Whether pass has been used
    pass_id: u64,         // Unique pass identifier
}
```

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `PASS_VALIDITY_DURATION` | 86400000 | Pass validity duration (24 hours in milliseconds) |

## Error Codes

| Error | Code | Description |
|-------|------|-------------|
| `EEventNotActive` | 1 | Event is not in active state |
| `EAlreadyRegistered` | 2 | User is already registered for this event |
| `ECapacityReached` | 6 | Event has reached maximum capacity |
| `ENotRegistered` | 7 | User is not registered for this event |

## Public Functions

### Registration Management

#### `register_for_event`
Registers a user for an event and generates an ephemeral access pass.

```move
public fun register_for_event(
    event: &mut Event,
    registry: &mut RegistrationRegistry,
    clock: &Clock,
    ctx: &mut TxContext
)
```

**Parameters:**
- `event`: Mutable reference to the event object
- `registry`: Mutable reference to registration registry
- `clock`: System clock reference
- `ctx`: Transaction context

**Validation:**
- Event must be active
- Event must not be at capacity
- User must not already be registered

**Process:**
1. Validates event state and capacity
2. Creates unique pass ID and hash
3. Stores registration record
4. Updates user's event list
5. Generates time-limited access pass
6. Emits `UserRegistered` and `PassGenerated` events

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::identity_access::register_for_event`,
    arguments: [
        tx.object(EVENT_ID),
        tx.object(REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});
```

#### `regenerate_pass`
Generates a new ephemeral pass for an already registered user.

```move
public fun regenerate_pass(
    event: &Event,
    registry: &mut RegistrationRegistry,
    clock: &Clock,
    ctx: &mut TxContext
)
```

**Use Cases:**
- Pass has expired
- Pass was compromised
- User needs fresh access credentials

**Process:**
1. Validates user is registered
2. Removes old pass mapping
3. Generates new pass with fresh expiration
4. Updates registration record
5. Emits `PassGenerated` event

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::identity_access::regenerate_pass`,
    arguments: [
        tx.object(EVENT_ID),
        tx.object(REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});
```

### Pass Validation

#### `validate_pass`
Validates an ephemeral pass and marks it as used (called by verifier systems).

```move
public fun validate_pass(
    pass_hash: vector<u8>,
    event_id: ID,
    registry: &mut RegistrationRegistry,
    clock: &Clock,
): (bool, address)
```

**Parameters:**
- `pass_hash`: Hash of the ephemeral pass to validate
- `event_id`: ID of the event
- `registry`: Mutable reference to registration registry
- `clock`: System clock reference

**Returns:** `(bool, address)` - Validation success and wallet address

**Validation Checks:**
- Pass exists in registry
- Pass has not been used
- Pass has not expired
- Event exists

**Frontend Usage:**
```typescript
const tx = new Transaction();
const [isValid, wallet] = tx.moveCall({
    target: `${PACKAGE_ID}::identity_access::validate_pass`,
    arguments: [
        tx.pure(bcs.vector(bcs.U8).serialize(passHash)),
        tx.pure.id(eventId),
        tx.object(REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});
```

### Integration Functions

#### `mark_checked_in`
Marks a user as checked in (called by attendance contract).

```move
public fun mark_checked_in(
    wallet: address,
    event_id: ID,
    registry: &mut RegistrationRegistry,
)
```

**Note:** This function is typically called by other contracts in the EIA protocol, not directly by frontend applications.

### Query Functions (Read-Only)

#### `is_registered`
Checks if a wallet is registered for an event.

```move
public fun is_registered(
    wallet: address,
    event_id: ID,
    registry: &RegistrationRegistry,
): bool
```

**Frontend Usage:**
```typescript
// Query using SuiClient (read-only)
const isRegistered = await suiClient.devInspectTransactionBlock({
    transactionBlock: tx,
    sender: wallet,
});
```

#### `get_registration`
Gets registration details for a specific user and event.

```move
public fun get_registration(
    wallet: address,
    event_id: ID,
    registry: &RegistrationRegistry,
): (u64, bool)
```

**Returns:** `(u64, bool)` - Registration timestamp and check-in status

#### `get_user_events`
Gets all events a user is registered for.

```move
public fun get_user_events(
    wallet: address,
    registry: &RegistrationRegistry,
): vector<ID>
```

**Returns:** Vector of event IDs the user is registered for

## Events Emitted

### UserRegistered
```move
public struct UserRegistered has copy, drop {
    event_id: ID,
    wallet: address,
    registered_at: u64,
}
```

### PassGenerated
```move
public struct PassGenerated has copy, drop {
    event_id: ID,
    wallet: address,
    pass_id: u64,
    expires_at: u64,
}
```

### PassValidated
```move
public struct PassValidated has copy, drop {
    event_id: ID,
    wallet: address,
    pass_id: u64,
}
```

## Security Features

### Ephemeral Pass System
- **Time-Limited**: Passes expire after 24 hours
- **Single-Use**: Each pass can only be validated once
- **Cryptographic**: Uses Keccak256 hashing for pass generation
- **Non-Transferable**: Passes are tied to specific wallet addresses

### Privacy Protection
- **No PII Storage**: Only wallet addresses are stored
- **Ephemeral Design**: Pass data is temporary and tied to events
- **Hash-Based**: Pass validation uses cryptographic hashes

### Access Control
- **Event State Validation**: Only active events accept registrations
- **Capacity Limits**: Respects event capacity constraints
- **Duplicate Prevention**: Prevents multiple registrations per user

## Frontend Integration Examples

### Complete Registration Flow
```typescript
import { Transaction } from '@mysten/sui/transactions';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { bcs } from '@mysten/sui/bcs';

const client = new SuiClient({ url: getFullnodeUrl('testnet') });

// 1. Check if user is already registered
async function checkRegistration(wallet: string, eventId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::identity_access::is_registered`,
        arguments: [
            tx.pure.address(wallet),
            tx.pure.id(eventId),
            tx.object(REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: wallet,
    });
    
    return result.effects?.status?.status === 'success';
}

// 2. Register for event
async function registerForEvent(eventId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::identity_access::register_for_event`,
        arguments: [
            tx.object(eventId),
            tx.object(REGISTRY_ID),
            tx.object(CLOCK_ID),
        ],
    });
    
    const result = await wallet.signAndExecuteTransactionBlock({
        transactionBlock: tx,
    });
    
    return result;
}

// 3. Get user's events
async function getUserEvents(wallet: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::identity_access::get_user_events`,
        arguments: [
            tx.pure.address(wallet),
            tx.object(REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: wallet,
    });
    
    return result;
}

// 4. Regenerate expired pass
async function regeneratePass(eventId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::identity_access::regenerate_pass`,
        arguments: [
            tx.object(eventId),
            tx.object(REGISTRY_ID),
            tx.object(CLOCK_ID),
        ],
    });
    
    return await wallet.signAndExecuteTransactionBlock({
        transactionBlock: tx,
    });
}
```

### Event Subscription for Real-Time Updates
```typescript
// Listen for registration events
client.subscribeEvent({
    filter: {
        MoveEventType: `${PACKAGE_ID}::identity_access::UserRegistered`,
    },
    onMessage: (event) => {
        console.log('User registered:', event.parsedJson);
        // Update UI with new registration
    },
});

// Listen for pass generation
client.subscribeEvent({
    filter: {
        MoveEventType: `${PACKAGE_ID}::identity_access::PassGenerated`,
    },
    onMessage: (event) => {
        console.log('Pass generated:', event.parsedJson);
        // Store pass information securely
    },
});

// Listen for pass validation
client.subscribeEvent({
    filter: {
        MoveEventType: `${PACKAGE_ID}::identity_access::PassValidated`,
    },
    onMessage: (event) => {
        console.log('Pass validated:', event.parsedJson);
        // Update attendance tracking
    },
});
```

### Error Handling
```typescript
async function safeRegisterForEvent(eventId: string) {
    try {
        const tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::identity_access::register_for_event`,
            arguments: [
                tx.object(eventId),
                tx.object(REGISTRY_ID),
                tx.object(CLOCK_ID),
            ],
        });

        const result = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx,
            options: {
                showEffects: true,
                showEvents: true,
            },
        });

        if (result.effects?.status?.status === 'failure') {
            const error = result.effects.status.error;
            switch (error) {
                case 'EEventNotActive':
                    throw new Error('Event is not currently active for registration');
                case 'EAlreadyRegistered':
                    throw new Error('You are already registered for this event');
                case 'ECapacityReached':
                    throw new Error('Event has reached maximum capacity');
                default:
                    throw new Error(`Registration failed: ${error}`);
            }
        }

        return result;
    } catch (error) {
        console.error('Registration error:', error);
        throw error;
    }
}
```

## Pass Generation and Validation

### Pass ID Generation
The system generates unique pass IDs using:
- User wallet address
- Event ID
- Registration timestamp
- Keccak256 hash function

### Pass Hash Creation
Pass hashes are created from:
- Pass ID
- Event ID
- Wallet address
- Cryptographic hashing for security

### Validation Process
1. Pass hash is provided to validator
2. System checks pass exists and is valid
3. Validates expiration time (24 hours)
4. Ensures pass hasn't been used
5. Marks pass as used upon successful validation
6. Returns validation result and wallet address

## Integration with Other Contracts

This contract integrates with:
- **Event Management Contract**: Validates event state and capacity
- **Attendance Contract**: Provides check-in status updates
- **Verification Systems**: External QR code scanners and validators

## Best Practices

### For Frontend Developers
1. **Always check registration status** before attempting to register
2. **Monitor pass expiration** and offer regeneration when needed
3. **Handle capacity limits** gracefully with user feedback
4. **Store pass information securely** on the client side
5. **Subscribe to events** for real-time updates

### For Security
1. **Validate passes server-side** for critical operations
2. **Implement rate limiting** on registration attempts
3. **Monitor for suspicious activity** patterns
4. **Use HTTPS** for all pass-related communications
5. **Clear expired passes** from client storage

## Limitations and Considerations

1. **24-Hour Pass Validity**: Passes expire after 24 hours and must be regenerated
2. **Single Event Registration**: Users can only register once per event
3. **No Pass Transfer**: Passes are tied to specific wallet addresses
4. **Capacity Constraints**: Registration fails when event capacity is reached
5. **Active Event Requirement**: Only active events accept new registrations

This contract provides a secure, privacy-preserving foundation for event registration and access control within the EIA Protocol ecosystem.