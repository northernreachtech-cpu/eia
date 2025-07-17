# EIA Airdrop Distribution Contract Documentation

## Overview

The EIA Airdrop Distribution contract enables event organizers to create and manage automated token distributions for event participants within the Ephemeral Identity & Attendance (EIA) Protocol. This contract supports multiple distribution strategies, customizable eligibility criteria, and automated claiming mechanisms based on verified event participation.

## Module Information

- **Module**: `eia::airdrop_distribution`
- **Network**: Sui Blockchain
- **Language**: Move
- **Dependencies**: `eia::event_management`, `eia::nft_minting`, `eia::attendance_verification`, `eia::rating_reputation`

## Core Data Structures

### AirdropRegistry
Central registry managing all airdrops and global distribution statistics.

```move
public struct AirdropRegistry has key {
    id: UID,
    airdrops: Table<ID, Airdrop>,                       // airdrop_id -> airdrop
    event_airdrops: Table<ID, vector<ID>>,              // event_id -> airdrop_ids
    user_claims: Table<address, vector<ClaimRecord>>,   // wallet -> claim history
    total_distributed: u64,                             // Total SUI distributed
}
```

### Airdrop
Individual airdrop campaign with distribution rules and fund pool.

```move
public struct Airdrop has store {
    id: ID,                           // Unique airdrop identifier
    event_id: ID,                     // Associated event
    organizer: address,               // Airdrop creator
    name: String,                     // Campaign name
    description: String,              // Campaign description
    pool: Balance<SUI>,               // SUI token pool
    distribution_type: u8,            // Distribution strategy
    eligibility_criteria: EligibilityCriteria, // Participation requirements
    per_user_amount: u64,             // Base amount per user (for equal distribution)
    total_recipients: u64,            // Estimated eligible recipients
    claimed_count: u64,               // Number of claims processed
    claims: Table<address, ClaimInfo>, // Individual claim records
    created_at: u64,                  // Creation timestamp
    expires_at: u64,                  // Expiration timestamp
    active: bool,                     // Whether airdrop is active
}
```

### EligibilityCriteria
Defines requirements for airdrop participation.

```move
public struct EligibilityCriteria has store, drop, copy {
    require_attendance: bool,         // Must have checked in
    require_completion: bool,         // Must have checked out
    min_duration: u64,               // Minimum attendance duration (ms)
    require_rating_submitted: bool,   // Must have submitted event rating
}
```

### ClaimInfo
Individual claim record with transaction details.

```move
public struct ClaimInfo has store, drop, copy {
    amount: u64,                     // Amount claimed
    claimed_at: u64,                 // Claim timestamp
    transaction_id: ID,              // Transaction identifier
}
```

### ClaimRecord
User's claim history entry.

```move
public struct ClaimRecord has store, drop, copy {
    airdrop_id: ID,                  // Airdrop identifier
    event_id: ID,                    // Event identifier
    amount: u64,                     // Amount received
    claimed_at: u64,                 // Claim timestamp
}
```

## Distribution Types

| Type | Value | Description |
|------|-------|-------------|
| `TYPE_EQUAL_DISTRIBUTION` | 0 | Equal amount for all eligible participants |
| `TYPE_WEIGHTED_BY_DURATION` | 1 | Amount weighted by attendance duration |
| `TYPE_COMPLETION_BONUS` | 2 | Bonus for full event completion |

## Error Codes

| Error | Code | Description |
|-------|------|-------------|
| `ENotOrganizer` | 1 | Caller is not the event organizer |
| `EInsufficientFunds` | 2 | Insufficient funds for operation |
| `EAirdropNotFound` | 3 | Airdrop does not exist |
| `ENotEligible` | 4 | User does not meet eligibility criteria |
| `EAlreadyClaimed` | 5 | User has already claimed this airdrop |
| `EAirdropExpired` | 6 | Airdrop has expired |
| `EInvalidDistribution` | 7 | Invalid distribution parameters |
| `EAirdropNotActive` | 8 | Airdrop is not active |

## Public Functions

### Airdrop Creation and Management

#### `create_airdrop`
Creates a new airdrop campaign for an event.

```move
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
): ID
```

