import { useMemo } from "react";
import { EventManagementSDK } from "./eventManagement";
import { IdentityAccessSDK } from "./identityAccess";
import { AttendanceVerificationSDK } from "./attendanceVerification";
import { useNetworkVariable } from "../../config/sui";

// Main SDK class that combines all modules
export class AriyaSDK {
  public eventManagement: EventManagementSDK;
  public identityAccess: IdentityAccessSDK;
  public attendanceVerification: AttendanceVerificationSDK;

  constructor(packageId: string) {
    this.eventManagement = new EventManagementSDK(packageId);
    this.identityAccess = new IdentityAccessSDK(packageId);
    this.attendanceVerification = new AttendanceVerificationSDK(packageId);
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

// Re-export ERROR_CODES with explicit naming to avoid conflicts
export { ERROR_CODES as EVENT_MANAGEMENT_ERROR_CODES } from "./eventManagement";
