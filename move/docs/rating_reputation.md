# EIA Rating & Reputation Contract Documentation

## Overview

The EIA Rating & Reputation contract manages post-event feedback and builds reputation systems within the Ephemeral Identity & Attendance (EIA) Protocol. This contract enables attendees to rate events and organizers after completing attendance, while maintaining comprehensive reputation tracking for event organizers across all their events.

## Module Information

- **Module**: `eia::rating_reputation`
- **Network**: Sui Blockchain
- **Language**: Move
- **Dependencies**: `eia::attendance_verification`, `eia::event_management`

## Core Data Structures

### RatingRegistry
Central registry for all ratings and reputation data.

```move
public struct RatingRegistry has key {
    id: UID,
    event_ratings: Table<ID, EventRatings>,           // event_id -> event ratings
    user_ratings: Table<address, vector<UserRating>>, // wallet -> user's rating history
    convener_ratings: Table<address, ConvenerReputation>, // organizer -> reputation
}
```

### EventRatings
Aggregated rating data for a specific event.

```move
public struct EventRatings has store {
    ratings: Table<address, Rating>,    // Individual user ratings
    total_rating_sum: u64,             // Sum of all ratings
    total_ratings: u64,                // Number of ratings submitted
    average_rating: u64,               // Calculated average rating
    rating_deadline: u64,              // Deadline for rating submission (7 days after event)
}
```

### Rating
Individual rating submission from an attendee.

```move
public struct Rating has store, drop, copy {
    rater: address,           // Who submitted the rating
    event_rating: u64,        // Rating for the event (100-500)
    convener_rating: u64,     // Rating for the organizer (100-500)
    feedback: String,         // Optional text feedback
    timestamp: u64,           // When the rating was submitted
}
```

### ConvenerReputation
Organizer's overall reputation across all events.

```move
public struct ConvenerReputation has store {
    total_events_rated: u64,                      // Number of events with ratings
    total_rating_sum: u64,                        // Sum of all convener ratings
    average_rating: u64,                          // Overall average rating
    rating_history: vector<ConvenerRatingEntry>,  // Per-event rating history
}
```

### ConvenerRatingEntry
Per-event rating data for an organizer.

```move
public struct ConvenerRatingEntry has store, drop, copy {
    event_id: ID,           // Event identifier
    rating: u64,            // Average rating for this event
    rater_count: u64,       // Number of raters for this event
    timestamp: u64,         // When first rating was received
}
```

### UserRating
Individual user's rating history entry.

```move
public struct UserRating has store, drop, copy {
    event_id: ID,           // Event that was rated
    rating_given: u64,      // Rating given to the event
    timestamp: u64,         // When the rating was submitted
}
```

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_RATING` | 500 | Maximum rating value (5.0 * 100) |
| `MIN_RATING` | 100 | Minimum rating value (1.0 * 100) |
| `RATING_PERIOD` | 604800000 | Rating submission period (7 days in milliseconds) |

**Rating Scale**: Ratings are stored as integers multiplied by 100:
- 1.0 stars = 100
- 2.5 stars = 250  
- 4.5 stars = 450
- 5.0 stars = 500

## Error Codes

| Error | Code | Description |
|-------|------|-------------|
| `ENotEligibleToRate` | 1 | User did not complete full attendance cycle |
| `EAlreadyRated` | 2 | User has already rated this event |
| `EInvalidRating` | 3 | Rating value is outside valid range (100-500) |
| `ERatingPeriodExpired` | 4 | Rating submission deadline has passed (7 days) |
| `EEventNotCompleted` | 5 | Event must be completed before rating |

## Public Functions

### Rating Submission

#### `submit_rating`
Submits a rating for an event and its organizer.

```move
public fun submit_rating(
    event: &Event,
    event_rating: u64,
    convener_rating: u64,
    feedback: String,
    registry: &mut RatingRegistry,
    attendance_registry: &AttendanceRegistry,
    organizer_profile: &mut OrganizerProfile,
    clock: &Clock,
    ctx: &mut TxContext
)
```

**Parameters:**
- `event`: Reference to the completed event
- `event_rating`: Rating for the event (100-500)
- `convener_rating`: Rating for the organizer (100-500)
- `feedback`: Optional text feedback
- `registry`: Mutable reference to rating registry
- `attendance_registry`: Reference to attendance registry for verification
- `organizer_profile`: Mutable reference to organizer's profile
- `clock`: System clock reference
- `ctx`: Transaction context

**Validation Requirements:**
1. **Event Completed**: Event must be in completed state
2. **Attendance Verified**: User must have completed check-in and check-out
3. **Rating Bounds**: Both ratings must be between 100-500
4. **Time Limit**: Must submit within 7 days of event completion
5. **Single Rating**: User can only rate each event once

**Process:**
1. Validates event completion and user attendance
2. Checks rating bounds and submission deadline
3. Prevents duplicate ratings from same user
4. Stores individual rating record
5. Updates event aggregate statistics
6. Updates organizer reputation across all events
7. Updates organizer profile rating
8. Emits rating events

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::rating_reputation::submit_rating`,
    arguments: [
        tx.object(EVENT_ID),
        tx.pure.u64(450), // 4.5 star event rating
        tx.pure.u64(480), // 4.8 star organizer rating
        tx.pure.string("Great event! Well organized and informative."),
        tx.object(RATING_REGISTRY_ID),
        tx.object(ATTENDANCE_REGISTRY_ID),
        tx.object(ORGANIZER_PROFILE_ID),
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
```

### Query Functions (Read-Only)

#### `get_event_average_rating`
Gets the average rating for an event.

```move
public fun get_event_average_rating(
    event_id: ID,
    registry: &RatingRegistry
): u64
```

**Returns:** `u64` - Average rating (0 if no ratings, otherwise 100-500)

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::rating_reputation::get_event_average_rating`,
    arguments: [
        tx.pure.id(eventId),
        tx.object(RATING_REGISTRY_ID),
    ],
});

