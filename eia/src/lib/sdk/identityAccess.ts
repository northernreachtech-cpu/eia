import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../../config/sui";
import { keccak_256 } from "@noble/hashes/sha3";
import { bcs } from "@mysten/sui/bcs";
import { AttendanceVerificationSDK } from "./attendanceVerification";

const CLOCK_ID = "0x6";

export interface Registration {
  wallet: string;
  registered_at: number;
  pass_hash: string | Uint8Array;
  checked_in: boolean;
}

export class IdentityAccessSDK {
  private packageId: string;
  private attendanceSDK: AttendanceVerificationSDK;

  constructor(packageId: string) {
    this.packageId = packageId;
    this.attendanceSDK = new AttendanceVerificationSDK(packageId);
  }

  /**
   * Register for an event and generate QR code data
   * Returns the QR data with a short reference ID
   */
  async registerForEventAndGenerateQR(
    eventId: string,
    registrationRegistryId: string,
    userAddress: string,
    signAndExecute: (params: { transaction: Transaction }) => Promise<any>
  ): Promise<{ qrData: any; passHash: Uint8Array } | null> {
    try {
      // 1. Register for the event
      const registerTx = this.registerForEvent(eventId, registrationRegistryId);

      // 2. Execute the registration transaction
      await signAndExecute({ transaction: registerTx });

      // 3. Extract pass_id from the PassGenerated event
      let pass_id: number | null = null;

      // Wait a moment for the transaction to be processed
      await new Promise((resolve) => setTimeout(resolve, 2000));

      // Query recent transactions to find the PassGenerated event
      const { data: transactions } = await suiClient.queryTransactionBlocks({
        filter: {
          MoveFunction: {
            package: this.packageId,
            module: "identity_access",
            function: "register_for_event",
          },
        },
        options: {
          showEffects: true,
          showEvents: true,
          showObjectChanges: true,
        },
        limit: 10, // Get recent transactions
      });

      // Find the PassGenerated event for this specific user and event
      for (const txn of transactions) {
        if (txn.events) {
          for (const event of txn.events) {
            if (event.type?.includes("PassGenerated")) {
              const eventData = event.parsedJson as {
                event_id: string;
                wallet: string;
                pass_id: number;
                expires_at: number;
              };

              if (
                eventData &&
                eventData.event_id === eventId &&
                eventData.wallet === userAddress
              ) {
                pass_id = eventData.pass_id;
                break;
              }
            }
          }
        }
      }

      if (!pass_id) {
        return null;
      }

      // 4. Generate the pass hash using the real pass_id
      const passHash = this.generatePassHash(
        BigInt(pass_id),
        eventId,
        userAddress
      );

      // 5. Generate QR code data with short reference ID
      const qrData = {
        ref: `${eventId.slice(0, 8)}${pass_id}${userAddress.slice(0, 8)}`, // Short reference
        e: eventId,
        p: pass_id,
        u: userAddress,
        t: Date.now(),
      };

      return { qrData, passHash };
    } catch (error) {
      return null;
    }
  }

  /**
   * After registration, call this to generate pass hash and check in
   * (You must provide the pass_id from the PassGenerated event)
   */
  checkInAfterRegistration(
    eventId: string,
    registrationRegistryId: string,
    attendanceRegistryId: string,
    userAddress: string,
    pass_id: number
  ): Transaction {
    // 2. Generate the pass hash
    const passHash = this.generatePassHash(
      BigInt(pass_id),
      eventId,
      userAddress
    );
    // 3. Prepare qrData
    const qrData = { pass_hash: passHash };
    // 4. Create the check-in transaction
    return this.attendanceSDK.checkInAttendee(
      eventId,
      userAddress,
      attendanceRegistryId,
      registrationRegistryId,
      qrData
    );
  }

  /**
   * Create the registration transaction
   */
  registerForEvent(
    eventId: string,
    registrationRegistryId: string
  ): Transaction {
    const tx = new Transaction();
    tx.moveCall({
      target: `${this.packageId}::identity_access::register_for_event`,
      arguments: [
        tx.object(eventId), // event: &mut Event
        tx.object(registrationRegistryId), // registry: &mut RegistrationRegistry
        tx.object(CLOCK_ID), // clock: &Clock
      ],
    });
    return tx;
  }

