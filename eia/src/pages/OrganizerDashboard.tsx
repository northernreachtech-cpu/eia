import { useState, useEffect } from "react";
import {
  Calendar,
  Users,
  Star,
  DollarSign,
  Eye,
  Settings,
  Plus,
  Loader2,
  Play,
  QrCode,
  Share2,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useAriyaSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import { Transaction } from "@mysten/sui/transactions";
import Card from "../components/Card";
import Button from "../components/Button";
import StatCard from "../components/StatCard";
import RatingStars from "../components/RatingStars";
import QRScanner from "../components/QRScanner";
import useScrollToTop from "../hooks/useScrollToTop";
import { suiClient } from "../config/sui";

interface Event {
  id: string;
  title: string;
  date: string;
  status: "upcoming" | "active" | "completed";
  checkedIn: number;
  totalCapacity: number;
  escrowStatus: "pending" | "released" | "locked";
  rating: number;
  revenue: number;
  state: number; // Add state for activation logic
}

// Simple SuccessModal component
const SuccessModal = ({
  isOpen,
  message,
  onClose,
}: {
  isOpen: boolean;
  message: string;
  onClose: () => void;
}) => {
  if (!isOpen) return null;
  return (
    <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50">
      <div
        onClick={onClose}
        className="bg-white rounded-lg p-8 max-w-sm mx-4 shadow-lg"
      >
        <h3 className="text-xl font-semibold text-green-600 mb-4">Success</h3>
        <p className="text-gray-800 mb-6">{message}</p>
        <Button onClick={onClose} className="w-full">
          Close
        </Button>
      </div>
    </div>
  );
};

const OrganizerDashboard = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const sdk = useAriyaSDK();
  const eventRegistryId = useNetworkVariable("eventRegistryId");
  const attendanceRegistryId = useNetworkVariable("attendanceRegistryId");
  const registrationRegistryId = useNetworkVariable("registrationRegistryId");
  const nftRegistryId = useNetworkVariable("nftRegistryId");

  const [loading, setLoading] = useState(true);
  const [activatingEvent, setActivatingEvent] = useState<string | null>(null);
  const [showQRScanner, setShowQRScanner] = useState(false);
  const [selectedEventId, setSelectedEventId] = useState<string | null>(null);
  const [showCheckOutScanner, setShowCheckOutScanner] = useState(false);
  const [selectedCheckOutEventId, setSelectedCheckOutEventId] = useState<
    string | null
  >(null);
  // const [organizerProfile, setOrganizerProfile] = useState<any>(null);
  const [events, setEvents] = useState<Event[]>([]);
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [successMessage, setSuccessMessage] = useState("");
  const [settingMetadataEvent, setSettingMetadataEvent] = useState<
    string | null
  >(null);
  const [completingEvent, setCompletingEvent] = useState<string | null>(null);
  const [showCompleteModal, setShowCompleteModal] = useState(false);
  const [eventToComplete, setEventToComplete] = useState<any>(null);
  const [organizerProfileId, setOrganizerProfileId] = useState<string | null>(
    null
  );
  const [showShareModal, setShowShareModal] = useState(false);
  const [shareEventLink, setShareEventLink] = useState("");

  const eventsPerPage = 5;
  const [currentPage, setCurrentPage] = useState(1);
  const indexOfLastEvent = currentPage * eventsPerPage;
  const indexOfFirstEvent = indexOfLastEvent - eventsPerPage;
  const currentEvents = events.slice(indexOfFirstEvent, indexOfLastEvent);
  const totalPages = Math.ceil(events.length / eventsPerPage);
  const nextPage = () =>
    setCurrentPage((prev) => Math.min(prev + 1, totalPages));
  const prevPage = () => setCurrentPage((prev) => Math.max(prev - 1, 1));
  useEffect(() => {
    setCurrentPage(1);
  }, [events.length]);

  // Fetch organizer profile ID on mount
  useEffect(() => {
    const fetchProfile = async () => {
      if (!currentAccount) return;
      const { data: objects } = await suiClient.getOwnedObjects({
        owner: currentAccount.address,
        filter: {
          StructType: `${sdk.eventManagement.getPackageId()}::event_management::OrganizerCap`,
        },
        options: { showContent: true },
      });
      for (const obj of objects) {
        if (obj.data?.content?.dataType === "moveObject") {
          const fields = obj.data.content.fields;
          // Extract profileId as a string
          const profileId =
            typeof (fields as any)["profile_id"] === "string"
              ? (fields as any)["profile_id"]
              : undefined;
          if (profileId) {
            setOrganizerProfileId(profileId);
            break;
          }
        }
      }
    };
    fetchProfile();
  }, [currentAccount, sdk]);

  const handleActivateEvent = async (eventId: string) => {
    try {
      setActivatingEvent(eventId);
      const tx = sdk.eventManagement.activateEvent(eventId, eventRegistryId);

      await signAndExecute({
        transaction: tx,
      });

      // Reload events to reflect the state change
      await loadOrganizerData();
    } catch (error) {
      alert("Failed to activate event. Please try again.");
    } finally {
      setActivatingEvent(null);
    }
  };

  const handleCheckIn = (eventId: string) => {
    setSelectedEventId(eventId);
    setShowQRScanner(true);
  };

  const handleCheckOut = (eventId: string) => {
    setSelectedCheckOutEventId(eventId);
    setShowCheckOutScanner(true);
  };

  const handleQRScan = async (qrData: any) => {
    try {
      // Check if this is the new QR format with pass_id
      if (qrData.pass_id && qrData.pass_hash === null) {
        // Use the new check-in method that generates pass hash from pass_id
        const tx = sdk.attendanceVerification.checkInAttendeeWithPassId(
          selectedEventId!,
          qrData.user_address,
          qrData.pass_id,
          attendanceRegistryId,
          registrationRegistryId
        );

        await signAndExecute({
          transaction: tx,
        });

        alert(`Successfully checked in ${qrData.user_address}`);
      } else {
        // Fallback to old method for backward compatibility
        // Validate QR code
        const validation = await sdk.attendanceVerification.validateQRCode(
          qrData,
          selectedEventId!
        );

        if (!validation.success) {
          alert(validation.message);
          return;
        }

        // Check-in attendee
        const tx = sdk.attendanceVerification.checkInAttendee(
          selectedEventId!,
          validation.attendeeAddress!,
          attendanceRegistryId,
          registrationRegistryId,
          qrData
        );

        await signAndExecute({
          transaction: tx,
        });

        alert(`Successfully checked in ${validation.attendeeAddress}`);
      }

      // Reload events to update attendee count
      await loadOrganizerData();
    } catch (error) {
      alert("Failed to check in attendee. Please try again.");
    }
  };

  const handleCheckOutQRScan = async (qrData: any) => {
    try {
      // Expect qrData.user_address and qrData.event_id
      if (!qrData.user_address || !qrData.event_id) {
        setSuccessMessage("Invalid QR code for check-out");
        setShowSuccessModal(true);
        return;
      }
      const tx = sdk.attendanceVerification.checkOutAttendee(
        qrData.user_address,
        qrData.event_id,
        attendanceRegistryId
      );
      await signAndExecute({ transaction: tx });
      setSuccessMessage(
        `Successfully checked out ${qrData.user_address}. The attendee can now mint their Completion NFT!`
      );
      setShowSuccessModal(true);
      await loadOrganizerData();
    } catch (error) {
      alert("Failed to check out attendee. Please try again.");
    }
  };

  const handleSetEventMetadata = async (event: any) => {
    if (!nftRegistryId || !currentAccount) return;
    setSettingMetadataEvent(event.id);
    try {
      const tx = new Transaction();
      tx.moveCall({
        target: `${sdk.attendanceVerification.getPackageId()}::nft_minting::set_event_metadata`,
        arguments: [
          tx.pure.id(event.id),
          tx.pure.string(event.title),
          tx.pure.string(event.metadata_uri || ""),
          tx.pure.string(event.location || ""),
          tx.pure.address(currentAccount.address),
          tx.object(nftRegistryId),
        ],
      });
      await signAndExecute({ transaction: tx });
      setSuccessMessage("Event metadata set successfully for NFT minting!");
      setShowSuccessModal(true);
    } catch (e: any) {
      setSuccessMessage(e.message || "Failed to set event metadata.");
      setShowSuccessModal(true);
    } finally {
      setSettingMetadataEvent(null);
    }
  };

  const handleCompleteEvent = (event: any) => {
    // Log all relevant IDs and event object for confirmation
    console.log("Selected event for completion:", {
      eventId: event.id,
      eventRegistryId,
      organizerProfileId,
      eventObject: event,
    });
    setEventToComplete(event);
    setShowCompleteModal(true);
  };

  const confirmCompleteEvent = async () => {
    if (!eventToComplete || !organizerProfileId) return;
    setCompletingEvent(eventToComplete.id);
    try {
      const tx = sdk.eventManagement.completeEvent(
        eventToComplete.id,
        eventRegistryId,
        organizerProfileId
      );
      console.log("Completing event with:", {
        eventId: eventToComplete.id,
        eventRegistryId,
        organizerProfileId,
      });
      await signAndExecute({ transaction: tx });
      setSuccessMessage("Event marked as completed!");
      setShowSuccessModal(true);
      setShowCompleteModal(false);
      await loadOrganizerData();
    } catch (e: any) {
      // Enhanced error handling for Move abort codes
      let message = e.message || "Failed to complete event.";
      if (
        message.includes("MoveAbort") &&
        message.includes('function_name: Some("complete_event")')
      ) {
        if (message.includes(", 1)")) {
          message = "You are not the organizer of this event.";
        } else if (message.includes(", 2)")) {
          message = "Event is not active. Only active events can be completed.";
        } else if (message.includes(", 3)")) {
          message =
            "Event cannot be completed until after its end time. Please wait until the event has ended.";
        } else {
          message = "Event completion failed due to a contract error.";
        }
      }
      setSuccessMessage(message);
      setShowSuccessModal(true);
    } finally {
      setCompletingEvent(null);
    }
  };

  const loadOrganizerData = async () => {
    if (!currentAccount) return;

    try {
      setLoading(true);
      // Check if user has profile
      const hasProfile = await sdk.eventManagement.hasOrganizerProfile(
        currentAccount.address
      );
      if (!hasProfile) {
        navigate("/create-organizer-profile");
        return;
      }

      // Get organizer's events
      const organizerEvents = await sdk.eventManagement.getEventsByOrganizer(
        currentAccount.address,
        eventRegistryId
      );

      // Transform events to match interface
      const transformedEvents = await Promise.all(
        organizerEvents.map(async (event) => {
          // Get real attendee count
          const attendeeCount = await sdk.eventManagement.getEventAttendeeCount(
            event.id,
            eventRegistryId
          );

          return {
            id: event.id,
            title: event.name,
            date: new Date(event.start_time * 1000).toISOString().split("T")[0],
            status: (event.state === 0
              ? "upcoming"
              : event.state === 1
              ? "active"
              : "completed") as "upcoming" | "active" | "completed",
            checkedIn: attendeeCount, // Use real attendee count
            totalCapacity: 100, // TODO: Get from event data
            escrowStatus: "pending" as "pending" | "released" | "locked",
            rating: 0, // TODO: Get from event data
            revenue: 0, // TODO: Get from event data
            state: event.state, // Add state for activation logic
          };
        })
      );

      setEvents(transformedEvents);
    } catch (error) {
      // Only keep error log if needed for debugging
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadOrganizerData();
  }, [currentAccount, sdk, navigate]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="flex items-center gap-2">
          <Loader2 className="h-6 w-6 animate-spin text-primary" />
          <span className="text-white">Loading dashboard...</span>
        </div>
      </div>
    );
  }

  const totalEvents = events.length;
  const totalAttendees = events.reduce(
    (sum, event) => sum + event.checkedIn,
    0
  );
  const totalRevenue = events.reduce((sum, event) => sum + event.revenue, 0);
  const avgRating =
    events
      .filter((e) => e.rating > 0)
      .reduce((sum, event) => sum + event.rating, 0) /
    events.filter((e) => e.rating > 0).length;

  const getStatusColor = (status: string) => {
    switch (status) {
      case "active":
        return "text-green-400 bg-green-400/20";
      case "completed":
        return "text-blue-400 bg-blue-400/20";
      case "upcoming":
        return "text-yellow-400 bg-yellow-400/20";
      default:
        return "text-white/60 bg-white/10";
    }
  };

  const getEscrowStatusColor = (status: string) => {
    switch (status) {
      case "released":
        return "text-green-400";
      case "pending":
        return "text-yellow-400";
      case "locked":
        return "text-red-400";
      default:
        return "text-white/60";
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-black">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-8 sm:pb-12">
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 sm:gap-6 mb-6 sm:mb-8">
          <div>
            <h1 className="text-3xl sm:text-4xl font-livvic font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text mb-2">
              Organizer Dashboard
            </h1>
            <p className="text-white/60 text-sm sm:text-base">
              Manage your events and track performance
            </p>
          </div>

          <Button
            onClick={() => navigate("/event/create")}
            className="w-full sm:w-auto py-3 sm:py-2"
          >
            <Plus className="mr-2 h-4 w-4" />
            Create Event
          </Button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-6 sm:mb-8">
          <StatCard
            title="Total Events"
            value={totalEvents}
            icon={Calendar}
            color="primary"
            trend={{ value: 12, isPositive: true }}
            description="Events created"
          />
          <StatCard
            title="Total Attendees"
            value={totalAttendees}
            icon={Users}
            color="secondary"
            trend={{ value: 8, isPositive: true }}
            description="Across all events"
          />
          <StatCard
            title="Total Revenue"
            value={`$${totalRevenue.toLocaleString()}`}
            icon={DollarSign}
            color="accent"
            trend={{ value: 15, isPositive: true }}
            description="Total earnings"
          />
          <StatCard
            title="Average Rating"
            value={avgRating ? avgRating.toFixed(1) : "0.0"}
            icon={Star}
            color="success"
            description="Event feedback"
          />
        </div>

        <div className="mb-6 sm:mb-8">
          <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mb-4 sm:mb-6">
            <h2 className="text-xl sm:text-2xl font-bold text-white">
              Your Events
            </h2>
          </div>
          {events.length === 0 ? (
            <div className="text-center py-12 sm:py-16">
              <div className="mb-6">
                <Calendar className="h-16 w-16 mx-auto text-white/30" />
              </div>
              <h3 className="text-xl font-semibold mb-2 text-white/70">
                No events yet
              </h3>
              <p className="text-white/50 mb-6 max-w-md mx-auto">
                Create your first event to get started as an organizer.
              </p>
              <Button onClick={() => navigate("/event/create")}>
                <Plus className="mr-2 h-4 w-4" />
                Create Event
              </Button>
            </div>
          ) : (
            <>
              <div className="grid gap-4 sm:gap-6">
                {currentEvents.map((event) => (
                  <Card
                    key={event.id}
                    className="p-4 sm:p-6 hover:shadow-lg hover:shadow-primary/5 transition-all duration-300"
                  >
                    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-stretch">
                      {/* Event Info */}
                      <div className="flex flex-col justify-between bg-white/5 rounded-lg p-4 h-full">
                        <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 mb-4">
                          <div>
                            <h3 className="text-lg sm:text-xl font-semibold text-white mb-1 sm:mb-2">
                              {event.title}
                            </h3>
                            <p className="text-white/60 text-sm">
                              {new Date(event.date).toLocaleDateString(
                                "en-US",
                                {
                                  weekday: "long",
                                  year: "numeric",
                                  month: "long",
                                  day: "numeric",
                                }
                              )}
                            </p>
                          </div>

                          <div className="flex items-center gap-2">
                            <span
                              className={`px-3 py-1 rounded-full text-xs font-medium ${getStatusColor(
                                event.status
                              )}`}
                            >
                              {event.status.charAt(0).toUpperCase() +
                                event.status.slice(1)}
                            </span>
                          </div>
                        </div>

                        {/* Progress Bar */}
                        <div className="mb-4">
                          <div className="flex items-center justify-between mb-2">
                            <span className="text-sm text-white/70">
                              Check-ins
                            </span>
                            <span className="text-sm text-white">
                              {event.checkedIn} / {event.totalCapacity}
                            </span>
                          </div>
                          <div className="w-full bg-white/10 rounded-full h-2">
                            <div
                              className="bg-gradient-to-r from-primary to-secondary h-2 rounded-full transition-all duration-500"
                              style={{
                                width: `${Math.min(
                                  (event.checkedIn / event.totalCapacity) * 100,
                                  100
                                )}%`,
                              }}
                            ></div>
                          </div>
                          <p className="text-xs text-white/60 mt-1">
                            {Math.round(
                              (event.checkedIn / event.totalCapacity) * 100
                            )}
                            % capacity
                          </p>
                        </div>
                      </div>

                      {/* Event Stats */}
                      <div className="flex flex-col justify-center bg-white/5 rounded-lg p-4 h-full min-w-[180px]">
                        <div className="flex flex-row items-center justify-between gap-4 mb-2">
                          {/* Escrow Status */}
                          <div className="flex-1 text-center p-2 rounded bg-white/10">
                            <div className="text-xs text-white/60 mb-1">
                              Escrow
                            </div>
                            <div
                              className={`text-sm font-medium ${getEscrowStatusColor(
                                event.escrowStatus
                              )}`}
                            >
                              {event.escrowStatus.charAt(0).toUpperCase() +
                                event.escrowStatus.slice(1)}
                            </div>
                          </div>
                          {/* Revenue */}
                          <div className="flex-1 text-center p-2 rounded bg-white/10">
                            <div className="text-xs text-white/60 mb-1">
                              Revenue
                            </div>
                            <div className="text-sm font-medium text-white">
                              ${event.revenue.toLocaleString()}
                            </div>
                          </div>
                        </div>
                        {/* Rating */}
                        {event.rating > 0 && (
                          <div className="text-center p-2 rounded bg-white/10 mt-2">
                            <div className="text-xs text-white/60 mb-2">
                              Rating
                            </div>
                            <RatingStars
                              rating={event.rating}
                              size="sm"
                              showLabel
                            />
                          </div>
                        )}
                      </div>
                    </div>
                    {/* Actions Footer */}
                    <div className="flex flex-wrap gap-2 mt-6 border-t border-white/10 pt-4">
                      {event.state === 0 && (
                        <Button
                          size="sm"
                          className="flex-1"
                          onClick={() => handleActivateEvent(event.id)}
                          disabled={activatingEvent === event.id}
                        >
                          {activatingEvent === event.id ? (
                            <Loader2 className="mr-1 h-3 w-3 animate-spin" />
                          ) : (
                            <Play className="mr-1 h-3 w-3" />
                          )}
                          {activatingEvent === event.id
                            ? "Activating..."
                            : "Activate"}
                        </Button>
                      )}

                      {event.state === 1 && (
                        <>
                          <Button
                            size="sm"
                            className="flex-1"
                            onClick={() => handleCheckIn(event.id)}
                          >
                            <QrCode className="mr-1 h-3 w-3" />
                            Check-in
                          </Button>
                          <Button
                            size="sm"
                            className="flex-1"
                            variant="secondary"
                            onClick={() => handleCheckOut(event.id)}
                          >
                            <QrCode className="mr-1 h-3 w-3" />
                            Check-out
                          </Button>
                          <Button
                            size="sm"
                            className="flex-1"
                            variant="outline"
                            onClick={() => handleCompleteEvent(event)}
                            disabled={completingEvent === event.id}
                          >
                            {completingEvent === event.id ? (
                              <Loader2 className="mr-1 h-3 w-3 animate-spin" />
                            ) : (
                              <Play className="mr-1 h-3 w-3" />
                            )}
                            {completingEvent === event.id
                              ? "Completing..."
                              : "Complete Event"}
                          </Button>
                        </>
                      )}

                      <Button
                        variant="outline"
                        size="sm"
                        className="flex-1"
                        onClick={() => {
                          setShareEventLink(
                            window.location.origin + "/event/" + event.id
                          );
                          setShowShareModal(true);
                        }}
                      >
                        <Share2 className="mr-1 h-3 w-3" />
                        Share
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        className="flex-1"
                        onClick={() => navigate(`/event/${event.id}`)}
                      >
                        <Eye className="mr-1 h-3 w-3" />
                        View
                      </Button>
                      <Button
                        variant="outline"
                        size="sm"
                        className="flex-1"
                        onClick={() => handleSetEventMetadata(event)}
                        disabled={settingMetadataEvent === event.id}
                      >
                        {settingMetadataEvent === event.id ? (
                          <Loader2 className="mr-1 h-3 w-3 animate-spin" />
                        ) : (
                          <Settings className="mr-1 h-3 w-3" />
                        )}
                        {settingMetadataEvent === event.id
                          ? "Enabling..."
                          : "Enable NFT Minting"}
                      </Button>
                    </div>
                  </Card>
                ))}
              </div>
              {/* Pagination Controls */}
              {totalPages > 1 && (
                <div className="flex justify-center mt-8">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={prevPage}
                    disabled={currentPage === 1}
                    className="mr-2"
                  >
                    Previous
                  </Button>
                  <span className="text-white/70 text-sm">
                    Page {currentPage} of {totalPages}
                  </span>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={nextPage}
                    disabled={currentPage === totalPages}
                    className="ml-2"
                  >
                    Next
                  </Button>
                </div>
              )}
            </>
          )}
        </div>

        {/* QR Scanner Modal for Check-in */}
        {showQRScanner && selectedEventId && (
          <QRScanner
            isOpen={showQRScanner}
            onClose={() => {
              setShowQRScanner(false);
              setSelectedEventId(null);
            }}
            onScan={handleQRScan}
            eventId={selectedEventId}
          />
        )}
        {/* QR Scanner Modal for Check-out */}
        {showCheckOutScanner && selectedCheckOutEventId && (
          <QRScanner
            isOpen={showCheckOutScanner}
            onClose={() => {
              setShowCheckOutScanner(false);
              setSelectedCheckOutEventId(null);
            }}
            onScan={handleCheckOutQRScan}
            eventId={selectedCheckOutEventId}
          />
        )}
        {/* Success Modal */}
        <SuccessModal
          isOpen={showSuccessModal}
          message={successMessage}
          onClose={() => setShowSuccessModal(false)}
        />
        {/* Complete Event Confirmation Modal */}
        {showCompleteModal && eventToComplete && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80">
            <div className="bg-white rounded-lg p-8 max-w-sm mx-4 shadow-lg text-center">
              <h3 className="text-xl font-semibold mb-4 text-primary">
                Complete Event
              </h3>
              <p className="text-gray-800 mb-6">
                Are you sure you want to mark{" "}
                <span className="font-bold">{eventToComplete.title}</span> as
                completed? This action cannot be undone and will allow attendees
                to rate your event.
              </p>
              <div className="flex gap-2 mt-2">
                <Button
                  onClick={confirmCompleteEvent}
                  disabled={completingEvent === eventToComplete.id}
                  className="flex-1"
                >
                  {completingEvent === eventToComplete.id
                    ? "Completing..."
                    : "Yes, Complete"}
                </Button>
                <Button
                  variant="outline"
                  onClick={() => setShowCompleteModal(false)}
                  className="flex-1"
                >
                  Cancel
                </Button>
              </div>
            </div>
          </div>
        )}
        {showShareModal && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70">
            <div className="bg-white rounded-lg p-8 max-w-sm mx-4 shadow-lg text-center">
              <h3 className="text-xl font-semibold mb-4 text-primary">
                Share Event
              </h3>
              <p className="text-gray-800 mb-4 break-all">{shareEventLink}</p>
              <Button
                onClick={() => {
                  navigator.clipboard.writeText(shareEventLink);
                }}
                className="w-full mb-2"
              >
                Copy Link
              </Button>
              <Button
                variant="outline"
                onClick={() => setShowShareModal(false)}
                className="w-full"
              >
                Close
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default OrganizerDashboard;
