import { Transaction } from "@mysten/sui/transactions";
import { bcs } from "@mysten/sui/bcs";
import { keccak_256 } from "@noble/hashes/sha3";
import { suiClient } from "../../config/sui";

// System clock object ID is constant
const CLOCK_ID = "0x6";

// Types based on Move module documentation
export interface Registration {
  id: string;
  event_id: string;
  wallet: string;
  registered_at: number;
  check_in_time: number;
  check_out_time: number;
  status: number;
}

export interface EphemeralPass {
  pass_id: number;
  event_id: string;
  wallet: string;
  expires_at: number;
  verification_hash: Uint8Array;
}

export interface PassGenerated {
  event_id: string;
  wallet: string;
  pass_id: number;
  expires_at: number;
}

// Registration Status
export const REGISTRATION_STATUS = {
  REGISTERED: 0,
  CHECKED_IN: 1,
  CHECKED_OUT: 2,
  NO_SHOW: 3,
} as const;

// Error Codes
export const ERROR_CODES = {
  ENotRegistered: 1,
  EAlreadyRegistered: 2,
  EEventNotActive: 3,
  ECapacityExceeded: 4,
  EInvalidPass: 5,
  EPassExpired: 6,
  EPassAlreadyUsed: 7,
} as const;

/**
 * Generates the verification hash for an ephemeral pass
 * This must match the on-chain hash generation logic
 */
export function generatePassHash(
  passId: bigint,
  eventId: string,
  wallet: string
): Uint8Array {
  // Serialize using Sui BCS compatible types and convert to bytes
  const passIdBytes = bcs.U64.serialize(passId).toBytes();
  const eventIdBytes = bcs.Address.serialize(eventId).toBytes();
  const walletBytes = bcs.Address.serialize(wallet).toBytes();

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

export class IdentityAccessSDK {
  private packageId: string;

  constructor(packageId: string) {
    this.packageId = packageId;
  }

  /**
   * Register for an event
   */
  registerForEvent(
    eventId: string,
    registrationRegistryId: string
  ): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::identity_access::register_for_event`,
      arguments: [
        tx.object(eventId),
        tx.object(registrationRegistryId),
        tx.object(CLOCK_ID),
      ],
    });

    return tx;
  }

  /**
   * Regenerate an ephemeral pass
   */
  regeneratePass(eventId: string, registrationRegistryId: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::identity_access::regenerate_pass`,
      arguments: [
        tx.object(eventId),
        tx.object(registrationRegistryId),
        tx.object(CLOCK_ID),
      ],
    });

    return tx;
  }

  /**
   * Validate an ephemeral pass
   */
  validatePass(
    eventId: string,
    verificationHash: Uint8Array,
    registrationRegistryId: string
  ): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::identity_access::validate_pass`,
      arguments: [
        tx.object(eventId),
        tx.pure(verificationHash),
        tx.object(registrationRegistryId),
        tx.object(CLOCK_ID),
      ],
    });

    return tx;
  }

  /**
   * Check if a user is registered for an event
   */
  async isRegistered(
    _eventId: string,
    _walletAddress: string,
    registrationRegistryId: string
  ): Promise<boolean> {
    try {
      // Query the registration registry
      const response = await suiClient.getObject({
        id: registrationRegistryId,
        options: {
          showContent: true,
          showType: true,
        },
      });

      if (
        !response.data?.content ||
        response.data.content.dataType !== "moveObject"
      ) {
        return false;
      }

      // This would need to be implemented based on the actual registry structure
      // For now, return false as placeholder
      return false;
    } catch (error) {
      console.error("Error checking registration:", error);
      return false;
    }
  }

  /**
   * Get registration details
   */
  async getRegistration(
    _eventId: string,
    _walletAddress: string,
    _registrationRegistryId: string
  ): Promise<Registration | null> {
    try {
      // This would query the specific registration object
      // Implementation depends on the actual registry structure
      return null;
    } catch (error) {
      console.error("Error fetching registration:", error);
      return null;
    }
  }

  /**
   * Get all registrations for a user
   */
  async getUserRegistrations(
    _walletAddress: string,
    _registrationRegistryId: string
  ): Promise<Registration[]> {
    try {
      // This would query all registrations for a user
      // Implementation depends on the actual registry structure
      return [];
    } catch (error) {
      console.error("Error fetching user registrations:", error);
      return [];
    }
  }

  /**
   * Create an ephemeral pass from a PassGenerated event
   */
  createEphemeralPass(passGenerated: PassGenerated): EphemeralPass {
    const verificationHash = generatePassHash(
      BigInt(passGenerated.pass_id),
      passGenerated.event_id,
      passGenerated.wallet
    );

    return {
      pass_id: passGenerated.pass_id,
      event_id: passGenerated.event_id,
      wallet: passGenerated.wallet,
      expires_at: passGenerated.expires_at,
      verification_hash: verificationHash,
    };
  }

  /**
   * Check if a pass is expired
   */
  isPassExpired(pass: EphemeralPass): boolean {
    return Date.now() > pass.expires_at;
  }

  /**
   * Generate QR code data for an ephemeral pass
   */
  generateQRCodeData(pass: EphemeralPass): string {
    return JSON.stringify({
      pass_id: pass.pass_id,
      event_id: pass.event_id,
      wallet: pass.wallet,
      expires_at: pass.expires_at,
      verification_hash: Array.from(pass.verification_hash),
    });
  }

  /**
   * Parse QR code data back to ephemeral pass
   */
  parseQRCodeData(qrData: string): EphemeralPass | null {
    try {
      const data = JSON.parse(qrData);
      return {
        pass_id: data.pass_id,
        event_id: data.event_id,
        wallet: data.wallet,
        expires_at: data.expires_at,
        verification_hash: new Uint8Array(data.verification_hash),
      };
    } catch (error) {
      console.error("Error parsing QR code data:", error);
      return null;
    }
  }
}
