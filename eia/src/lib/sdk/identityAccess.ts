import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../../config/sui";

// System clock object ID is constant
const CLOCK_ID = "0x6";

export interface Registration {
  wallet: string;
  registered_at: number;
  pass_hash: string;
  checked_in: boolean;
}

export interface PassInfo {
  wallet: string;
  event_id: string;
  created_at: number;
  expires_at: number;
  used: boolean;
  pass_id: number;
}

export class IdentityAccessSDK {
  private packageId: string;

  constructor(packageId: string) {
    this.packageId = packageId;
  }

  getPackageId(): string {
    return this.packageId;
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
   * Generate a new pass for an event
   */
  generatePass(eventId: string, registrationRegistryId: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::identity_access::generate_new_pass`,
      arguments: [
        tx.object(eventId),
        tx.object(registrationRegistryId),
        tx.object(CLOCK_ID),
      ],
    });

    return tx;
  }

  /**
   * Validate a pass
   */
  validatePass(
    passHash: Uint8Array,
    eventId: string,
    registrationRegistryId: string
  ): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::identity_access::validate_pass`,
      arguments: [
        tx.pure.vector("u8", passHash),
        tx.object(eventId),
        tx.object(registrationRegistryId),
        tx.object(CLOCK_ID),
      ],
    });

    return tx;
  }

  /**
   * Generate QR code data for event registration
   */
  generateQRCodeData(
    eventId: string,
    userAddress: string,
    registration: Registration
  ): string {
    const qrData = {
      event_id: eventId,
      user_address: userAddress,
      registration_hash: registration.pass_hash,
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
      return JSON.parse(qrData);
    } catch (error) {
      console.error("Error parsing QR code data:", error);
      return null;
    }
  }

  /**
   * Get registration status for a user
   */
  async getRegistrationStatus(
    eventId: string,
    userAddress: string,
    registrationRegistryId: string
  ): Promise<Registration | null> {
    try {
      console.log("Checking registration status:", {
        eventId,
        userAddress,
        registrationRegistryId,
      });

      // Query recent transactions to check if user registered for this event
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

      console.log("Found registration transactions:", transactions.length);

      // Look for UserRegistered event for this specific user and event
      for (const txn of transactions) {
        if (txn.events) {
          for (const event of txn.events) {
            if (event.type?.includes("UserRegistered")) {
              const eventData = event.parsedJson as {
                event_id: string;
                wallet: string;
                registered_at: number;
              };

              console.log("Registration event:", eventData);

              if (
                eventData &&
                eventData.event_id === eventId &&
                eventData.wallet === userAddress
              ) {
                console.log("Found registration for user!");
                return {
                  wallet: eventData.wallet,
                  registered_at: eventData.registered_at,
                  pass_hash: "", // We don't have this from the event
                  checked_in: false, // Would need to check attendance separately
                };
              }
            }
          }
        }
      }

      console.log("No registration found for user");
      return null;
    } catch (error) {
      console.error("Error fetching registration status:", error);
      return null;
    }
  }

  /**
   * Get all registrations for an event
   */
  async getEventRegistrations(
    _eventId: string,
    registrationRegistryId: string
  ): Promise<Registration[]> {
    try {
      // Query the registration registry for event registrations
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
        return [];
      }

      // This would need to be implemented based on the actual registry structure
      // For now, return empty array as placeholder
      return [];
    } catch (error) {
      console.error("Error fetching event registrations:", error);
      return [];
    }
  }
}
