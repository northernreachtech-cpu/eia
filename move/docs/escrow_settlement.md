# EIA Escrow Settlement Contract Documentation

## Overview

The EIA Escrow Settlement contract manages sponsor funds and automates settlement based on event performance metrics within the Ephemeral Identity & Attendance (EIA) Protocol. This contract enables sponsors to deposit funds with predefined conditions, automatically releasing funds to organizers when benchmarks are met or refunding sponsors when conditions fail.

## Module Information

- **Module**: `eia::escrow_settlement`
- **Network**: Sui Blockchain
- **Language**: Move
- **Dependencies**: `eia::event_management`, `eia::attendance_verification`, `eia::rating_reputation`

## Core Data Structures

### EscrowRegistry
Central registry for managing all escrow accounts and global statistics.

```move
public struct EscrowRegistry has key {
    id: UID,
    escrows: Table<ID, Escrow>,                    // event_id -> escrow account
    total_escrowed: u64,                          // Total funds in escrow
    total_released: u64,                          // Total funds released to organizers
    total_refunded: u64,                          // Total funds refunded to sponsors
    custom_metrics: Table<ID, Table<String, u64>>, // event_id -> (metric_name -> actual_value)
}
```

### Escrow
Individual escrow account for an event with sponsor conditions.

```move
public struct Escrow has store {
    event_id: ID,                    // Associated event
    organizer: address,              // Event organizer's wallet
    sponsor: address,                // Sponsor's wallet
    balance: Balance<SUI>,           // Escrowed SUI tokens
    conditions: SponsorConditions,   // Performance conditions
    created_at: u64,                 // Escrow creation timestamp
    settled: bool,                   // Whether escrow has been settled
    settlement_time: u64,            // Settlement timestamp
    settlement_result: SettlementResult, // Final settlement outcome
}
```

### SettlementResult
Comprehensive settlement outcome with all performance metrics.

```move
public struct SettlementResult has store, drop, copy {
    conditions_met: bool,            // Whether all conditions were satisfied
    attendees_actual: u64,           // Actual number of attendees
    attendees_required: u64,         // Required number of attendees
    completion_rate_actual: u64,     // Actual completion rate (basis points)
    completion_rate_required: u64,   // Required completion rate (basis points)
    avg_rating_actual: u64,          // Actual average rating (rating * 100)
    avg_rating_required: u64,        // Required average rating (rating * 100)
    amount_released: u64,            // Amount released to organizer
    amount_refunded: u64,            // Amount refunded to sponsor
}
```

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `SETTLEMENT_GRACE_PERIOD` | 604800000 | Grace period for emergency withdrawal (7 days in milliseconds) |

## Error Codes

| Error | Code | Description |
|-------|------|-------------|
| `EInsufficientFunds` | 1 | Payment amount is zero or insufficient |
| `EEventNotCompleted` | 2 | Event must be completed before settlement |
| `EAlreadySettled` | 3 | Escrow has already been settled |
| `ENotAuthorized` | 5 | Caller is not authorized for this operation |
| `EEscrowNotFound` | 6 | Escrow does not exist for this event |
| `ERefundPeriodNotExpired` | 7 | Grace period has not expired for emergency withdrawal |

## Public Functions

### Escrow Management

#### `create_escrow`
Creates an escrow account for an event with sponsor funds.

```move
public fun create_escrow(
    event: &Event,
    sponsor: address,
    payment: Coin<SUI>,
    registry: &mut EscrowRegistry,
    clock: &Clock,
    _ctx: &mut TxContext
)
```

**Parameters:**
- `event`: Reference to the event object
- `sponsor`: Sponsor's wallet address
- `payment`: SUI coin payment to escrow
- `registry`: Mutable reference to escrow registry
- `clock`: System clock reference
- `_ctx`: Transaction context (unused parameter)

**Validation:**
- Payment amount must be greater than zero
- Event must not already have an escrow account

