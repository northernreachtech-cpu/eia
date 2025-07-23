import { useState, useEffect } from "react";
import { useParams, useLocation, useNavigate } from "react-router-dom";
import {
  Calendar,
  MapPin,
  Users,
  QrCode,
  Share2,
  Trophy,
  //   Star,
  Loader2,
} from "lucide-react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useAriyaSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import Card from "../components/Card";
import Button from "../components/Button";
import QRDisplay from "../components/QRDisplay";
import useScrollToTop from "../hooks/useScrollToTop";
// import { useMemo } from "react";
import { Transaction } from "@mysten/sui/transactions";
import { suiClient } from "../config/sui";

interface EventData {
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
  sponsor_conditions: any;
  metadata_uri: string;
}

// Attendance status text helper (copied from MyEvents)
const getAttendanceStatusText = (state: any) => {
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

const EventDetails = () => {
  useScrollToTop();
  const { id } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const sdk = useAriyaSDK();
  const registrationRegistryId = useNetworkVariable("registrationRegistryId");
  const attendanceRegistryId = useNetworkVariable("attendanceRegistryId");
  const nftRegistryId = useNetworkVariable("nftRegistryId");
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();

  // Attendance state from navigation (if available)
  const navAttendanceState = location.state?.attendanceState;
  const navHasRecord = location.state?.hasRecord;
  const navCheckInTime = location.state?.checkInTime;
  const navCheckOutTime = location.state?.checkOutTime;

  const [event, setEvent] = useState<EventData | null>(null);
  const [loading, setLoading] = useState(true);
  const [isRegistered, setIsRegistered] = useState(false);
  const [isOrganizer, setIsOrganizer] = useState(false);
  const [registering, setRegistering] = useState(false);
  const [showQR, setShowQR] = useState(false);
  const [qrData, setQrData] = useState("");
  const [attendanceState, setAttendanceState] = useState(
    navAttendanceState ?? null
  );
  const [_hasRecord, setHasRecord] = useState(navHasRecord ?? null);
  const [_checkInTime, setCheckInTime] = useState(navCheckInTime ?? null);
  const [_checkOutTime, setCheckOutTime] = useState(navCheckOutTime ?? null);
  const [hasMintedNFT, setHasMintedNFT] = useState(false); // Placeholder, should check actual mint status
  const [minting, setMinting] = useState(false);
  const [mintResult, setMintResult] = useState<{
    success: boolean;
    message: string;
  } | null>(null);
  const [showShareModal, setShowShareModal] = useState(false);
  const [shareEventLink, setShareEventLink] = useState("");

  useEffect(() => {
    const loadEvent = async () => {
      if (!id) return;

      try {
        setLoading(true);
        const eventData = await sdk.eventManagement.getEvent(id);
        setEvent(eventData);

        // Check if user is registered and if user is organizer
        if (currentAccount && eventData) {
          const [registration, organizerCheck] = await Promise.all([
            sdk.identityAccess.getRegistrationStatus(
              id,
              currentAccount.address,
              registrationRegistryId
            ),
            sdk.identityAccess.isEventOrganizer(id, currentAccount.address),
          ]);

          setIsRegistered(!!registration);
          setIsOrganizer(organizerCheck);
        }

        // Only fetch attendance state if not passed via navigation
        if (
          currentAccount &&
          (navAttendanceState === null || navAttendanceState === undefined)
        ) {
          try {
            const tx = new Transaction();
            tx.moveCall({
              target: `${sdk.attendanceVerification.getPackageId()}::attendance_verification::get_attendance_status`,
              arguments: [
                tx.pure.address(currentAccount.address),
                tx.pure.id(id),
                tx.object(attendanceRegistryId),
              ],
            });
            const result = await suiClient.devInspectTransactionBlock({
              transactionBlock: tx,
              sender: currentAccount.address,
            });
            if (result && result.results && result.results.length > 0) {
              const returnVals = result.results[0].returnValues;
              if (Array.isArray(returnVals) && returnVals.length >= 4) {
                setHasRecord(
                  Array.isArray(returnVals[0])
                    ? returnVals[0].length > 0
                    : !!returnVals[0]
                );
                setAttendanceState(
                  Array.isArray(returnVals[1])
                    ? returnVals[1][0]
                    : parseInt(returnVals[1]) || 0
                );
                setCheckInTime(
                  Array.isArray(returnVals[2])
                    ? returnVals[2][0]
                    : parseInt(returnVals[2]) || 0
                );
                setCheckOutTime(
                  Array.isArray(returnVals[3])
                    ? returnVals[3][0]
                    : parseInt(returnVals[3]) || 0
                );
              }
            }
          } catch (e) {
            setAttendanceState(0);
            setHasRecord(false);
            setCheckInTime(0);
            setCheckOutTime(0);
          }
        }
      } catch (error) {
        console.error("Error loading event:", error);
      } finally {
        setLoading(false);
      }
    };

    loadEvent();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id, currentAccount, sdk, registrationRegistryId]);

  const formatDate = (timestamp: number) => {
    return new Date(timestamp).toLocaleDateString("en-US", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
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
        return "bg-yellow-500/20 text-yellow-400";
      case 1:
        return "bg-green-500/20 text-green-400";
      case 2:
        return "bg-blue-500/20 text-blue-400";
      case 3:
        return "bg-purple-500/20 text-purple-400";
      default:
        return "bg-gray-500/20 text-gray-400";
    }
  };

  const handleRegister = async () => {
    if (!currentAccount || !event) return;

    try {
      setRegistering(true);

      // Use the new registerForEventAndGenerateQR function
      const result = await sdk.identityAccess.registerForEventAndGenerateQR(
        event.id,
        registrationRegistryId,
        currentAccount.address,
        signAndExecute
      );

      if (result) {
        console.log("User registered successfully!");
        console.log("QR Data:", result.qrData);

        // Generate QR code string for display
        const qrDataString = JSON.stringify(result.qrData);
        setQrData(qrDataString);
        setShowQR(true);
        setIsRegistered(true);
      } else {
        console.error("Failed to register for event");
        alert("Registration failed. Please try again.");
      }
    } catch (error: any) {
      console.error("Error in registration flow:", error);

      // Show user-friendly error message
      let errorMessage = "Registration failed";
      if (error.message?.includes("MoveAbort")) {
        if (error.message.includes(", 1)")) {
          errorMessage =
            "Event is not active for registration or you're already registered";
        } else if (error.message.includes(", 2)")) {
          errorMessage = "Event capacity is full";
        } else if (error.message.includes(", 3)")) {
          errorMessage = "Event not found";
        }
      }
      alert(errorMessage);
    } finally {
      setRegistering(false);
    }
  };

  const handleShowQR = async () => {
    if (!currentAccount || !event) return;

    try {
      const registration = await sdk.identityAccess.getRegistrationStatus(
        event.id,
        currentAccount.address,
        registrationRegistryId
      );

      if (registration) {
        const qrDataString = sdk.identityAccess.generateQRCodeData(
          event.id,
          currentAccount.address,
          registration
        );
        setQrData(qrDataString);
        setShowQR(true);
      }
    } catch (error) {
      console.error("Error generating QR code:", error);
    }
  };

  // Helper to check if user already has completion NFT for this event
  const checkHasCompletionNFT = async () => {
    if (!currentAccount || !event || !nftRegistryId) return false;
    try {
      // Call the Move view to check NFT ownership
      const tx = new Transaction();
      tx.moveCall({
        target: `${sdk.attendanceVerification.getPackageId()}::nft_minting::has_completion_nft`,
        arguments: [
          tx.pure.address(currentAccount.address),
          tx.pure.id(event.id),
          tx.object(nftRegistryId),
        ],
      });
      const result = await suiClient.devInspectTransactionBlock({
        transactionBlock: tx,
        sender: currentAccount.address,
      });
      if (result && result.results && result.results.length > 0) {
        const returnVals = result.results[0].returnValues;
        if (!Array.isArray(returnVals)) return false;
        let val = returnVals[0];
        // Only unwrap if val is a non-empty array and its first element is a primitive
        while (
          Array.isArray(val) &&
          val.length > 0 &&
          (typeof val[0] === "number" || typeof val[0] === "boolean")
        ) {
          val = val[0];
        }
        return (
          (typeof val === "number" || typeof val === "boolean") &&
          (val === true || val === 1)
        );
      }
    } catch (e) {}
    return false;
  };

  const handleMintCompletionNFT = async () => {
    if (!currentAccount || !event || !nftRegistryId) return;
    setMinting(true);
    setMintResult(null);
    try {
      // Check if already minted
      if (await checkHasCompletionNFT()) {
        setMintResult({
          success: false,
          message: "You have already minted this Completion NFT.",
        });
        setHasMintedNFT(true);
        setMinting(false);
        return;
      }
      await sdk.attendanceVerification.mintCompletionNFT(
        currentAccount.address,
        event.id,
        nftRegistryId,
        signAndExecute
      );
      setMintResult({
        success: true,
        message: "Completion NFT minted successfully!",
      });
      setHasMintedNFT(true);
    } catch (e: any) {
      // Show a friendlier error for EInvalidCapability
      if (e.message && e.message.includes("EInvalidCapability")) {
        setMintResult({
          success: false,
          message:
            "Mint failed: Event metadata is not set or your capability is invalid/used. Please contact the organizer or refresh your page.",
        });
      } else {
        setMintResult({
          success: false,
          message: e.message || "Minting failed",
        });
      }
    } finally {
      setMinting(false);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
        <div className="container mx-auto px-4">
          <div className="flex items-center justify-center min-h-[400px]">
            <div className="flex items-center gap-2">
              <Loader2 className="h-6 w-6 animate-spin text-primary" />
              <span className="text-white">Loading event...</span>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!event) {
    return (
      <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
        <div className="container mx-auto px-4">
          <div className="text-center py-12">
            <h2 className="text-2xl font-semibold mb-4">Event not found</h2>
            <p className="text-white/60">
              The event you're looking for doesn't exist.
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black">
      {/* Absolutely positioned back button above hero section */}
      <div className="container mx-auto px-4 pt-16">
        <button
          onClick={() => navigate(-1)}
          className="flex items-center gap-2 text-base font-semibold bg-gradient-to-r from-primary to-secondary text-white px-5 py-2 rounded-full shadow-lg border border-primary/60 hover:from-secondary hover:to-primary focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all duration-200 mb-4 w-fit"
        >
          <svg
            className="h-5 w-5"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M15 19l-7-7 7-7"
            />
          </svg>
          <span>Back</span>
        </button>
      </div>
      {/* Hero Section */}
      <div className="relative h-96 overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-r from-black/70 to-black/30 z-10" />
        <div className="relative z-20 container mx-auto px-4 h-full flex items-end pb-8">
          <div className="text-white">
            <div className="flex items-center mb-4">
              <span
                className={`px-3 py-1 rounded-full text-xs font-medium ${getStatusColor(
                  event.state
                )}`}
              >
                {getStatusText(event.state)}
              </span>
            </div>
            <h1 className="text-4xl md:text-6xl font-livvic font-bold mb-4">
              {event?.name || "Event Details"}
            </h1>
            <div className="flex flex-wrap items-center gap-6 text-white/80">
              <div className="flex items-center">
                <Calendar className="mr-2 h-5 w-5" />
                <span>
                  {formatDate(event.start_time)} at{" "}
                  {formatTime(event.start_time)}
                </span>
              </div>
              <div className="flex items-center">
                <MapPin className="mr-2 h-5 w-5" />
                <span>{event.location}</span>
              </div>
              <div className="flex items-center">
                <Users className="mr-2 h-5 w-5" />
                <span>
                  {event.current_attendees}/{event.capacity} attendees
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="container mx-auto px-4 py-6 sm:py-8">
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 lg:gap-8">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-6 sm:space-y-8">
            {/* About Section */}
            <Card className="p-4 sm:p-6">
              <h2 className="text-2xl font-semibold mb-4">About This Event</h2>
              <p className="text-white/80 leading-relaxed">
                {event.description}
              </p>
            </Card>

            {/* Organizer Section */}
            <Card className="p-4 sm:p-6">
              <h2 className="text-2xl font-semibold mb-4">Event Organizer</h2>
              <div className="flex flex-col sm:flex-row items-start sm:items-center gap-3 sm:gap-0">
                <div className="w-16 h-16 rounded-full bg-gradient-to-r from-primary to-secondary flex items-center justify-center text-white font-bold text-lg mr-0 sm:mr-4">
                  {event.organizer.charAt(0).toUpperCase()}
                </div>
                <div className="flex-1 min-w-0">
                  <h3 className="text-lg font-medium">Organizer</h3>
                  <p className="text-white/60 text-sm break-all whitespace-pre-line">
                    {event.organizer}
                  </p>
                </div>
                <Button variant="outline" size="sm" className="mt-2 sm:mt-0">
                  View Profile
                </Button>
              </div>
            </Card>
          </div>

          {/* Sidebar */}
          <div className="space-y-4 sm:space-y-6">
            {/* Action Card */}
            <Card className="p-4 sm:p-6">
              <div className="text-center mb-6">
                <div className="text-3xl font-bold text-primary mb-1">
                  {event.current_attendees}
                </div>
                <div className="text-white/60">attending</div>
                {attendanceState !== null && (
                  <div className="mt-2">
                    <span
                      className={`inline-block px-3 py-1.5 rounded-full text-xs font-medium shadow-sm backdrop-blur-sm ${
                        (Array.isArray(attendanceState)
                          ? attendanceState[0]
                          : attendanceState) === 0
                          ? "bg-gradient-to-r from-amber-500/20 to-orange-500/20 border border-amber-500/30 text-amber-300"
                          : (Array.isArray(attendanceState)
                              ? attendanceState[0]
                              : attendanceState) === 1
                          ? "bg-gradient-to-r from-emerald-500/20 to-green-500/20 border border-emerald-500/30 text-emerald-300"
                          : (Array.isArray(attendanceState)
                              ? attendanceState[0]
                              : attendanceState) === 2
                          ? "bg-gradient-to-r from-blue-500/20 to-indigo-500/20 border border-blue-500/30 text-blue-300"
                          : "bg-gradient-to-r from-gray-500/20 to-slate-500/20 border border-gray-500/30 text-gray-300"
                      }`}
                    >
                      {getAttendanceStatusText(attendanceState)}
                    </span>
                  </div>
                )}
              </div>

              <div className="space-y-3 mb-6">
                {!currentAccount ? (
                  <Button size="lg" className="w-full" disabled>
                    <Users className="mr-2 h-5 w-5" />
                    Connect Wallet to Register
                  </Button>
                ) : isOrganizer ? (
                  <Button size="lg" className="w-full" disabled>
                    <Users className="mr-2 h-5 w-5" />
                    You're the Organizer
                  </Button>
                ) : event.state !== 1 ? (
                  <Button size="lg" className="w-full" disabled>
                    <Users className="mr-2 h-5 w-5" />
                    Event Not Active
                  </Button>
                ) : !isRegistered ? (
                  <Button
                    size="lg"
                    className="w-full"
                    onClick={handleRegister}
                    disabled={registering}
                  >
                    {registering ? (
                      <>
                        <Loader2 className="mr-2 h-5 w-5 animate-spin" />
                        Registering...
                      </>
                    ) : (
                      <>
                        <Users className="mr-2 h-5 w-5" />
                        Join Event
                      </>
                    )}
                  </Button>
                ) : (
                  <div className="space-y-3">
                    {(attendanceState === 0 ||
                      attendanceState === 1 ||
                      (Array.isArray(attendanceState) &&
                        (attendanceState[0] === 0 ||
                          attendanceState[0] === 1))) && (
                      <Button
                        size="lg"
                        className="w-full"
                        onClick={handleShowQR}
                      >
                        <QrCode className="mr-2 h-5 w-5" />
                        Show QR Code
                      </Button>
                    )}
                    {(attendanceState === 2 ||
                      (Array.isArray(attendanceState) &&
                        attendanceState[0] === 2)) &&
                      !hasMintedNFT && (
                        <Button
                          variant="outline"
                          size="lg"
                          className="w-full flex items-center justify-center gap-2"
                          onClick={handleMintCompletionNFT}
                          disabled={minting}
                        >
                          <Trophy className="h-5 w-5" />
                          {minting ? "Minting..." : "Mint Completion NFT"}
                        </Button>
                      )}
                    <div className="text-center text-sm text-green-400">
                      ✓ You're registered for this event
                    </div>
                  </div>
                )}

                <Button
                  variant="outline"
                  size="lg"
                  className="w-full"
                  onClick={() => {
                    setShareEventLink(
                      window.location.origin + "/event/" + event.id
                    );
                    setShowShareModal(true);
                  }}
                >
                  <Share2 className="mr-2 h-5 w-5" />
                  Share Event
                </Button>
              </div>

              {/* Event Stats */}
              <div className="border-t border-white/10 pt-4 space-y-3">
                <div className="flex justify-between text-sm">
                  <span className="text-white/60">Event State</span>
                  <span className="font-medium">
                    {getStatusText(event.state)}
                  </span>
                </div>
                {isOrganizer && (
                  <div className="text-center text-xs text-yellow-400 bg-yellow-400/10 p-2 rounded">
                    You're the organizer of this event
                  </div>
                )}
                {!isOrganizer && event.state !== 1 && (
                  <div className="text-center text-xs text-yellow-400 bg-yellow-400/10 p-2 rounded">
                    Registration opens when event is activated
                  </div>
                )}
                <div className="flex justify-between text-sm">
                  <span className="text-white/60">Created</span>
                  <span className="font-medium">
                    {formatDate(event.created_at)}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-white/60">End Time</span>
                  <span className="font-medium">
                    {formatDate(event.end_time)}
                  </span>
                </div>
              </div>
            </Card>

            {/* Event Details */}
            <Card className="p-4 sm:p-6">
              <h3 className="text-lg font-semibold mb-4">Event Details</h3>
              <div className="space-y-4">
                <div>
                  <div className="text-white/60 text-sm mb-1">Date & Time</div>
                  <div className="font-medium">
                    {formatDate(event.start_time)}
                    <br />
                    {formatTime(event.start_time)}
                  </div>
                </div>

                <div>
                  <div className="text-white/60 text-sm mb-1">Location</div>
                  <div className="font-medium">{event.location}</div>
                </div>

                <div>
                  <div className="text-white/60 text-sm mb-1">Capacity</div>
                  <div className="font-medium">
                    {event.current_attendees} / {event.capacity} people
                  </div>
                </div>
              </div>
            </Card>
          </div>
        </div>
      </div>

      {/* QR Code Modal */}
      {showQR && event && (
        <QRDisplay
          qrData={qrData}
          eventName={event.name}
          isOpen={showQR}
          onClose={() => setShowQR(false)}
        />
      )}
      {/* Mint result modal */}
      {mintResult && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70">
          <div className="bg-white rounded-lg p-8 max-w-sm mx-4 shadow-lg text-center">
            <h3
              className={`text-xl font-semibold mb-4 ${
                mintResult.success ? "text-green-600" : "text-red-600"
              }`}
            >
              {mintResult.success ? "Success" : "Error"}
            </h3>
            <p className="text-gray-800 mb-6">{mintResult.message}</p>
            <Button onClick={() => setMintResult(null)} className="w-full">
              Close
            </Button>
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
  );
};

export default EventDetails;
