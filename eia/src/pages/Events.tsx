import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { Calendar, Users, Search } from "lucide-react";
import { useCurrentAccount } from "@mysten/dapp-kit";
import { useEIAProtocolSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import Card from "../components/Card";
import Button from "../components/Button";
// import EventCard from "../components/EventCard";
import useScrollToTop from "../hooks/useScrollToTop";

const Events = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const sdk = useEIAProtocolSDK();
  const registrationRegistryId = useNetworkVariable("registrationRegistryId");

  const [events, setEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  useEffect(() => {
    const loadEvents = async () => {
      try {
        setLoading(true);
        const allEvents = await sdk.eventManagement.getActiveEvents();

        // Add registration status for current user if connected
        if (currentAccount) {
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
          setEvents(eventsWithRegistration);
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
  }, [currentAccount, sdk, registrationRegistryId]);

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

  return (
    <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
      <div className="container mx-auto px-4">
        <div className="max-w-6xl mx-auto">
          {/* Header */}
          <div className="text-center mb-8 sm:mb-12">
            <h1 className="text-3xl sm:text-4xl lg:text-5xl font-satoshi font-bold mb-3 sm:mb-4">
              Discover Events
            </h1>
            <p className="text-white/80 text-base sm:text-lg lg:text-xl max-w-2xl mx-auto">
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

          {/* Events Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 sm:gap-8">
            {filteredEvents.map((event) => (
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
                    {event.isRegistered && (
                      <span className="text-xs text-green-400">
                        ✓ Registered
                      </span>
                    )}
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
                    event.isRegistered ? (
                      <Button variant="outline" size="sm" className="w-full">
                        ✓ Registered
                      </Button>
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

          {/* Loading State */}
          {loading && (
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto"></div>
              <p className="text-white/60 mt-4">Loading events...</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Events;