**Process:**
1. Extracts event details and sponsor conditions
2. Creates escrow account with sponsor funds
3. Stores escrow in registry
4. Updates global escrow statistics
5. Emits `EscrowCreated` event

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::escrow_settlement::create_escrow`,
    arguments: [
        tx.object(EVENT_ID),
        tx.pure.address(sponsorWallet),
        tx.object(suiCoinId), // SUI coin object
        tx.object(ESCROW_REGISTRY_ID),
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

#### `settle_escrow`
Evaluates event performance and settles escrow (release or refund).

```move
public fun settle_escrow(
    event: &mut Event,
    event_id: ID,
    registry: &mut EscrowRegistry,
    attendance_registry: &AttendanceRegistry,
    rating_registry: &RatingRegistry,
    organizer_profile: &mut OrganizerProfile,
    clock: &Clock,
    ctx: &mut TxContext
)
```

**Parameters:**
- `event`: Mutable reference to completed event
- `event_id`: Event identifier
- `registry`: Mutable reference to escrow registry
- `attendance_registry`: Reference to attendance registry
- `rating_registry`: Reference to rating registry
- `organizer_profile`: Mutable reference to organizer profile
- `clock`: System clock reference
- `ctx`: Transaction context

**Authorization:**
Only event organizer or sponsor can initiate settlement

**Validation:**
- Event must be completed
- Escrow must exist and not be settled
- Caller must be organizer or sponsor

**Settlement Criteria:**
1. **Minimum Attendees**: Actual attendees ≥ required attendees
2. **Completion Rate**: Actual completion rate ≥ required rate
3. **Average Rating**: Actual rating ≥ required rating
4. **Custom Benchmarks**: All custom metrics meet their targets

**Process:**
1. Gathers performance data from all protocol contracts
2. Evaluates each condition against actual results
3. If all conditions met: releases funds to organizer
4. If conditions failed: refunds funds to sponsor
5. Updates organizer profile with settlement result
6. Emits settlement events

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::escrow_settlement::settle_escrow`,
    arguments: [
        tx.object(EVENT_ID),
        tx.pure.id(eventId),
        tx.object(ESCROW_REGISTRY_ID),
        tx.object(ATTENDANCE_REGISTRY_ID),
        tx.object(RATING_REGISTRY_ID),
        tx.object(ORGANIZER_PROFILE_ID),
        tx.object(CLOCK_ID),
    ],
});

const result = await wallet.signAndExecuteTransactionBlock({
    transactionBlock: tx,
});
```

#### `emergency_withdraw`
Emergency withdrawal after grace period expires.

```move
public fun emergency_withdraw(
    event_id: ID,
    registry: &mut EscrowRegistry,
    clock: &Clock,
    ctx: &mut TxContext
)
```

**Use Cases:**
- Settlement disputes or delays
- Technical issues preventing normal settlement
- Abandoned events or unresponsive parties

**Requirements:**
- 7-day grace period must have expired since escrow creation
- Escrow must not be settled
- Caller must be organizer or sponsor

**Process:**
1. Validates grace period expiration
2. Automatically refunds funds to sponsor
3. Marks escrow as settled
4. Emits refund event

#### `add_funds_to_escrow`
Adds additional funds to an existing escrow.

```move
public fun add_funds_to_escrow(
    event_id: ID,
    payment: Coin<SUI>,
    registry: &mut EscrowRegistry,
    ctx: &mut TxContext
)
```

**Authorization:** Only the original sponsor can add funds

**Use Cases:**
- Increasing reward pool for better performance
- Adding bonus incentives during event planning
- Correcting initial underfunding

### Custom Metrics Management

#### `update_custom_metric`
Updates actual values for custom performance benchmarks.

```move
public fun update_custom_metric(
    event_id: ID,
    metric_name: String,
    actual_value: u64,
    registry: &mut EscrowRegistry,
    ctx: &mut TxContext
)
```

**Parameters:**
- `event_id`: Event identifier
- `metric_name`: Name of the custom metric (must match benchmark)
- `actual_value`: Actual achieved value
- `registry`: Mutable reference to escrow registry
- `ctx`: Transaction context

**Authorization:** Only event organizer can update metrics

**Examples of Custom Metrics:**
- Social media engagement (followers, mentions, hashtag usage)
- Media coverage (articles, interviews, press releases)
- Networking connections (business cards exchanged, LinkedIn connects)
- Lead generation (sign-ups, downloads, demo requests)
- Carbon footprint (emissions, sustainability score)
- Accessibility compliance (features implemented, feedback score)

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::escrow_settlement::update_custom_metric`,
    arguments: [
        tx.pure.id(eventId),
        tx.pure.string("social_media_mentions"),
        tx.pure.u64(2500), // 2,500 mentions achieved
        tx.object(ESCROW_REGISTRY_ID),
    ],
});
```

### Query Functions (Read-Only)

#### `get_escrow_details`
Gets basic escrow account information.

```move
public fun get_escrow_details(
    event_id: ID,
    registry: &EscrowRegistry
): (address, address, u64, bool, u64)
```

**Returns:** `(address, address, u64, bool, u64)` - Organizer, sponsor, balance, settled status, settlement time

#### `get_settlement_result`
Gets detailed settlement outcome.

```move
public fun get_settlement_result(
    event_id: ID,
    registry: &EscrowRegistry
): SettlementResult
```

**Returns:** Complete settlement result with all performance metrics

#### `check_conditions_status`
Checks current performance against sponsor conditions (before settlement).

```move
public fun check_conditions_status(
    event_id: ID,
    registry: &EscrowRegistry,
    attendance_registry: &AttendanceRegistry,
    rating_registry: &RatingRegistry,
): (bool, u64, u64, u64)
```

**Returns:** `(bool, u64, u64, u64)` - Conditions met, actual attendees, completion rate, average rating

#### `check_custom_benchmarks_status`
Evaluates custom benchmark conditions for an event.

```move
public fun get_evaluate_custom_benchmarks(
    event_id: ID,
    conditions: SponsorConditions,
    registry: &EscrowRegistry
): bool
```

**Parameters:**
- `event_id`: Event identifier
- `conditions`: Sponsor conditions containing custom benchmarks
- `registry`: Reference to escrow registry with custom metrics data

**Returns:** `bool` - Whether all custom benchmarks are met

**Process:**
1. Extracts custom benchmarks from sponsor conditions
2. Checks if custom metrics data exists for the event
3. Evaluates each benchmark against actual values
4. Returns true only if all benchmarks pass their comparison tests

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::escrow_settlement::check_custom_benchmarks_status`,
    arguments: [
        tx.pure.id(eventId),
        tx.object(SPONSOR_CONDITIONS), // SponsorConditions object
        tx.object(ESCROW_REGISTRY_ID),
    ],
});