**Parameters:**
- `event`: Reference to the event object
- `name`: Airdrop campaign name
- `description`: Campaign description
- `payment`: SUI coin for the airdrop pool
- `distribution_type`: Distribution strategy (0-2)
- `require_attendance`: Whether check-in is required
- `require_completion`: Whether check-out is required
- `min_duration`: Minimum attendance duration in milliseconds
- `require_rating_submitted`: Whether event rating is required
- `validity_days`: Number of days before airdrop expires
- `registry`: Mutable reference to airdrop registry
- `attendance_registry`: Reference to attendance registry
- `clock`: System clock reference
- `ctx`: Transaction context

**Returns:** `ID` - The created airdrop's identifier

**Authorization:** Only event organizer can create airdrops

**Frontend Usage:**
```typescript
const tx = new Transaction();
const airdropId = tx.moveCall({
    target: `${PACKAGE_ID}::airdrop_distribution::create_airdrop`,
    arguments: [
        tx.object(EVENT_ID),
        tx.pure.string("Post-Event Reward"),
        tx.pure.string("Thank you for attending our amazing event!"),
        tx.object(suiCoinId), // SUI coin object
        tx.pure.u8(0), // Equal distribution
        tx.pure.bool(true), // Require attendance
        tx.pure.bool(true), // Require completion
        tx.pure.u64(3600000), // 1 hour minimum duration
        tx.pure.bool(false), // Rating not required
        tx.pure.u64(30), // Valid for 30 days
        tx.object(AIRDROP_REGISTRY_ID),
        tx.object(ATTENDANCE_REGISTRY_ID),
        tx.object(CLOCK_ID),
    ],
});
```

#### `claim_airdrop`
Claims airdrop rewards for eligible users.

```move
public fun claim_airdrop(
    airdrop_id: ID,
    registry: &mut AirdropRegistry,
    attendance_registry: &AttendanceRegistry,
    nft_registry: &NFTRegistry,
    rating_registry: &RatingRegistry,
    clock: &Clock,
    ctx: &mut TxContext
)
```

**Parameters:**
- `airdrop_id`: Airdrop identifier to claim from
- `registry`: Mutable reference to airdrop registry
- `attendance_registry`: Reference to attendance registry
- `nft_registry`: Reference to NFT registry
- `rating_registry`: Reference to rating registry
- `clock`: System clock reference
- `ctx`: Transaction context

