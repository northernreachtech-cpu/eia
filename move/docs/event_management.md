# EIA Event Management Contract Documentation

## Overview

The EIA Event Management contract is the core module for creating, managing, and tracking events within the Ephemeral Identity & Attendance (EIA) Protocol. This contract handles event lifecycle management, organizer profiles, and sponsor conditions for decentralized event attendance verification.

## Module Information

- **Module**: `eia::event_management`
- **Network**: Sui Blockchain
- **Language**: Move

## Core Data Structures

### Event
The main event object that stores all event-related information.

```move
public struct Event has key, store {
    id: UID,
    name: String,
    description: String,
    location: String,
    start_time: u64,          // Unix timestamp in milliseconds
    end_time: u64,            // Unix timestamp in milliseconds
    capacity: u64,            // Maximum attendees
    current_attendees: u64,   // Current number of attendees
    organizer: address,       // Event organizer's wallet address
    state: u8,               // Current event state (0-3)
    created_at: u64,         // Creation timestamp
    sponsor_conditions: SponsorConditions,
    metadata_uri: String,    // Walrus storage reference
}
```

### OrganizerProfile
Tracks organizer reputation and statistics across all events.

```move
public struct OrganizerProfile has key, store {
    id: UID,
    address: address,
    name: String,
    bio: String,
    total_events: u64,
    successful_events: u64,
    total_attendees_served: u64,
    avg_rating: u64,         // Rating * 100 (e.g., 450 = 4.5/5)
    created_at: u64,
}
```

### SponsorConditions
Defines performance benchmarks for sponsor fund release.

```move
public struct SponsorConditions has store, drop, copy {
    min_attendees: u64,
    min_completion_rate: u64,    // Percentage * 100 (e.g., 8000 = 80%)
    min_avg_rating: u64,         // Rating * 100 (e.g., 450 = 4.5/5)
    custom_benchmarks: vector<CustomBenchmark>,
}
```

### EventRegistry
Global registry for event discovery and indexing.

```move
public struct EventRegistry has key {
    id: UID,
    events: Table<ID, EventInfo>,
    events_by_organizer: Table<address, vector<ID>>,
}
```

## Event States

| State | Value | Description |
|-------|-------|-------------|
| `STATE_CREATED` | 0 | Event created but not yet active for registration |
| `STATE_ACTIVE` | 1 | Event is live and accepting registrations |
| `STATE_COMPLETED` | 2 | Event has ended |
| `STATE_SETTLED` | 3 | Event has been settled (funds released/withheld) |

## Error Codes

| Error | Code | Description |
|-------|------|-------------|
| `ENotOrganizer` | 1 | Caller is not the event organizer |
| `EEventNotActive` | 2 | Event is not in the correct state for this operation |
| `EEventAlreadyCompleted` | 3 | Event has already been completed |
| `EInvalidCapacity` | 4 | Invalid capacity value |
| `EInvalidTimestamp` | 5 | Invalid timestamp (e.g., start time in past) |

## Public Functions

### Organizer Profile Management

#### `create_organizer_profile`
Creates a new organizer profile and returns capability object.

```move
public fun create_organizer_profile(
    name: String,
    bio: String,
    clock: &Clock,
    ctx: &mut TxContext
): OrganizerCap
```

**Parameters:**
- `name`: Organizer's display name
- `bio`: Organizer's biography/description
- `clock`: System clock reference
- `ctx`: Transaction context

**Returns:** `OrganizerCap` - Capability object for managing the profile

**Frontend Usage:**
```typescript
const tx = new Transaction();
const [organizerCap] = tx.moveCall({
    target: `${PACKAGE_ID}::event_management::create_organizer_profile`,
    arguments: [
        tx.pure.string("John Doe"),
        tx.pure.string("Professional event organizer with 5+ years experience"),
        tx.object(CLOCK_ID),
    ],
});
```

### Event Creation and Management

#### `create_event`
Creates a new event with sponsor conditions.

```move
public fun create_event(
    name: String,
    description: String,
    location: String,
    start_time: u64,
    end_time: u64,
    capacity: u64,
    min_attendees: u64,
    min_completion_rate: u64,
    min_avg_rating: u64,
    metadata_uri: String,
    clock: &Clock,
    registry: &mut EventRegistry,
    profile: &mut OrganizerProfile,
    ctx: &mut TxContext
): ID
```