const result = await client.devInspectTransactionBlock({
    transactionBlock: tx,
    sender: userWallet,
});
```

#### `get_global_stats`
Gets platform-wide escrow statistics.

```move
public fun get_global_stats(registry: &EscrowRegistry): (u64, u64, u64)
```

**Returns:** `(u64, u64, u64)` - Total escrowed, total released, total refunded

## Events Emitted

### EscrowCreated
```move
public struct EscrowCreated has copy, drop {
    event_id: ID,
    organizer: address,
    sponsor: address,
    amount: u64,
    created_at: u64,
}
```

### FundsReleased
```move
public struct FundsReleased has copy, drop {
    event_id: ID,
    organizer: address,
    amount: u64,
    settlement_time: u64,
}
```

### FundsRefunded
```move
public struct FundsRefunded has copy, drop {
    event_id: ID,
    sponsor: address,
    amount: u64,
    reason: String,
}
```

### SettlementCompleted
```move
public struct SettlementCompleted has copy, drop {
    event_id: ID,
    result: SettlementResult,
}
```

## Frontend Integration Examples

### Complete Sponsorship Flow
```typescript
import { Transaction } from '@mysten/sui/transactions';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';

const client = new SuiClient({ url: getFullnodeUrl('testnet') });

// 1. Create escrow with sponsor funds
async function createSponsorshipEscrow(
    eventId: string,
    sponsorWallet: string,
    sponsorshipAmount: number // Amount in SUI
) {
    try {
        // First, get or create SUI coin for the amount
        const suiCoin = await getSuiCoin(sponsorshipAmount);
        
        const tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::escrow_settlement::create_escrow`,
            arguments: [
                tx.object(eventId),
                tx.pure.address(sponsorWallet),
                tx.object(suiCoin),
                tx.object(ESCROW_REGISTRY_ID),
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
        
        console.log('Escrow created successfully:', result);
        return result;
        
    } catch (error) {
        console.error('Escrow creation failed:', error);
        throw error;
    }
}

// 2. Monitor event performance during/after event
async function checkEventPerformance(eventId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::escrow_settlement::check_conditions_status`,
        arguments: [
            tx.pure.id(eventId),
            tx.object(ESCROW_REGISTRY_ID),
            tx.object(ATTENDANCE_REGISTRY_ID),
            tx.object(RATING_REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: await wallet.getAddress(),
    });
    
    if (result.effects?.status?.status === 'success') {
        const [conditionsMet, attendees, completionRate, avgRating] = result.returnValues;
        
        return {
            conditionsMet: conditionsMet === 'true',
            actualAttendees: parseInt(attendees),
            completionRate: parseInt(completionRate) / 100, // Convert from basis points
            averageRating: parseInt(avgRating) / 100, // Convert to stars
        };
    }
    
    return null;
}

// 3. Update custom metrics (organizer only)
async function updateCustomMetric(
    eventId: string,
    metricName: string,
    actualValue: number
) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::escrow_settlement::update_custom_metric`,
        arguments: [
            tx.pure.id(eventId),
            tx.pure.string(metricName),
            tx.pure.u64(actualValue),
            tx.object(ESCROW_REGISTRY_ID),
        ],
    });
    
    return await wallet.signAndExecuteTransactionBlock({
        transactionBlock: tx,
    });
}

// 4. Settle escrow after event completion
async function settleEscrow(eventId: string) {
    try {
        const tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::escrow_settlement::settle_escrow`,
            arguments: [
                tx.object(eventId),
                tx.pure.id(eventId),
                tx.object(ESCROW_REGISTRY_ID),
                tx.object(ATTENDANCE_REGISTRY_ID),
                tx.object(RATING_REGISTRY_ID),
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
        
        // Extract settlement result from events
        const settlementEvent = result.events?.find(
            event => event.type.includes('SettlementCompleted')
        );
        
        if (settlementEvent) {
            console.log('Settlement completed:', settlementEvent.parsedJson);
        }
        
        return result;
        
    } catch (error) {
        console.error('Settlement failed:', error);
        throw error;
    }
}

