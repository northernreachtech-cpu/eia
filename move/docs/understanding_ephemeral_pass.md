## 🎫 Understanding the Ephemeral Pass System

This system is used to manage **event access control** securely and privately using **temporary QR-based passes** that are **generated off-chain** but **validated on-chain**.

### 🔍 What is an Ephemeral Pass?

An **Ephemeral Pass** is a temporary, verifiable object that a registered user holds off-chain (e.g., as a QR code). It contains:

```ts
interface EphemeralPass {
  pass_id: number;
  event_id: string;
  wallet: string;
  expires_at: number;
  verification_hash: Uint8Array; // Computed locally
}
```

---

### ⚙️ How is it created?

When a user registers or regenerates a pass:

* The **Move contract emits** a `PassGenerated` event with:

  * `event_id`
  * `wallet`
  * `pass_id`
  * `expires_at`

The frontend listens for this or gets it after calling `register_for_event()` or `regenerate_pass()`.

---

### 🔐 How is the verification hash computed?

The frontend **computes the hash** locally using: It's neccessary to follow this to match the same
verification hash generated on-chain.

```ts
import { bcs } from '@mysten/sui/bcs';
import { keccak_256 } from '@noble/hashes/sha3';

/**
 * Reproduces `generate_pass_hash` from the on-chain Move contract.
 *
 * @param passId - bigint (u64) from PassGenerated event
 * @param eventId - string ("0x..." Sui event object ID)
 * @param wallet   - string ("0x..." user wallet address)
 * @returns Uint8Array - computed keccak256 hash matching on-chain logic
 */
export function generatePassHash(
  passId: bigint,
  eventId: string,
  wallet: string
): Uint8Array {
  // Serialize using Sui BCS compatible types
  const passIdBytes = bcs.U64.serialize(passId);
  const eventIdBytes = bcs.Address.serialize(eventId);
  const walletBytes = bcs.Address.serialize(wallet);

  // Concatenate buffers
  const combined = new Uint8Array(
    passIdBytes.length + eventIdBytes.length + walletBytes.length
  );
  combined.set(passIdBytes, 0);
  combined.set(eventIdBytes, passIdBytes.length);
  combined.set(walletBytes, passIdBytes.length + eventIdBytes.length);

  // Hash with keccak256
  return keccak_256(combined);
}

```

This hash becomes the `verification_hash` of the Ephemeral Pass and is what is sent back to the blockchain for validation.

---

### ✅ How is the pass used?

* The user presents their QR/pass.
* The frontend extracts the `verification_hash` and sends it to `validate_pass()` with the `event_id`.
* The smart contract checks:

  * The pass exists
  * It’s not expired
  * It hasn’t been used before
* If valid, the user is authenticated.

---

### ⏳ Why is it ephemeral?

* **Expires in 24 hours** (configurable in `PASS_VALIDITY_DURATION`)
* Can be **regenerated anytime** before expiry
* Designed for **temporary access** (e.g., check-ins, venue entry)

---

### 🧪 TL;DR Flow

1. User registers ➝ `PassGenerated` emitted
2. Frontend computes hash ➝ builds `EphemeralPass`
3. On check-in ➝ hash sent to `validate_pass()`
4. If valid ➝ access granted, pass marked as used


