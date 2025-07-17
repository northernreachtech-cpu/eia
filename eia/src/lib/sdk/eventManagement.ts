import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../../config/sui";
import { extractMoveObjectFields } from "../../utils/extractors";

// System clock object ID is constant
const CLOCK_ID = "0x6";

// Types based on Move module documentation
export interface Event {
  id: string;
  name: string;
  description: string;
  location: string;
  start_time: number;
  end_time: number;
  capacity: number;
  current_attendees: number;
  organizer: string;
  state: number;
  created_at: number;
  sponsor_conditions: SponsorConditions;
  metadata_uri: string;
}

export interface OrganizerProfile {
  id: string;
  address: string;
  name: string;
  bio: string;
  total_events: number;
  successful_events: number;
  total_attendees_served: number;
  avg_rating: number;
  created_at: number;
}

export interface SponsorConditions {
  min_attendees: number;
  min_completion_rate: number;
  min_avg_rating: number;
  custom_benchmarks: CustomBenchmark[];
}

export interface CustomBenchmark {
  description: string;
  target_value: number;
  current_value: number;
}

export interface EventInfo {
  id: string;
  name: string;
  organizer: string;
  start_time: number;
  state: number;
}

// Event States
export const EVENT_STATES = {
  CREATED: 0,
  ACTIVE: 1,
  COMPLETED: 2,
  SETTLED: 3,
} as const;

// Error Codes
export const ERROR_CODES = {
  ENotOrganizer: 1,
  EEventNotActive: 2,
  EEventAlreadyCompleted: 3,
  EInvalidCapacity: 4,
  EInvalidTimestamp: 5,
} as const;

export class EventManagementSDK {
  private packageId: string;

  constructor(packageId: string) {
    this.packageId = packageId;
  }

  getPackageId(): string {
    return this.packageId;
  }

  /**
   * Creates a new organizer profile
   */
  createOrganizerProfile(
    name: string,
    bio: string,
    recipient: string
  ): Transaction {
    const tx = new Transaction();

    const [organizerCap] = tx.moveCall({
      target: `${this.packageId}::event_management::create_organizer_profile`,
      arguments: [
        tx.pure.string(name),
        tx.pure.string(bio),
        tx.object(CLOCK_ID),
      ],
    });

    tx.transferObjects([organizerCap], tx.pure.address(recipient));
    tx.setGasBudget(10000000);
    return tx;
  }