// 5. Get settlement details
async function getSettlementDetails(eventId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::escrow_settlement::get_settlement_result`,
        arguments: [
            tx.pure.id(eventId),
            tx.object(ESCROW_REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: await wallet.getAddress(),
    });
    
    if (result.effects?.status?.status === 'success') {
        // Parse settlement result struct
        const settlementData = parseSettlementResult(result.returnValues);
        return settlementData;
    }
    
    return null;
}

// Helper function to parse settlement result
function parseSettlementResult(returnValues: any) {
    return {
        conditionsMet: returnValues.conditions_met,
        performance: {
            attendees: {
                actual: parseInt(returnValues.attendees_actual),
                required: parseInt(returnValues.attendees_required),
            },
            completionRate: {
                actual: parseInt(returnValues.completion_rate_actual) / 100,
                required: parseInt(returnValues.completion_rate_required) / 100,
            },
            rating: {
                actual: parseInt(returnValues.avg_rating_actual) / 100,
                required: parseInt(returnValues.avg_rating_required) / 100,
            },
        },
        financials: {
            amountReleased: parseInt(returnValues.amount_released),
            amountRefunded: parseInt(returnValues.amount_refunded),
        },
    };
}
```

### Sponsor Dashboard
```typescript
interface SponsorDashboardProps {
    sponsorWallet: string;
}

function SponsorDashboard({ sponsorWallet }: SponsorDashboardProps) {
    const [sponsoredEvents, setSponsoredEvents] = useState([]);
    const [globalStats, setGlobalStats] = useState(null);
    
    useEffect(() => {
        loadSponsorData();
    }, [sponsorWallet]);
    
    const loadSponsorData = async () => {
        try {
            // Get global platform statistics
            const stats = await getGlobalEscrowStats();
            setGlobalStats(stats);
            
            // Get sponsored events (would need to track separately or query events)
            const events = await getSponsoredEvents(sponsorWallet);
            setSponsoredEvents(events);
            
        } catch (error) {
            console.error('Error loading sponsor data:', error);
        }
    };
    
    return (
        <div className="sponsor-dashboard">
            <h2>Sponsor Dashboard</h2>
            
            {globalStats && (
                <div className="global-stats">
                    <h3>Platform Statistics</h3>
                    <div className="stats-grid">
                        <div className="stat">
                            <label>Total Escrowed</label>
                            <span>{globalStats.totalEscrowed} SUI</span>
                        </div>
                        <div className="stat">
                            <label>Funds Released</label>
                            <span>{globalStats.totalReleased} SUI</span>
                        </div>
                        <div className="stat">
                            <label>Funds Refunded</label>
                            <span>{globalStats.totalRefunded} SUI</span>
                        </div>
                        <div className="stat">
                            <label>Success Rate</label>
                            <span>
                                {((globalStats.totalReleased / 
                                   (globalStats.totalReleased + globalStats.totalRefunded)) * 100
                                ).toFixed(1)}%
                            </span>
                        </div>
                    </div>
                </div>
            )}
            
            <div className="sponsored-events">
                <h3>Your Sponsored Events</h3>
                {sponsoredEvents.map(event => (
                    <SponsoredEventCard key={event.id} event={event} />
                ))}
            </div>
        </div>
    );
}

function SponsoredEventCard({ event }) {
    const [performance, setPerformance] = useState(null);
    const [settlementResult, setSettlementResult] = useState(null);
    
    useEffect(() => {
        loadEventData();
    }, [event.id]);
    
    const loadEventData = async () => {
        const perf = await checkEventPerformance(event.id);
        setPerformance(perf);
        
        if (event.settled) {
            const result = await getSettlementDetails(event.id);
            setSettlementResult(result);
        }
    };
    
    return (
        <div className="event-card">
            <h4>{event.name}</h4>
            <div className="event-details">
                <p>Escrow Amount: {event.escrowAmount} SUI</p>
                <p>Status: {event.settled ? 'Settled' : 'Active'}</p>
            </div>
            
            {performance && (
                <div className="performance-metrics">
                    <h5>Performance Metrics</h5>
                    <div className="metrics">
                        <div className={`metric ${performance.conditionsMet ? 'success' : 'pending'}`}>
                            <label>Attendees</label>
                            <span>{performance.actualAttendees}</span>
                        </div>
                        <div className="metric">
                            <label>Completion Rate</label>
                            <span>{performance.completionRate.toFixed(1)}%</span>
                        </div>
                        <div className="metric">
                            <label>Average Rating</label>
                            <span>{performance.averageRating.toFixed(1)} ⭐</span>
                        </div>
                    </div>
                </div>
            )}
            
            {settlementResult && (
                <div className="settlement-result">
                    <h5>Settlement Result</h5>
                    <p className={settlementResult.conditionsMet ? 'success' : 'failure'}>
                        {settlementResult.conditionsMet ? 
                            `✅ Funds Released: ${settlementResult.financials.amountReleased} SUI` :
                            `❌ Funds Refunded: ${settlementResult.financials.amountRefunded} SUI`
                        }
                    </p>
                </div>
            )}
            
            {!event.settled && event.completed && (
                <button onClick={() => settleEscrow(event.id)}>
                    Settle Escrow
                </button>
            )}
        </div>
    );
}
```

### Organizer Performance Tracking
```typescript
// Organizer interface for tracking performance
function OrganizerPerformanceTracker({ eventId, organizerWallet }) {
    const [customMetrics, setCustomMetrics] = useState([]);
    const [performance, setPerformance] = useState(null);
    
    // Load current performance
    useEffect(() => {
        const loadPerformance = async () => {
            const perf = await checkEventPerformance(eventId);
            setPerformance(perf);
        };
        
        loadPerformance();
        // Poll every 30 seconds during event
        const interval = setInterval(loadPerformance, 30000);
        return () => clearInterval(interval);
    }, [eventId]);
    
    // Update custom metric
    const handleMetricUpdate = async (metricName: string, value: number) => {
        try {
            await updateCustomMetric(eventId, metricName, value);
            
            // Update local state
            setCustomMetrics(prev => 
                prev.map(metric => 
                    metric.name === metricName 
                        ? { ...metric, actualValue: value }
                        : metric
                )
            );
            
        } catch (error) {
            console.error('Failed to update metric:', error);
        }
    };
    
    return (
        <div className="performance-tracker">
            <h3>Performance Tracking</h3>
            
            {performance && (
                <div className="live-performance">
                    <h4>Live Metrics</h4>
                    <div className="metrics-grid">
                        <div className="metric">
                            <label>Attendees</label>
                            <span>{performance.actualAttendees}</span>
                            <small>Conditions: {performance.conditionsMet ? '✅' : '⏳'}</small>
                        </div>
                        <div className="metric">
                            <label>Completion Rate</label>
                            <span>{performance.completionRate.toFixed(1)}%</span>
                        </div>
                        <div className="metric">
                            <label>Average Rating</label>
                            <span>{performance.averageRating.toFixed(1)} ⭐</span>
                        </div>
                    </div>
                </div>
            )}
            
            <div className="custom-metrics">
                <h4>Custom Metrics</h4>
                {customMetrics.map(metric => (
                    <CustomMetricInput
                        key={metric.name}
                        metric={metric}
                        onUpdate={handleMetricUpdate}
                    />
                ))}
            </div>
        </div>
    );
}

function CustomMetricInput({ metric, onUpdate }) {
    const [value, setValue] = useState(metric.actualValue || 0);
    const [isUpdating, setIsUpdating] = useState(false);
    
    const handleSubmit = async () => {
        setIsUpdating(true);
        try {
            await onUpdate(metric.name, value);
        } finally {
            setIsUpdating(false);
        }
    };
    
    return (
        <div className="custom-metric">
            <label>{metric.name}</label>
            <div className="metric-input">
                <input
                    type="number"
                    value={value}
                    onChange={(e) => setValue(parseInt(e.target.value))}
                    disabled={isUpdating}
                />
                <span className="target">Target: {metric.targetValue}</span>
                <button onClick={handleSubmit} disabled={isUpdating}>
                    {isUpdating ? 'Updating...' : 'Update'}
                </button>
            </div>
            <small>
                Comparison: {metric.comparisonType === 0 ? '≥' : 
                          metric.comparisonType === 1 ? '≤' : '='}
            </small>
        </div>
    );
}
```

### Real-Time Escrow Monitoring
```typescript
// Monitor escrow events
class EscrowMonitor {
    private client: SuiClient;
    
    constructor() {
        this.client = new SuiClient({ url: getFullnodeUrl('testnet') });
        this.setupEventListeners();
    }
    
    private setupEventListeners() {
        // Monitor escrow creation
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::escrow_settlement::EscrowCreated`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handleEscrowCreated(data);
            },
        });
        
        // Monitor fund releases
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::escrow_settlement::FundsReleased`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handleFundsReleased(data);
            },
        });
        
        // Monitor refunds
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::escrow_settlement::FundsRefunded`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handleFundsRefunded(data);
            },
        });
        
        // Monitor settlement completion
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::escrow_settlement::SettlementCompleted`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handleSettlementCompleted(data);
            },
        });
    }
    
    private handleEscrowCreated(data: any) {
        console.log(`New escrow created for event ${data.event_id}: ${data.amount} SUI`);
        // Update UI with new escrow
    }
    
    private handleFundsReleased(data: any) {
        console.log(`Funds released to organizer ${data.organizer}: ${data.amount} SUI`);
        // Show success notification
    }
    
    private handleFundsRefunded(data: any) {
        console.log(`Funds refunded to sponsor: ${data.amount} SUI. Reason: ${data.reason}`);
        // Show refund notification
    }
    
    private handleSettlementCompleted(data: any) {
        const result = data.result;
        console.log(`Settlement completed for event ${data.event_id}:`, result);
        // Update settlement dashboard
    }
}
```