  /**
   * Generate pass hash using the same logic as the Move contract
   */
  private generatePassHash(
    passId: bigint,
    eventId: string,
    wallet: string
  ): Uint8Array {
    const passIdBytes = bcs.U64.serialize(passId).toBytes();
    const eventIdBytes = bcs.Address.serialize(eventId).toBytes();
    const walletBytes = bcs.Address.serialize(wallet).toBytes();
    const combined = new Uint8Array(
      passIdBytes.length + eventIdBytes.length + walletBytes.length
    );
    combined.set(passIdBytes, 0);
    combined.set(eventIdBytes, passIdBytes.length);
    combined.set(walletBytes, passIdBytes.length + eventIdBytes.length);
    return keccak_256(combined);
  }

  /**
   * Get registration status for a user (for UI components)
   */
  async getRegistrationStatus(
    eventId: string,
    userAddress: string,
    _registrationRegistryId: string
  ): Promise<Registration | null> {
    try {
      // Query for PassGenerated events to check if user is registered
      const { data: transactions } = await suiClient.queryTransactionBlocks({
        filter: {
          MoveFunction: {
            package: this.packageId,
            module: "identity_access",
            function: "register_for_event",
          },
        },
        options: {
          showEffects: true,
          showEvents: true,
          showObjectChanges: true,
        },
        limit: 50,
      });

      // Look for PassGenerated event for this specific user and event
      for (const txn of transactions) {
        if (txn.events) {
          for (const event of txn.events) {
            if (event.type?.includes("PassGenerated")) {
              const eventData = event.parsedJson as {
                event_id: string;
                wallet: string;
                pass_id: number;
                expires_at: number;
              };

              if (
                eventData &&
                eventData.event_id === eventId &&
                eventData.wallet === userAddress
              ) {
                // Generate the pass hash for the registration object
                const passHash = this.generatePassHash(
                  BigInt(eventData.pass_id),
                  eventId,
                  userAddress
                );
                const passHashHex = Array.from(passHash)
                  .map((b) => b.toString(16).padStart(2, "0"))
                  .join("");

                return {
                  wallet: userAddress,
                  registered_at: eventData.expires_at - 24 * 60 * 60 * 1000, // Approximate registration time
                  pass_hash: passHashHex,
                  checked_in: false, // Would need to check attendance separately
                };
              }
            }
          }
        }
      }

      return null;
    } catch (error) {
      return null;
    }
  }

  /**
   * Check if user is the event organizer
   */
  async isEventOrganizer(
    eventId: string,
    userAddress: string
  ): Promise<boolean> {
    try {
      // Get the event object to check organizer
      const eventResponse = await suiClient.getObject({
        id: eventId,
        options: {
          showContent: true,
          showType: true,
        },
      });

      if (
        !eventResponse.data?.content ||
        eventResponse.data.content.dataType !== "moveObject"
      ) {
        return false;
      }

      const fields = eventResponse.data.content.fields as any;
      const organizer = fields.organizer;

      return organizer === userAddress;
    } catch (error) {
      return false;
    }
  }

  /**
   * Generate QR code data for event registration
   */
  generateQRCodeData(
    eventId: string,
    userAddress: string,
    registration: Registration
  ): string {
    // Convert pass_hash to base64 for QR storage
    let passHashBase64: string;
    if (typeof registration.pass_hash === "string") {
      // If it's already a hex string, convert to Uint8Array first
      const hex = registration.pass_hash;
      const bytes = new Uint8Array(hex.length / 2);
      for (let i = 0; i < hex.length; i += 2) {
        bytes[i / 2] = parseInt(hex.substr(i, 2), 16);
      }
      passHashBase64 = btoa(String.fromCharCode(...bytes));
    } else {
      // If it's already Uint8Array
      passHashBase64 = btoa(
        String.fromCharCode(...(registration.pass_hash as Uint8Array))
      );
    }

    const qrData = {
      event_id: eventId,
      user_address: userAddress,
      pass_hash: passHashBase64, // Base64 encoded Uint8Array
      registered_at: registration.registered_at,
      timestamp: Date.now(),
    };

    return JSON.stringify(qrData);
  }

  /**
   * Parse QR code data
   */
  parseQRCodeData(qrData: string): any {
    try {
      const parsed = JSON.parse(qrData);

      // Convert base64 pass_hash back to Uint8Array
      if (parsed.pass_hash) {
        const passHashBytes = atob(parsed.pass_hash);
        const passHashArray = new Uint8Array(passHashBytes.length);
        for (let i = 0; i < passHashBytes.length; i++) {
          passHashArray[i] = passHashBytes.charCodeAt(i);
        }
        parsed.pass_hash = passHashArray;
      }

      return parsed;
    } catch (error) {
      return null;
    }
  }
}