  /**
   * Creates a new event
   */
  createEvent(
    name: string,
    description: string,
    location: string,
    startTime: number,
    endTime: number,
    capacity: number,
    minAttendees: number,
    minCompletionRate: number,
    minAvgRating: number,
    metadataUri: string,
    eventRegistryId: string,
    profileId: string
  ): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::event_management::create_event`,
      arguments: [
        tx.pure.string(name),
        tx.pure.string(description),
        tx.pure.string(location),
        tx.pure.u64(startTime),
        tx.pure.u64(endTime),
        tx.pure.u64(capacity),
        tx.pure.u64(minAttendees),
        tx.pure.u64(minCompletionRate),
        tx.pure.u64(minAvgRating),
        tx.pure.string(metadataUri),
        tx.object(CLOCK_ID),
        tx.object(eventRegistryId),
        tx.object(profileId),
      ],
    });

    return tx;
  }

  /**
   * Activates an event for registration
   */
  activateEvent(eventId: string, eventRegistryId: string): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::event_management::activate_event`,
      arguments: [
        tx.object(eventId),
        tx.object(CLOCK_ID),
        tx.object(eventRegistryId),
      ],
    });

    return tx;
  }

  /**
   * Completes an event (only callable after end time)
   */
  completeEvent(
    eventId: string,
    eventRegistryId: string,
    profileId: string
  ): Transaction {
    const tx = new Transaction();

    tx.moveCall({
      target: `${this.packageId}::event_management::complete_event`,
      arguments: [
        tx.object(eventId),
        tx.object(CLOCK_ID),
        tx.object(eventRegistryId),
        tx.object(profileId),
      ],
    });

    return tx;
  }

  /**
   * Get event details by ID
   */
  async getEvent(eventId: string): Promise<Event | null> {
    try {
      const response = await suiClient.getObject({
        id: eventId,
        options: {
          showContent: true,
          showType: true,
        },
      });

      if (
        !response.data?.content ||
        response.data.content.dataType !== "moveObject"
      ) {
        return null;
      }

      const fields = response.data.content.fields as any;
      return {
        id: fields.id.id,
        name: fields.name,
        description: fields.description,
        location: fields.location,
        start_time: parseInt(fields.start_time),
        end_time: parseInt(fields.end_time),
        capacity: parseInt(fields.capacity),
        current_attendees: parseInt(fields.current_attendees),
        organizer: fields.organizer,
        state: parseInt(fields.state),
        created_at: parseInt(fields.created_at),
        sponsor_conditions: fields.sponsor_conditions,
        metadata_uri: fields.metadata_uri,
      };
    } catch (error) {
      console.error("Error fetching event:", error);
      return null;
    }
  }

  /**
   * Get organizer profile by address
   */
  async getOrganizerProfile(
    profileId: string
  ): Promise<OrganizerProfile | null> {
    try {
      const response = await suiClient.getObject({
        id: profileId,
        options: {
          showContent: true,
          showType: true,
        },
      });

      if (
        !response.data?.content ||
        response.data.content.dataType !== "moveObject"
      ) {
        return null;
      }

      const fields = response.data.content.fields as any;
      // console.log("fields:::", fields);
      return {
        id: fields.id.id,
        address: fields.address,
        name: fields.name,
        bio: fields.bio,
        total_events: parseInt(fields.total_events),
        successful_events: parseInt(fields.successful_events),
        total_attendees_served: parseInt(fields.total_attendees_served),
        avg_rating: parseInt(fields.avg_rating),
        created_at: parseInt(fields.created_at),
      };
    } catch (error) {
      console.error("Error fetching organizer profile:", error);
      return null;
    }
  }

  /**
   * Get events by organizer address
   */
  async getEventsByOrganizer(_organizerAddress: string): Promise<EventInfo[]> {
    try {
      // Query events from the registry
      const response = await suiClient.getObject({
        id: CLOCK_ID, // This ID is no longer used for the registry, but kept for consistency
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
      console.error("Error fetching events by organizer:", error);
      return [];
    }
  }

  /**
   * Get all active events
   */
  async getActiveEvents(): Promise<EventInfo[]> {
    try {
      // This would query the EventRegistry for active events
      // Implementation depends on the actual registry structure
      return [];
    } catch (error) {
      console.error("Error fetching active events:", error);
      return [];
    }
  }

  async hasOrganizerProfile(address: string): Promise<boolean> {
    try {
      console.log("Checking profile for address:", address);
      const { data: objects } = await suiClient.getOwnedObjects({
        owner: address,
        filter: {
          StructType: `${this.packageId}::event_management::OrganizerCap`,
        },
        options: { showContent: true },
      });

      console.log("Found OrganizerCap objects:", objects);

      if (objects.length === 0) return false;

      for (const obj of objects) {
        const fields = extractMoveObjectFields(obj);
        console.log("OrganizerCap fields:", fields);

        if (fields) {
          const profileId = fields.profile_id;
          console.log("Profile ID:", profileId);

          const profileResponse = await suiClient.getObject({
            id: profileId,
            options: { showContent: true },
          });

          console.log("Profile response:", profileResponse);
          const profileFields = extractMoveObjectFields(profileResponse);
          console.log("Profile fields:", profileFields);

          if (profileFields && profileFields.address === address) {
            return true;
          }
        }
      }

      return false;
    } catch (error) {
      console.error("Error checking organizer profile:", error);
      return false;
    }
  }
}
