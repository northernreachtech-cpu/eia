import { useState, useEffect } from "react";
import {
  Calendar,
  Users,
  Star,
  DollarSign,
  TrendingUp,
  Eye,
  Settings,
  Plus,
  Loader2,
  Play,
  QrCode,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useEIAProtocolSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import Card from "../components/Card";
import Button from "../components/Button";
import StatCard from "../components/StatCard";
import RatingStars from "../components/RatingStars";
import QRScanner from "../components/QRScanner";
import useScrollToTop from "../hooks/useScrollToTop";

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

const OrganizerDashboard = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const sdk = useEIAProtocolSDK();
  const eventRegistryId = useNetworkVariable("eventRegistryId");
  const attendanceRegistryId = useNetworkVariable("attendanceRegistryId");
  const registrationRegistryId = useNetworkVariable("registrationRegistryId");

  const [loading, setLoading] = useState(true);
  const [activatingEvent, setActivatingEvent] = useState<string | null>(null);
  const [showQRScanner, setShowQRScanner] = useState(false);
  const [selectedEventId, setSelectedEventId] = useState<string | null>(null);
  // const [organizerProfile, setOrganizerProfile] = useState<any>(null);
  const [events, setEvents] = useState<Event[]>([]);

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
      console.error("Error activating event:", error);
      alert("Failed to activate event. Please try again.");
    } finally {
      setActivatingEvent(null);
    }
  };

  const handleCheckIn = (eventId: string) => {
    console.log("Opening QR scanner for event:", eventId);
    setSelectedEventId(eventId);
    setShowQRScanner(true);
  };

  const handleQRScan = async (qrData: any) => {
    try {
      console.log("QR data received:", qrData);

      // Check if this is the new QR format with pass_id
      if (qrData.pass_id && qrData.pass_hash === null) {
        console.log("Using new QR format with pass_id:", qrData.pass_id);

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
        console.log("Using legacy QR format");

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
      console.error("Error checking in attendee:", error);
      alert("Failed to check in attendee. Please try again.");
    }
  };

  const loadOrganizerData = async () => {
    if (!currentAccount) return;

    try {
      setLoading(true);
      console.log("Loading organizer data for:", currentAccount.address);

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
      console.log("Organizer events:", organizerEvents);

      // Transform events to match interface
      const transformedEvents = await Promise.all(
        organizerEvents.map(async (event) => {
          console.log("Processing event:", event.id, event.name);
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
      console.error("Error loading organizer data:", error);
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
            <h1 className="text-3xl sm:text-4xl font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text mb-2">
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
            <Button
              variant="outline"
              size="sm"
              className="w-full sm:w-auto py-2.5 sm:py-2"
            >
              <Settings className="mr-2 h-4 w-4" />
              Manage
            </Button>
          </div>

          <div className="grid gap-4 sm:gap-6">
            {events.map((event) => (
              <Card
                key={event.id}
                className="p-4 sm:p-6 hover:shadow-lg hover:shadow-primary/5 transition-all duration-300"
              >
                <div className="flex flex-col lg:flex-row lg:items-center gap-4 sm:gap-6">
                  {/* Event Info */}
                  <div className="flex-1">
                    <div className="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-3 mb-4">
                      <div>
                        <h3 className="text-lg sm:text-xl font-semibold text-white mb-1 sm:mb-2">
                          {event.title}
                        </h3>
                        <p className="text-white/60 text-sm">
                          {new Date(event.date).toLocaleDateString("en-US", {
                            weekday: "long",
                            year: "numeric",
                            month: "long",
                            day: "numeric",
                          })}
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
                        <span className="text-sm text-white/70">Check-ins</span>
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

                  {/* Event Stats with improved mobile layout */}
                  <div className="lg:w-80 grid grid-cols-2 gap-3 sm:gap-4 p-3 sm:p-4 rounded-lg bg-white/5">
                    {/* Escrow Status */}
                    <div className="text-center p-2 sm:p-3 rounded bg-white/5">
                      <div className="text-xs text-white/60 mb-1">Escrow</div>
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
                    <div className="text-center p-2 sm:p-3 rounded bg-white/5">
                      <div className="text-xs text-white/60 mb-1">Revenue</div>
                      <div className="text-sm font-medium text-white">
                        ${event.revenue.toLocaleString()}
                      </div>
                    </div>

                    {/* Rating */}
                    {event.rating > 0 && (
                      <div className="col-span-2 text-center p-2 sm:p-3 rounded bg-white/5">
                        <div className="text-xs text-white/60 mb-2">Rating</div>
                        <RatingStars
                          rating={event.rating}
                          size="sm"
                          showLabel
                        />
                      </div>
                    )}
                  </div>

                  {/* Actions */}
                  <div className="flex gap-2 mt-4 sm:mt-6">
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
                      <Button
                        size="sm"
                        className="flex-1"
                        onClick={() => handleCheckIn(event.id)}
                      >
                        <QrCode className="mr-1 h-3 w-3" />
                        Check-in
                      </Button>
                    )}

                    <Button
                      variant="outline"
                      size="sm"
                      className="flex-1"
                      onClick={() => navigate(`/event/${event.id}`)}
                    >
                      <Eye className="mr-1 h-3 w-3" />
                      View
                    </Button>
                    <Button variant="outline" size="sm" className="flex-1">
                      <TrendingUp className="mr-1 h-3 w-3" />
                      Analytics
                    </Button>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </div>

        {/* Quick Actions */}
        <Card className="p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Quick Actions
          </h3>
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <Button variant="outline" className="justify-start">
              <Plus className="mr-2 h-4 w-4" />
              Create Event
            </Button>
            <Button variant="outline" className="justify-start">
              <TrendingUp className="mr-2 h-4 w-4" />
              View Analytics
            </Button>
            <Button variant="outline" className="justify-start">
              <Users className="mr-2 h-4 w-4" />
              Manage Attendees
            </Button>
            <Button variant="outline" className="justify-start">
              <Settings className="mr-2 h-4 w-4" />
              Settings
            </Button>
          </div>
        </Card>
      </div>

      {/* QR Scanner Modal */}
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
    </div>
  );
};

export default OrganizerDashboard;