**Validation Process:**
1. **Airdrop Verification**: Ensures airdrop exists and is active
2. **Expiration Check**: Validates current time is within airdrop validity
3. **Duplicate Prevention**: Prevents multiple claims from same user
4. **Eligibility Verification**: Validates all eligibility criteria
5. **Amount Calculation**: Computes claim amount based on distribution type

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::airdrop_distribution::claim_airdrop`,
    arguments: [
        tx.pure.id(airdropId),
        tx.object(AIRDROP_REGISTRY_ID),
        tx.object(ATTENDANCE_REGISTRY_ID),
        tx.object(NFT_REGISTRY_ID),
        tx.object(RATING_REGISTRY_ID),
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

#### `batch_distribute`
Distributes airdrop to multiple recipients in batch (organizer-initiated).

```move
public fun batch_distribute(
    airdrop_id: ID,
    recipients: vector<address>,
    registry: &mut AirdropRegistry,
    attendance_registry: &AttendanceRegistry,
    nft_registry: &NFTRegistry,
    rating_registry: &RatingRegistry,
    clock: &Clock,
    ctx: &mut TxContext
)
```

**Parameters:**
- `airdrop_id`: Airdrop identifier
- `recipients`: Vector of recipient wallet addresses
- `registry`: Mutable reference to airdrop registry
- `attendance_registry`: Reference to attendance registry
- `nft_registry`: Reference to NFT registry
- `rating_registry`: Reference to rating registry
- `clock`: System clock reference
- `ctx`: Transaction context

**Authorization:** Only airdrop organizer can initiate batch distribution

**Use Cases:**
- Mass distribution to all eligible participants
- Proactive reward distribution
- Gas optimization for multiple small claims

#### `withdraw_unclaimed`
Withdraws unclaimed funds after airdrop expiration.

```move
public fun withdraw_unclaimed(
    airdrop_id: ID,
    registry: &mut AirdropRegistry,
    clock: &Clock,
    ctx: &mut TxContext
)
```

**Requirements:**
- Only organizer can withdraw
- Airdrop must be expired
- Remaining funds will be returned to organizer

### Query Functions (Read-Only)

#### `get_airdrop_details`
Gets comprehensive airdrop information.

```move
public fun get_airdrop_details(
    airdrop_id: ID,
    registry: &AirdropRegistry
): (ID, String, u64, u64, u64, bool)
```

**Returns:** `(ID, String, u64, u64, u64, bool)` - Event ID, name, pool balance, claimed count, expiration time, active status

#### `get_claim_status`
Gets user's claim status for a specific airdrop.

```move
public fun get_claim_status(
    user: address,
    airdrop_id: ID,
    registry: &AirdropRegistry
): (bool, u64)
```

**Returns:** `(bool, u64)` - Whether claimed and claim amount

#### `is_user_eligible`
Checks if a user is eligible for an airdrop.

```move
public fun is_user_eligible(
    user: address,
    airdrop_id: ID,
    registry: &AirdropRegistry,
    attendance_registry: &AttendanceRegistry,
    nft_registry: &NFTRegistry,
    rating_registry: &RatingRegistry,
): bool
```

**Returns:** `bool` - Whether user meets all eligibility criteria

#### `get_event_airdrops`
Gets all airdrops for a specific event.

```move
public fun get_event_airdrops(
    event_id: ID,
    registry: &AirdropRegistry
): vector<ID>
```

**Returns:** Vector of airdrop IDs associated with the event

#### `get_user_claims`
Gets user's complete claim history.

```move
public fun get_user_claims(
    user: address,
    registry: &AirdropRegistry
): vector<ClaimRecord>
```

**Returns:** Vector of all claim records for the user

## Events Emitted

### AirdropCreated
```move
public struct AirdropCreated has copy, drop {
    airdrop_id: ID,
    event_id: ID,
    total_amount: u64,
    distribution_type: u8,
    expires_at: u64,
}
```

### AirdropClaimed
```move
public struct AirdropClaimed has copy, drop {
    airdrop_id: ID,
    claimer: address,
    amount: u64,
    claimed_at: u64,
}
```

### AirdropCompleted
```move
public struct AirdropCompleted has copy, drop {
    airdrop_id: ID,
    total_claimed: u64,
    recipients: u64,
}
```

## Frontend Integration Examples

### Complete Airdrop Management Flow
```typescript
import { Transaction } from '@mysten/sui/transactions';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';

const client = new SuiClient({ url: getFullnodeUrl('testnet') });

