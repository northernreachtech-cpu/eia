import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import {
  Calendar,
  // MapPin,
  Users,
  //   Clock,
  //   Star,
  QrCode,
  Trophy,
  ChevronLeft,
  ChevronRight,
  Star,
  CheckCircle,
  MessageCircle,
  //Loader2,
} from "lucide-react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useAriyaSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../config/sui";
import Card from "../components/Card";
import Button from "../components/Button";
// import EventCard from "../components/EventCard";
import QRDisplay from "../components/QRDisplay";
import useScrollToTop from "../hooks/useScrollToTop";
import RatingStars from "../components/RatingStars";

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

// Skeleton loader component for MyEvents
const MyEventCardSkeleton = () => (
  <Card className="p-6 sm:p-8 animate-pulse">
    <div className="flex items-start justify-between mb-4 sm:mb-6">
      <div className="flex-1">
        <div className="h-6 bg-white/10 rounded mb-2 w-3/4"></div>
        <div className="h-5 bg-white/10 rounded w-20"></div>
      </div>
    </div>

    <div className="space-y-3 mb-6">
      <div className="flex items-center">
        <div className="h-4 w-4 bg-white/10 rounded mr-2"></div>
        <div className="h-4 bg-white/10 rounded w-24"></div>
      </div>
      <div className="flex items-center">
        <div className="h-4 w-4 bg-white/10 rounded mr-2"></div>
        <div className="h-4 bg-white/10 rounded w-32"></div>
      </div>
    </div>

    <div className="space-y-2">
      <div className="h-8 bg-white/10 rounded"></div>
      <div className="h-8 bg-white/10 rounded"></div>
    </div>
  </Card>
);