const result = await client.devInspectTransactionBlock({
    transactionBlock: tx,
    sender: userWallet,
});

// Convert rating to stars: rating / 100 = stars
const averageStars = result.returnValues[0] / 100;
```

#### `get_event_rating_stats`
Gets comprehensive rating statistics for an event.

```move
public fun get_event_rating_stats(
    event_id: ID,
    registry: &RatingRegistry
): (u64, u64, u64)
```

**Returns:** `(u64, u64, u64)` - Total ratings count, average rating, rating deadline

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::rating_reputation::get_event_rating_stats`,
    arguments: [
        tx.pure.id(eventId),
        tx.object(RATING_REGISTRY_ID),
    ],
});

const result = await client.devInspectTransactionBlock({
    transactionBlock: tx,
    sender: userWallet,
});

// Parse results
const [totalRatings, averageRating, deadline] = result.returnValues;
const averageStars = averageRating / 100;
const deadlineDate = new Date(deadline);
```

#### `get_convener_reputation`
Gets organizer's overall reputation statistics.

```move
public fun get_convener_reputation(
    convener: address,
    registry: &RatingRegistry
): (u64, u64, u64)
```

**Returns:** `(u64, u64, u64)` - Total events rated, average rating, rating history length

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::rating_reputation::get_convener_reputation`,
    arguments: [
        tx.pure.address(organizerWallet),
        tx.object(RATING_REGISTRY_ID),
    ],
});

const result = await client.devInspectTransactionBlock({
    transactionBlock: tx,
    sender: userWallet,
});

const [totalEvents, averageRating, historyLength] = result.returnValues;
const organizerStars = averageRating / 100;
```

#### `has_user_rated`
Checks if a user has already rated a specific event.

```move
public fun has_user_rated(
    rater: address,
    event_id: ID,
    registry: &RatingRegistry
): bool
```

**Returns:** `bool` - Whether user has rated the event

#### `get_user_rating`
Gets a user's specific rating for an event.

```move
public fun get_user_rating(
    rater: address,
    event_id: ID,
    registry: &RatingRegistry
): (u64, u64, String)
```

**Returns:** `(u64, u64, String)` - Event rating, convener rating, feedback text

**Note:** This function will abort if the user hasn't rated the event. Use `has_user_rated` first.

#### `get_convener_rating_history`
Gets detailed rating history for an organizer.

```move
public fun get_convener_rating_history(
    convener: address,
    registry: &RatingRegistry
): vector<ConvenerRatingEntry>
```

**Returns:** Vector of rating entries for each event the organizer has ratings for

## Events Emitted

### RatingSubmitted
```move
public struct RatingSubmitted has copy, drop {
    event_id: ID,
    rater: address,
    event_rating: u64,
    convener_rating: u64,
    timestamp: u64,
}
```

### ConvenerReputationUpdated
```move
public struct ConvenerReputationUpdated has copy, drop {
    convener: address,
    new_average: u64,
    total_events: u64,
}
```

## Frontend Integration Examples

### Complete Rating Flow
```typescript
import { Transaction } from '@mysten/sui/transactions';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';

