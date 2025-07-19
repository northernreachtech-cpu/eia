import { useState, useEffect } from "react";
import { useParams } from "react-router-dom";
import {
  Calendar,
  MapPin,
  Users,
  QrCode,
  Share2,
  //   Trophy,
  //   Star,
  Loader2,
} from "lucide-react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useEIAProtocolSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import Card from "../components/Card";
import Button from "../components/Button";
import QRDisplay from "../components/QRDisplay";
import useScrollToTop from "../hooks/useScrollToTop";

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

const EventDetails = () => {
  useScrollToTop();
  const { id } = useParams();
  const currentAccount = useCurrentAccount();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const sdk = useEIAProtocolSDK();
  const registrationRegistryId = useNetworkVariable("registrationRegistryId");

  const [event, setEvent] = useState<EventData | null>(null);
  const [loading, setLoading] = useState(true);
  const [isRegistered, setIsRegistered] = useState(false);
  const [registering, setRegistering] = useState(false);
  const [showQR, setShowQR] = useState(false);
  const [qrData, setQrData] = useState("");

  useEffect(() => {
    const loadEvent = async () => {
      if (!id) return;

      try {
        setLoading(true);
        const eventData = await sdk.eventManagement.getEvent(id);
        setEvent(eventData);

        // Check if user is registered
        if (currentAccount && eventData) {
          const registration = await sdk.identityAccess.getRegistrationStatus(
            id,
            currentAccount.address,
            registrationRegistryId
          );
          setIsRegistered(!!registration);
        }
      } catch (error) {
        console.error("Error loading event:", error);
      } finally {
        setLoading(false);
      }
    };

    loadEvent();
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
      const tx = sdk.identityAccess.registerForEvent(
        event.id,
        registrationRegistryId
      );

      // Execute transaction using dApp-kit
      await signAndExecute({
        transaction: tx,
      });

      setIsRegistered(true);
    } catch (error: any) {
      console.error("Error registering for event:", error);

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
    <div className="min-h-screen bg-black pt-16">
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
            <h1 className="text-4xl md:text-6xl font-satoshi font-bold mb-4">
              {event.name}
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

      <div className="container mx-auto px-4 py-8">
        <div className="grid lg:grid-cols-3 gap-8">
          {/* Main Content */}
          <div className="lg:col-span-2 space-y-8">
            {/* About Section */}
            <Card className="p-6">
              <h2 className="text-2xl font-semibold mb-4">About This Event</h2>
              <p className="text-white/80 leading-relaxed">
                {event.description}
              </p>
            </Card>

            {/* Organizer Section */}
            <Card className="p-6">
              <h2 className="text-2xl font-semibold mb-4">Event Organizer</h2>
              <div className="flex items-center">
                <div className="w-16 h-16 rounded-full bg-gradient-to-r from-primary to-secondary flex items-center justify-center text-white font-bold text-lg mr-4">
                  {event.organizer.charAt(0).toUpperCase()}
                </div>
                <div className="flex-1">
                  <h3 className="text-lg font-medium">Organizer</h3>
                  <p className="text-white/60 text-sm">{event.organizer}</p>
                </div>
                <Button variant="outline" size="sm">
                  View Profile
                </Button>
              </div>
            </Card>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Action Card */}
            <Card className="p-6">
              <div className="text-center mb-6">
                <div className="text-3xl font-bold text-primary mb-1">
                  {event.current_attendees}
                </div>
                <div className="text-white/60">attending</div>
              </div>

              <div className="space-y-3 mb-6">
                {!currentAccount ? (
                  <Button size="lg" className="w-full" disabled>
                    <Users className="mr-2 h-5 w-5" />
                    Connect Wallet to Register
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
                    <Button size="lg" className="w-full" onClick={handleShowQR}>
                      <QrCode className="mr-2 h-5 w-5" />
                      Show QR Code
                    </Button>
                    <div className="text-center text-sm text-green-400">
                      ✓ You're registered for this event
                    </div>
                  </div>
                )}

                <Button variant="outline" size="lg" className="w-full">
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
            <Card className="p-6">
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
    </div>
  );
};

export default EventDetails;
