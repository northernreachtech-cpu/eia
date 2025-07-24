import { useEffect, useState } from "react";
import {
  Target,
  Users,
  Star,
  Calendar,
  DollarSign,
  Plus,
  Eye,
  //Loader2,
} from "lucide-react";
import Card from "../components/Card";
import StatCard from "../components/StatCard";
//import RatingStars from "../components/RatingStars";
import useScrollToTop from "../hooks/useScrollToTop";
import { useAriyaSDK, EscrowSettlementSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import Button from "../components/Button";
import { useNavigate } from "react-router-dom";

// Skeleton loader components
const AvailableEventSkeleton = () => (
  <Card className="p-4 sm:p-6 animate-pulse">
    <div className="flex items-start justify-between mb-4">
      <div className="flex-1">
        <div className="h-6 bg-white/10 rounded mb-2 w-3/4"></div>
        <div className="h-4 bg-white/10 rounded w-full mb-2"></div>
        <div className="flex items-center gap-2 mb-2">
          <div className="h-5 bg-white/10 rounded w-16"></div>
          <div className="h-4 bg-white/10 rounded w-32"></div>
        </div>
      </div>
    </div>

    <div className="space-y-2 mb-4">
      <div className="flex items-center">
        <div className="h-4 w-4 bg-white/10 rounded mr-2"></div>
        <div className="h-4 bg-white/10 rounded w-20"></div>
      </div>
      <div className="flex items-center">
        <div className="h-4 w-4 bg-white/10 rounded mr-2"></div>
        <div className="h-4 bg-white/10 rounded w-24"></div>
      </div>
    </div>

    <div className="flex gap-2">
      <div className="h-8 bg-white/10 rounded flex-1"></div>
      <div className="h-8 bg-white/10 rounded flex-1"></div>
    </div>
  </Card>
);

const SponsoredEventSkeleton = () => (
  <Card className="p-4 sm:p-6 animate-pulse">
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div className="flex flex-col justify-between">
        <div className="mb-4">
          <div className="h-6 bg-white/10 rounded mb-2 w-3/4"></div>
          <div className="h-4 bg-white/10 rounded w-full mb-3"></div>
          <div className="flex items-center gap-2 mb-3">
            <div className="h-5 bg-white/10 rounded w-16"></div>
            <div className="h-4 bg-white/10 rounded w-20"></div>
          </div>
        </div>
        <div className="bg-white/5 rounded-lg p-3">
          <div className="h-3 bg-white/10 rounded w-24 mb-1"></div>
          <div className="h-5 bg-white/10 rounded w-20"></div>
        </div>
      </div>
      <div className="space-y-4">
        <div>
          <div className="flex items-center justify-between mb-2">
            <div className="h-4 bg-white/10 rounded w-16"></div>
            <div className="h-4 bg-white/10 rounded w-12"></div>
          </div>
          <div className="w-full bg-white/10 rounded-full h-2"></div>
        </div>
        <div>
          <div className="flex items-center justify-between mb-2">
            <div className="h-4 bg-white/10 rounded w-20"></div>
            <div className="h-4 bg-white/10 rounded w-16"></div>
          </div>
          <div className="w-full bg-white/10 rounded-full h-2"></div>
        </div>
        <div>
          <div className="flex items-center justify-between mb-2">
            <div className="h-4 bg-white/10 rounded w-24"></div>
            <div className="h-4 bg-white/10 rounded w-12"></div>
          </div>
          <div className="w-full bg-white/10 rounded-full h-2"></div>
        </div>
        <div className="h-8 bg-white/10 rounded"></div>
      </div>
    </div>
  </Card>
);

const SponsorDashboard = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const sdk = useAriyaSDK();
  const [escrowSDK, setEscrowSDK] = useState<EscrowSettlementSDK | null>(null);
  const escrowRegistryId = useNetworkVariable("escrowRegistryId");
  const [sponsoredEvents, setSponsoredEvents] = useState<any[]>([]);
  const [availableEvents, setAvailableEvents] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [_globalStats, setGlobalStats] = useState<any>(null);

  useEffect(() => {
    setEscrowSDK(new EscrowSettlementSDK(sdk.eventManagement.getPackageId()));
  }, [sdk]);

  useEffect(() => {
    const fetchSponsorData = async () => {
      if (!escrowSDK || !escrowRegistryId) return;
      setLoading(true);
      try {
        // Get all events
        const allEvents = await sdk.eventManagement.getActiveEvents();
        const sponsored: any[] = [];
        const available: any[] = [];

        for (const event of allEvents) {
          const escrow = await escrowSDK.getEscrowDetails(
            event.id,
            escrowRegistryId
          );

          if (escrow && escrow.sponsor !== "0x0") {
            // Event is already sponsored
            const settlement = await escrowSDK.getSettlementResult(
              event.id,
              escrowRegistryId
            );
            sponsored.push({
              ...event,
              escrow,
              settlement,
            });
          } else {
            // Event can be sponsored (no escrow exists yet)
            available.push({
              ...event,
              escrow: null,
            });
          }
        }

        setSponsoredEvents(sponsored);
        setAvailableEvents(available);
        const stats = await escrowSDK.getGlobalStats(escrowRegistryId);
        setGlobalStats(stats);
      } catch (e) {
        console.error("Error fetching sponsor data:", e);
        setSponsoredEvents([]);
        setAvailableEvents([]);
      } finally {
        setLoading(false);
      }
    };
    fetchSponsorData();
  }, [escrowSDK, escrowRegistryId, sdk.eventManagement]);

  // Stats calculations
  const totalSponsored = sponsoredEvents.reduce(
    (sum, event) => sum + (event.escrow?.balance || 0),
    0
  );
  const totalCheckIns = sponsoredEvents.reduce(
    (sum, event) => sum + (event.settlement?.attendees_actual || 0),
    0
  );
  const avgRating =
    sponsoredEvents
      .filter((e) => e.settlement?.avg_rating_actual > 0)
      .reduce(
        (sum, event) => sum + (event.settlement?.avg_rating_actual || 0),
        0
      ) /
    (sponsoredEvents.filter((e) => e.settlement?.avg_rating_actual > 0)
      .length || 1);
  const completedEvents = sponsoredEvents.filter(
    (e) => e.escrow?.settled
  ).length;

  const getStatusColor = (settled: boolean) => {
    if (settled) return "text-blue-400 bg-blue-400/20";
    return "text-green-400 bg-green-400/20";
  };

  const getProgressColor = (actual: number, target: number) => {
    const percentage = (actual / target) * 100;
    if (percentage >= 100) return "from-green-400 to-green-600";
    if (percentage >= 75) return "from-yellow-400 to-yellow-600";
    return "from-primary to-secondary";
  };

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

  const getEventStateText = (state: number) => {
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

  const getEventStateColor = (state: number) => {
    switch (state) {
      case 0:
        return "text-yellow-400 bg-yellow-400/20";
      case 1:
        return "text-green-400 bg-green-400/20";
      case 2:
        return "text-blue-400 bg-blue-400/20";
      case 3:
        return "text-gray-400 bg-gray-400/20";
      default:
        return "text-white/60 bg-white/10";
    }
  };

  const getEventStateDescription = (state: number) => {
    switch (state) {
      case 0:
        return "Event created, ready for sponsorship";
      case 1:
        return "Event is active and running";
      case 2:
        return "Event completed, can still be sponsored";
      case 3:
        return "Event fully settled";
      default:
        return "Unknown state";
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-black">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-8 sm:pb-12">
        {/* Header */}
        <div className="mb-6 sm:mb-8">
          <h1 className="text-3xl sm:text-4xl font-livvic font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text mb-2">
            Sponsor Dashboard
          </h1>
          <p className="text-white/60 text-sm sm:text-base font-open-sans">
            Fund events and track your sponsorships
          </p>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-6 sm:mb-8">
          <StatCard
            title="Total Sponsored"
            value={`${(totalSponsored / 1e9).toFixed(2)} SUI`}
            icon={DollarSign}
            color="primary"
            description="Total funds committed"
          />
          <StatCard
            title="Total Check-ins"
            value={totalCheckIns}
            icon={Users}
            color="secondary"
            description="Across all events"
          />
          <StatCard
            title="Average Rating"
            value={avgRating ? avgRating.toFixed(1) : "0.0"}
            icon={Star}
            color="accent"
            description="Event feedback"
          />
          <StatCard
            title="Completed Events"
            value={completedEvents}
            icon={Calendar}
            color="success"
            description="Settled sponsorships"
          />
        </div>

        {/* Available Events to Sponsor */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl sm:text-2xl font-livvic font-bold text-white">
              Available Events to Sponsor
            </h2>
            <span className="text-white/60 text-sm font-open-sans">
              {loading
                ? "Loading..."
                : `${availableEvents.length} events available`}
            </span>
          </div>

          {loading ? (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 sm:gap-6">
              {Array.from({ length: 6 }).map((_, index) => (
                <AvailableEventSkeleton key={index} />
              ))}
            </div>
          ) : availableEvents.length === 0 ? (
            <Card className="p-8 text-center">
              <Calendar className="h-12 w-12 mx-auto text-white/30 mb-4" />
              <h3 className="text-lg font-livvic font-semibold text-white/70 mb-2">
                No events available for sponsorship
              </h3>
              <p className="text-white/50 font-open-sans">
                All events are either already sponsored or completed.
              </p>
            </Card>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 sm:gap-6">
              {availableEvents.map((event) => (
                <Card
                  key={event.id}
                  className="p-4 sm:p-6 hover:shadow-lg hover:shadow-primary/5 transition-all duration-300"
                >
                  <div className="flex items-start justify-between mb-4">
                    <div className="flex-1">
                      <h3 className="text-lg font-livvic font-semibold text-white mb-2">
                        {event.name}
                      </h3>
                      <p className="text-white/60 text-sm font-open-sans mb-2">
                        {event.description}
                      </p>
                      <div className="flex items-center gap-2 mb-2">
                        <span
                          className={`inline-block px-2 py-1 rounded-full text-xs font-medium ${getEventStateColor(
                            event.state
                          )}`}
                        >
                          {getEventStateText(event.state)}
                        </span>
                        <span className="text-white/50 text-xs font-open-sans">
                          {getEventStateDescription(event.state)}
                        </span>
                      </div>
                    </div>
                  </div>

                  <div className="space-y-2 mb-4 font-open-sans">
                    <div className="flex items-center text-white/70 text-sm">
                      <Calendar className="mr-2 h-4 w-4 flex-shrink-0" />
                      <span>{formatDate(event.start_time)}</span>
                    </div>
                    <div className="flex items-center text-white/70 text-sm">
                      <Users className="mr-2 h-4 w-4 flex-shrink-0" />
                      <span>Capacity: {event.capacity}</span>
                    </div>
                  </div>

                  <div className="flex gap-2">
                    <Button
                      size="sm"
                      className="flex-1"
                      onClick={() => navigate(`/event/${event.id}`)}
                    >
                      <Eye className="mr-1 h-3 w-3" />
                      View Details
                    </Button>
                    <Button
                      size="sm"
                      variant="secondary"
                      className="flex-1"
                      onClick={() => navigate(`/event/${event.id}`)}
                    >
                      <Plus className="mr-1 h-3 w-3" />
                      Sponsor
                    </Button>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </div>

        {/* Sponsored Events */}
        <div className="mb-8">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-xl sm:text-2xl font-livvic font-bold text-white">
              Your Sponsored Events
            </h2>
            <span className="text-white/60 text-sm font-open-sans">
              {loading
                ? "Loading..."
                : `${sponsoredEvents.length} events sponsored`}
            </span>
          </div>

          {loading ? (
            <div className="grid gap-4 sm:gap-6">
              {Array.from({ length: 3 }).map((_, index) => (
                <SponsoredEventSkeleton key={index} />
              ))}
            </div>
          ) : sponsoredEvents.length === 0 ? (
            <Card className="p-8 text-center">
              <Target className="h-12 w-12 mx-auto text-white/30 mb-4" />
              <h3 className="text-lg font-livvic font-semibold text-white/70 mb-2">
                No sponsored events yet
              </h3>
              <p className="text-white/50 font-open-sans mb-4">
                Start sponsoring events to see them here.
              </p>
              <Button onClick={() => navigate("/events")}>Browse Events</Button>
            </Card>
          ) : (
            <div className="grid gap-4 sm:gap-6">
              {sponsoredEvents.map((event) => (
                <Card
                  key={event.id}
                  className="p-4 sm:p-6 hover:shadow-lg hover:shadow-primary/5 transition-all duration-300"
                >
                  <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    {/* Event Info */}
                    <div className="flex flex-col justify-between">
                      <div className="mb-4">
                        <h3 className="text-lg sm:text-xl font-livvic font-semibold text-white mb-2">
                          {event.name}
                        </h3>
                        <p className="text-white/60 text-sm font-open-sans mb-3">
                          {event.description}
                        </p>
                        <div className="flex items-center gap-2 mb-3">
                          <span
                            className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(
                              event.escrow?.settled || false
                            )}`}
                          >
                            {event.escrow?.settled ? "Settled" : "Active"}
                          </span>
                          <span className="text-white/60 text-sm font-open-sans">
                            {formatDate(event.start_time)}
                          </span>
                        </div>
                      </div>

                      {/* Sponsorship Amount */}
                      <div className="bg-white/5 rounded-lg p-3">
                        <div className="text-xs text-white/60 font-open-sans mb-1">
                          Sponsored Amount
                        </div>
                        <div className="text-lg font-livvic font-bold text-primary">
                          {(event.escrow?.balance / 1e9).toFixed(2)} SUI
                        </div>
                      </div>
                    </div>

                    {/* Progress Metrics */}
                    <div className="space-y-4">
                      {event.settlement && (
                        <>
                          {/* Attendees Progress */}
                          <div>
                            <div className="flex items-center justify-between mb-2">
                              <span className="text-sm text-white/70 font-open-sans">
                                Attendees
                              </span>
                              <span className="text-sm text-white font-open-sans">
                                {event.settlement.attendees_actual} /{" "}
                                {event.settlement.attendees_required}
                              </span>
                            </div>
                            <div className="w-full bg-white/10 rounded-full h-2">
                              <div
                                className={`bg-gradient-to-r h-2 rounded-full transition-all duration-500 ${getProgressColor(
                                  event.settlement.attendees_actual,
                                  event.settlement.attendees_required
                                )}`}
                                style={{
                                  width: `${Math.min(
                                    (event.settlement.attendees_actual /
                                      event.settlement.attendees_required) *
                                      100,
                                    100
                                  )}%`,
                                }}
                              ></div>
                            </div>
                          </div>

                          {/* Completion Rate Progress */}
                          <div>
                            <div className="flex items-center justify-between mb-2">
                              <span className="text-sm text-white/70 font-open-sans">
                                Completion Rate
                              </span>
                              <span className="text-sm text-white font-open-sans">
                                {event.settlement.completion_rate_actual}% /{" "}
                                {event.settlement.completion_rate_required}%
                              </span>
                            </div>
                            <div className="w-full bg-white/10 rounded-full h-2">
                              <div
                                className={`bg-gradient-to-r h-2 rounded-full transition-all duration-500 ${getProgressColor(
                                  event.settlement.completion_rate_actual,
                                  event.settlement.completion_rate_required
                                )}`}
                                style={{
                                  width: `${Math.min(
                                    (event.settlement.completion_rate_actual /
                                      event.settlement
                                        .completion_rate_required) *
                                      100,
                                    100
                                  )}%`,
                                }}
                              ></div>
                            </div>
                          </div>

                          {/* Rating Progress */}
                          <div>
                            <div className="flex items-center justify-between mb-2">
                              <span className="text-sm text-white/70 font-open-sans">
                                Average Rating
                              </span>
                              <span className="text-sm text-white font-open-sans">
                                {event.settlement.avg_rating_actual} /{" "}
                                {event.settlement.avg_rating_required}
                              </span>
                            </div>
                            <div className="w-full bg-white/10 rounded-full h-2">
                              <div
                                className={`bg-gradient-to-r h-2 rounded-full transition-all duration-500 ${getProgressColor(
                                  event.settlement.avg_rating_actual,
                                  event.settlement.avg_rating_required
                                )}`}
                                style={{
                                  width: `${Math.min(
                                    (event.settlement.avg_rating_actual /
                                      event.settlement.avg_rating_required) *
                                      100,
                                    100
                                  )}%`,
                                }}
                              ></div>
                            </div>
                          </div>
                        </>
                      )}

                      {/* Action Buttons */}
                      <div className="flex gap-2 pt-2">
                        <Button
                          size="sm"
                          variant="outline"
                          className="flex-1"
                          onClick={() => navigate(`/event/${event.id}`)}
                        >
                          <Eye className="mr-1 h-3 w-3" />
                          View Event
                        </Button>
                      </div>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default SponsorDashboard;