### Error Handling
```typescript
async function safeSettleEscrow(eventId: string) {
    try {
        const result = await settleEscrow(eventId);
        
        if (result.effects?.status?.status === 'failure') {
            const error = result.effects.status.error;
            switch (error) {
                case 'EEventNotCompleted':
                    throw new Error('Event must be completed before settlement');
                case 'EAlreadySettled':
                    throw new Error('This escrow has already been settled');
                case 'ENotAuthorized':
                    throw new Error('Only organizer or sponsor can settle escrow');
                case 'EEscrowNotFound':
                    throw new Error('No escrow found for this event');
                default:
                    throw new Error(`Settlement failed: ${error}`);
            }
        }
        
        return result;
        
    } catch (error) {
        console.error('Settlement error:', error);
        throw error;
    }
}
```

## Integration with Other Contracts

### Event Management Contract
- **Event State Validation**: Ensures only completed events can be settled
- **Sponsor Conditions**: Retrieves performance benchmarks and custom metrics
- **Organizer Profile**: Updates success/failure statistics

### Attendance Verification Contract
- **Attendance Metrics**: Gets check-in/check-out counts and completion rates
- **Performance Data**: Provides actual attendance statistics for settlement

### Rating Reputation Contract
- **Rating Data**: Gets average event ratings for settlement evaluation
- **Quality Metrics**: Ensures rating-based sponsor conditions are met