// 1. Create airdrop campaign
async function createAirdropCampaign(
    eventId: string,
    campaignData: {
        name: string;
        description: string;
        totalAmount: number; // SUI amount
        distributionType: number; // 0, 1, or 2
        eligibility: {
            requireAttendance: boolean;
            requireCompletion: boolean;
            minDuration: number; // milliseconds
            requireRating: boolean;
        };
        validityDays: number;
    }
) {
    try {
        // Get or create SUI coin for the amount
        const suiCoin = await getSuiCoin(campaignData.totalAmount);
        
        const tx = new Transaction();
        const airdropId = tx.moveCall({
            target: `${PACKAGE_ID}::airdrop_distribution::create_airdrop`,
            arguments: [
                tx.object(eventId),
                tx.pure.string(campaignData.name),
                tx.pure.string(campaignData.description),
                tx.object(suiCoin),
                tx.pure.u8(campaignData.distributionType),
                tx.pure.bool(campaignData.eligibility.requireAttendance),
                tx.pure.bool(campaignData.eligibility.requireCompletion),
                tx.pure.u64(campaignData.eligibility.minDuration),
                tx.pure.bool(campaignData.eligibility.requireRating),
                tx.pure.u64(campaignData.validityDays),
                tx.object(AIRDROP_REGISTRY_ID),
                tx.object(ATTENDANCE_REGISTRY_ID),
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
        
        // Extract airdrop ID from events
        const createdEvent = result.events?.find(
            event => event.type.includes('AirdropCreated')
        );
        
        if (createdEvent) {
            console.log('Airdrop created:', createdEvent.parsedJson);
            return createdEvent.parsedJson.airdrop_id;
        }
        
        return result;
        
    } catch (error) {
        console.error('Airdrop creation failed:', error);
        throw error;
    }
}

// 2. Check user eligibility
async function checkAirdropEligibility(
    userWallet: string,
    airdropId: string
): Promise<boolean> {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::airdrop_distribution::is_user_eligible`,
        arguments: [
            tx.pure.address(userWallet),
            tx.pure.id(airdropId),
            tx.object(AIRDROP_REGISTRY_ID),
            tx.object(ATTENDANCE_REGISTRY_ID),
            tx.object(NFT_REGISTRY_ID),
            tx.object(RATING_REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: userWallet,
    });
    
    return result.effects?.status?.status === 'success';
}

// 3. Claim airdrop
async function claimAirdrop(airdropId: string) {
    try {
        // Check eligibility first
        const eligible = await checkAirdropEligibility(
            await wallet.getAddress(),
            airdropId
        );
        
        if (!eligible) {
            throw new Error('You are not eligible for this airdrop');
        }
        
        const tx = new Transaction();
        tx.moveCall({
            target: `${PACKAGE_ID}::airdrop_distribution::claim_airdrop`,
            arguments: [
                tx.pure.id(airdropId),
                tx.object(AIRDROP_REGISTRY_ID),
                tx.object(ATTENDANCE_REGISTRY_ID),
                tx.object(NFT_REGISTRY_ID),
                tx.object(RATING_REGISTRY_ID),
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
            throw new Error(`Claim failed: ${result.effects.status.error}`);
        }
        
        // Extract claim amount from events
        const claimEvent = result.events?.find(
            event => event.type.includes('AirdropClaimed')
        );
        
        if (claimEvent) {
            const claimData = claimEvent.parsedJson as any;
            console.log(`Successfully claimed ${claimData.amount} SUI`);
        }
        
        return result;
        
    } catch (error) {
        console.error('Claim failed:', error);
        throw error;
    }
}

// 4. Get airdrop details
async function getAirdropDetails(airdropId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::airdrop_distribution::get_airdrop_details`,
        arguments: [
            tx.pure.id(airdropId),
            tx.object(AIRDROP_REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: await wallet.getAddress(),
    });
    
    if (result.effects?.status?.status === 'success') {
        const [eventId, name, poolBalance, claimedCount, expiresAt, active] = result.returnValues;
        
        return {
            eventId: eventId,
            name: name,
            poolBalance: parseInt(poolBalance),
            claimedCount: parseInt(claimedCount),
            expiresAt: new Date(parseInt(expiresAt)),
            active: active === 'true',
            hasExpired: Date.now() > parseInt(expiresAt),
        };
    }
    
    return null;
}

// 5. Batch distribution (organizer only)
async function batchDistribute(airdropId: string, recipients: string[]) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::airdrop_distribution::batch_distribute`,
        arguments: [
            tx.pure.id(airdropId),
            tx.pure.vector('address', recipients),
            tx.object(AIRDROP_REGISTRY_ID),
            tx.object(ATTENDANCE_REGISTRY_ID),
            tx.object(NFT_REGISTRY_ID),
            tx.object(RATING_REGISTRY_ID),
            tx.object(CLOCK_ID),
        ],
    });
    
    return await wallet.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
            showEffects: true,
            showEvents: true,
        },
    });
}

// Helper function to get SUI coin
async function getSuiCoin(amount: number): Promise<string> {
    // Implementation depends on wallet integration
    // This would typically involve getting SUI coins from user's wallet
    // and potentially merging them to get the required amount
    throw new Error('Implement getSuiCoin based on your wallet integration');
}
```

### Airdrop Dashboard Component
```typescript
interface AirdropDashboardProps {
    eventId: string;
    userWallet: string;
    isOrganizer: boolean;
}

function AirdropDashboard({ eventId, userWallet, isOrganizer }: AirdropDashboardProps) {
    const [airdrops, setAirdrops] = useState([]);
    const [userClaims, setUserClaims] = useState([]);
    const [loading, setLoading] = useState(true);
    
    useEffect(() => {
        loadAirdropData();
    }, [eventId, userWallet]);
    
    const loadAirdropData = async () => {
        try {
            setLoading(true);
            
            // Get all airdrops for the event
            const airdropIds = await getEventAirdrops(eventId);
            
            // Get details for each airdrop
            const airdropDetails = await Promise.all(
                airdropIds.map(id => getAirdropDetails(id))
            );
            
            setAirdrops(airdropDetails.filter(Boolean));
            
            // Get user's claim history
            const claims = await getUserClaims(userWallet);
            setUserClaims(claims);
            
        } catch (error) {
            console.error('Error loading airdrop data:', error);
        } finally {
            setLoading(false);
        }
    };
    
    if (loading) return <div>Loading airdrops...</div>;
    
    return (
        <div className="airdrop-dashboard">
            <h3>Event Airdrops</h3>
            
            {airdrops.length === 0 ? (
                <p>No airdrops available for this event.</p>
            ) : (
                <div className="airdrops-list">
                    {airdrops.map(airdrop => (
                        <AirdropCard
                            key={airdrop.eventId}
                            airdrop={airdrop}
                            userWallet={userWallet}
                            isOrganizer={isOrganizer}
                            onClaim={loadAirdropData}
                        />
                    ))}
                </div>
            )}
            
            {userClaims.length > 0 && (
                <div className="claim-history">
                    <h4>Your Claims</h4>
                    <div className="claims-list">
                        {userClaims.map((claim, index) => (
                            <div key={index} className="claim-item">
                                <span>Amount: {claim.amount} SUI</span>
                                <span>Date: {new Date(claim.claimed_at).toLocaleDateString()}</span>
                            </div>
                        ))}
                    </div>
                </div>
            )}
        </div>
    );
}

function AirdropCard({ airdrop, userWallet, isOrganizer, onClaim }) {
    const [eligible, setEligible] = useState(false);
    const [claimed, setClaimed] = useState(false);
    const [claiming, setClaiming] = useState(false);
    
    useEffect(() => {
        checkEligibilityAndStatus();
    }, [airdrop, userWallet]);
    
    const checkEligibilityAndStatus = async () => {
        try {
            const isEligible = await checkAirdropEligibility(userWallet, airdrop.id);
            setEligible(isEligible);
            
            const claimStatus = await getClaimStatus(userWallet, airdrop.id);
            setClaimed(claimStatus.claimed);
            
        } catch (error) {
            console.error('Error checking eligibility:', error);
        }
    };
    
    const handleClaim = async () => {
        setClaiming(true);
        try {
            await claimAirdrop(airdrop.id);
            setClaimed(true);
            onClaim(); // Refresh data
        } catch (error) {
            console.error('Claim failed:', error);
            // Show error message to user
        } finally {
            setClaiming(false);
        }
    };
    
    return (
        <div className="airdrop-card">
            <h4>{airdrop.name}</h4>
            <div className="airdrop-details">
                <p>Pool: {airdrop.poolBalance} SUI</p>
                <p>Claims: {airdrop.claimedCount}</p>
                <p>Expires: {airdrop.expiresAt.toLocaleDateString()}</p>
                <p>Status: {airdrop.active && !airdrop.hasExpired ? 'Active' : 'Inactive'}</p>
            </div>
            
            <div className="airdrop-actions">
                {claimed ? (
                    <span className="claimed-badge">✅ Claimed</span>
                ) : eligible && airdrop.active && !airdrop.hasExpired ? (
                    <button 
                        onClick={handleClaim} 
                        disabled={claiming}
                        className="claim-button"
                    >
                        {claiming ? 'Claiming...' : 'Claim Reward'}
                    </button>
                ) : (
                    <span className="not-eligible">
                        {!eligible ? 'Not Eligible' : 
                         airdrop.hasExpired ? 'Expired' : 'Inactive'}
                    </span>
                )}
                
                {isOrganizer && airdrop.hasExpired && airdrop.poolBalance > 0 && (
                    <button onClick={() => withdrawUnclaimed(airdrop.id)}>
                        Withdraw Unclaimed
                    </button>
                )}
            </div>
        </div>
    );
}
```

### Distribution Type Examples
```typescript
// Distribution type configurations
const DISTRIBUTION_TYPES = {
    EQUAL: {
        type: 0,
        name: "Equal Distribution",
        description: "Same amount for all eligible participants"
    },
    DURATION_WEIGHTED: {
        type: 1,
        name: "Duration Weighted",
        description: "Amount based on attendance duration"
    },
    COMPLETION_BONUS: {
        type: 2,
        name: "Completion Bonus",
        description: "Bonus rewards for full event completion"
    }
};

// Example airdrop configurations
const AIRDROP_TEMPLATES = {
    // Basic attendance reward
    ATTENDANCE_REWARD: {
        name: "Attendance Reward",
        description: "Thank you for attending!",
        distributionType: DISTRIBUTION_TYPES.EQUAL.type,
        eligibility: {
            requireAttendance: true,
            requireCompletion: false,
            minDuration: 0,
            requireRating: false,
        }
    },
    
    // Completion bonus
    COMPLETION_BONUS: {
        name: "Completion Certificate Bonus",
        description: "Extra reward for completing the full event",
        distributionType: DISTRIBUTION_TYPES.COMPLETION_BONUS.type,
        eligibility: {
            requireAttendance: true,
            requireCompletion: true,
            minDuration: 3600000, // 1 hour
            requireRating: false,
        }
    },
    
    // Engagement reward
    ENGAGEMENT_REWARD: {
        name: "Community Engagement Reward",
        description: "For active participants who provided feedback",
        distributionType: DISTRIBUTION_TYPES.DURATION_WEIGHTED.type,
        eligibility: {
            requireAttendance: true,
            requireCompletion: true,
            minDuration: 1800000, // 30 minutes
            requireRating: true,
        }
    }
};
```

### Real-Time Airdrop Monitoring
```typescript
// Monitor airdrop events
class AirdropMonitor {
    private client: SuiClient;
    
    constructor() {
        this.client = new SuiClient({ url: getFullnodeUrl('testnet') });
        this.setupEventListeners();
    }
    
    private setupEventListeners() {
        // Monitor airdrop creation
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::airdrop_distribution::AirdropCreated`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handleAirdropCreated(data);
            },
        });
        
        // Monitor claims
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::airdrop_distribution::AirdropClaimed`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handleAirdropClaimed(data);
            },
        });
        
        // Monitor completion
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::airdrop_distribution::AirdropCompleted`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handleAirdropCompleted(data);
            },
        });
    }
    
    private handleAirdropCreated(data: any) {
        console.log(`New airdrop created: ${data.total_amount} SUI for event ${data.event_id}`);
        // Update UI with new airdrop
    }
    
    private handleAirdropClaimed(data: any) {
        console.log(`Airdrop claimed: ${data.amount} SUI by ${data.claimer}`);
        // Update claim statistics
    }
    
    private handleAirdropCompleted(data: any) {
        console.log(`Airdrop completed: ${data.total_claimed} SUI distributed to ${data.recipients} recipients`);
        // Mark airdrop as complete in UI
    }
}
```

### Error Handling
```typescript
async function safeClaimAirdrop(airdropId: string) {
    try {
        const result = await claimAirdrop(airdropId);
        
        if (result.effects?.status?.status === 'failure') {
            const error = result.effects.status.error;
            switch (error) {
                case 'ENotEligible':
                    throw new Error('You do not meet the eligibility requirements for this airdrop');
                case 'EAlreadyClaimed':
                    throw new Error('You have already claimed this airdrop');
                case 'EAirdropExpired':
                    throw new Error('This airdrop has expired');
                case 'EAirdropNotActive':
                    throw new Error('This airdrop is no longer active');
                case 'EInsufficientFunds':
                    throw new Error('Insufficient funds remaining in airdrop pool');
                default:
                    throw new Error(`Claim failed: ${error}`);
            }
        }
        
        return result;
        
    } catch (error) {
        console.error('Airdrop claim error:', error);
        throw error;
    }
}
```

## Integration with Other Contracts

### Attendance Verification Contract
- **Eligibility Validation**: Verifies check-in/check-out status and duration
- **Performance Metrics**: Uses attendance data for weighted distributions
- **Fraud Prevention**: Ensures only genuine participants receive rewards

### NFT Minting Contract
- **Completion Verification**: Checks for Completion NFTs as eligibility criteria
- **Token Gating**: Can require specific NFT ownership for exclusive airdrops
- **Cross-Validation**: Ensures consistency between NFT ownership and airdrop eligibility

### Rating Reputation Contract
- **Rating Requirements**: Validates users have submitted event ratings
- **Quality Control**: Ensures only engaged participants receive certain rewards
- **Feedback Incentivization**: Encourages post-event rating submissions

### Event Management Contract
- **Event Validation**: Ensures airdrops are only created for valid events
- **Organizer Authorization**: Validates airdrop creator is event organizer
- **Event Completion**: Links airdrop timing to event lifecycle

## Best Practices

### For Event Organizers
1. **Set Clear Criteria**: Define specific, achievable eligibility requirements
2. **Choose Appropriate Distribution**: Match distribution type to event goals
3. **Set Reasonable Expiry**: Allow sufficient time for participants to claim
4. **Fund Adequately**: Ensure pool covers all potential eligible participants
5. **Monitor Claims**: Track distribution progress and participant engagement

### For Event Participants
1. **Complete Requirements**: Fulfill all eligibility criteria during the event
2. **Claim Promptly**: Don't wait until the last minute to claim rewards
3. **Verify Eligibility**: Check eligibility status before attempting to claim
4. **Keep Wallets Secure**: Ensure wallet security for receiving rewards

### For Frontend Developers
1. **Handle All Errors**: Implement comprehensive error handling for all operations
2. **Real-Time Updates**: Subscribe to events for live airdrop monitoring
3. **Clear Status Display**: Show eligibility, claim status, and requirements clearly
4. **Batch Operations**: Use batch distribution for gas optimization when possible
5. **User Education**: Provide clear instructions on claim processes and requirements

## Advanced Use Cases

### Multi-Tier Rewards
```typescript
// Create multiple airdrops with different criteria for the same event
async function createTieredRewards(eventId: string) {
    const campaigns = [
        {
            name: "Basic Attendance",
            amount: 10, // 10 SUI total
            criteria: { attendance: true, completion: false, rating: false },
            distribution: 0, // Equal
        },
        {
            name: "Completion Bonus",
            amount: 20, // 20 SUI total
            criteria: { attendance: true, completion: true, rating: false },
            distribution: 2, // Completion bonus
        },
        {
            name: "Community Champion",
            amount: 30, // 30 SUI total
            criteria: { attendance: true, completion: true, rating: true },
            distribution: 1, // Duration weighted
        }
    ];
    
    const airdropIds = [];
    for (const campaign of campaigns) {
        const id = await createAirdropCampaign(eventId, {
            name: campaign.name,
            description: `Reward tier: ${campaign.name}`,
            totalAmount: campaign.amount,
            distributionType: campaign.distribution,
            eligibility: {
                requireAttendance: campaign.criteria.attendance,
                requireCompletion: campaign.criteria.completion,
                minDuration: campaign.criteria.completion ? 3600000 : 0,
                requireRating: campaign.criteria.rating,
            },
            validityDays: 30,
        });
        airdropIds.push(id);
    }
    
    return airdropIds;
}
```

### Analytics Dashboard
```typescript
// Comprehensive airdrop analytics
function AirdropAnalytics({ organizerWallet }) {
    const [analytics, setAnalytics] = useState(null);
    
    useEffect(() => {
        loadAnalytics();
    }, [organizerWallet]);
    
    const loadAnalytics = async () => {
        // Get all events organized by this user
        const events = await getOrganizerEvents(organizerWallet);
        
        const analyticsData = {
            totalAirdrops: 0,
            totalDistributed: 0,
            totalRecipients: 0,
            averageClaimRate: 0,
            distributionByType: { equal: 0, weighted: 0, bonus: 0 },
            monthlyTrends: [],
            topEvents: [],
        };
        
        for (const event of events) {
            const airdrops = await getEventAirdrops(event.id);
            
            for (const airdropId of airdrops) {
                const details = await getAirdropDetails(airdropId);
                
                analyticsData.totalAirdrops++;
                analyticsData.totalDistributed += (details.totalAmount - details.poolBalance);
                analyticsData.totalRecipients += details.claimedCount;
                
                // Track distribution types
                if (details.distributionType === 0) analyticsData.distributionByType.equal++;
                else if (details.distributionType === 1) analyticsData.distributionByType.weighted++;
                else if (details.distributionType === 2) analyticsData.distributionByType.bonus++;
            }
        }
        
        analyticsData.averageClaimRate = analyticsData.totalRecipients / analyticsData.totalAirdrops;
        setAnalytics(analyticsData);
    };
    
    return (
        <div className="airdrop-analytics">
            <h2>Airdrop Analytics</h2>
            
            {analytics && (
                <div className="analytics-grid">
                    <div className="metric-card">
                        <h3>Total Distributed</h3>
                        <span className="big-number">{analytics.totalDistributed} SUI</span>
                    </div>
                    
                    <div className="metric-card">
                        <h3>Total Recipients</h3>
                        <span className="big-number">{analytics.totalRecipients}</span>
                    </div>
                    
                    <div className="metric-card">
                        <h3>Airdrops Created</h3>
                        <span className="big-number">{analytics.totalAirdrops}</span>
                    </div>
                    
                    <div className="metric-card">
                        <h3>Avg Claim Rate</h3>
                        <span className="big-number">
                            {(analytics.averageClaimRate * 100).toFixed(1)}%
                        </span>
                    </div>
                </div>
            )}
            
            <DistributionTypeChart data={analytics?.distributionByType} />
        </div>
    );
}
```

### Automated Airdrop Workflows
```typescript
// Automated post-event airdrop creation
class AutomatedAirdropManager {
    private monitoredEvents: Set<string> = new Set();
    
