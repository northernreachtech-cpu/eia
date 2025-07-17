# EIA NFT Minting Contract Documentation

## Overview

The EIA NFT Minting contract automatically generates verifiable NFTs based on event attendance within the Ephemeral Identity & Attendance (EIA) Protocol. This contract issues two types of NFTs: Proof-of-Attendance (PoA) NFTs for check-ins and Completion NFTs for full event participation, providing immutable proof of event engagement.

## Module Information

- **Module**: `eia::nft_minting`
- **Network**: Sui Blockchain
- **Language**: Move
- **Dependencies**: `eia::attendance_verification`

## Core Data Structures

### NFT Types

#### ProofOfAttendance
NFT issued upon successful event check-in.

```move
public struct ProofOfAttendance has key, store {
    id: UID,
    event_id: ID,              // Associated event
    event_name: String,        // Human-readable event name
    attendee: address,         // NFT owner's wallet
    check_in_time: u64,        // Check-in timestamp (ms)
    metadata: NFTMetadata,     // Rich metadata and attributes
}
```

#### NFTOfCompletion
NFT issued upon successful event check-out (full participation).

```move
public struct NFTOfCompletion has key, store {
    id: UID,
    event_id: ID,
    event_name: String,
    attendee: address,
    check_in_time: u64,
    check_out_time: u64,
    attendance_duration: u64,   // Total attendance time (ms)
    metadata: NFTMetadata,
}
```

### Metadata Structures

#### NFTMetadata
Rich metadata for NFT display and marketplaces.

```move
public struct NFTMetadata has store, drop, copy {
    description: String,        // NFT description
    image_url: String,         // Image/artwork URL
    location: String,          // Event location
    organizer: address,        // Event organizer
    attributes: vector<Attribute>, // Trait attributes
}
```

#### Attribute
Individual trait attributes for NFT metadata.

```move
public struct Attribute has store, drop, copy {
    trait_type: String,        // Attribute name (e.g., "Duration")
    value: String,             // Attribute value (e.g., "2h 30m")
}
```

### Registry and Tracking

#### NFTRegistry
Central registry tracking all minted NFTs and statistics.

```move
public struct NFTRegistry has key {
    id: UID,
    event_nfts: Table<ID, EventNFTs>,           // event_id -> NFT data
    user_nfts: Table<address, UserNFTs>,        // wallet -> owned NFTs
    total_poa_minted: u64,                      // Global PoA count
    total_completion_minted: u64,               // Global completion count
}
```

#### EventNFTs
Per-event NFT tracking and metadata.

```move
public struct EventNFTs has store {
    poa_minted: Table<address, ID>,        // wallet -> PoA NFT ID
    completion_minted: Table<address, ID>, // wallet -> Completion NFT ID
    total_poa: u64,                        // Event PoA count
    total_completions: u64,                // Event completion count
    event_metadata: EventMetadata,         // Event display metadata
}
```

#### UserNFTs
User's NFT collection tracking.

```move
public struct UserNFTs has store {
    poa_tokens: vector<ID>,        // User's PoA NFTs
    completion_tokens: vector<ID>, // User's completion NFTs
}
```

## Error Codes

| Error | Code | Description |
|-------|------|-------------|
| `EInvalidCapability` | 1 | Invalid or consumed minting capability |
| `EAlreadyMinted` | 2 | NFT already minted for this user/event |

## Public Functions

### Metadata Management

#### `set_event_metadata`
Configures display metadata for event NFTs.

```move
public fun set_event_metadata(
    event_id: ID,
    event_name: String,
    image_url: String,
    location: String,
    organizer: address,
    registry: &mut NFTRegistry,
    ctx: &mut TxContext
)
```

**Parameters:**
- `event_id`: Event identifier
- `event_name`: Display name for the event
- `image_url`: URL to event artwork/image
- `location`: Event location string
- `organizer`: Event organizer's address
- `registry`: Mutable reference to NFT registry
- `ctx`: Transaction context

**Usage:**
This function should be called by event organizers before NFT minting begins to ensure proper metadata display.