## Best Practices

### For Sponsors
1. **Set Realistic Conditions**: Ensure benchmarks are achievable but meaningful
2. **Monitor Performance**: Track progress during events
3. **Fund Appropriately**: Escrow sufficient amounts to incentivize quality
4. **Define Clear Metrics**: Use specific, measurable custom benchmarks
5. **Allow Settlement Time**: Don't rush settlement immediately after events

### For Event Organizers
1. **Understand Conditions**: Review all sponsor requirements before accepting
2. **Track Metrics Actively**: Update custom metrics regularly during events
3. **Focus on Completion**: Encourage full attendance cycles for better rates
4. **Maintain Quality**: Aim for high ratings to meet sponsor expectations
5. **Communicate Performance**: Keep sponsors informed of progress

### For Frontend Developers
1. **Handle All Error Cases**: Implement comprehensive error handling
2. **Real-Time Updates**: Subscribe to events for live escrow monitoring
3. **Clear Status Display**: Show settlement conditions and progress clearly
4. **Secure Transactions**: Validate all inputs before transaction submission
5. **Performance Tracking**: Provide dashboards for all stakeholders

## Custom Metrics Examples

### Social Media Engagement
```typescript
// Example custom metrics for a tech conference
const socialMediaMetrics = [
    {
        name: "twitter_mentions",
        description: "Twitter mentions of event hashtag",
        targetValue: 1000,
        comparisonType: 0, // >=
    },
    {
        name: "linkedin_posts",
        description: "LinkedIn posts about the event",
        targetValue: 50,
        comparisonType: 0, // >=
    },
    {
        name: "instagram_stories",
        description: "Instagram stories featuring event",
        targetValue: 200,
        comparisonType: 0, // >=
    }
];

// Update social media metrics
async function updateSocialMetrics(eventId: string) {
    const metrics = await fetchSocialMediaData(eventId);
    
    for (const metric of metrics) {
        await updateCustomMetric(eventId, metric.name, metric.value);
    }
}
```

