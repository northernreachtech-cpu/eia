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

// React hook to use the SDK
export function useEIAProtocolSDK(): EIAProtocolSDK {
  const packageId = useNetworkVariable("packageId");

  return useMemo(() => {
    return new EIAProtocolSDK(packageId);
  }, [packageId]);
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
  type Registration,
  type PassInfo,
} from "./identityAccess";

// Re-export ERROR_CODES with explicit naming to avoid conflicts
export { ERROR_CODES as EVENT_MANAGEMENT_ERROR_CODES } from "./eventManagement";
