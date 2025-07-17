# EIA Attendance Verification Contract Documentation

## Overview

The EIA Attendance Verification contract manages the check-in and check-out process for event attendees within the Ephemeral Identity & Attendance (EIA) Protocol. This contract validates ephemeral passes, tracks attendance status, implements fraud detection mechanisms, and generates capabilities for NFT minting upon attendance milestones.

## Module Information

- **Module**: `eia::attendance_verification`
- **Network**: Sui Blockchain
- **Language**: Move
- **Dependencies**: `eia::event_management`, `eia::identity_access`

## Core Data Structures

### AttendanceRegistry
Central registry for managing all attendance records and statistics.

```move
public struct AttendanceRegistry has key {
    id: UID,
    event_attendances: Table<ID, EventAttendance>,        // event_id -> attendances
    user_attendances: Table<address, vector<AttendanceRecord>>, // wallet -> records
}
```

### EventAttendance
Tracks attendance data and fraud detection for a specific event.

```move
public struct EventAttendance has store {
    records: Table<address, AttendanceRecord>,    // Individual attendance records
    check_in_count: u64,                         // Total check-ins
    check_out_count: u64,                        // Total check-outs
    unique_devices: Table<vector<u8>, bool>,     // Device fingerprint tracking
}
```

### AttendanceRecord
Individual attendance record with timestamps and security data.

```move
public struct AttendanceRecord has store, drop, copy {
    event_id: ID,                    // Associated event
    wallet: address,                 // Attendee's wallet
    state: u8,                      // Current attendance state (0-2)
    check_in_time: u64,             // Check-in timestamp (ms)
    check_out_time: u64,            // Check-out timestamp (ms)
    device_fingerprint: vector<u8>, // Device identification
    location_proof: vector<u8>,     // Encrypted location data
}
```

### NFT Minting Capabilities

#### MintPoACapability
Capability granted upon check-in for Proof-of-Attendance NFT minting.

```move
public struct MintPoACapability has key, store {
    id: UID,
    event_id: ID,
    wallet: address,
    check_in_time: u64,
}
```

#### MintCompletionCapability
Capability granted upon check-out for Completion NFT minting.

```move
public struct MintCompletionCapability has key, store {
    id: UID,
    event_id: ID,
    wallet: address,
    check_in_time: u64,
    check_out_time: u64,
    attendance_duration: u64,
}
```

## Constants

### Attendance States
| State | Value | Description |
|-------|-------|-------------|
| `STATE_REGISTERED` | 0 | User registered but not checked in |
| `STATE_CHECKED_IN` | 1 | User has checked in to event |
| `STATE_CHECKED_OUT` | 2 | User has checked out of event |

## Error Codes

| Error | Code | Description |
|-------|------|-------------|
| `EEventNotActive` | 1 | Event is not in active state |
| `EAlreadyCheckedIn` | 3 | User is already checked in |
| `ENotCheckedIn` | 4 | User has not checked in |
| `EInvalidPass` | 5 | Invalid or expired access pass |
| `ECheckOutBeforeCheckIn` | 7 | Attempting to check out without checking in |

## Public Functions

### Attendance Management

#### `check_in`
Processes attendee check-in with pass validation and fraud detection.

```move
public fun check_in(
    pass_hash: vector<u8>,
    device_fingerprint: vector<u8>,
    location_proof: vector<u8>,
    event: &mut Event,
    attendance_registry: &mut AttendanceRegistry,
    identity_registry: &mut RegistrationRegistry,
    clock: &Clock,
    ctx: &mut TxContext
): MintPoACapability
```

**Parameters:**
- `pass_hash`: Ephemeral pass hash for validation
- `device_fingerprint`: Device identification for fraud detection
- `location_proof`: Encrypted location data for verification
- `event`: Mutable reference to event object
- `attendance_registry`: Mutable reference to attendance registry
- `identity_registry`: Mutable reference to identity registry
- `clock`: System clock reference
- `ctx`: Transaction context

**Returns:** `MintPoACapability` - Capability for minting Proof-of-Attendance NFT

**Process:**
1. Validates event is active
2. Validates ephemeral pass and extracts wallet
3. Performs fraud detection on device fingerprint
4. Creates attendance record with timestamps
5. Updates event attendee count
6. Marks user as checked in identity registry
7. Returns capability for NFT minting
8. Emits `AttendeeCheckedIn` event

**Security Features:**
- **Pass Validation**: Ensures only valid, non-expired passes work
- **Duplicate Prevention**: Prevents multiple check-ins
- **Device Tracking**: Detects suspicious device reuse
- **Location Proof**: Optional location verification