**Frontend Usage:**
```typescript
const tx = new Transaction();
tx.moveCall({
    target: `${PACKAGE_ID}::nft_minting::set_event_metadata`,
    arguments: [
        tx.pure.id(eventId),
        tx.pure.string("Tech Conference 2024"),
        tx.pure.string("https://ipfs.io/ipfs/QmExample..."),
        tx.pure.string("San Francisco, CA"),
        tx.pure.address(organizerAddress),
        tx.object(NFT_REGISTRY_ID),
    ],
});
```

### NFT Minting

#### `mint_proof_of_attendance`
Mints a Proof-of-Attendance NFT from a check-in capability.

```move
public fun mint_proof_of_attendance(
    capability: MintPoACapability,
    registry: &mut NFTRegistry,
    ctx: &mut TxContext
): ID
```

**Parameters:**
- `capability`: MintPoACapability from attendance verification
- `registry`: Mutable reference to NFT registry
- `ctx`: Transaction context

**Returns:** `ID` - The minted NFT's object ID

**Process:**
1. Consumes the PoA capability from attendance contract
2. Validates event metadata exists
3. Checks for duplicate minting
4. Creates NFT with attendance attributes
5. Updates registry statistics
6. Transfers NFT to attendee
7. Emits `PoAMinted` event

**Attributes Generated:**
- Event Type: "Proof of Attendance"
- Check-in Time: Formatted timestamp
- Location: Event location

**Frontend Usage:**
```typescript
// Capability is received from check-in process
const tx = new Transaction();
const [nftId] = tx.moveCall({
    target: `${PACKAGE_ID}::nft_minting::mint_proof_of_attendance`,
    arguments: [
        tx.object(poaCapabilityId), // From check-in transaction
        tx.object(NFT_REGISTRY_ID),
    ],
});
```

#### `mint_nft_of_completion`
Mints a Completion NFT from a check-out capability.

```move
public fun mint_nft_of_completion(
    capability: MintCompletionCapability,
    registry: &mut NFTRegistry,
    ctx: &mut TxContext
): ID
```

**Parameters:**
- `capability`: MintCompletionCapability from attendance verification
- `registry`: Mutable reference to NFT registry
- `ctx`: Transaction context

**Returns:** `ID` - The minted NFT's object ID

**Process:**
1. Consumes the completion capability
2. Validates event metadata exists
3. Checks for duplicate minting
4. Creates NFT with completion attributes
5. Updates registry statistics
6. Transfers NFT to attendee
7. Emits `CompletionMinted` event

**Attributes Generated:**
- Event Type: "Certificate of Completion"
- Attendance Duration: Formatted duration (e.g., "2h 30m")
- Check-in Time: Formatted timestamp
- Check-out Time: Formatted timestamp
- Location: Event location

**Frontend Usage:**
```typescript
// Capability is received from check-out process
const tx = new Transaction();
const [nftId] = tx.moveCall({
    target: `${PACKAGE_ID}::nft_minting::mint_nft_of_completion`,
    arguments: [
        tx.object(completionCapabilityId), // From check-out transaction
        tx.object(NFT_REGISTRY_ID),
    ],
});
```

### Query Functions (Read-Only)

#### `has_proof_of_attendance`
Checks if a user has a PoA NFT for a specific event.

```move
public fun has_proof_of_attendance(
    wallet: address,
    event_id: ID,
    registry: &NFTRegistry
): bool
```

**Returns:** `bool` - Whether user owns a PoA NFT for the event

#### `has_completion_nft`
Checks if a user has a Completion NFT for a specific event.

```move
public fun has_completion_nft(
    wallet: address,
    event_id: ID,
    registry: &NFTRegistry
): bool
```

**Returns:** `bool` - Whether user owns a Completion NFT for the event

#### `get_user_nfts`
Gets all NFTs owned by a user.

```move
public fun get_user_nfts(
    wallet: address,
    registry: &NFTRegistry
): (vector<ID>, vector<ID>)
```

**Returns:** `(vector<ID>, vector<ID>)` - PoA NFT IDs and Completion NFT IDs

#### `get_event_nft_stats`
Gets minting statistics for an event.