### Business Outcomes
```typescript
// Business-focused metrics for corporate events
const businessMetrics = [
    {
        name: "leads_generated",
        description: "Number of qualified leads generated",
        targetValue: 100,
        comparisonType: 0, // >=
    },
    {
        name: "demo_requests",
        description: "Product demo requests",
        targetValue: 25,
        comparisonType: 0, // >=
    },
    {
        name: "carbon_footprint",
        description: "CO2 emissions in kg",
        targetValue: 500,
        comparisonType: 1, // <= (lower is better)
    },
    {
        name: "satisfaction_score",
        description: "Post-event satisfaction survey score",
        targetValue: 850, // 8.5/10 * 100
        comparisonType: 0, // >=
    }
];
```

### Media Coverage
```typescript
// Media and PR metrics
const mediaCoverageMetrics = [
    {
        name: "press_releases",
        description: "Number of press releases published",
        targetValue: 5,
        comparisonType: 0, // >=
    },
    {
        name: "media_interviews",
        description: "Media interviews conducted",
        targetValue: 10,
        comparisonType: 0, // >=
    },
    {
        name: "article_mentions",
        description: "Articles mentioning the event",
        targetValue: 20,
        comparisonType: 0, // >=
    }
];
```

## Advanced Use Cases

### Multi-Tier Sponsorship
```typescript
// Create multiple escrows for different sponsor tiers
async function createTieredSponsorship(eventId: string, sponsorshipTiers: any[]) {
    const escrows = [];
    
    for (const tier of sponsorshipTiers) {
        // Each tier could have different conditions
        const escrow = await createSponsorshipEscrow(
            eventId,
            tier.sponsorWallet,
            tier.amount
        );
        
        // Update custom metrics specific to this tier
        for (const metric of tier.customMetrics) {
            await updateCustomMetric(eventId, metric.name, metric.targetValue);
        }
        
        escrows.push(escrow);
    }
    
    return escrows;
}
```

### Performance-Based Bonuses
```typescript
// Implement bonus releases for exceptional performance
async function settleWithBonuses(eventId: string) {
    const performance = await checkEventPerformance(eventId);
    
    // Check for bonus conditions
    const bonusEligible = 
        performance.actualAttendees > (performance.requiredAttendees * 1.2) && // 20% over target
        performance.averageRating > 4.5 && // Exceptional rating
        performance.completionRate > 0.9; // 90%+ completion
    
    if (bonusEligible) {
        // Add bonus funds to escrow before settlement
        const bonusAmount = calculateBonus(performance);
        await addFundsToEscrow(eventId, bonusAmount);
    }
    
    // Proceed with normal settlement
    return await settleEscrow(eventId);
}
```

