import { useMemo } from "react";
import { EventManagementSDK } from "./eventManagement";
import { IdentityAccessSDK } from "./identityAccess";
import { AttendanceVerificationSDK } from "./attendanceVerification";
import { CommunityAccessSDK } from "./communityAccess";
import { useNetworkVariable } from "../../config/sui";

// Main SDK class that combines all modules
export class AriyaSDK {
  public eventManagement: EventManagementSDK;
  public identityAccess: IdentityAccessSDK;
  public attendanceVerification: AttendanceVerificationSDK;
  public communityAccess: CommunityAccessSDK;

  constructor(packageId: string) {
    this.eventManagement = new EventManagementSDK(packageId);
    this.identityAccess = new IdentityAccessSDK(packageId);
    this.attendanceVerification = new AttendanceVerificationSDK(packageId);
    this.communityAccess = new CommunityAccessSDK(packageId);
  }
}

// React hook to use the SDK
export function useAriyaSDK(): AriyaSDK {
  const packageId = useNetworkVariable("packageId");

  return useMemo(() => {
    return new AriyaSDK(packageId);
  }, [packageId]);
}

// Re-export types and utilities (excluding ERROR_CODES to avoid conflicts)
export {
  EventManagementSDK,
  EVENT_STATES,
  type Event,
  type OrganizerProfile,
} from "./eventManagement";

export { IdentityAccessSDK, type Registration } from "./identityAccess";

export {
  AttendanceVerificationSDK,
  type CheckInResult,
  type QRCodeData,
} from "./attendanceVerification";

export {
  CommunityAccessSDK,
  type CommunityConfig,
  type CommunityInfo,
  type AccessPass,
} from "./communityAccess";

// Add export for EscrowSettlementSDK (to be implemented)
export { EscrowSettlementSDK } from "./escrowSettlement";

// Re-export ERROR_CODES with explicit naming to avoid conflicts
export { ERROR_CODES as EVENT_MANAGEMENT_ERROR_CODES } from "./eventManagement";