```move
public fun get_event_nft_stats(
    event_id: ID,
    registry: &NFTRegistry
): (u64, u64)
```

**Returns:** `(u64, u64)` - Total PoA NFTs minted and total Completion NFTs minted

## Events Emitted

### PoAMinted
```move
public struct PoAMinted has copy, drop {
    nft_id: ID,
    event_id: ID,
    attendee: address,
    check_in_time: u64,
}
```

### CompletionMinted
```move
public struct CompletionMinted has copy, drop {
    nft_id: ID,
    event_id: ID,
    attendee: address,
    attendance_duration: u64,
}
```

## NFT Display Configuration

The contract automatically configures NFT display properties for marketplaces and wallets:

### Proof of Attendance Display
- **Name**: "Proof of Attendance - {event_name}"
- **Description**: Dynamic from metadata
- **Image**: Event-specific artwork
- **Project URL**: EIA Protocol frontend

### Completion NFT Display
- **Name**: "Certificate of Completion - {event_name}"
- **Description**: Dynamic from metadata
- **Image**: Event-specific artwork
- **Project URL**: EIA Protocol frontend

## Frontend Integration Examples

### Complete NFT Minting Flow
```typescript
import { Transaction } from '@mysten/sui/transactions';
import { SuiClient, getFullnodeUrl } from '@mysten/sui/client';

const client = new SuiClient({ url: getFullnodeUrl('testnet') });

// 1. Set event metadata (organizer only)
async function setupEventNFTMetadata(eventId: string, eventData: any) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::nft_minting::set_event_metadata`,
        arguments: [
            tx.pure.id(eventId),
            tx.pure.string(eventData.name),
            tx.pure.string(eventData.imageUrl),
            tx.pure.string(eventData.location),
            tx.pure.address(eventData.organizer),
            tx.object(NFT_REGISTRY_ID),
        ],
    });
    
    return await wallet.signAndExecuteTransactionBlock({
        transactionBlock: tx,
    });
}

// 2. Mint PoA NFT after check-in
async function mintPoANFT(poaCapabilityId: string) {
    try {
        const tx = new Transaction();
        const [nftId] = tx.moveCall({
            target: `${PACKAGE_ID}::nft_minting::mint_proof_of_attendance`,
            arguments: [
                tx.object(poaCapabilityId),
                tx.object(NFT_REGISTRY_ID),
            ],
        });
        
        const result = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx,
            options: {
                showEffects: true,
                showEvents: true,
            },
        });
        
        // Extract NFT ID from results
        const nftObjectId = extractNFTId(result);
        return nftObjectId;
        
    } catch (error) {
        console.error('PoA NFT minting failed:', error);
        throw error;
    }
}

// 3. Mint Completion NFT after check-out
async function mintCompletionNFT(completionCapabilityId: string) {
    try {
        const tx = new Transaction();
        const [nftId] = tx.moveCall({
            target: `${PACKAGE_ID}::nft_minting::mint_nft_of_completion`,
            arguments: [
                tx.object(completionCapabilityId),
                tx.object(NFT_REGISTRY_ID),
            ],
        });
        
        const result = await wallet.signAndExecuteTransactionBlock({
            transactionBlock: tx,
            options: {
                showEffects: true,
                showEvents: true,
            },
        });
        
        return extractNFTId(result);
        
    } catch (error) {
        console.error('Completion NFT minting failed:', error);
        throw error;
    }
}

