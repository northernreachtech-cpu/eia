import { useState } from "react";
import {
  Calendar,
  Users,
  Star,
  DollarSign,
  TrendingUp,
  Eye,
  Settings,
  Plus,
} from "lucide-react";
import { useNavigate } from "react-router-dom";
import Card from "../components/Card";
import Button from "../components/Button";
import StatCard from "../components/StatCard";
import RatingStars from "../components/RatingStars";
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
}

const OrganizerDashboard = () => {
  useScrollToTop();
  const navigate = useNavigate();

  const [events] = useState<Event[]>([
    {
      id: "1",
      title: "Web3 Developer Conference 2024",
      date: "2024-02-15",
      status: "active",
      checkedIn: 145,
      totalCapacity: 200,
      escrowStatus: "pending",
      rating: 4.8,
      revenue: 2500,
    },
    {
      id: "2",
      title: "Blockchain Workshop Series",
      date: "2024-01-20",
      status: "completed",
      checkedIn: 89,
      totalCapacity: 100,
      escrowStatus: "released",
      rating: 4.6,
      revenue: 1200,
    },
    {
      id: "3",
      title: "DeFi Summit 2024",
      date: "2024-03-10",
      status: "upcoming",
      checkedIn: 0,
      totalCapacity: 300,
      escrowStatus: "locked",
      rating: 0,
      revenue: 0,
    },
  ]);

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
            <h2 className="text-xl sm:text-2xl font-bold text-white">Your Events</h2>
            <Button variant="outline" size="sm" className="w-full sm:w-auto py-2.5 sm:py-2">
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
                            width: `${Math.min((event.checkedIn / event.totalCapacity) * 100, 100)}%`,
                          }}
                        ></div>
                      </div>
                      <p className="text-xs text-white/60 mt-1">
                        {Math.round((event.checkedIn / event.totalCapacity) * 100)}% capacity
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
                      <div className="text-xs text-white/60 mb-1">
                        Revenue
                      </div>
                      <div className="text-sm font-medium text-white">
                        ${event.revenue.toLocaleString()}
                      </div>
                    </div>

                    {/* Rating */}
                    {event.rating > 0 && (
                      <div className="col-span-2 text-center p-2 sm:p-3 rounded bg-white/5">
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

                  {/* Actions */}
                  <div className="flex gap-2 mt-4 sm:mt-6">
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
    </div>
  );
};

export default OrganizerDashboard;
