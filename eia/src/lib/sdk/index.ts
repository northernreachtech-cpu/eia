import { useMemo } from "react";
import { EventManagementSDK } from "./eventManagement";
import { IdentityAccessSDK } from "./identityAccess";
import { useNetworkVariable } from "../../config/sui";

// Main SDK class that combines all modules
export class EIAProtocolSDK {
  public eventManagement: EventManagementSDK;
  public identityAccess: IdentityAccessSDK;

  constructor(packageId: string) {
    this.eventManagement = new EventManagementSDK(packageId);
    this.identityAccess = new IdentityAccessSDK(packageId);
  }
}

// Hook to get SDK instance with network variables
export function useEIAProtocolSDK(): EIAProtocolSDK {
  const packageId = useNetworkVariable("packageId");

  return useMemo(() => new EIAProtocolSDK(packageId), [packageId]);
}

// Re-export types and utilities (excluding ERROR_CODES to avoid conflicts)
export {
  EventManagementSDK,
  EVENT_STATES,
  type Event,
  type OrganizerProfile,
} from "./eventManagement";

export {
  IdentityAccessSDK,
  REGISTRATION_STATUS,
  generatePassHash,
  type Registration,
  type EphemeralPass,
  type PassGenerated,
} from "./identityAccess";

// Re-export ERROR_CODES with explicit naming to avoid conflicts
export { ERROR_CODES as EVENT_MANAGEMENT_ERROR_CODES } from "./eventManagement";
export { ERROR_CODES as IDENTITY_ACCESS_ERROR_CODES } from "./identityAccess";
