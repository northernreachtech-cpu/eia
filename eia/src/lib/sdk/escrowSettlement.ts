import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../../config/sui";

export interface EscrowDetails {
  organizer: string;
  sponsor: string;
  balance: number;
  settled: boolean;
  settlement_time: number;
}

export interface SettlementResult {
  conditions_met: boolean;
  attendees_actual: number;
  attendees_required: number;
  completion_rate_actual: number;
  completion_rate_required: number;
  avg_rating_actual: number;
  avg_rating_required: number;
  amount_released: number;
  amount_refunded: number;
}

export class EscrowSettlementSDK {
  private packageId: string;

  constructor(packageId: string) {
    this.packageId = packageId;
  }

  // Fund an event (create escrow)
  fundEvent(
    eventId: string,
    sponsor: string,
    paymentObjectId: string,
    escrowRegistryId: string,
    clockId: string
  ): Transaction {
    const tx = new Transaction();
    tx.moveCall({
      target: `${this.packageId}::escrow_settlement::create_escrow`,
      arguments: [
        tx.object(eventId),
        tx.pure.address(sponsor),
        tx.object(paymentObjectId),
        tx.object(escrowRegistryId),
        tx.object(clockId),
      ],
    });
    return tx;
  }

  // Add funds to an existing escrow
  addFunds(
    eventId: string,
    paymentObjectId: string,
    escrowRegistryId: string
  ): Transaction {
    const tx = new Transaction();
    tx.moveCall({
      target: `${this.packageId}::escrow_settlement::add_funds_to_escrow`,
      arguments: [
        tx.object(eventId),
        tx.object(paymentObjectId),
        tx.object(escrowRegistryId),
      ],
    });
    return tx;
  }

  // Settle escrow (release or refund)
  settleEscrow(
    eventId: string,
    _eventRegistryId: string,
    escrowRegistryId: string,
    attendanceRegistryId: string,
    ratingRegistryId: string,
    organizerProfileId: string,
    clockId: string
  ): Transaction {
    const tx = new Transaction();
    tx.moveCall({
      target: `${this.packageId}::escrow_settlement::settle_escrow`,
      arguments: [
        tx.object(eventId),
        tx.object(eventId),
        tx.object(escrowRegistryId),
        tx.object(attendanceRegistryId),
        tx.object(ratingRegistryId),
        tx.object(organizerProfileId),
        tx.object(clockId),
      ],
    });
    return tx;
  }

  // Emergency withdraw (after grace period)
  emergencyWithdraw(
    eventId: string,
    escrowRegistryId: string,
    clockId: string
  ): Transaction {
    const tx = new Transaction();
    tx.moveCall({
      target: `${this.packageId}::escrow_settlement::emergency_withdraw`,
      arguments: [
        tx.object(eventId),
        tx.object(escrowRegistryId),
        tx.object(clockId),
      ],
    });
    return tx;
  }