const client = new SuiClient({ url: getFullnodeUrl('testnet') });

// 1. Check if user can rate (completed attendance)
async function canUserRate(userWallet: string, eventId: string): Promise<boolean> {
    try {
        const tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::attendance_verification::verify_attendance_completion`,
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

        return result.effects?.status?.status === 'success';
    } catch (error) {
        console.error('Error checking rating eligibility:', error);
        return false;
    }
}

// 2. Check if user has already rated
async function hasUserRated(userWallet: string, eventId: string): Promise<boolean> {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::rating_reputation::has_user_rated`,
        arguments: [
            tx.pure.address(userWallet),
            tx.pure.id(eventId),
            tx.object(RATING_REGISTRY_ID),
        ],
    });

    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: userWallet,
    });

    return result.effects?.status?.status === 'success';
}

// 3. Submit rating
async function submitRating(
    eventId: string,
    eventRating: number, // 1.0 to 5.0 stars
    organizerRating: number, // 1.0 to 5.0 stars
    feedback: string
) {
    try {
        // Convert star ratings to integer format
        const eventRatingInt = Math.round(eventRating * 100);
        const organizerRatingInt = Math.round(organizerRating * 100);

        // Validate ratings
        if (eventRatingInt < 100 || eventRatingInt > 500) {
            throw new Error('Event rating must be between 1.0 and 5.0 stars');
        }
        if (organizerRatingInt < 100 || organizerRatingInt > 500) {
            throw new Error('Organizer rating must be between 1.0 and 5.0 stars');
        }

        const tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::rating_reputation::submit_rating`,
            arguments: [
                tx.object(eventId),
                tx.pure.u64(eventRatingInt),
                tx.pure.u64(organizerRatingInt),
                tx.pure.string(feedback),
                tx.object(RATING_REGISTRY_ID),
                tx.object(ATTENDANCE_REGISTRY_ID),
                tx.object(ORGANIZER_PROFILE_ID),
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
            throw new Error(`Rating submission failed: ${result.effects.status.error}`);
        }

        return result;
    } catch (error) {
        console.error('Rating submission error:', error);
        throw error;
    }
}

// 4. Get event rating statistics
async function getEventRatingStats(eventId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::rating_reputation::get_event_rating_stats`,
        arguments: [
            tx.pure.id(eventId),
            tx.object(RATING_REGISTRY_ID),
        ],
    });

    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: await wallet.getAddress(),
    });

    if (result.effects?.status?.status === 'success') {
        // Parse the results
        const [totalRatings, averageRating, deadline] = result.returnValues;
        return {
            totalRatings: parseInt(totalRatings),
            averageRating: parseInt(averageRating) / 100, // Convert to stars
            deadline: new Date(parseInt(deadline)),
            canStillRate: Date.now() < parseInt(deadline),
        };
    }

    return null;
}

// 5. Get organizer reputation
async function getOrganizerReputation(organizerWallet: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::rating_reputation::get_convener_reputation`,
        arguments: [
            tx.pure.address(organizerWallet),
            tx.object(RATING_REGISTRY_ID),
        ],
    });

    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: await wallet.getAddress(),
    });

    if (result.effects?.status?.status === 'success') {
        const [totalEvents, averageRating, historyLength] = result.returnValues;
        return {
            totalEventsRated: parseInt(totalEvents),
            averageRating: parseInt(averageRating) / 100, // Convert to stars
            totalEventsOrganized: parseInt(historyLength),
        };
    }

    return null;
}

// 6. Get user's rating for an event (if exists)
async function getUserRating(userWallet: string, eventId: string) {
    try {
        // First check if user has rated
        const hasRated = await hasUserRated(userWallet, eventId);
        if (!hasRated) {
            return null;
        }

        const tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::rating_reputation::get_user_rating`,
            arguments: [
                tx.pure.address(userWallet),
                tx.pure.id(eventId),
                tx.object(RATING_REGISTRY_ID),
            ],
        });

        const result = await client.devInspectTransactionBlock({
            transactionBlock: tx,
            sender: userWallet,
        });

        if (result.effects?.status?.status === 'success') {
            const [eventRating, convenerRating, feedback] = result.returnValues;
            return {
                eventRating: parseInt(eventRating) / 100, // Convert to stars
                organizerRating: parseInt(convenerRating) / 100, // Convert to stars
                feedback: feedback,
            };
        }
    } catch (error) {
        console.error('Error getting user rating:', error);
    }

    return null;
}
```

### Rating Dashboard Component
```typescript
interface RatingDashboardProps {
    eventId: string;
    userWallet: string;
}