**Frontend Usage:**
```typescript
const tx = new Transaction();
const [mintCap] = tx.moveCall({
    target: `${PACKAGE_ID}::attendance_verification::check_in`,
    arguments: [
        tx.pure(bcs.vector(bcs.U8).serialize(passHash)),
        tx.pure(bcs.vector(bcs.U8).serialize(deviceFingerprint)),
        tx.pure(bcs.vector(bcs.U8).serialize(locationProof)),
        tx.object(EVENT_ID),
        tx.object(ATTENDANCE_REGISTRY_ID),
        tx.object(IDENTITY_REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});

// Transfer capability to NFT contract or user
tx.transferObjects([mintCap], userAddress);
```

#### `check_out`
Processes attendee check-out and calculates attendance duration.

```move
public fun check_out(
    wallet: address,
    event_id: ID,
    attendance_registry: &mut AttendanceRegistry,
    clock: &Clock,
    ctx: &mut TxContext
): MintCompletionCapability
```

**Parameters:**
- `wallet`: Attendee's wallet address
- `event_id`: Event identifier
- `attendance_registry`: Mutable reference to attendance registry
- `clock`: System clock reference
- `ctx`: Transaction context

**Returns:** `MintCompletionCapability` - Capability for minting Completion NFT

**Process:**
1. Validates user is checked in
2. Calculates attendance duration
3. Updates attendance record to checked-out state
4. Updates event statistics
5. Returns capability for completion NFT
6. Emits `AttendeeCheckedOut` event

**Frontend Usage:**
```typescript
const tx = new Transaction();
const [completionCap] = tx.moveCall({
    target: `${PACKAGE_ID}::attendance_verification::check_out`,
    arguments: [
        tx.pure.address(userWallet),
        tx.pure.id(eventId),
        tx.object(ATTENDANCE_REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});

// Transfer capability to NFT contract or user
tx.transferObjects([completionCap], userAddress);
```

### Query Functions (Read-Only)

#### `get_attendance_status`
Gets current attendance status for a user at an event.

```move
public fun get_attendance_status(
    wallet: address,
    event_id: ID,
    attendance_registry: &AttendanceRegistry,
): (bool, u8, u64, u64)
```

**Returns:** `(bool, u8, u64, u64)` - Has record, state, check-in time, check-out time

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::attendance_verification::get_attendance_status`,
    arguments: [
        tx.pure.address(userWallet),
        tx.pure.id(eventId),
        tx.object(ATTENDANCE_REGISTRY_ID),
    ],
});

const result = await client.devInspectTransactionBlock({
    transactionBlock: tx,
    sender: userWallet,
});
```

#### `get_event_stats`
Gets comprehensive statistics for an event.

```move
public fun get_event_stats(
    event_id: ID,
    attendance_registry: &AttendanceRegistry,
): (u64, u64, u64)
```

**Returns:** `(u64, u64, u64)` - Check-in count, check-out count, completion rate (basis points)

**Note:** Completion rate is returned in basis points (e.g., 8500 = 85.00%)

#### `get_user_attendance_history`
Gets complete attendance history for a user across all events.

```move
public fun get_user_attendance_history(
    wallet: address,
    attendance_registry: &AttendanceRegistry,
): vector<AttendanceRecord>
```

**Returns:** Vector of all attendance records for the user

#### `verify_attendance_completion`
Verifies if a user completed attendance (checked in and out) for rating eligibility.

```move
public fun verify_attendance_completion(
    wallet: address,
    event_id: ID,
    attendance_registry: &AttendanceRegistry,
): bool
```

**Returns:** `bool` - Whether user completed full attendance cycle

### Capability Management

#### `get_poa_capability_data`
Extracts data from Proof-of-Attendance capability.

```move
public fun get_poa_capability_data(cap: &MintPoACapability): (ID, address, u64)
```

**Returns:** `(ID, address, u64)` - Event ID, wallet, check-in time

#### `get_completion_capability_data`
Extracts data from Completion capability.

```move
public fun get_completion_capability_data(cap: &MintCompletionCapability): (ID, address, u64, u64, u64)
```

**Returns:** `(ID, address, u64, u64, u64)` - Event ID, wallet, check-in time, check-out time, duration

#### `consume_poa_capability`
Consumes PoA capability and returns data (called by NFT contract).

```move
public fun consume_poa_capability(cap: MintPoACapability): (ID, address, u64)
```

#### `consume_completion_capability`
Consumes completion capability and returns data (called by NFT contract).

```move
public fun consume_completion_capability(cap: MintCompletionCapability): (ID, address, u64, u64, u64)
```

## Events Emitted

