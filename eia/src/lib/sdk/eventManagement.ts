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
   * Extract event ID from transaction result
   */
  extractEventIdFromResult(result: any): string | null {
    try {
      // Look for EventCreated event in the transaction result
      if (result.events) {
        for (const event of result.events) {
          if (event.type?.includes("EventCreated")) {
            return event.parsedJson?.event_id || null;
          }
        }
      }

      // Fallback: look for created objects
      if (result.objectChanges) {
        for (const change of result.objectChanges) {
          if (
            change.type === "created" &&
            change.objectType?.includes("Event")
          ) {
            return change.objectId;
          }
        }
      }

      return null;
    } catch (error) {
      console.error("Error extracting event ID:", error);
      return null;
    }
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
  async getEventsByOrganizer(
    organizerAddress: string,
    _eventRegistryId: string
  ): Promise<EventInfo[]> {
    try {
      // Since events are shared objects, we need to query them differently
      // For now, let's use a simple approach: query recent transactions and extract events
      const { data: transactions } = await suiClient.queryTransactionBlocks({
        filter: {
          MoveFunction: {
            package: this.packageId,
            module: "event_management",
            function: "create_event",
          },
        },
        options: {
          showEffects: true,
          showEvents: true,
          showObjectChanges: true,
        },
        limit: 50,
      });

      const eventInfos: EventInfo[] = [];

      for (const txn of transactions) {
        if (txn.events) {
          for (const event of txn.events) {
            if (event.type?.includes("EventCreated")) {
              const eventData = event.parsedJson as {
                event_id: string;
                organizer: string;
              };
              if (
                eventData &&
                eventData.event_id &&
                eventData.organizer === organizerAddress
              ) {
                // Get the full event object
                const eventResponse = await suiClient.getObject({
                  id: eventData.event_id,
        options: {
          showContent: true,
          showType: true,
        },
      });

                if (eventResponse.data?.content?.dataType === "moveObject") {
                  const fields = eventResponse.data.content.fields as any;
                  eventInfos.push({
                    id: eventData.event_id,
                    name: fields.name,
                    organizer: fields.organizer,
                    start_time: parseInt(fields.start_time),
                    state: parseInt(fields.state),
                  });
                }
              }
            }
          }
        }
      }

      return eventInfos;
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
      // Query recent transactions to get all events
      const { data: transactions } = await suiClient.queryTransactionBlocks({
        filter: {
          MoveFunction: {
            package: this.packageId,
            module: "event_management",
            function: "create_event",
          },
        },
        options: {
          showEffects: true,
          showEvents: true,
          showObjectChanges: true,
        },
        limit: 100,
      });

      const eventInfos: EventInfo[] = [];

      for (const txn of transactions) {
        if (txn.events) {
          for (const event of txn.events) {
            if (event.type?.includes("EventCreated")) {
              const eventData = event.parsedJson as {
                event_id: string;
                organizer: string;
              };
              if (eventData && eventData.event_id) {
                // Get the full event object
                const eventResponse = await suiClient.getObject({
                  id: eventData.event_id,
                  options: {
                    showContent: true,
                    showType: true,
                  },
                });

                if (eventResponse.data?.content?.dataType === "moveObject") {
                  const fields = eventResponse.data.content.fields as any;
                  eventInfos.push({
                    id: eventData.event_id,
                    name: fields.name,
                    organizer: fields.organizer,
                    start_time: parseInt(fields.start_time),
                    state: parseInt(fields.state),
                  });
                }
              }
            }
          }
        }
      }

      return eventInfos;
    } catch (error) {
      console.error("Error fetching active events:", error);
      return [];
    }
  }

  /**
   * Get all organizers with profiles
   */
  async getAllOrganizers(): Promise<OrganizerProfile[]> {
    try {
      // Query for all OrganizerProfile objects
      const { data: transactions } = await suiClient.queryTransactionBlocks({
        filter: {
          MoveFunction: {
            package: this.packageId,
            module: "event_management",
            function: "create_organizer_profile",
          },
        },
        options: {
          showEffects: true,
          showEvents: true,
          showObjectChanges: true,
        },
        limit: 100,
      });

      const organizers: OrganizerProfile[] = [];

      for (const txn of transactions) {
        if (txn.objectChanges) {
          for (const change of txn.objectChanges) {
            if (
              change.type === "created" &&
              change.objectType?.includes("OrganizerProfile")
            ) {
              const profileResponse = await suiClient.getObject({
                id: change.objectId,
                options: {
                  showContent: true,
                  showType: true,
                },
              });

              if (profileResponse.data?.content?.dataType === "moveObject") {
                const fields = profileResponse.data.content.fields as any;
                organizers.push({
                  id: fields.id.id,
                  address: fields.address,
                  name: fields.name,
                  bio: fields.bio,
                  total_events: parseInt(fields.total_events),
                  successful_events: parseInt(fields.successful_events),
                  total_attendees_served: parseInt(
                    fields.total_attendees_served
                  ),
                  avg_rating: parseInt(fields.avg_rating),
                  created_at: parseInt(fields.created_at),
                });
              }
            }
          }
        }
      }

      return organizers;
    } catch (error) {
      console.error("Error fetching organizers:", error);
      return [];
    }
  }

  async hasOrganizerProfile(address: string): Promise<boolean> {
    try {
      const { data: objects } = await suiClient.getOwnedObjects({
        owner: address,
        filter: {
          StructType: `${this.packageId}::event_management::OrganizerCap`,
        },
        options: { showContent: true },
      });

      if (objects.length === 0) return false;

      for (const obj of objects) {
        const fields = extractMoveObjectFields(obj);

        if (fields) {
          const profileId = fields.profile_id;

          const profileResponse = await suiClient.getObject({
            id: profileId,
            options: { showContent: true },
          });

          const profileFields = extractMoveObjectFields(profileResponse);

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

  /**
   * Get real-time attendee count for an event
   */
  async getEventAttendeeCount(
    eventId: string,
    _registrationRegistryId: string
  ): Promise<number> {
    try {
      // Query registration events for this specific event
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
        limit: 100,
      });

      let attendeeCount = 0;

      // Count UserRegistered events for this event
      for (const txn of transactions) {
        if (txn.events) {
          for (const event of txn.events) {
            if (event.type?.includes("UserRegistered")) {
              const eventData = event.parsedJson as {
                event_id: string;
                wallet: string;
              };

              if (eventData && eventData.event_id === eventId) {
                attendeeCount++;
              }
            }
          }
        }
      }

      return attendeeCount;
    } catch (error) {
      console.error("Error getting attendee count:", error);
      return 0;
    }
  }

  /**
   * Get event with real-time attendee count
   */
  async getEventWithAttendeeCount(
    eventId: string,
    registrationRegistryId: string
  ): Promise<Event | null> {
    try {
      const event = await this.getEvent(eventId);
      if (!event) return null;

      const attendeeCount = await this.getEventAttendeeCount(
        eventId,
        registrationRegistryId
      );

      return {
        ...event,
        current_attendees: attendeeCount,
      };
    } catch (error) {
      console.error("Error getting event with attendee count:", error);
      return null;
    }
  }
}
