import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../../config/sui";
import { keccak_256 } from "@noble/hashes/sha3";
import { bcs } from "@mysten/sui/bcs";

// System clock object ID is constant
const CLOCK_ID = "0x6";

export interface CheckInResult {
  success: boolean;
  message: string;
  attendeeAddress?: string;
}

export interface QRCodeData {
  event_id: string;
  user_address: string;
  pass_hash: string;
  registered_at: number;
  timestamp: number;
}

export class AttendanceVerificationSDK {
  private packageId: string;

  constructor(packageId: string) {
    this.packageId = packageId;
  }

  getPackageId(): string {
    return this.packageId;
  }

  /**
   * Validate QR code data for check-in
   */
  async validateQRCode(
    qrData: QRCodeData,
    eventId: string
  ): Promise<CheckInResult> {
    try {
      console.log("=== QR CODE VALIDATION ===");
      console.log("QR data received:", qrData);
      console.log("Expected event ID:", eventId);

      // Validate event ID matches
      if (qrData.event_id !== eventId) {
        console.log("❌ Event ID mismatch");
        return {
          success: false,
          message: "QR code is not valid for this event",
        };
      }

      // Validate pass hash format
      if (!qrData.pass_hash || typeof qrData.pass_hash !== "string") {
        console.log("❌ Invalid pass hash format");
        return {
          success: false,
          message: "Invalid pass hash format in QR code",
        };
      }

      // Check if user is registered for this event
      const registrationStatus = await this.checkRegistrationStatus(
        eventId,
        qrData.user_address
      );

      if (!registrationStatus) {
        console.log("❌ User not registered");
        return {
          success: false,
          message: "User is not registered for this event",
        };
      }

      // Check if already checked in
      if (registrationStatus.checked_in) {
        console.log("❌ Already checked in");
        return {
          success: false,
          message: "User has already been checked in",
        };
      }

      // Validate pass hash matches what the contract expects
      const isValidPassHash = await this.validatePassHash(
        qrData.pass_hash,
        eventId,
        qrData.user_address
      );

      if (!isValidPassHash) {
        console.log("❌ Pass hash validation failed");
        return {
          success: false,
          message: "Invalid pass hash - QR code may be corrupted or expired",
        };
      }

      console.log("✅ QR code validation successful");
      return {
        success: true,
        message: "QR code validated successfully",
        attendeeAddress: qrData.user_address,
      };
    } catch (error) {
      console.error("Error validating QR code:", error);
      return {
        success: false,
        message: "Error validating QR code",
      };
    }
  }

  /**
   * Validate pass hash against what the Move contract expects
   */
  private async validatePassHash(
    passHash: string,
    eventId: string,
    userAddress: string
  ): Promise<boolean> {
    try {
      console.log("=== PASS HASH VALIDATION ===");
      console.log("Validating pass hash:", passHash);
      console.log("For event:", eventId);
      console.log("For user:", userAddress);

      // Get the expected pass hash from the blockchain
      const expectedPassHash = await this.getExpectedPassHashFromBlockchain(
        eventId,
        userAddress
      );

      console.log("Expected pass hash:", expectedPassHash);
      console.log("Received pass hash:", passHash);
      console.log("Hashes match:", passHash === expectedPassHash);

      return passHash === expectedPassHash;
    } catch (error) {
      console.error("Error validating pass hash:", error);
      return false;
    }
  }