    async setupEventMonitoring(eventId: string, airdropConfig: any) {
        this.monitoredEvents.add(eventId);
        
        // Monitor event completion
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::event_management::EventCompleted`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                if (data.event_id === eventId) {
                    this.handleEventCompleted(eventId, airdropConfig);
                }
            },
        });
    }
    
    private async handleEventCompleted(eventId: string, config: any) {
        try {
            // Wait for settlement period
            await this.waitForSettlement(24 * 60 * 60 * 1000); // 24 hours
            
            // Create automatic airdrop
            const airdropId = await createAirdropCampaign(eventId, {
                name: config.name || "Post-Event Reward",
                description: config.description || "Thank you for participating!",
                totalAmount: config.amount,
                distributionType: config.distributionType || 0,
                eligibility: config.eligibility,
                validityDays: config.validityDays || 30,
            });
            
            // Get eligible participants
            const participants = await getEligibleParticipants(eventId, config.eligibility);
            
            // Batch distribute to all eligible participants
            if (participants.length > 0) {
                await batchDistribute(airdropId, participants);
            }
            
            console.log(`Automated airdrop distributed to ${participants.length} participants`);
            
        } catch (error) {
            console.error('Automated airdrop failed:', error);
            // Could implement retry logic or fallback notifications
        }
    }
    
    private async waitForSettlement(delay: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, delay));
    }
    
    private async getEligibleParticipants(eventId: string, criteria: any): Promise<string[]> {
        // Implementation would query attendance records and filter by criteria
        // This is a placeholder - actual implementation would be more complex
        return [];
    }
}
```

## Security Considerations

### Fund Safety
1. **Immutable Conditions**: Eligibility criteria cannot be changed after creation
2. **Expiration Protection**: Unclaimed funds can be withdrawn after expiry
3. **Single Claim**: Each user can only claim once per airdrop
4. **Balance Verification**: Claims are validated against available pool balance

### Eligibility Verification
1. **Multi-Contract Validation**: Verifies conditions across multiple protocol contracts
2. **Attendance Proof**: Requires verifiable attendance records
3. **NFT Ownership**: Can require specific NFT possession for eligibility
4. **Rating Participation**: Validates community engagement through ratings

### Anti-Gaming Measures
1. **Real Participation**: Links rewards to verified event participation
2. **Time Constraints**: Prevents retroactive gaming with expiration dates
3. **Organizer Control**: Only event organizers can create airdrops
4. **Transparent Rules**: All eligibility criteria are publicly verifiable

## Limitations and Considerations

1. **SUI Only**: Currently supports only SUI token distributions
2. **Manual Metrics**: Some eligibility criteria rely on self-reported data
3. **Gas Costs**: Individual claims incur transaction fees for users
4. **Expiration Required**: All airdrops must have expiration dates
5. **Single Distribution**: Each airdrop uses one distribution method only

## Future Enhancements

### Planned Features
1. **Multi-Token Support**: Support for other Sui ecosystem tokens
2. **Conditional Logic**: More complex eligibility criteria combinations
3. **Recurring Airdrops**: Automated periodic distributions
4. **Cross-Event Rewards**: Airdrops based on multiple event participation
5. **Gamification**: Achievement-based reward systems

### Integration Opportunities
1. **DeFi Protocols**: Staking rewards for long-term token holders
2. **DAO Governance**: Voting power based on event participation
3. **Marketplace Integration**: NFT trading rewards for active participants
4. **External APIs**: Integration with social media and other platforms
5. **Cross-Chain**: Multi-chain airdrop coordination

This contract provides a comprehensive, flexible foundation for automated reward distribution within the EIA Protocol, enabling organizers to incentivize participation while ensuring only genuine event participants receive rewards through transparent, verifiable mechanisms.