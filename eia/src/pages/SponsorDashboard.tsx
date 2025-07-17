import { useState } from "react";
import {
  Target,
  Users,
  Star,
  Calendar,
  DollarSign,
} from "lucide-react";
import Card from "../components/Card";
import StatCard from "../components/StatCard";
import RatingStars from "../components/RatingStars";
import useScrollToTop from "../hooks/useScrollToTop";

interface SponsoredEvent {
  id: string;
  title: string;
  targetCheckIns: number;
  actualCheckIns: number;
  targetRating: number;
  actualRating: number;
  sponsorAmount: number;
  status: "pending" | "active" | "completed";
  date: string;
}

const SponsorDashboard = () => {
  useScrollToTop();

  const [sponsoredEvents] = useState<SponsoredEvent[]>([
    {
      id: "1",
      title: "Web3 Developer Conference 2024",
      targetCheckIns: 100,
      actualCheckIns: 145,
      targetRating: 4.0,
      actualRating: 4.8,
      sponsorAmount: 5000,
      status: "active",
      date: "2024-02-15",
    },
    {
      id: "2",
      title: "Blockchain Workshop Series",
      targetCheckIns: 80,
      actualCheckIns: 89,
      targetRating: 4.0,
      actualRating: 4.6,
      sponsorAmount: 3000,
      status: "completed",
      date: "2024-01-20",
    },
    {
      id: "3",
      title: "DeFi Summit 2024",
      targetCheckIns: 200,
      actualCheckIns: 0,
      targetRating: 4.5,
      actualRating: 0,
      sponsorAmount: 8000,
      status: "pending",
      date: "2024-03-10",
    },
  ]);

  const totalSponsored = sponsoredEvents.reduce(
    (sum, event) => sum + event.sponsorAmount,
    0
  );
  const totalCheckIns = sponsoredEvents.reduce(
    (sum, event) => sum + event.actualCheckIns,
    0
  );
  const avgRating =
    sponsoredEvents
      .filter((e) => e.actualRating > 0)
      .reduce((sum, event) => sum + event.actualRating, 0) /
    sponsoredEvents.filter((e) => e.actualRating > 0).length;
  const completedEvents = sponsoredEvents.filter(
    (e) => e.status === "completed"
  ).length;

  const getStatusColor = (status: string) => {
    switch (status) {
      case "active":
        return "text-green-400 bg-green-400/20";
      case "completed":
        return "text-blue-400 bg-blue-400/20";
      case "pending":
        return "text-yellow-400 bg-yellow-400/20";
      default:
        return "text-white/60 bg-white/10";
    }
  };

  const getProgressColor = (actual: number, target: number) => {
    const percentage = (actual / target) * 100;
    if (percentage >= 100) return "from-green-400 to-green-600";
    if (percentage >= 75) return "from-yellow-400 to-yellow-600";
    return "from-primary to-secondary";
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-black">
      <div className="container mx-auto px-4 sm:px-6 lg:px-8 pt-24 pb-8 sm:pb-12">
        {/* Header with improved responsive design */}
        <div className="mb-6 sm:mb-8">
          <h1 className="text-3xl sm:text-4xl font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text mb-2">
            Sponsor Dashboard
          </h1>
          <p className="text-white/60 text-sm sm:text-base">
            Track your sponsored events performance and ROI
          </p>
        </div>

        {/* Stats Overview with improved grid layout */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6 mb-6 sm:mb-8">
          <StatCard
            title="Total Sponsored"
            value={`$${totalSponsored.toLocaleString()}`}
            icon={DollarSign}
            color="accent"
            description="Investment amount"
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
            color="success"
            description="Event satisfaction"
          />
          <StatCard
            title="Completed Events"
            value={completedEvents}
            icon={Calendar}
            color="primary"
            description="Successfully completed"
          />
        </div>

        {/* Sponsored Events with improved spacing */}
        <div className="mb-6 sm:mb-8">
          <h2 className="text-xl sm:text-2xl font-bold text-white mb-4 sm:mb-6">
            Sponsored Events
          </h2>

          <div className="grid gap-4 sm:gap-6">
            {sponsoredEvents.map((event) => (
              <Card key={event.id} className="p-6">
                <div className="flex flex-col lg:flex-row lg:items-center gap-6">
                  {/* Event Info */}
                  <div className="flex-1">
                    <div className="flex items-start justify-between mb-4">
                      <div>
                        <h3 className="text-xl font-semibold text-white mb-2">
                          {event.title}
                        </h3>
                        <p className="text-white/60 text-sm">
                          {new Date(event.date).toLocaleDateString()}
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

                    {/* KPI Progress - Check-ins */}
                    <div className="mb-4">
                      <div className="flex items-center justify-between mb-2">
                        <span className="text-sm text-white/70 flex items-center">
                          <Target className="h-4 w-4 mr-1" />
                          Check-in Target
                        </span>
                        <span className="text-sm text-white">
                          {event.actualCheckIns} / {event.targetCheckIns}
                        </span>
                      </div>
                      <div className="w-full bg-white/10 rounded-full h-2">
                        <div
                          className={`bg-gradient-to-r ${getProgressColor(
                            event.actualCheckIns,
                            event.targetCheckIns
                          )} h-2 rounded-full transition-all duration-500`}
                          style={{
                            width: `${Math.min(
                              (event.actualCheckIns / event.targetCheckIns) *
                                100,
                              100
                            )}%`,
                          }}
                        ></div>
                      </div>
                      <p className="text-xs text-white/60 mt-1">
                        {event.actualCheckIns >= event.targetCheckIns
                          ? `🎉 Target exceeded by ${Math.round(
                              ((event.actualCheckIns - event.targetCheckIns) /
                                event.targetCheckIns) *
                                100
                            )}%`
                          : `${Math.round(
                              (event.actualCheckIns / event.targetCheckIns) *
                                100
                            )}% of target reached`}
                      </p>
                    </div>

                    {/* KPI Progress - Rating */}
                    {event.actualRating > 0 && (
                      <div className="mb-4">
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-sm text-white/70 flex items-center">
                            <Star className="h-4 w-4 mr-1" />
                            Rating Target
                          </span>
                          <span className="text-sm text-white">
                            {event.actualRating.toFixed(1)} /{" "}
                            {event.targetRating.toFixed(1)}
                          </span>
                        </div>
                        <div className="flex items-center gap-3">
                          <div className="flex-1">
                            <div className="w-full bg-white/10 rounded-full h-2">
                              <div
                                className={`bg-gradient-to-r ${
                                  event.actualRating >= event.targetRating
                                    ? "from-green-400 to-green-600"
                                    : "from-yellow-400 to-yellow-600"
                                } h-2 rounded-full transition-all duration-500`}
                                style={{
                                  width: `${Math.min(
                                    (event.actualRating / 5) * 100,
                                    100
                                  )}%`,
                                }}
                              ></div>
                            </div>
                          </div>
                          <RatingStars rating={event.actualRating} size="sm" />
                        </div>
                      </div>
                    )}
                  </div>

                  {/* Sponsor Investment */}
                  <div className="lg:w-60">
                    <div className="bg-gradient-to-r from-accent/10 to-accent/20 rounded-xl p-4 border border-accent/20">
                      <div className="text-center">
                        <div className="text-xs text-white/60 mb-1">
                          Sponsored Amount
                        </div>
                        <div className="text-2xl font-bold text-accent mb-2">
                          ${event.sponsorAmount.toLocaleString()}
                        </div>

                        {event.status === "completed" && (
                          <div className="text-xs text-green-400">
                            ✓ ROI: Positive Impact
                          </div>
                        )}

                        {event.status === "active" && (
                          <div className="text-xs text-yellow-400">
                            ⏳ In Progress
                          </div>
                        )}

                        {event.status === "pending" && (
                          <div className="text-xs text-white/60">
                            📅 Upcoming
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </div>

        {/* Summary Card */}
        <Card className="p-6">
          <h3 className="text-lg font-semibold text-white mb-4">
            Sponsorship Impact Summary
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="text-center">
              <div className="text-3xl font-bold text-primary mb-2">
                {Math.round(
                  (totalCheckIns /
                    sponsoredEvents.reduce(
                      (sum, e) => sum + e.targetCheckIns,
                      0
                    )) *
                    100
                )}
                %
              </div>
              <div className="text-sm text-white/60">
                Overall Target Achievement
              </div>
            </div>

            <div className="text-center">
              <div className="text-3xl font-bold text-secondary mb-2">
                {avgRating ? avgRating.toFixed(1) : "0.0"}★
              </div>
              <div className="text-sm text-white/60">Average Event Rating</div>
            </div>

            <div className="text-center">
              <div className="text-3xl font-bold text-accent mb-2">
                ${Math.round(totalSponsored / Math.max(totalCheckIns, 1))}
              </div>
              <div className="text-sm text-white/60">Cost per Check-in</div>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
};

export default SponsorDashboard;