function RatingDashboard({ eventId, userWallet }: RatingDashboardProps) {
    const [canRate, setCanRate] = useState(false);
    const [hasRated, setHasRated] = useState(false);
    const [eventStats, setEventStats] = useState(null);
    const [userRating, setUserRating] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        loadRatingData();
    }, [eventId, userWallet]);

    const loadRatingData = async () => {
        try {
            setLoading(true);
            
            // Check if user can rate
            const canRateResult = await canUserRate(userWallet, eventId);
            setCanRate(canRateResult);
            
            // Check if user has already rated
            const hasRatedResult = await hasUserRated(userWallet, eventId);
            setHasRated(hasRatedResult);
            
            // Get event rating statistics
            const stats = await getEventRatingStats(eventId);
            setEventStats(stats);
            
            // Get user's rating if they have rated
            if (hasRatedResult) {
                const rating = await getUserRating(userWallet, eventId);
                setUserRating(rating);
            }
            
        } catch (error) {
            console.error('Error loading rating data:', error);
        } finally {
            setLoading(false);
        }
    };

    if (loading) return <div>Loading...</div>;

    return (
        <div className="rating-dashboard">
            <h3>Event Ratings</h3>
            
            {eventStats && (
                <div className="event-stats">
                    <p>Average Rating: {eventStats.averageRating.toFixed(1)} ⭐</p>
                    <p>Total Ratings: {eventStats.totalRatings}</p>
                    <p>Rating Deadline: {eventStats.deadline.toLocaleDateString()}</p>
                </div>
            )}
            
            {canRate && !hasRated && eventStats?.canStillRate && (
                <RatingForm eventId={eventId} onSubmit={loadRatingData} />
            )}
            
            {hasRated && userRating && (
                <div className="user-rating">
                    <h4>Your Rating</h4>
                    <p>Event: {userRating.eventRating.toFixed(1)} ⭐</p>
                    <p>Organizer: {userRating.organizerRating.toFixed(1)} ⭐</p>
                    <p>Feedback: {userRating.feedback}</p>
                </div>
            )}
            
            {!canRate && (
                <p>You must complete full event attendance to rate this event.</p>
            )}
            
            {hasRated && (
                <p>You have already rated this event.</p>
            )}
            
            {!eventStats?.canStillRate && (
                <p>Rating period has expired (7 days after event completion).</p>
            )}
        </div>
    );
}
```

### Real-Time Rating Updates
```typescript
// Monitor rating events
class RatingMonitor {
    private client: SuiClient;
    private eventId: string;

    constructor(eventId: string) {
        this.client = new SuiClient({ url: getFullnodeUrl('testnet') });
        this.eventId = eventId;
        this.setupEventListeners();
    }

