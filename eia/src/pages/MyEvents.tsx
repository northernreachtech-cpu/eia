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
} from "lucide-react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { useEIAProtocolSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import Card from "../components/Card";
import Button from "../components/Button";
// import EventCard from "../components/EventCard";
import QRDisplay from "../components/QRDisplay";
import useScrollToTop from "../hooks/useScrollToTop";

const MyEvents = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const sdk = useEIAProtocolSDK();
  const registrationRegistryId = useNetworkVariable("registrationRegistryId");

  const [activeTab, setActiveTab] = useState("attending");
  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showQR, setShowQR] = useState(false);
  const [selectedEvent, setSelectedEvent] = useState<any>(null);
  const [qrData, setQrData] = useState("");

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

  useEffect(() => {
    const loadEvents = async () => {
      if (!currentAccount) return;

      try {
        setLoading(true);
        let eventList: any[] = [];

        if (activeTab === "attending") {
          // Get all events and filter by registration status
          const allEvents = await sdk.eventManagement.getActiveEvents();
          const eventsWithRegistration = await Promise.all(
            allEvents.map(async (event) => {
              const registration =
                await sdk.identityAccess.getRegistrationStatus(
                  event.id,
                  currentAccount.address,
                  registrationRegistryId
                );
              return {
                ...event,
                isRegistered: !!registration,
              };
            })
          );
          eventList = eventsWithRegistration.filter(
            (event) => event.isRegistered
          );
        } else if (activeTab === "completed") {
          // Get completed events (state = 2)
          const allEvents = await sdk.eventManagement.getActiveEvents();
          const completedEvents = allEvents.filter(
            (event) => event.state === 2
          );
          const eventsWithRegistration = await Promise.all(
            completedEvents.map(async (event) => {
              const registration =
                await sdk.identityAccess.getRegistrationStatus(
                  event.id,
                  currentAccount.address,
                  registrationRegistryId
                );
              return {
                ...event,
                isRegistered: !!registration,
              };
            })
          );
          eventList = eventsWithRegistration.filter(
            (event) => event.isRegistered
          );
        }

        setEvents(eventList);
      } catch (error) {
        console.error("Error loading events:", error);
      } finally {
        setLoading(false);
      }
    };

    loadEvents();
  }, [currentAccount, activeTab, sdk, registrationRegistryId]);

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
            <h1 className="text-3xl sm:text-4xl lg:text-5xl font-satoshi font-bold mb-3 sm:mb-4">
              My Events
            </h1>
            <p className="text-white/80 text-base sm:text-lg lg:text-xl max-w-2xl mx-auto">
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
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 sm:gap-8">
            {events.map((event) => (
              <Card key={event.id} hover className="p-6 sm:p-8">
                <div className="flex items-start justify-between mb-4 sm:mb-6">
                  <div className="flex-1">
                    <h3 className="text-lg sm:text-xl font-semibold mb-2">
                      {event.name}
                    </h3>
                    <p
                      className={`text-sm font-medium ${getStatusColor(
                        event.state
                      )}`}
                    >
                      {getStatusText(event.state)}
                    </p>
                    <span className="text-xs text-green-400">✓ Registered</span>
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
                  {event.state === 1 && (
                    <Button
                      size="sm"
                      className="w-full"
                      onClick={() => handleShowQR(event)}
                    >
                      <QrCode className="mr-2 h-4 w-4" />
                      Show QR Code
                    </Button>
                  )}

                  {event.state === 2 && (
                    <Button variant="outline" size="sm" className="w-full">
                      <Trophy className="mr-2 h-4 w-4" />
                      View NFT
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
          {events.length === 0 && !loading && (
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
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto"></div>
              <p className="text-white/60 mt-4">Loading your events...</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default MyEvents;