  // Get escrow details (organizer, sponsor, balance, settled, settlement_time)
  async getEscrowDetails(
    eventId: string,
    escrowRegistryId: string
  ): Promise<EscrowDetails | null> {
    try {
      const tx = new Transaction();
      tx.moveCall({
        target: `${this.packageId}::escrow_settlement::get_escrow_details`,
        arguments: [tx.object(eventId), tx.object(escrowRegistryId)],
      });
      const result = await suiClient.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: "0x0", // dummy sender, not used for view
      });
      if (result && result.results && result.results.length > 0) {
        const returnVals = result.results[0].returnValues;
        if (Array.isArray(returnVals) && returnVals.length >= 5) {
          const organizer = Array.isArray(returnVals[0])
            ? returnVals[0][0]
            : returnVals[0];
          const sponsor = Array.isArray(returnVals[1])
            ? returnVals[1][0]
            : returnVals[1];
          const balance = Array.isArray(returnVals[2])
            ? returnVals[2][0]
            : returnVals[2];
          const settled = Array.isArray(returnVals[3])
            ? returnVals[3][0]
            : returnVals[3];
          const settlement_time = Array.isArray(returnVals[4])
            ? returnVals[4][0]
            : returnVals[4];

          return {
            organizer: String(organizer),
            sponsor: String(sponsor),
            balance: Number(balance),
            settled: Boolean(settled),
            settlement_time: Number(settlement_time),
          };
        }
      }
    } catch (e) {}
    return null;
  }

  // Get settlement result
  async getSettlementResult(
    eventId: string,
    escrowRegistryId: string
  ): Promise<SettlementResult | null> {
    try {
      const tx = new Transaction();
      tx.moveCall({
        target: `${this.packageId}::escrow_settlement::get_settlement_result`,
        arguments: [tx.object(eventId), tx.object(escrowRegistryId)],
      });
      const result = await suiClient.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: "0x0",
      });
      if (result && result.results && result.results.length > 0) {
        const returnVals = result.results[0].returnValues;
        if (Array.isArray(returnVals) && returnVals.length >= 9) {
          const conditions_met = Array.isArray(returnVals[0])
            ? returnVals[0][0]
            : returnVals[0];
          const attendees_actual = Array.isArray(returnVals[1])
            ? returnVals[1][0]
            : returnVals[1];
          const attendees_required = Array.isArray(returnVals[2])
            ? returnVals[2][0]
            : returnVals[2];
          const completion_rate_actual = Array.isArray(returnVals[3])
            ? returnVals[3][0]
            : returnVals[3];
          const completion_rate_required = Array.isArray(returnVals[4])
            ? returnVals[4][0]
            : returnVals[4];
          const avg_rating_actual = Array.isArray(returnVals[5])
            ? returnVals[5][0]
            : returnVals[5];
          const avg_rating_required = Array.isArray(returnVals[6])
            ? returnVals[6][0]
            : returnVals[6];
          const amount_released = Array.isArray(returnVals[7])
            ? returnVals[7][0]
            : returnVals[7];
          const amount_refunded = Array.isArray(returnVals[8])
            ? returnVals[8][0]
            : returnVals[8];

          return {
            conditions_met: Boolean(conditions_met),
            attendees_actual: Number(attendees_actual),
            attendees_required: Number(attendees_required),
            completion_rate_actual: Number(completion_rate_actual),
            completion_rate_required: Number(completion_rate_required),
            avg_rating_actual: Number(avg_rating_actual),
            avg_rating_required: Number(avg_rating_required),
            amount_released: Number(amount_released),
            amount_refunded: Number(amount_refunded),
          };
        }
      }
    } catch (e) {}
    return null;
  }

  // Get global stats (total_escrowed, total_released, total_refunded)
  async getGlobalStats(escrowRegistryId: string): Promise<{
    total_escrowed: number;
    total_released: number;
    total_refunded: number;
  } | null> {
    try {
      const tx = new Transaction();
      tx.moveCall({
        target: `${this.packageId}::escrow_settlement::get_global_stats`,
        arguments: [tx.object(escrowRegistryId)],
      });
      const result = await suiClient.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: "0x0",
      });
      if (result && result.results && result.results.length > 0) {
        const returnVals = result.results[0].returnValues;
        if (Array.isArray(returnVals) && returnVals.length >= 3) {
          const total_escrowed = Array.isArray(returnVals[0])
            ? returnVals[0][0]
            : returnVals[0];
          const total_released = Array.isArray(returnVals[1])
            ? returnVals[1][0]
            : returnVals[1];
          const total_refunded = Array.isArray(returnVals[2])
            ? returnVals[2][0]
            : returnVals[2];

          return {
            total_escrowed: Number(total_escrowed),
            total_released: Number(total_released),
            total_refunded: Number(total_refunded),
          };
        }
      }
    } catch (e) {}
    return null;
  }
}
