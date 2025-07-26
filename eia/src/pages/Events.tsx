import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import {
  Calendar,
  Users,
  Search,
  ChevronLeft,
  ChevronRight,
  MessageCircle,
  QrCode,
  Trophy,
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
import useScrollToTop from "../hooks/useScrollToTop";

// Skeleton loader component for event cards
const EventCardSkeleton = () => (
  <Card className="p-6 animate-pulse">
    <div className="flex items-start justify-between mb-4">
      <div className="flex-1">
        <div className="h-6 bg-white/10 rounded mb-2 w-3/4"></div>
        <div className="h-4 bg-white/10 rounded w-1/2"></div>
      </div>
      <div className="h-6 bg-white/10 rounded w-16"></div>
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

const Events = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const sdk = useAriyaSDK();
  const registrationRegistryId = useNetworkVariable("registrationRegistryId");
  const attendanceRegistryId = useNetworkVariable("attendanceRegistryId");
  const nftRegistryId = useNetworkVariable("nftRegistryId");
  const communityRegistryId = useNetworkVariable("communityRegistryId");
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();

  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const eventsPerPage = 6;
  const [joiningCommunity, setJoiningCommunity] = useState<string | null>(null);
  const [showSuccessModal, setShowSuccessModal] = useState(false);
  const [successMessage, setSuccessMessage] = useState("");
  const [mintingPoA, setMintingPoA] = useState<string | null>(null);

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
      try {
        setLoading(true);
        const allEvents = await sdk.eventManagement.getActiveEvents();

        // Add registration status and attendance state for current user if connected
        if (currentAccount) {
          const eventsWithStatus = await Promise.all(
            allEvents.map(async (event) => {
              const registration =
                await sdk.identityAccess.getRegistrationStatus(
                  event.id,
                  currentAccount.address,
                  registrationRegistryId
                );

              // Check if user is the organizer
              const isOrganizer = await sdk.identityAccess.isEventOrganizer(
                event.id,
                currentAccount.address
              );

              // Get attendance status from contract
              let attendanceState = 0;
              let hasRecord = false;
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
                  }
                }
              } catch (e) {
                attendanceState = 0;
                hasRecord = false;
              }

              return {
                ...event,
                isRegistered: !!registration,
                isOrganizer,
                attendanceState,
                hasRecord,
              };
            })
          );
          setEvents(eventsWithStatus);
        } else {
          setEvents(allEvents);
        }
      } catch (error) {
        console.error("Error loading events:", error);
      } finally {
        setLoading(false);
      }
    };

    loadEvents();
  }, [currentAccount, sdk, registrationRegistryId, attendanceRegistryId]);

  const filteredEvents = events.filter(
    (event) =>
      event.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      event.organizer.toLowerCase().includes(searchTerm.toLowerCase())
  );

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

  const getStatusText = (state: number) => {
    switch (state) {
      case 0:
        return "Created";
      case 1:
        return "Active";
      case 2:
        return "Completed";
      case 3:
        return "Settled";
      default:
        return "Unknown";
    }
  };

  const getStatusColor = (state: number) => {
    switch (state) {
      case 0:
        return "bg-gradient-to-r from-amber-500/20 to-orange-500/20 border border-amber-500/30 text-amber-300";
      case 1:
        return "bg-gradient-to-r from-emerald-500/20 to-green-500/20 border border-emerald-500/30 text-emerald-300";
      case 2:
        return "bg-gradient-to-r from-blue-500/20 to-indigo-500/20 border border-blue-500/30 text-blue-300";
      case 3:
        return "bg-gradient-to-r from-purple-500/20 to-violet-500/20 border border-purple-500/30 text-purple-300";
      default:
        return "bg-gradient-to-r from-gray-500/20 to-slate-500/20 border border-gray-500/30 text-gray-300";
    }
  };

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

  return (
    <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
      <div className="container mx-auto px-4">
        <div className="max-w-6xl mx-auto">
          {/* Header */}
          <div className="text-center mb-8 sm:mb-12">
            <h1 className="text-3xl sm:text-4xl lg:text-5xl font-livvic font-bold mb-3 sm:mb-4">
              Discover Events
            </h1>
            <p className="text-white/80 text-base sm:text-lg lg:text-xl max-w-2xl mx-auto font-open-sans">
              Browse and join exciting events in your area
            </p>
          </div>

          {/* Search Bar */}
          <div className="mb-8">
            <div className="relative max-w-md mx-auto">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-white/40" />
              <input
                type="text"
                placeholder="Search events or organizers..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-white/40 focus:outline-none focus:ring-2 focus:ring-primary"
              />
            </div>
          </div>

          {/* Loading State */}
          {loading && (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 sm:gap-8">
              {Array.from({ length: 6 }).map((_, index) => (
                <EventCardSkeleton key={index} />
              ))}
            </div>
          )}

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
                        className={`text-sm font-medium px-3 py-1.5 rounded-full inline-flex items-center justify-center shadow-sm backdrop-blur-sm ${getStatusColor(
                          event.state
                        )}`}
                      >
                        {getStatusText(event.state)}
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
                    {currentAccount ? (
                      event.isOrganizer ? (
                        <Button
                          variant="outline"
                          size="sm"
                          className="w-full"
                          disabled
                        >
                          You're the Organizer
                        </Button>
                      ) : event.isRegistered ? (
                        <>
                          {/* Show different buttons based on attendance state */}
                          {event.attendanceState === 1 ? (
                            <>
                              <Button
                                variant="outline"
                                size="sm"
                                className="w-full"
                              >
                                <QrCode className="mr-2 h-4 w-4" />✓ Checked In
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
                          ) : event.attendanceState === 2 ? (
                            <Button
                              variant="outline"
                              size="sm"
                              className="w-full"
                            >
                              ✓ Completed
                            </Button>
                          ) : (
                            <Button
                              variant="outline"
                              size="sm"
                              className="w-full"
                            >
                              ✓ Registered
                            </Button>
                          )}
                        </>
                      ) : (
                        <Button
                          size="sm"
                          className="w-full"
                          onClick={() => navigate(`/event/${event.id}`)}
                        >
                          Register Now
                        </Button>
                      )
                    ) : (
                      <Button size="sm" className="w-full" disabled>
                        Connect Wallet to Register
                      </Button>
                    )}

                    <Button
                      variant="ghost"
                      size="sm"
                      className="w-full"
                      onClick={() => navigate(`/event/${event.id}`)}
                    >
                      View Details
                    </Button>
                  </div>
                </Card>
              ))}
            </div>
          )}

          {/* Empty State */}
          {filteredEvents.length === 0 && !loading && (
            <div className="text-center py-12 sm:py-16">
              <div className="mb-6">
                <Calendar className="h-16 w-16 mx-auto text-white/30" />
              </div>
              <h3 className="text-xl font-semibold mb-2 text-white/70">
                No events found
              </h3>
              <p className="text-white/50 mb-6 max-w-md mx-auto">
                {searchTerm
                  ? "Try adjusting your search terms"
                  : "Check back later for new events"}
              </p>
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
              <span className="text-white/60 text-sm">
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
        </div>
      </div>

      {/* Success Modal */}
      {showSuccessModal && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center z-50">
          <div
            onClick={() => setShowSuccessModal(false)}
            className="bg-white rounded-lg p-8 max-w-sm mx-4 shadow-lg"
          >
            <h3 className="text-xl font-semibold text-green-600 mb-4">
              Success
            </h3>
            <p className="text-gray-800 mb-6">{successMessage}</p>
            <Button
              onClick={() => setShowSuccessModal(false)}
              className="w-full"
            >
              Close
            </Button>
          </div>
        </div>
      )}
    </div>
  );
};

export default Events;