**Parameters:**
- `name`: Event name
- `description`: Event description
- `location`: Event location
- `start_time`: Event start time (Unix timestamp in ms)
- `end_time`: Event end time (Unix timestamp in ms)
- `capacity`: Maximum number of attendees
- `min_attendees`: Minimum attendees for sponsor success
- `min_completion_rate`: Minimum completion rate (percentage * 100)
- `min_avg_rating`: Minimum average rating (rating * 100)
- `metadata_uri`: Walrus storage URI for additional metadata
- `clock`: System clock reference
- `registry`: Event registry object
- `profile`: Organizer's profile object
- `ctx`: Transaction context

**Returns:** `ID` - The created event's object ID

**Frontend Usage:**
```typescript
const tx = new Transaction();
const eventId = tx.moveCall({
    target: `${PACKAGE_ID}::event_management::create_event`,
    arguments: [
        tx.pure.string("Tech Conference 2024"),
        tx.pure.string("Annual technology conference"),
        tx.pure.string("San Francisco, CA"),
        tx.pure.u64(Date.now() + 86400000), // Tomorrow
        tx.pure.u64(Date.now() + 172800000), // Day after tomorrow
        tx.pure.u64(100), // Capacity
        tx.pure.u64(50),  // Min attendees
        tx.pure.u64(8000), // 80% completion rate
        tx.pure.u64(400),  // 4.0/5.0 rating
        tx.pure.string("walrus://metadata-hash"),
        tx.object(CLOCK_ID),
        tx.object(REGISTRY_ID),
        tx.object(PROFILE_ID),
    ],
});
```

#### `activate_event`
Activates an event for registration.

```move
public fun activate_event(
    event: &mut Event,
    clock: &Clock,
    registry: &mut EventRegistry,
    ctx: &mut TxContext
)
```

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::event_management::activate_event`,
    arguments: [
        tx.object(EVENT_ID),
        tx.object(CLOCK_ID),
        tx.object(REGISTRY_ID),
    ],
});
```

#### `complete_event`
Marks an event as completed (only callable after end time).

```move
public fun complete_event(
    event: &mut Event,
    clock: &Clock,
    registry: &mut EventRegistry,
    profile: &mut OrganizerProfile,
    ctx: &mut TxContext
)
```

**Frontend Usage:**
```typescript
const txb = new TransactionBlock();
txb.moveCall({
    target: `${PACKAGE_ID}::event_management::complete_event`,
    arguments: [
        txb.object(EVENT_ID),
        txb.object(CLOCK_ID),
        txb.object(REGISTRY_ID),
        txb.object(PROFILE_ID),
    ],
});
```

#### `update_event_details`
Updates event details (only before activation).

```move
public fun update_event_details(
    event: &mut Event,
    name: String,
    description: String,
    location: String,
    metadata_uri: String,
    ctx: &mut TxContext
)
```

#### `add_custom_benchmark`
Adds custom performance benchmarks to sponsor conditions.

```move
public fun add_custom_benchmark(
    event: &mut Event,
    metric_name: String,
    target_value: u64,
    comparison_type: u8,
    ctx: &mut TxContext
)
```

**Comparison Types:**
- `0`: Greater than or equal (>=)
- `1`: Less than or equal (<=)
- `2`: Equal to (==)

### Query Functions (Read-Only)

#### Event Information
```move
public fun get_event_state(event: &Event): u8
public fun get_event_organizer(event: &Event): address
public fun get_event_capacity(event: &Event): u64
public fun get_current_attendees(event: &Event): u64
public fun get_event_id(event: &Event): ID
public fun get_event_metadata_uri(event: &Event): String
public fun get_event_timing(event: &Event): (u64, u64, u64) // start, end, created
```

#### Event Status Checks
```move
public fun is_event_active(event: &Event): bool
public fun is_event_completed(event: &Event): bool
public fun event_exists(registry: &EventRegistry, event_id: ID): bool
```

#### Sponsor Conditions
```move
public fun get_event_sponsor_conditions(event: &Event): (u64, u64, u64, u64)
// Returns: (min_attendees, min_completion_rate, min_avg_rating, custom_benchmarks_count)
```

#### Custom Benchmark Access

#### `get_custom_benchmarks`
Gets the vector of custom benchmarks from sponsor conditions.