### Escrow Analytics Dashboard
```typescript
// Comprehensive analytics for platform insights
function EscrowAnalyticsDashboard() {
    const [analytics, setAnalytics] = useState(null);
    
    useEffect(() => {
        loadAnalytics();
    }, []);
    
    const loadAnalytics = async () => {
        const globalStats = await getGlobalEscrowStats();
        const recentSettlements = await getRecentSettlements();
        const performanceMetrics = await getPerformanceMetrics();
        
        setAnalytics({
            globalStats,
            recentSettlements,
            performanceMetrics,
            successRate: globalStats.totalReleased / (globalStats.totalReleased + globalStats.totalRefunded),
            averageEscrowAmount: globalStats.totalEscrowed / recentSettlements.length,
            topPerformingOrganizers: await getTopOrganizers(),
            mostActiveSectors: await getSectorAnalytics(),
        });
    };
    
    return (
        <div className="escrow-analytics">
            <h2>Escrow Analytics Dashboard</h2>
            
            {analytics && (
                <>
                    <div className="key-metrics">
                        <div className="metric-card">
                            <h3>Platform Success Rate</h3>
                            <span className="big-number">
                                {(analytics.successRate * 100).toFixed(1)}%
                            </span>
                        </div>
                        <div className="metric-card">
                            <h3>Average Escrow</h3>
                            <span className="big-number">
                                {analytics.averageEscrowAmount.toFixed(0)} SUI
                            </span>
                        </div>
                        <div className="metric-card">
                            <h3>Total Volume</h3>
                            <span className="big-number">
                                {analytics.globalStats.totalEscrowed} SUI
                            </span>
                        </div>
                    </div>
                    
                    <div className="charts-section">
                        <SettlementTrendsChart data={analytics.recentSettlements} />
                        <PerformanceDistribution data={analytics.performanceMetrics} />
                        <SectorAnalysis data={analytics.mostActiveSectors} />
                    </div>
                    
                    <div className="leaderboards">
                        <TopOrganizersTable organizers={analytics.topPerformingOrganizers} />
                    </div>
                </>
            )}
        </div>
    );
}
```

## Security Considerations

### Fund Safety
1. **Immutable Conditions**: Sponsor conditions cannot be changed after escrow creation
2. **Multi-Party Authorization**: Settlement requires organizer or sponsor initiation
3. **Grace Period Protection**: Emergency withdrawal only after 7-day grace period
4. **Balance Verification**: All fund movements are tracked and validated

### Fraud Prevention
1. **Performance Verification**: Multiple contracts validate actual metrics
2. **Custom Metric Authentication**: Only organizers can update their metrics
3. **Settlement Delays**: Time-based protections prevent rushed settlements
4. **Audit Trail**: All transactions and updates are permanently recorded

### Smart Contract Security
1. **Reentrancy Protection**: Proper fund withdrawal patterns
2. **Access Control**: Function-level authorization checks
3. **State Validation**: Comprehensive state verification before operations
4. **Error Handling**: Graceful failure modes with clear error messages

## Limitations and Considerations

1. **Single Settlement**: Each escrow can only be settled once (no partial releases)
2. **Custom Metric Trust**: Organizers self-report custom metrics (trust-based)
3. **SUI Denomination**: All escrows are in SUI tokens only
4. **Grace Period**: 7-day emergency withdrawal period is fixed
5. **Settlement Authority**: Only organizer or sponsor can initiate settlement
6. **Performance Dependencies**: Settlement requires all dependent contracts (attendance, rating)

## Future Enhancements

### Planned Features
1. **Multi-Token Support**: Support for other Sui ecosystem tokens
2. **Partial Settlements**: Graduated releases based on milestone achievement
3. **Automated Settlement**: Time-based automatic settlement triggers
4. **Oracle Integration**: External data sources for custom metrics verification
5. **Insurance Layer**: Optional insurance for sponsor fund protection
6. **Dispute Resolution**: On-chain arbitration for settlement disputes

### Integration Opportunities
1. **DeFi Protocols**: Yield generation on escrowed funds
2. **Insurance Products**: Coverage for event cancellation or underperformance
3. **Credit Systems**: Reputation-based escrow terms and rates
4. **Cross-Chain**: Bridge support for multi-chain sponsorships
5. **AI Analytics**: Machine learning for performance prediction

This contract provides a comprehensive, secure foundation for automated sponsorship management within the EIA Protocol, enabling trustless performance-based funding while protecting both sponsors and organizers through transparent, verifiable settlement mechanisms.