### AttendeeCheckedIn
```move
public struct AttendeeCheckedIn has copy, drop {
    event_id: ID,
    wallet: address,
    check_in_time: u64,
}
```

### AttendeeCheckedOut
```move
public struct AttendeeCheckedOut has copy, drop {
    event_id: ID,
    wallet: address,
    check_out_time: u64,
    attendance_duration: u64,
}
```

### FraudAttemptDetected
```move
public struct FraudAttemptDetected has copy, drop {
    event_id: ID,
    wallet: address,
    reason: String,
    timestamp: u64,
}
```

## Security and Fraud Detection

### Device Fingerprinting
- **Unique Device Tracking**: Prevents multiple check-ins from same device
- **Fraud Detection**: Alerts when duplicate devices are detected
- **Privacy Preserving**: Uses fingerprints, not device IDs

### Location Verification
- **Encrypted Proofs**: Location data is encrypted for privacy
- **Optional Implementation**: Can be enabled per event
- **Geofencing Support**: Validates attendees are at event location

### Pass Validation
- **Ephemeral Pass System**: Integrates with identity_access contract
- **Time-Limited**: Passes expire after 24 hours
- **Single-Use**: Each pass can only be used once

## Frontend Integration Examples

### Complete Attendance Flow
```typescript
import { Transaction } from '@mysten/sui/transactions';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';
import { bcs } from '@mysten/sui/bcs';

const client = new SuiClient({ url: getFullnodeUrl('testnet') });

// 1. Generate device fingerprint
function generateDeviceFingerprint(): Uint8Array {
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    ctx.textBaseline = 'top';
    ctx.font = '14px Arial';
    ctx.fillText('Device fingerprint', 2, 2);
    
    const fingerprint = canvas.toDataURL();
    return new TextEncoder().encode(fingerprint);
}

// 2. Get user location (with permission)
async function getLocationProof(): Promise<Uint8Array> {
    return new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(
            (position) => {
                const location = {
                    lat: position.coords.latitude,
                    lng: position.coords.longitude,
                    timestamp: Date.now()
                };
                // Encrypt location data here
                const encrypted = new TextEncoder().encode(JSON.stringify(location));
                resolve(encrypted);
            },
            reject
        );
    });
}

// 3. Check-in process
async function checkInToEvent(passHash: Uint8Array, eventId: string) {
    try {
        const deviceFingerprint = generateDeviceFingerprint();
        const locationProof = await getLocationProof();
        
        const tx = new Transaction();
        const [mintCap] = tx.moveCall({
            target: `${PACKAGE_ID}::attendance_verification::check_in`,
            arguments: [
                tx.pure(bcs.vector(bcs.U8).serialize(Array.from(passHash))),
                tx.pure(bcs.vector(bcs.U8).serialize(Array.from(deviceFingerprint))),
                tx.pure(bcs.vector(bcs.U8).serialize(Array.from(locationProof))),
                tx.object(eventId),
                tx.object(ATTENDANCE_REGISTRY_ID),
                tx.object(IDENTITY_REGISTRY_ID),
                tx.object(CLOCK_ID),
            ],
        });
        
        // Transfer PoA capability to user
        tx.transferObjects([mintCap], await wallet.getAddress());
        
        const result = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx,
            options: {
                showEffects: true,
                showEvents: true,
            },
        });
        
        return result;
    } catch (error) {
        console.error('Check-in failed:', error);
        throw error;
    }
}

// 4. Check-out process
async function checkOutFromEvent(eventId: string, userWallet: string) {
    try {
        const tx = new Transaction();
        const [completionCap] = tx.moveCall({
            target: `${PACKAGE_ID}::attendance_verification::check_out`,
            arguments: [
                tx.pure.address(userWallet),
                tx.pure.id(eventId),
                tx.object(ATTENDANCE_REGISTRY_ID),
                tx.object(CLOCK_ID),
            ],
        });
        
        // Transfer completion capability to user
        tx.transferObjects([completionCap], userWallet);
        
        const result = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx,
        });
        
        return result;
    } catch (error) {
        console.error('Check-out failed:', error);
        throw error;
    }
}

// 5. Check attendance status
async function getAttendanceStatus(userWallet: string, eventId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::attendance_verification::get_attendance_status`,
        arguments: [
            tx.pure.address(userWallet),
            tx.pure.id(eventId),
            tx.object(ATTENDANCE_REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: userWallet,
    });
    
    if (result.effects?.status?.status === 'success') {
        // Parse result to get (hasRecord, state, checkInTime, checkOutTime)
        return result.results;
    }
    
    return null;
}