    private setupEventListeners() {
        // Monitor rating submissions
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::rating_reputation::RatingSubmitted`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                if (data.event_id === this.eventId) {
                    this.handleRatingSubmitted(data);
                }
            },
        });

        // Monitor organizer reputation updates
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::rating_reputation::ConvenerReputationUpdated`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handleReputationUpdate(data);
            },
        });
    }

    private handleRatingSubmitted(data: any) {
        const eventRating = data.event_rating / 100;
        const organizerRating = data.convener_rating / 100;
        
        console.log(`New rating submitted for event ${this.eventId}:`);
        console.log(`Event: ${eventRating} stars, Organizer: ${organizerRating} stars`);
        
        // Update UI with new rating
        this.updateEventStats();
    }

    private handleReputationUpdate(data: any) {
        const averageRating = data.new_average / 100;
        console.log(`Organizer ${data.convener} reputation updated: ${averageRating} stars across ${data.total_events} events`);
    }

    private async updateEventStats() {
        const stats = await getEventRatingStats(this.eventId);
        // Update UI components with new stats
    }
}
```

### Error Handling
```typescript
async function safeSubmitRating(
    eventId: string,
    eventRating: number,
    organizerRating: number,
    feedback: string
) {
    try {
        // Pre-validation
        const canRate = await canUserRate(userWallet, eventId);
        if (!canRate) {
            throw new Error('You must complete full event attendance to submit a rating');
        }

        const hasRated = await hasUserRated(userWallet, eventId);
        if (hasRated) {
            throw new Error('You have already rated this event');
        }

        const stats = await getEventRatingStats(eventId);
        if (stats && !stats.canStillRate) {
            throw new Error('Rating period has expired (7 days after event completion)');
        }

        // Submit rating
        const result = await submitRating(eventId, eventRating, organizerRating, feedback);

        if (result.effects?.status?.status === 'failure') {
            const error = result.effects.status.error;
            switch (error) {
                case 'ENotEligibleToRate':
                    throw new Error('You are not eligible to rate this event');
                case 'EAlreadyRated':
                    throw new Error('You have already rated this event');
                case 'EInvalidRating':
                    throw new Error('Rating must be between 1.0 and 5.0 stars');
                case 'ERatingPeriodExpired':
                    throw new Error('Rating period has expired');
                case 'EEventNotCompleted':
                    throw new Error('Event must be completed before rating');
                default:
                    throw new Error(`Rating submission failed: ${error}`);
            }
        }

        return result;
    } catch (error) {
        console.error('Rating submission error:', error);
        throw error;
    }
}
```

### Organizer Reputation Display
```typescript
async function displayOrganizerReputation(organizerWallet: string) {
    try {
        const reputation = await getOrganizerReputation(organizerWallet);
        
        if (!reputation) {
            return <div>No reputation data available</div>;
        }

        // Get detailed rating history
        const tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::rating_reputation::get_convener_rating_history`,
            arguments: [
                tx.pure.address(organizerWallet),
                tx.object(RATING_REGISTRY_ID),
            ],
        });

        const historyResult = await client.devInspectTransactionBlock({
            transactionBlock: tx,
            sender: await wallet.getAddress(),
        });

        return (
            <div className="organizer-reputation">
                <h3>Organizer Reputation</h3>
                <div className="reputation-stats">
                    <p>Overall Rating: {reputation.averageRating.toFixed(1)} ⭐</p>
                    <p>Events Rated: {reputation.totalEventsRated}</p>
                    <p>Total Events Organized: {reputation.totalEventsOrganized}</p>
                </div>
                
                {/* Display rating badges based on performance */}
                <div className="reputation-badges">
                    {reputation.averageRating >= 4.5 && (
                        <span className="badge gold">⭐ Top Rated Organizer</span>
                    )}
                    {reputation.averageRating >= 4.0 && (
                        <span className="badge silver">✅ Trusted Organizer</span>
                    )}
                    {reputation.totalEventsRated >= 10 && (
                        <span className="badge bronze">🏆 Experienced Organizer</span>
                    )}
                </div>
            </div>
        );
    } catch (error) {
        console.error('Error displaying reputation:', error);
        return <div>Error loading reputation data</div>;
    }
}
```

## Integration with Other Contracts

### Attendance Verification Contract
- **Completion Verification**: Validates users completed full attendance cycle
- **Eligibility Check**: Only users who checked in AND out can rate
- **Anti-Gaming**: Prevents rating without actual participation

### Event Management Contract
- **Event State**: Only completed events can be rated
- **Organizer Profiles**: Ratings update organizer reputation statistics
- **Event Completion**: Triggers rating period start

### NFT Contract
- **Community Access**: High-rated events may provide premium NFT benefits
- **Reputation Tokens**: Future feature for reputation-based token rewards

## Best Practices

### For Frontend Developers
1. **Always validate eligibility** before showing rating forms
2. **Check rating deadline** and show appropriate messages
3. **Convert ratings properly** between stars (1.0-5.0) and integers (100-500)
4. **Handle all error cases** gracefully with user-friendly messages
5. **Subscribe to events** for real-time updates

### For Event Organizers
1. **Encourage participation** in full attendance cycle for rating eligibility
2. **Monitor reputation** trends across events
3. **Respond to feedback** to improve future events
4. **Build rating history** for enhanced credibility

### For Users
1. **Complete full attendance** to gain rating privileges
2. **Submit thoughtful feedback** to help organizers improve
3. **Rate within deadline** (7 days after event completion)
4. **Be honest and constructive** in ratings and feedback

## Limitations and Considerations

1. **7-Day Rating Window**: Users must rate within 7 days of event completion
2. **Single Rating Per Event**: Users can only rate each event once (no editing)
3. **Attendance Requirement**: Must complete check-in AND check-out to rate
4. **No Rating Deletion**: Ratings are permanent once submitted
5. **Reputation Calculation**: Organizer reputation averages across all rated events

This contract provides a comprehensive rating and reputation system that builds trust in the EIA Protocol ecosystem while ensuring only genuine participants can provide feedback.