// 4. Check user's NFT ownership
async function checkUserNFTs(userWallet: string, eventId: string) {
    const tx = new Transaction();
    
    // Check PoA ownership
    tx.moveCall({
        target: `${PACKAGE_ID}::nft_minting::has_proof_of_attendance`,
        arguments: [
            tx.pure.address(userWallet),
            tx.pure.id(eventId),
            tx.object(NFT_REGISTRY_ID),
        ],
    });
    
    // Check Completion ownership
    tx.moveCall({
        target: `${PACKAGE_ID}::nft_minting::has_completion_nft`,
        arguments: [
            tx.pure.address(userWallet),
            tx.pure.id(eventId),
            tx.object(NFT_REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: userWallet,
    });
    
    return result;
}

// 5. Get user's complete NFT collection
async function getUserNFTCollection(userWallet: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::nft_minting::get_user_nfts`,
        arguments: [
            tx.pure.address(userWallet),
            tx.object(NFT_REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: userWallet,
    });
    
    if (result.effects?.status?.status === 'success') {
        // Parse PoA and Completion NFT arrays
        const [poaNFTs, completionNFTs] = parseNFTArrays(result);
        return { poaNFTs, completionNFTs };
    }
    
    return { poaNFTs: [], completionNFTs: [] };
}

// 6. Get event NFT statistics
async function getEventNFTStats(eventId: string) {
    const tx = new Transaction();
    tx.moveCall({
        target: `${PACKAGE_ID}::nft_minting::get_event_nft_stats`,
        arguments: [
            tx.pure.id(eventId),
            tx.object(NFT_REGISTRY_ID),
        ],
    });
    
    const result = await client.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: await wallet.getAddress(),
    });
    
    return result;
}

// Helper function to extract NFT ID from transaction results
function extractNFTId(result: any): string | null {
    if (result.effects?.created) {
        // Find the created NFT object
        const createdObjects = result.effects.created;
        for (const obj of createdObjects) {
            if (obj.objectType.includes('ProofOfAttendance') || 
                obj.objectType.includes('NFTOfCompletion')) {
                return obj.objectId;
            }
        }
    }
    return null;
}
```

### Automated NFT Minting Integration
```typescript
// Integrated check-in with automatic PoA minting
async function checkInAndMintPoA(passHash: Uint8Array, eventId: string) {
    const tx = new Transaction();
    
    // Step 1: Check in to event
    const [poaCapability] = tx.moveCall({
        target: `${PACKAGE_ID}::attendance_verification::check_in`,
        arguments: [
            tx.pure(bcs.vector(bcs.U8).serialize(Array.from(passHash))),
            tx.pure(bcs.vector(bcs.U8).serialize([])), // device fingerprint
            tx.pure(bcs.vector(bcs.U8).serialize([])), // location proof
            tx.object(eventId),
            tx.object(ATTENDANCE_REGISTRY_ID),
            tx.object(IDENTITY_REGISTRY_ID),
            tx.object(CLOCK_ID),
        ],
    });
    
    // Step 2: Immediately mint PoA NFT
    const [nftId] = tx.moveCall({
        target: `${PACKAGE_ID}::nft_minting::mint_proof_of_attendance`,
        arguments: [
            poaCapability, // Use capability from check-in
            tx.object(NFT_REGISTRY_ID),
        ],
    });
    
    const result = await wallet.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
            showEffects: true,
            showEvents: true,
        },
    });
    
    return result;
}

// Integrated check-out with automatic Completion NFT minting
async function checkOutAndMintCompletion(userWallet: string, eventId: string) {
    const tx = new Transaction();
    
    // Step 1: Check out from event
    const [completionCapability] = tx.moveCall({
        target: `${PACKAGE_ID}::attendance_verification::check_out`,
        arguments: [
            tx.pure.address(userWallet),
            tx.pure.id(eventId),
            tx.object(ATTENDANCE_REGISTRY_ID),
            tx.object(CLOCK_ID),
        ],
    });
    
    // Step 2: Immediately mint Completion NFT
    const [nftId] = tx.moveCall({
        target: `${PACKAGE_ID}::nft_minting::mint_nft_of_completion`,
        arguments: [
            completionCapability, // Use capability from check-out
            tx.object(NFT_REGISTRY_ID),
        ],
    });
    
    const result = await wallet.signAndExecuteTransactionBlock({
        transactionBlock: tx,
        options: {
            showEffects: true,
            showEvents: true,
        },
    });
    
    return result;
}
```

### NFT Display and Marketplace Integration
```typescript
// Fetch and display user's NFT collection
async function displayUserNFTCollection(userWallet: string) {
    const { poaNFTs, completionNFTs } = await getUserNFTCollection(userWallet);
    
    // Fetch detailed NFT data
    const nftDetails = await Promise.all([
        ...poaNFTs.map(id => client.getObject({
            id,
            options: { showContent: true, showDisplay: true }
        })),
        ...completionNFTs.map(id => client.getObject({
            id,
            options: { showContent: true, showDisplay: true }
        }))
    ]);
    
    return nftDetails.map(nft => ({
        id: nft.data?.objectId,
        type: nft.data?.type?.includes('ProofOfAttendance') ? 'PoA' : 'Completion',
        display: nft.data?.display?.data,
        content: nft.data?.content,
    }));
}

// Create NFT marketplace listing
async function createMarketplaceListing(nftId: string, price: number) {
    // Integration with Sui NFT marketplaces
    const tx = new Transaction();
    
    // Example: List on a marketplace
    tx.moveCall({
        target: `${MARKETPLACE_PACKAGE}::marketplace::list_nft`,
        arguments: [
            tx.object(nftId),
            tx.pure.u64(price),
            tx.object(MARKETPLACE_ID),
        ],
    });
    
    return await wallet.signAndExecuteTransactionBlock({
        transactionBlock: tx,
    });
}
```

### Event Monitoring for NFT Minting
```typescript
// Monitor NFT minting events
class NFTMintingMonitor {
    private client: SuiClient;
    
    constructor() {
        this.client = new SuiClient({ url: getFullnodeUrl('testnet') });
        this.setupEventListeners();
    }
    
    private setupEventListeners() {
        // Monitor PoA NFT minting
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::nft_minting::PoAMinted`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handlePoAMinted(data);
            },
        });
        
        // Monitor Completion NFT minting
        this.client.subscribeEvent({
            filter: {
                MoveEventType: `${PACKAGE_ID}::nft_minting::CompletionMinted`,
            },
            onMessage: (event) => {
                const data = event.parsedJson as any;
                this.handleCompletionMinted(data);
            },
        });
    }
    
    private handlePoAMinted(data: any) {
        console.log(`PoA NFT minted: ${data.nft_id} for user ${data.attendee}`);
        // Update UI, send notifications, etc.
    }
    
    private handleCompletionMinted(data: any) {
        const duration = this.formatDuration(data.attendance_duration);
        console.log(`Completion NFT minted: ${data.nft_id} (${duration} attendance)`);
        // Update UI, send notifications, etc.
    }
    
    private formatDuration(ms: number): string {
        const hours = Math.floor(ms / 3600000);
        const minutes = Math.floor((ms % 3600000) / 60000);
        return `${hours}h ${minutes}m`;
    }
}
```

## Integration with Other Contracts

### Attendance Verification Contract
- **Capability Consumption**: Consumes PoA and Completion capabilities
- **Automatic Minting**: Triggered by attendance milestones
- **Duplicate Prevention**: Ensures one NFT per capability

### Token-Gated Communities
- **Access Control**: NFT ownership grants community access
- **Tier-Based Benefits**: Different benefits for PoA vs Completion NFTs
- **Verification**: Easy ownership verification for gates

### Marketplace Integration
- **Standard Compliance**: Compatible with Sui NFT standards
- **Display Metadata**: Optimized for marketplace display
- **Transfer Support**: Full transfer and trading capabilities

## Best Practices

### For Event Organizers
1. **Set Metadata Early**: Configure event metadata before minting begins
2. **High-Quality Images**: Use IPFS for reliable image hosting
3. **Consistent Branding**: Maintain consistent visual identity
4. **Attribute Planning**: Plan meaningful attributes for NFTs

### For Frontend Developers
1. **Capability Handling**: Properly manage minting capabilities
2. **Error Handling**: Handle duplicate minting and invalid capabilities
3. **Display Integration**: Use display metadata for UI
4. **Collection Views**: Provide comprehensive NFT collection views

### For Users
1. **NFT Storage**: Understand NFT ownership and storage
2. **Transfer Rights**: NFTs can be transferred or sold
3. **Verification**: Use NFTs for community access and benefits
4. **Collection Building**: Build attendance history through NFTs

This contract provides a complete NFT ecosystem for event attendance verification, creating lasting digital certificates of participation that users can own, display, and trade.