const MyEvents = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const sdk = useAriyaSDK();
  const registrationRegistryId = useNetworkVariable("registrationRegistryId");
  const attendanceRegistryId = useNetworkVariable("attendanceRegistryId");
  const nftRegistryId = useNetworkVariable("nftRegistryId");
  const ratingRegistryId = useNetworkVariable("ratingRegistryId");
  const communityRegistryId = useNetworkVariable("communityRegistryId");
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();

  const [activeTab, setActiveTab] = useState("attending");
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showQR, setShowQR] = useState(false);
  const [selectedEvent, setSelectedEvent] = useState<any>(null);
  const [qrData, setQrData] = useState("");
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [successMessage, setSuccessMessage] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const eventsPerPage = 6;

  const [showRatingModal, setShowRatingModal] = useState(false);
  const [ratingEvent, setRatingEvent] = useState<any>(null);
  const [eventRating, setEventRating] = useState(0);
  const [organizerRating, setOrganizerRating] = useState(0);
  const [feedback, setFeedback] = useState("");
  const [ratingLoading, setRatingLoading] = useState(false);
  const [ratingError, setRatingError] = useState("");
  const [ratingSuccess, setRatingSuccess] = useState("");
  const [joiningCommunity, setJoiningCommunity] = useState<string | null>(null);

  const handleShowQR = async (event: any) => {
    try {
      const registration = await sdk.identityAccess.getRegistrationStatus(
        event.id,
        currentAccount!.address,
        registrationRegistryId
      );

      if (registration) {
        const qrDataString = sdk.identityAccess.generateQRCodeData(
          event.id,
          currentAccount!.address,
          registration
        );
        setQrData(qrDataString);
        setSelectedEvent(event);
        setShowQR(true);
      }
    } catch (error) {
      console.error("Error generating QR code:", error);
    }
  };

  // Mint Completion NFT handler
  const handleMintCompletionNFT = async (_event: any) => {
    try {
      // Assume the MintCompletionCapability is in the user's wallet after check-out
      // and the NFT registry ID is available from config
      // const nftRegistryId = useNetworkVariable("nftRegistryId");
      // Find the capability object in the user's wallet (simplified, in real use you may need to query for it)
      // For demo, assume the capability is named as event.id + "_completion_capability"
      // In production, you should query the wallet for the correct object type
      // const tx = new Transaction();
      // This is a placeholder; you should implement capability discovery logic
      // const completionCapId = await sdk.attendanceVerification.findCompletionCapability(event.id, currentAccount.address);
      // For now, just show a success modal
      setSuccessMessage(
        "Completion NFT minted successfully! (Demo: implement capability discovery and mint call)"
      );
      setShowSuccessModal(true);
    } catch (error) {
      setSuccessMessage("Failed to mint Completion NFT. Please try again.");
      setShowSuccessModal(true);
    }
  };

  const handleOpenRating = (event: any) => {
    setRatingEvent(event);
    setShowRatingModal(true);
    setEventRating(0);
    setOrganizerRating(0);
    setFeedback("");
    setRatingError("");
    setRatingSuccess("");
  };

  const handleSubmitRating = async () => {
    if (!currentAccount || !ratingEvent || !ratingRegistryId) return;
    setRatingLoading(true);
    setRatingError("");
    setRatingSuccess("");
    try {
      // Convert to Move format (1.0-5.0 stars => 100-500)
      const eventRatingInt = Math.round(eventRating * 100);
      const organizerRatingInt = Math.round(organizerRating * 100);
      if (
        eventRatingInt < 100 ||
        eventRatingInt > 500 ||
        organizerRatingInt < 100 ||
        organizerRatingInt > 500
      ) {
        setRatingError("Ratings must be between 1.0 and 5.0 stars");
        setRatingLoading(false);
        return;
      }
      const tx = new Transaction();
      if (!ratingEvent.organizer_profile_id) {
        setRatingError("Organizer profile not found. Cannot submit rating.");
        setRatingLoading(false);
        return;
      }
      tx.moveCall({
        target: `${sdk.eventManagement.getPackageId()}::rating_reputation::submit_rating`,
        arguments: [
          tx.object(ratingEvent.id),
          tx.pure.u64(eventRatingInt),
          tx.pure.u64(organizerRatingInt),
          tx.pure.string(feedback),
          tx.object(ratingRegistryId),
          tx.object(attendanceRegistryId),
          tx.object(ratingEvent.organizer_profile_id),
          tx.object("0x6"), // CLOCK_ID
        ],
      });
      await signAndExecute({ transaction: tx });
      setRatingSuccess("Thank you for rating this event!");
      setShowRatingModal(false);
    } catch (e: any) {
      setRatingError(e.message || "Failed to submit rating.");
    } finally {
      setRatingLoading(false);
    }
  };

  const handleJoinCommunity = async (event: any) => {
    if (!currentAccount || !communityRegistryId || !nftRegistryId) return;
    setJoiningCommunity(event.id);
    try {
      // First check if there are communities for this event
      const communities = await sdk.communityAccess.getEventCommunities(
        event.id,
        communityRegistryId
      );

      if (communities.length === 0) {
        setSuccessMessage(
          "No community available for this event yet. The organizer may create one during the event."
        );
        setShowSuccessModal(true);
        return;
      }

      // For now, join the first community (could be enhanced with community selection)
      const communityId = communities[0].id;

      // Check if user is already an active member
      const membershipCheck = await sdk.communityAccess.isActiveCommunityMember(
        communityId,
        currentAccount.address,
        communityRegistryId,
        nftRegistryId
      );

      if (membershipCheck.isActive) {
        // User is already an active member, navigate directly to community
        setSuccessMessage(
          "You're already a member of this community! Redirecting you now."
        );
        setShowSuccessModal(true);
        setTimeout(() => {
          navigate(`/community/${communityId}`);
        }, 1500);
        return;
      }

      // User needs to join or rejoin the community
      const tx = sdk.communityAccess.requestCommunityAccess(
        communityId,
        currentAccount.address,
        nftRegistryId,
        communityRegistryId
      );

      await signAndExecute({ transaction: tx });
      setSuccessMessage(
        "Successfully joined the event community! You can now access forums and resources."
      );
      setShowSuccessModal(true);
      navigate(`/community/${communityId}`);
    } catch (e: any) {
      let message = e.message || "Failed to join community.";

      // Handle specific Move abort codes
      if (message.includes("MoveAbort") && message.includes("2")) {
        message =
          "You need a PoA (Proof of Attendance) NFT to join this community. The NFT should be automatically minted when you check in to the event. If you've already checked in but don't have the NFT, please contact the event organizer.";
      } else if (message.includes("NFT required")) {
        message =
          "You need a PoA NFT to join this community. Make sure you've checked in to the event.";
      } else if (message.includes("MoveAbort")) {
        // Parse other Move abort codes if needed
        if (message.includes("1")) {
          message = "Community not found or inactive.";
        } else if (message.includes("3")) {
          message = "You're already a member of this community.";
        }
      }

      setSuccessMessage(message);
      setShowSuccessModal(true);
    } finally {
      setJoiningCommunity(null);
    }
  };

  useEffect(() => {
    const loadEvents = async () => {
      if (!currentAccount) return;
      try {
        setLoading(true);
        let eventList: any[] = [];
        // Get all events and filter by registration status
        const allEvents = await sdk.eventManagement.getActiveEvents();
        // Fetch all organizer profiles
        const allProfiles = await sdk.eventManagement.getAllOrganizers();
        // Log all organizer profiles for debugging
        console.log("[EIA] All organizer profiles:", allProfiles);
        const eventsWithStatus = await Promise.all(
          allEvents.map(async (event) => {
            // Get registration status
            const registration = await sdk.identityAccess.getRegistrationStatus(
              event.id,
              currentAccount.address,
              registrationRegistryId
            );
            // Get attendance status from contract
            let attendanceState = 0;
            let hasRecord = false;
            let checkInTime = 0;
            let checkOutTime = 0;
            try {
              const tx = new Transaction();
              tx.moveCall({
                target: `${sdk.attendanceVerification.getPackageId()}::attendance_verification::get_attendance_status`,
                arguments: [
                  tx.pure.address(currentAccount.address),
                  tx.pure.id(event.id),
                  tx.object(attendanceRegistryId),
                ],
              });
              const result = await suiClient.devInspectTransactionBlock({
                transactionBlock: tx,
                sender: currentAccount.address,
              });
              // Parse result: [hasRecord, state, checkInTime, checkOutTime]
              if (result && result.results && result.results.length > 0) {
                const returnVals = result.results[0].returnValues;
                if (Array.isArray(returnVals) && returnVals.length >= 4) {
                  hasRecord = Array.isArray(returnVals[0])
                    ? returnVals[0].length > 0
                    : !!returnVals[0];
                  attendanceState = (
                    Array.isArray(returnVals[1])
                      ? returnVals[1][0]
                      : parseInt(returnVals[1]) || 0
                  ) as number;
                  checkInTime = (
                    Array.isArray(returnVals[2])
                      ? returnVals[2][0]
                      : parseInt(returnVals[2]) || 0
                  ) as number;
                  checkOutTime = (
                    Array.isArray(returnVals[3])
                      ? returnVals[3][0]
                      : parseInt(returnVals[3]) || 0
                  ) as number;
                }
              }
            } catch (e) {
              attendanceState = 0;
              hasRecord = false;
              checkInTime = 0;
              checkOutTime = 0;
            }

            // Console log attendance state for debugging
            console.log(
              `[MyEvents] Event ${event.id} - User ${currentAccount.address}:`,
              {
                attendanceState,
                hasRecord,
                checkInTime,
                checkOutTime,
                eventName: event.name,
              }
            );

            // Attach organizer_profile_id
            const normalize = (addr: string) => {
              if (!addr) return "";
              return addr.toLowerCase().startsWith("0x")
                ? addr.toLowerCase()
                : `0x${addr.toLowerCase()}`;
            };
            const organizerProfile = allProfiles.find(
              (profile) =>
                normalize(profile.address) === normalize(event.organizer)
            );
            if (!organizerProfile) {
              console.warn(
                "[EIA] No organizer profile found for event",
                event.id,
                "organizer:",
                event.organizer
              );
              // Log all profile addresses being compared
              console.log(
                "[EIA] All profile addresses:",
                allProfiles.map((p) => p.address)
              );
              // Log the full profile object if any profile address matches after normalization
              const matchingProfile = allProfiles.find(
                (profile) =>
                  normalize(profile.address) === normalize(event.organizer)
              );
              if (matchingProfile) {
                console.log("[EIA] Matching profile object:", matchingProfile);
              }
            }
            const organizer_profile_id = organizerProfile
              ? organizerProfile.id
              : undefined;
            return {
              ...event,
              isRegistered: !!registration,
              attendanceState,
              hasRecord,
              checkInTime,
              checkOutTime,
              organizer_profile_id,
            };
          })
        );
        eventList = eventsWithStatus.filter((event) => event.isRegistered);
        setEvents(eventList);
      } catch (error) {
        console.error("Error loading events:", error);
      } finally {
        setLoading(false);
      }
    };
    loadEvents();
  }, [
    currentAccount,
    activeTab,
    sdk,
    registrationRegistryId,
    attendanceRegistryId,
    nftRegistryId,
    ratingRegistryId,
  ]);

  const formatDate = (timestamp: number) => {
    return new Date(timestamp).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

  const formatTime = (timestamp: number) => {
    return new Date(timestamp).toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    });
  };

  const getAttendanceStatusText = (state: any) => {
    // Handle array format from Move contract
    const stateValue = Array.isArray(state) ? state[0] : state;
    switch (stateValue) {
      case 0:
        return "Registered";
      case 1:
        return "Checked In";
      case 2:
        return "Checked Out";
      default:
        return "Unknown";
    }
  };

  const getAttendanceStatusColor = (state: any) => {
    // Handle array format from Move contract
    const stateValue = Array.isArray(state) ? state[0] : state;
    switch (stateValue) {
      case 0:
        return "bg-gradient-to-r from-amber-500/20 to-orange-500/20 border border-amber-500/30 text-amber-300";
      case 1:
        return "bg-gradient-to-r from-emerald-500/20 to-green-500/20 border border-emerald-500/30 text-emerald-300";
      case 2:
        return "bg-gradient-to-r from-blue-500/20 to-indigo-500/20 border border-blue-500/30 text-blue-300";
      default:
        return "bg-gradient-to-r from-gray-500/20 to-slate-500/20 border border-gray-500/30 text-gray-300";
    }
  };

  // Filter events based on active tab
  const filteredEvents = events.filter((event) => {
    const attendanceState = Array.isArray(event.attendanceState)
      ? event.attendanceState[0]
      : event.attendanceState;
    if (activeTab === "completed") {
      return attendanceState === 2; // Checked out events
    } else {
      return attendanceState !== 2; // All other events (registered, checked in)
    }
  });

  // Pagination logic
  const indexOfLastEvent = currentPage * eventsPerPage;
  const indexOfFirstEvent = indexOfLastEvent - eventsPerPage;
  const currentEvents = filteredEvents.slice(
    indexOfFirstEvent,
    indexOfLastEvent
  );
  const totalPages = Math.ceil(filteredEvents.length / eventsPerPage);

  const nextPage = () => {
    setCurrentPage((prev) => Math.min(prev + 1, totalPages));
  };

  const prevPage = () => {
    setCurrentPage((prev) => Math.max(prev - 1, 1));
  };

  // Reset to page 1 when tab changes
  useEffect(() => {
    setCurrentPage(1);
  }, [activeTab]);

  if (!currentAccount) {
    return (
      <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
        <div className="container mx-auto px-4">
          <div className="text-center py-12">
            <h2 className="text-2xl font-semibold mb-4">Connect Your Wallet</h2>
            <p className="text-white/60">
              Please connect your wallet to view your events.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
      <div className="container mx-auto px-4">
        <div className="max-w-6xl mx-auto">
          {/* Header */}
          <div className="text-center mb-8 sm:mb-12">
            <h1 className="text-3xl sm:text-4xl lg:text-5xl font-livvic font-bold mb-3 sm:mb-4">
              My Events
            </h1>
            <p className="text-white/80 text-base sm:text-lg lg:text-xl max-w-2xl mx-auto font-open-sans">
              Track your event registrations and attendance
            </p>
          </div>

          {/* Tab Navigation */}
          <div className="flex justify-center mb-8 sm:mb-12">
            <div className="flex space-x-1 bg-white/10 rounded-lg p-1">
              <button
                onClick={() => setActiveTab("attending")}
                className={`px-4 py-2 rounded-md transition-colors ${
                  activeTab === "attending"
                    ? "bg-primary text-white"
                    : "text-white/70 hover:text-white"
                }`}
              >
                Attending
              </button>
              <button
                onClick={() => setActiveTab("completed")}
                className={`px-4 py-2 rounded-md transition-colors ${
                  activeTab === "completed"
                    ? "bg-primary text-white"
                    : "text-white/70 hover:text-white"
                }`}
              >
                Completed
              </button>
            </div>
          </div>

          {/* Events Grid */}
          {!loading && (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 sm:gap-8">
              {currentEvents.map((event) => (
                <Card key={event.id} hover className="p-6 sm:p-8">
                  <div className="flex items-start justify-between mb-4 sm:mb-6">
                    <div className="flex-1">
                      <h3 className="text-lg sm:text-xl font-semibold mb-2">
                        {event.name}
                      </h3>
                      <p
                        className={`text-sm font-medium px-3 py-1.5 rounded-full inline-flex items-center justify-center shadow-sm backdrop-blur-sm ${getAttendanceStatusColor(
                          event.attendanceState
                        )}`}
                      >
                        {getAttendanceStatusText(event.attendanceState)}
                      </p>
                    </div>
                  </div>

                  <div className="space-y-3 mb-6">
                    <div className="flex items-center text-white/70">
                      <Calendar className="mr-2 h-4 w-4 flex-shrink-0" />
                      <span className="text-sm">
                        {formatDate(event.start_time)} at{" "}
                        {formatTime(event.start_time)}
                      </span>
                    </div>

                    <div className="flex items-center text-white/70">
                      <Users className="mr-2 h-4 w-4 flex-shrink-0" />
                      <span className="text-sm">
                        Organized by {event.organizer.slice(0, 8)}...
                      </span>
                    </div>
                  </div>

                  {/* Action Buttons */}
                  <div className="space-y-2">
                    {(Array.isArray(event.attendanceState)
                      ? event.attendanceState[0]
                      : event.attendanceState) === 1 && (
                      <>
                        <Button
                          size="sm"
                          className="w-full"
                          onClick={() => handleShowQR(event)}
                        >
                          <QrCode className="mr-2 h-4 w-4" />
                          Show QR Code
                        </Button>
                        <Button
                          size="sm"
                          className="w-full"
                          variant="secondary"
                          onClick={() => handleJoinCommunity(event)}
                          disabled={joiningCommunity === event.id}
                        >
                          <MessageCircle className="mr-2 h-4 w-4" />
                          {joiningCommunity === event.id
                            ? "Joining..."
                            : "Join Community"}
                        </Button>
                      </>
                    )}
                    {(Array.isArray(event.attendanceState)
                      ? event.attendanceState[0]
                      : event.attendanceState) === 2 && (
                      <>
                        <div className="mb-2 flex items-center gap-2">
                          <span className="inline-block px-3 py-1.5 rounded-full bg-gradient-to-r from-blue-500/20 to-indigo-500/20 border border-blue-500/30 text-blue-300 text-xs font-medium shadow-sm backdrop-blur-sm">
                            Checked Out
                          </span>
                          <span className="inline-block px-3 py-1.5 rounded-full bg-gradient-to-r from-emerald-500/20 to-green-500/20 border border-emerald-500/30 text-emerald-300 text-xs font-medium shadow-sm backdrop-blur-sm">
                            Eligible to Mint NFT
                          </span>
                        </div>
                        <Button
                          variant="outline"
                          size="sm"
                          className="w-full"
                          onClick={() => handleMintCompletionNFT(event)}
                        >
                          <Trophy className="mr-2 h-4 w-4" />
                          Mint Completion NFT
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          className="w-full"
                          onClick={() => handleOpenRating(event)}
                        >
                          <Star className="mr-2 h-4 w-4" />
                          Rate Event
                        </Button>
                      </>
                    )}
                    {(Array.isArray(event.attendanceState)
                      ? event.attendanceState[0]
                      : event.attendanceState) === 0 && (
                      <Button
                        size="sm"
                        className="w-full"
                        onClick={() => handleShowQR(event)}
                      >
                        <QrCode className="mr-2 h-4 w-4" />
                        Show QR Code
                      </Button>
                    )}
                    <Button
                      variant="ghost"
                      size="sm"
                      className="w-full"
                      onClick={() =>
                        navigate(`/event/${event.id}`, {
                          state: {
                            attendanceState: event.attendanceState,
                            hasRecord: event.hasRecord,
                            checkInTime: event.checkInTime,
                            checkOutTime: event.checkOutTime,
                          },
                        })
                      }
                    >
                      View Details
                    </Button>
                  </div>
                </Card>
              ))}
            </div>
          )}

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex justify-center mt-8">
              <Button
                variant="outline"
                size="sm"
                onClick={prevPage}
                disabled={currentPage === 1}
                className="mr-2"
              >
                <ChevronLeft className="h-4 w-4" />
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
                <ChevronRight className="h-4 w-4" />
              </Button>
            </div>
          )}

          {/* QR Code Modal */}
          {showQR && selectedEvent && (
            <QRDisplay
              qrData={qrData}
              eventName={selectedEvent.name}
              isOpen={showQR}
              onClose={() => setShowQR(false)}
            />
          )}

          {/* Empty State */}
          {filteredEvents.length === 0 && !loading && (
            <div className="text-center py-12 sm:py-16">
              <div className="mb-6">
                <Calendar className="h-16 w-16 mx-auto text-white/30" />
              </div>
              <h3 className="text-xl font-semibold mb-2 text-white/70">
                No {activeTab} events yet
              </h3>
              <p className="text-white/50 mb-6 max-w-md mx-auto">
                {activeTab === "attending" &&
                  "Discover and join events to see them here"}
                {activeTab === "completed" &&
                  "Complete events to see them here with your NFT rewards"}
              </p>
              <Button onClick={() => navigate("/events")}>
                <Calendar className="mr-2 h-4 w-4" />
                Browse Events
              </Button>
            </div>
          )}

          {/* Loading State */}
          {loading && (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 sm:gap-8">
              {Array.from({ length: 6 }).map((_, index) => (
                <MyEventCardSkeleton key={index} />
              ))}
            </div>
          )}

          {/* Success Modal */}
          <SuccessModal
            isOpen={showSuccessModal}
            message={successMessage}
            onClose={() => setShowSuccessModal(false)}
          />
        </div>
      </div>
      {/* Sleek Rating Modal */}
      {showRatingModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm animate-fade-in">
          <div className="relative bg-white/20 backdrop-blur-2xl border border-white/20 shadow-2xl rounded-2xl max-w-md w-full mx-4 p-0 overflow-hidden animate-slide-up">
            {/* Top Icon */}
            <div className="flex flex-col items-center justify-center pt-8 pb-2 bg-gradient-to-r from-primary/80 to-secondary/80">
              <span className="text-5xl mb-2">🌟</span>
              <h3 className="text-2xl font-bold text-white drop-shadow mb-1">
                Rate This Event
              </h3>
              <p className="text-white/80 text-sm mb-2">
                Share your experience and help others!
              </p>
            </div>
            <div className="px-8 py-6 flex flex-col gap-4">
              <div className="flex flex-col items-center justify-center">
                <div className="mb-1 text-base font-semibold text-primary text-center">
                  Event Rating
                </div>
                <RatingStars
                  rating={eventRating}
                  interactive
                  onRatingChange={setEventRating}
                  size="lg"
                  className="scale-110 mx-auto"
                />
              </div>
              <div className="flex flex-col items-center justify-center">
                <div className="mb-1 text-base font-semibold text-primary text-center">
                  Organizer Rating
                </div>
                <RatingStars
                  rating={organizerRating}
                  interactive
                  onRatingChange={setOrganizerRating}
                  size="lg"
                  className="scale-110 mx-auto"
                />
              </div>
              <textarea
                className="w-full border-0 bg-white/40 rounded-xl p-3 text-sm text-gray-800 focus:ring-2 focus:ring-primary/40 transition outline-none placeholder:text-gray-400"
                rows={3}
                placeholder="Optional feedback..."
                value={feedback}
                onChange={(e) => setFeedback(e.target.value)}
                maxLength={300}
              />
              {ratingError && (
                <div className="text-red-500 text-sm mb-2">{ratingError}</div>
              )}
              {ratingSuccess && (
                <div className="flex flex-col items-center gap-2 text-green-600 text-base font-semibold animate-fade-in">
                  <CheckCircle className="h-8 w-8" />
                  {ratingSuccess}
                </div>
              )}
              <div className="flex gap-3 mt-2">
                <Button
                  onClick={handleSubmitRating}
                  disabled={ratingLoading}
                  className="flex-1 bg-gradient-to-r from-primary to-secondary text-white font-bold py-2 rounded-xl shadow-lg hover:from-secondary hover:to-primary transition-all text-base min-w-0"
                >
                  {ratingLoading ? "Submitting..." : "Submit Rating"}
                </Button>
                <Button
                  variant="outline"
                  onClick={() => setShowRatingModal(false)}
                  className="flex-1 border-0 bg-white/60 text-gray-700 font-semibold py-2 rounded-xl hover:bg-white/80 transition-all text-base min-w-0"
                >
                  Cancel
                </Button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default MyEvents;
