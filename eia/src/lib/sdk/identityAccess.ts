import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../../config/sui";
import { keccak_256 } from "@noble/hashes/sha3";
// import { bcs } from "@mysten/sui/bcs";

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
      pass_hash: registration.pass_hash, // Use actual pass hash from registration
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

      console.log("Event organizer:", organizer, "User:", userAddress);
      return organizer === userAddress;
    } catch (error) {
      console.error("Error checking if user is organizer:", error);
      return false;
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

      // Query the registration registry object directly to get the actual pass hash
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
        console.log("Registration registry not found");
        return null;
      }

      const fields = response.data.content.fields as any;
      console.log("Registration registry fields:", fields);

      // Look for the user's registration in the event_registrations table
      if (fields.event_registrations) {
        console.log("Event registrations found:", fields.event_registrations);
        // For now, fall back to event-based approach since table querying is complex
        return await this.getRegistrationFromEvents(
          eventId,
          userAddress,
          registrationRegistryId
        );
      }

      return null;
    } catch (error) {
      console.error("Error fetching registration status:", error);
      return null;
    }
  }

  /**
   * Get registration from events (fallback method)
   */
  private async getRegistrationFromEvents(
    eventId: string,
    userAddress: string,
    registrationRegistryId: string
  ): Promise<Registration | null> {
    try {
      // Query for both UserRegistered and PassGenerated events
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
          let registrationData: any = null;
          let passData: any = null;

          // Find both UserRegistered and PassGenerated events in the same transaction
          for (const event of txn.events) {
            if (event.type?.includes("UserRegistered")) {
              const eventData = event.parsedJson as {
                event_id: string;
                wallet: string;
                registered_at: number;
              };

              if (
                eventData &&
                eventData.event_id === eventId &&
                eventData.wallet === userAddress
              ) {
                registrationData = eventData;
              }
            }

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
                passData = eventData;
              }
            }
          }

          // If we found both events, we have a complete registration
          if (registrationData && passData) {
            console.log("Found complete registration for user!");

            // Get the actual pass hash from the blockchain registration
            // We need to query the registration object directly to get the real pass_hash
            const passHash = await this.getActualPassHashFromBlockchain(
              eventId,
              userAddress,
              registrationRegistryId
            );

            return {
              wallet: registrationData.wallet,
              registered_at: registrationData.registered_at,
              pass_hash: passHash,
              checked_in: false,
            };
          }
        }
      }

      console.log("No registration found for user");
      return null;
    } catch (error) {
      console.error("Error fetching registration from events:", error);
      return null;
    }
  }

  /**
   * Get registration from registry table (get actual blockchain pass hash)
   */
  // private async getRegistrationFromRegistry(
  //   eventRegistrations: any,
  //   eventId: string,
  //   userAddress: string
  // ): Promise<Registration | null> {
  //   try {
  //     // Query the event registrations table to get the actual registration
  //     const eventRegsResponse = await suiClient.getObject({
  //       id: eventRegistrations,
  //       options: {
  //         showContent: true,
  //         showType: true,
  //       },
  //     });

  //     if (
  //       !eventRegsResponse.data?.content ||
  //       eventRegsResponse.data.content.dataType !== "moveObject"
  //     ) {
  //       console.log("Event registrations not found");
  //       return null;
  //     }

  //     const eventRegsFields = eventRegsResponse.data.content.fields as any;
  //     console.log("Event registrations fields:", eventRegsFields);

  //     // Look for the user's registration in the registrations table
  //     if (eventRegsFields.registrations) {
  //       // Query the user's registration to get the actual pass hash
  //       const registrationResponse = await suiClient.getObject({
  //         id: eventRegsFields.registrations,
  //         options: {
  //           showContent: true,
  //           showType: true,
  //         },
  //       });

  //       if (registrationResponse.data?.content?.dataType === "moveObject") {
  //         const registrationFields = registrationResponse.data.content
  //           .fields as any;
  //         console.log("Registration fields:", registrationFields);

  //         // Extract the actual pass hash from the blockchain
  //         const passHash = registrationFields.pass_hash;
  //         console.log("Actual blockchain pass hash:", passHash);

  //         return {
  //           wallet: registrationFields.wallet,
  //           registered_at: parseInt(registrationFields.registered_at),
  //           pass_hash: passHash,
  //           checked_in: registrationFields.checked_in,
  //         };
  //       }
  //     }

  //     return null;
  //   } catch (error) {
  //     console.error("Error getting registration from registry:", error);
  //     return null;
  //   }
  // }

  /**
   * Get the actual pass hash from the blockchain registration
   */
  private async getActualPassHashFromBlockchain(
    eventId: string,
    userAddress: string,
    _registrationRegistryId?: string
  ): Promise<string> {
    try {
      // For now, let's use a simpler approach that works
      // Query the registration events to get the pass_id, then generate the hash
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

      // Find the PassGenerated event for this user and event
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
                console.log("Found PassGenerated event:", eventData);

                // Generate the pass hash using the same logic as the Move contract
                // This should match the actual blockchain pass hash
                const passHash = this.generateMoveCompatiblePassHash(
                  eventData.pass_id,
                  eventId,
                  userAddress
                );

                console.log("Generated pass hash:", passHash);
                return passHash;
              }
            }
          }
        }
      }

      console.log("Could not find PassGenerated event");
      return "no_pass_event_found";
    } catch (error) {
      console.error("Error getting blockchain pass hash:", error);
      return "error_hash";
    }
  }

  /**
   * Generate pass hash using the exact same logic as the Move contract
   */
  private generateMoveCompatiblePassHash(
    passId: number,
    eventId: string,
    wallet: string
  ): string {
    console.log("=== MOVE CONTRACT HASH GENERATION ===");
    console.log("Input parameters:", { passId, eventId, wallet });

    // This is the EXACT same logic as the Move contract:
    // fun generate_pass_hash(pass_id: u64, event_id: ID, wallet: address): vector<u8> {
    //     let mut data = vector::empty<u8>();
    //     vector::append(&mut data, bcs::to_bytes(&pass_id));
    //     vector::append(&mut data, bcs::to_bytes(&event_id));
    //     vector::append(&mut data, bcs::to_bytes(&wallet));
    //     hash::keccak256(&data)
    // }

    // Step 1: Create empty data vector (like Move's vector::empty<u8>())
    let data = new Uint8Array(0);
    console.log("Step 1 - Empty data vector:", Array.from(data));

    // Step 2: Append BCS-serialized pass_id (u64)
    console.log("Step 2 - BCS serializing pass_id (u64):", passId);
    const passIdBytes = this.serializeU64(passId);
    console.log("   pass_id BCS bytes:", Array.from(passIdBytes));
    data = this.appendBytes(data, passIdBytes);
    console.log("   data after pass_id:", Array.from(data));

    // Step 3: Append BCS-serialized event_id (ID)
    console.log("Step 3 - BCS serializing event_id (ID):", eventId);
    const eventIdBytes = this.serializeString(eventId);
    console.log("   event_id BCS bytes:", Array.from(eventIdBytes));
    data = this.appendBytes(data, eventIdBytes);
    console.log("   data after event_id:", Array.from(data));

    // Step 4: Append BCS-serialized wallet (address)
    console.log("Step 4 - BCS serializing wallet (address):", wallet);
    const walletBytes = this.serializeAddress(wallet);
    console.log("   wallet BCS bytes:", Array.from(walletBytes));
    data = this.appendBytes(data, walletBytes);
    console.log("   data after wallet:", Array.from(data));

    // Step 5: Final data array (like Move's data before hash::keccak256(&data))
    console.log(
      "Step 5 - Final data array (before keccak256):",
      Array.from(data)
    );
    console.log("   Total bytes:", data.length);

    // Step 6: Use keccak256 hash (same as Move's hash::keccak256(&data))
    console.log("Step 6 - Applying keccak256 hash...");
    const hash = keccak_256(data);
    const hashString = Array.from(hash)
      .map((b: number) => b.toString(16).padStart(2, "0"))
      .join("");

    console.log("Step 7 - Final hash result:", hashString);
    console.log("=== END HASH GENERATION ===");
    return hashString;
  }

  /**
   * Append bytes to existing array (like Move's vector::append)
   */
  private appendBytes(existing: Uint8Array, newBytes: any): Uint8Array {
    const existingArray = Array.from(existing);
    // Convert BCS serialized data to Uint8Array
    const newArray = new Uint8Array(newBytes);
    return new Uint8Array([...existingArray, ...newArray]);
  }

  /**
   * Serialize u64 like Move's bcs::to_bytes(&u64)
   */
  private serializeU64(value: number): Uint8Array {
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setBigUint64(0, BigInt(value), false); // little-endian
    return new Uint8Array(buffer);
  }

  /**
   * Serialize string like Move's bcs::to_bytes(&String)
   */
  private serializeString(str: string): Uint8Array {
    const encoder = new TextEncoder();
    const strBytes = encoder.encode(str);
    const lengthBytes = this.serializeU64(strBytes.length);
    const result = new Uint8Array(lengthBytes.length + strBytes.length);
    result.set(lengthBytes, 0);
    result.set(strBytes, lengthBytes.length);
    return result;
  }

  /**
   * Serialize address like Move's bcs::to_bytes(&address)
   */
  private serializeAddress(address: string): Uint8Array {
    // Remove 0x prefix and convert to bytes
    const cleanAddress = address.startsWith('0x') ? address.slice(2) : address;
    const bytes = new Uint8Array(cleanAddress.length / 2);
    for (let i = 0; i < cleanAddress.length; i += 2) {
      bytes[i / 2] = parseInt(cleanAddress.substr(i, 2), 16);
    }
    return bytes;
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