// 6. Get event statistics
async function getEventStats(eventId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::attendance_verification::get_event_stats`,
        arguments: [
            tx.pure.id(eventId),
            tx.object(ATTENDANCE_REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: await wallet.getAddress(),
    });
    
    return result;
}
```

### Event Monitoring Dashboard
```typescript
// Real-time attendance monitoring
class AttendanceMonitor {
    private client: SuiClient;
    private eventId: string;
    
    constructor(eventId: string) {
        this.client = new SuiClient({ url: getFullnodeUrl('testnet') });
        this.eventId = eventId;
        this.setupEventListeners();
    }
    
    private setupEventListeners() {
        // Monitor check-ins
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::attendance_verification::AttendeeCheckedIn`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                if (data.event_id === this.eventId) {
                    this.handleCheckIn(data);
                }
            },
        });
        
        // Monitor check-outs
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::attendance_verification::AttendeeCheckedOut`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                if (data.event_id === this.eventId) {
                    this.handleCheckOut(data);
                }
            },
        });
        
        // Monitor fraud attempts
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::attendance_verification::FraudAttemptDetected`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                if (data.event_id === this.eventId) {
                    this.handleFraudAlert(data);
                }
            },
        });
    }
    
    private handleCheckIn(data: any) {
        console.log(`User ${data.wallet} checked in at ${new Date(data.check_in_time)}`);
        this.updateDashboard();
    }
    
    private handleCheckOut(data: any) {
        const duration = data.attendance_duration / 1000 / 60; // Convert to minutes
        console.log(`User ${data.wallet} checked out after ${duration} minutes`);
        this.updateDashboard();
    }
    
    private handleFraudAlert(data: any) {
        console.warn(`Fraud attempt detected: ${data.reason} from ${data.wallet}`);
        this.showFraudAlert(data);
    }
    
    private async updateDashboard() {
        const stats = await getEventStats(this.eventId);
        // Update UI with latest statistics
    }
    
    private showFraudAlert(data: any) {
        // Display fraud alert in UI
    }
}
```

### Error Handling
```typescript
async function safeCheckIn(passHash: Uint8Array, eventId: string) {
    try {
        const result = await checkInToEvent(passHash, eventId);
        
        if (result.effects?.status?.status === 'failure') {
            const error = result.effects.status.error;
            switch (error) {
                case 'EEventNotActive':
                    throw new Error('Event is not currently active');
                case 'EAlreadyCheckedIn':
                    throw new Error('You are already checked in to this event');
                case 'EInvalidPass':
                    throw new Error('Invalid or expired access pass');
                default:
                    throw new Error(`Check-in failed: ${error}`);
            }
        }
        
        // Extract PoA capability from transaction
        const poaCapability = extractCapabilityFromResults(result);
        return poaCapability;
        
    } catch (error) {
        console.error('Check-in error:', error);
        throw error;
    }
}
```

## Integration with Other Contracts

### Event Management Contract
- **Event State Validation**: Ensures only active events accept check-ins
- **Attendee Count Updates**: Automatically increments event attendance counters
- **Capacity Management**: Respects event capacity limits

### Identity Access Contract
- **Pass Validation**: Validates ephemeral passes before check-in
- **Registration Status**: Marks users as checked in
- **Registration Verification**: Ensures only registered users can check in

### NFT Contract
- **PoA NFT Minting**: Uses MintPoACapability for Proof-of-Attendance NFTs
- **Completion NFT Minting**: Uses MintCompletionCapability for completion NFTs
- **Capability Consumption**: Safely consumes capabilities during minting

### Rating Contract
- **Attendance Verification**: Confirms users completed attendance before rating
- **Completion Requirements**: Ensures only checked-out users can rate events

## Best Practices

### For Frontend Developers
1. **Device Fingerprinting**: Implement consistent device identification
2. **Location Handling**: Request permissions and handle location errors gracefully
3. **Pass Management**: Securely store and validate ephemeral passes
4. **Real-time Updates**: Subscribe to events for live attendance tracking
5. **Error Recovery**: Handle network issues and transaction failures

### For Event Organizers
1. **Fraud Monitoring**: Monitor fraud detection events and respond appropriately
2. **Attendance Analytics**: Use event statistics for insights and improvements
3. **Capability Management**: Properly handle NFT minting capabilities
4. **User Experience**: Provide clear feedback during check-in/check-out process

### For Security
1. **Pass Validation**: Always validate passes server-side for critical operations
2. **Device Tracking**: Monitor for suspicious device reuse patterns
3. **Location Verification**: Implement robust location verification when required
4. **Rate Limiting**: Prevent abuse of check-in/check-out functions

This contract provides a comprehensive, secure foundation for attendance verification within the EIA Protocol, enabling verifiable event participation while maintaining user privacy and preventing fraud.