  /**
   * Get the expected pass hash from the blockchain (same logic as identity_access contract)
   */
  private async getExpectedPassHashFromBlockchain(
    eventId: string,
    userAddress: string
  ): Promise<string> {
    try {
      // Query for PassGenerated event to get pass_id
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

                // Generate the expected pass hash using the same logic as the Move contract
                const expectedHash = this.generateMoveCompatiblePassHash(
                  eventData.pass_id,
                  eventId,
                  userAddress
                );

                console.log("Generated expected hash:", expectedHash);
                return expectedHash;
              }
            }
          }
        }
      }

      console.log("Could not find PassGenerated event for validation");
      return "not_found";
    } catch (error) {
      console.error("Error getting expected pass hash:", error);
      return "error";
    }
  }

  /**
   * Generate pass hash using the same logic as the Move contract
   */
  private generateMoveCompatiblePassHash(
    passId: number,
    eventId: string,
    wallet: string
  ): string {
    console.log("=== GENERATING EXPECTED PASS HASH ===");
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

    // Step 2: Append BCS-serialized pass_id (u64)
    const passIdBytes = this.serializeU64(passId);
    data = this.appendBytes(data, passIdBytes);

    // Step 3: Append BCS-serialized event_id (ID)
    const eventIdBytes = this.serializeString(eventId);
    data = this.appendBytes(data, eventIdBytes);

    // Step 4: Append BCS-serialized wallet (address)
    const walletBytes = this.serializeAddress(wallet);
    data = this.appendBytes(data, walletBytes);

    // Step 5: Use keccak256 hash (same as Move's hash::keccak256(&data))
    const hash = keccak_256(data);
    const hashString = Array.from(hash)
      .map((b: number) => b.toString(16).padStart(2, "0"))
      .join("");

    console.log("Generated expected hash:", hashString);
    return hashString;
  }

  /**
   * Helper methods for BCS serialization (same as identity_access.ts)
   */
  private appendBytes(existing: Uint8Array, newBytes: Uint8Array): Uint8Array {
    const existingArray = Array.from(existing);
    const newArray = Array.from(newBytes);
    return new Uint8Array([...existingArray, ...newArray]);
  }

  private serializeU64(value: number): Uint8Array {
    const buffer = new ArrayBuffer(8);
    const view = new DataView(buffer);
    view.setBigUint64(0, BigInt(value), false); // little-endian
    return new Uint8Array(buffer);
  }

  private serializeString(str: string): Uint8Array {
    const encoder = new TextEncoder();
    const strBytes = encoder.encode(str);
    const lengthBytes = this.serializeU64(strBytes.length);
    const result = new Uint8Array(lengthBytes.length + strBytes.length);
    result.set(lengthBytes, 0);
    result.set(strBytes, lengthBytes.length);
    return result;
  }

  private serializeAddress(address: string): Uint8Array {
    // Remove 0x prefix and convert to bytes
    const cleanAddress = address.startsWith("0x") ? address.slice(2) : address;
    const bytes = new Uint8Array(cleanAddress.length / 2);
    for (let i = 0; i < cleanAddress.length; i += 2) {
      bytes[i / 2] = parseInt(cleanAddress.substr(i, 2), 16);
    }
    return bytes;
  }

  /**
   * Check registration status for a user
   */
  async checkRegistrationStatus(
    eventId: string,
    userAddress: string
  ): Promise<any> {
    try {
      // Query recent transactions to check registration
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

              if (
                eventData &&
                eventData.event_id === eventId &&
                eventData.wallet === userAddress
              ) {
                return {
                  wallet: eventData.wallet,
                  registered_at: eventData.registered_at,
                  checked_in: false, // Would need to check attendance separately
                };
              }
            }
          }
        }
      }

      return null;
    } catch (error) {
      console.error("Error checking registration status:", error);
      return null;
    }
  }

  /**
   * Check-in an attendee (create attendance verification transaction)
   */
  checkInAttendee(
    eventId: string,
    _attendeeAddress: string,
    attendanceRegistryId: string,
    registrationRegistryId: string,
    qrData: { pass_hash: Uint8Array }
  ): Transaction {
    const tx = new Transaction();

    const passHashBytes = Array.from(qrData.pass_hash); // still need to convert to plain array
    const deviceFingerprint = new TextEncoder().encode("device_fingerprint");
    const locationProof = new TextEncoder().encode("location_proof");

    // Call check_in and drop the returned MintPoACapability
    const capability = tx.moveCall({
      target: `${this.packageId}::attendance_verification::check_in`,
      arguments: [
        tx.pure.vector("u8", passHashBytes),
        tx.pure.vector("u8", Array.from(deviceFingerprint)),
        tx.pure.vector("u8", Array.from(locationProof)),
        tx.object(eventId),
        tx.object(attendanceRegistryId),
        tx.object(registrationRegistryId),
        tx.object(CLOCK_ID),
      ],
    });

    // Drop the returned capability to avoid UnusedValueWithoutDrop error
    tx.moveCall({
      target: `${this.packageId}::attendance_verification::consume_poa_capability`,
      arguments: [capability],
    });

    return tx;
  }

  /**
   * Check-in attendee using pass_id (for new QR format)
   */
  checkInAttendeeWithPassId(
    eventId: string,
    userAddress: string,
    passId: number,
    attendanceRegistryId: string,
    registrationRegistryId: string
  ): Transaction {
    const tx = new Transaction();

    // Generate pass hash from pass_id
    const passHash = this.generatePassHashFromId(passId, eventId, userAddress);
    const passHashBytes = Array.from(passHash);
    const deviceFingerprint = new TextEncoder().encode("device_fingerprint");
    const locationProof = new TextEncoder().encode("location_proof");

    // Call check_in and drop the returned MintPoACapability
    const capability = tx.moveCall({
      target: `${this.packageId}::attendance_verification::check_in`,
      arguments: [
        tx.pure.vector("u8", passHashBytes),
        tx.pure.vector("u8", Array.from(deviceFingerprint)),
        tx.pure.vector("u8", Array.from(locationProof)),
        tx.object(eventId),
        tx.object(attendanceRegistryId),
        tx.object(registrationRegistryId),
        tx.object(CLOCK_ID),
      ],
    });

    // Drop the returned capability to avoid UnusedValueWithoutDrop error
    tx.moveCall({
      target: `${this.packageId}::attendance_verification::consume_poa_capability`,
      arguments: [capability],
    });

    return tx;
  }

  /**
   * Generate pass hash from pass_id (same logic as identity_access module)
   */
  private generatePassHashFromId(
    passId: number,
    eventId: string,
    wallet: string
  ): Uint8Array {
    const passIdBytes = bcs.U64.serialize(BigInt(passId)).toBytes();
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
   * Check-out an attendee
   */
  checkOutAttendee(
    eventId: string,
    attendeeAddress: string,
    attendanceRegistryId: string
  ): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::attendance_verification::check_out_attendee`,
      arguments: [
        tx.object(eventId),
        tx.pure.address(attendeeAddress),
        tx.object(attendanceRegistryId),
        tx.object(CLOCK_ID),
      ],
    });

    return tx;
  }

  /**
   * Get attendance status for an event
   */
  async getEventAttendance(
    eventId: string,
    _attendanceRegistryId: string
  ): Promise<any[]> {
    try {
      // Query attendance events for this event
      const { data: transactions } = await suiClient.queryTransactionBlocks({
        filter: {
          MoveFunction: {
            package: this.packageId,
            module: "attendance_verification",
            function: "check_in_attendee",
          },
        },
        options: {
          showEffects: true,
          showEvents: true,
          showObjectChanges: true,
        },
        limit: 100,
      });

      const attendees: any[] = [];

      for (const txn of transactions) {
        if (txn.events) {
          for (const event of txn.events) {
            if (event.type?.includes("AttendeeCheckedIn")) {
              const eventData = event.parsedJson as {
                event_id: string;
                attendee: string;
                check_in_time: number;
              };

              if (eventData && eventData.event_id === eventId) {
                attendees.push({
                  address: eventData.attendee,
                  check_in_time: eventData.check_in_time,
                  checked_out: false, // Would need to check checkout separately
                });
              }
            }
          }
        }
      }

      return attendees;
    } catch (error) {
      console.error("Error fetching event attendance:", error);
      return [];
    }
  }
}