```move
public fun get_custom_benchmarks(conditions: &SponsorConditions): &vector<CustomBenchmark>
```

**Parameters:**
- `conditions`: Reference to sponsor conditions

**Returns:** `&vector<CustomBenchmark>` - Reference to the vector of custom benchmarks

**Frontend Usage:**
```typescript
// This function is typically used internally by other contracts
// Frontend would access custom benchmarks through event queries
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::event_management::get_custom_benchmarks`,
    arguments: [
        tx.object(SPONSOR_CONDITIONS_REF),
    ],
});
```

#### `get_benchmark_metric_name`
Extracts the metric name from a custom benchmark.

```move
public fun get_benchmark_metric_name(benchmark: &CustomBenchmark): String
```

**Parameters:**
- `benchmark`: Reference to a custom benchmark

**Returns:** `String` - The metric name (e.g., "social_media_mentions")

#### `get_benchmark_target_value`
Extracts the target value from a custom benchmark.

```move
public fun get_benchmark_target_value(benchmark: &CustomBenchmark): u64
```

**Parameters:**
- `benchmark`: Reference to a custom benchmark

**Returns:** `u64` - The target value that must be achieved

#### `get_benchmark_comparison_type`
Extracts the comparison type from a custom benchmark.

```move
public fun get_benchmark_comparison_type(benchmark: &CustomBenchmark): u8
```

**Parameters:**
- `benchmark`: Reference to a custom benchmark

**Returns:** `u8` - The comparison type (0: >=, 1: <=, 2: ==)

**Frontend Integration Example:**

```typescript
// Example: Displaying custom benchmarks for an event
async function getEventCustomBenchmarks(eventId: string) {
    try {
        // First get the event object to access sponsor conditions
        const eventObject = await client.getObject({
            id: eventId,
            options: { showContent: true },
        });
        
        if (!eventObject.data?.content) {
            throw new Error('Event not found');
        }
        
        // Extract sponsor conditions (this would be done through the event object)
        const sponsorConditions = eventObject.data.content.fields.sponsor_conditions;
        const customBenchmarks = sponsorConditions.custom_benchmarks;
        
        // Parse custom benchmarks
        const benchmarks = customBenchmarks.map(benchmark => ({
            metricName: benchmark.metric_name,
            targetValue: benchmark.target_value,
            comparisonType: benchmark.comparison_type,
            comparisonSymbol: benchmark.comparison_type === 0 ? '>=' : 
                             benchmark.comparison_type === 1 ? '<=' : '==',
        }));
        
        return benchmarks;
        
    } catch (error) {
        console.error('Error fetching custom benchmarks:', error);
        return [];
    }
}

// Usage in a React component
function CustomBenchmarksDisplay({ eventId }) {
    const [benchmarks, setBenchmarks] = useState([]);
    
    useEffect(() => {
        getEventCustomBenchmarks(eventId).then(setBenchmarks);
    }, [eventId]);
    
    return (
        <div className="custom-benchmarks">
            <h4>Sponsor Performance Conditions</h4>
            {benchmarks.length === 0 ? (
                <p>No custom benchmarks defined</p>
            ) : (
                <div className="benchmarks-list">
                    {benchmarks.map((benchmark, index) => (
                        <div key={index} className="benchmark-item">
                            <span className="metric-name">{benchmark.metricName}</span>
                            <span className="condition">
                                {benchmark.comparisonSymbol} {benchmark.targetValue}
                            </span>
                        </div>
                    ))}
                </div>
            )}
        </div>
    );
}
```

#### Organizer Information
```move
public fun get_organizer_stats(profile: &OrganizerProfile): (u64, u64, u64, u64)
// Returns: (total_events, successful_events, total_attendees_served, avg_rating)

public fun get_organizer_event_ids(registry: &EventRegistry, organizer: address): vector<ID>
```

#### Registry Queries
```move
public fun get_event_info_fields(registry: &EventRegistry, id: ID): (ID, String, u64, address, u8)
// Returns: (event_id, name, start_time, organizer, state)
```

## Events Emitted

### EventCreated
```move
public struct EventCreated has copy, drop {
    event_id: ID,
    name: String,
    organizer: address,
    start_time: u64,
    capacity: u64,
}
```

### EventActivated
```move
public struct EventActivated has copy, drop {
    event_id: ID,
    activated_at: u64,
}
```

### EventCompleted
```move
public struct EventCompleted has copy, drop {
    event_id: ID,
    total_attendees: u64,
    completed_at: u64,
}
```

## Frontend Integration Examples

### Creating an Event Flow
```typescript
// Import the correct SDK classes
import { Transaction } from '@mysten/sui/transactions';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';

// 1. Create organizer profile (if not exists)
const createProfileTx = new Transaction();
const [organizerCap] = createProfileTx.moveCall({
    target: `${PACKAGE_ID}::event_management::create_organizer_profile`,
    arguments: [
        createProfileTx.pure.string(organizerName),
        createProfileTx.pure.string(organizerBio),
        createProfileTx.object(CLOCK_ID),
    ],
});

// 2. Create event
const createEventTx = new Transaction();
const eventId = createEventTx.moveCall({
    target: `${PACKAGE_ID}::event_management::create_event`,
    arguments: [
        createEventTx.pure.string(eventData.name),
        createEventTx.pure.string(eventData.description),
        createEventTx.pure.string(eventData.location),
        createEventTx.pure.u64(eventData.startTime),
        createEventTx.pure.u64(eventData.endTime),
        createEventTx.pure.u64(eventData.capacity),
        createEventTx.pure.u64(sponsorConditions.minAttendees),
        createEventTx.pure.u64(sponsorConditions.minCompletionRate),
        createEventTx.pure.u64(sponsorConditions.minAvgRating),
        createEventTx.pure.string(eventData.metadataUri),
        createEventTx.object(CLOCK_ID),
        createEventTx.object(REGISTRY_ID),
        createEventTx.object(PROFILE_ID),
    ],
});

// 3. Activate event
const activateEventTx = new Transaction();
activateEventTx.moveCall({
    target: `${PACKAGE_ID}::event_management::activate_event`,
    arguments: [
        activateEventTx.object(eventId),
        activateEventTx.object(CLOCK_ID),
        activateEventTx.object(REGISTRY_ID),
    ],
});
```

### Querying Event Data
```typescript
// Get event details
const eventObject = await suiClient.getObject({
    id: eventId,
    options: {
        showContent: true,
    },
});

// Get organizer's events
const organizerEvents = await suiClient.getDynamicFields({
    parentId: REGISTRY_ID,
    cursor: null,
    limit: 50,
});

// Listen for event creation
suiClient.subscribeEvent({
    filter: {
        MoveEventType: `${PACKAGE_ID}::event_management::EventCreated`,
    },
    onMessage: (event) => {
        console.log('New event created:', event.parsedJson);
    },
});
```

### Error Handling
```typescript
try {
    const result = await suiClient.executeTransactionBlock({
        transactionBlock: txb,
        signer: keypair,
        options: {
            showEffects: true,
            showEvents: true,
        },
    });
    
    if (result.effects?.status?.status === 'failure') {
        // Handle specific error codes
        const errorCode = result.effects.status.error;
        switch (errorCode) {
            case 'ENotOrganizer':
                throw new Error('You are not the organizer of this event');
            case 'EEventNotActive':
                throw new Error('Event is not in the correct state');
            case 'EInvalidCapacity':
                throw new Error('Invalid capacity value');
            // ... handle other errors
        }
    }
} catch (error) {
    console.error('Transaction failed:', error);
}
```

## Important Notes

1. **Time Handling**: All timestamps are in milliseconds (Unix timestamp * 1000)
2. **Ratings**: Ratings are stored as integers multiplied by 100 (e.g., 4.5 stars = 450)
3. **Percentages**: Completion rates are stored as percentages * 100 (e.g., 80% = 8000)
4. **Object References**: Most functions require object references to shared objects (Event, Registry, Profile)
5. **Capability Management**: Organizer capabilities must be properly managed and stored by the frontend
6. **Event Lifecycle**: Events must follow the state progression: Created → Active → Completed → Settled

## Integration with Other Contracts

This contract is designed to work with:
- **Attendance Contract**: For check-in/check-out functionality
- **Escrow Contract**: For sponsor fund management
- **Rating Contract**: For post-event ratings
- **NFT Contract**: For proof-of-attendance tokens

The contract provides hooks and update functions that other contracts can call to maintain data consistency across the protocol.