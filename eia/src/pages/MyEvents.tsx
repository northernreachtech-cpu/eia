import { useState } from "react";
import { Calendar, MapPin, Users, QrCode, Trophy } from "lucide-react";
import Card from "../components/Card";
import Button from "../components/Button";
import type { Event } from "../types";
import { useNavigate } from "react-router-dom";
import useScrollToTop from "../hooks/useScrollToTop";

const MyEvents = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<
    "hosted" | "attending" | "completed"
  >("hosted");

  // Mock data - replace with real data later
  const mockEvents: Event[] = [
    {
      id: "1",
      title: "Web3 Developer Meetup",
      description: "Monthly gathering of Web3 developers",
      location: "San Francisco, CA",
      date: new Date("2024-02-15"),
      organizerId: "user1",
      organizer: {
        id: "user1",
        walletAddress: "0x123",
        username: "DevOrganizer",
      } as any,
      status: "upcoming",
      currentAttendees: 45,
      checkInCount: 0,
      maxAttendees: 100,
    },
    {
      id: "2",
      title: "NFT Art Exhibition",
      description: "Showcase of digital art NFTs",
      location: "New York, NY",
      date: new Date("2024-01-20"),
      organizerId: "user2",
      organizer: {
        id: "user2",
        walletAddress: "0x456",
        username: "ArtCurator",
      } as any,
      status: "completed",
      currentAttendees: 80,
      checkInCount: 75,
      maxAttendees: 80,
    },
  ];

  const tabs = [
    { id: "hosted", label: "Hosted Events", icon: Users, shortLabel: "Hosted" },
    {
      id: "attending",
      label: "Attending",
      icon: Calendar,
      shortLabel: "Attending",
    },
    {
      id: "completed",
      label: "Completed",
      icon: Trophy,
      shortLabel: "Completed",
    },
  ];

  const getEventsByTab = () => {
    // In a real app, filter based on user's relationship to events
    switch (activeTab) {
      case "hosted":
        return mockEvents.filter((event) => event.status !== "completed");
      case "attending":
        return mockEvents.filter((event) => event.status === "upcoming");
      case "completed":
        return mockEvents.filter((event) => event.status === "completed");
      default:
        return [];
    }
  };

  const getStatusColor = (status: Event["status"]) => {
    switch (status) {
      case "upcoming":
        return "text-accent";
      case "ongoing":
        return "text-secondary";
      case "completed":
        return "text-primary";
      case "cancelled":
        return "text-red-400";
      default:
        return "text-white/70";
    }
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

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
              Manage your hosted events and track your attendance
            </p>
          </div>

          {/* Enhanced Tab Navigation */}
          <div className="flex justify-center mb-8 sm:mb-12">
            <div className="w-full max-w-md sm:max-w-2xl">
              {/* Mobile Tab Design */}
              <div className="sm:hidden">
                <div className="card-glass p-1 rounded-xl">
                  <div className="grid grid-cols-3 gap-1">
                    {tabs.map((tab) => {
                      const Icon = tab.icon;
                      return (
                        <button
                          key={tab.id}
                          onClick={() => setActiveTab(tab.id as any)}
                          className={`
                            relative flex flex-col items-center py-3 px-2 rounded-lg transition-all duration-300 min-h-[60px]
                            ${
                              activeTab === tab.id
                                ? "bg-gradient-to-r from-primary to-secondary text-white shadow-lg"
                                : "text-white/70 hover:text-white hover:bg-white/10"
                            }
                          `}
                        >
                          <Icon
                            className={`h-5 w-5 mb-1 transition-transform duration-300 ${
                              activeTab === tab.id ? "scale-110" : ""
                            }`}
                          />
                          <span className="text-xs font-medium leading-tight text-center">
                            {tab.shortLabel}
                          </span>
                          {/* Active indicator */}
                          {activeTab === tab.id && (
                            <div className="absolute inset-0 rounded-lg bg-gradient-to-r from-primary/20 to-secondary/20 -z-10 blur-sm"></div>
                          )}
                        </button>
                      );
                    })}
                  </div>
                </div>
              </div>

              {/* Desktop Tab Design */}
              <div className="hidden sm:block">
                <div className="card-glass p-1.5 rounded-xl">
                  <div className="flex">
                    {tabs.map((tab) => {
                      const Icon = tab.icon;
                      return (
                        <button
                          key={tab.id}
                          onClick={() => setActiveTab(tab.id as any)}
                          className={`
                            relative flex items-center justify-center px-6 lg:px-8 py-3.5 rounded-lg transition-all duration-300 flex-1 group
                            ${
                              activeTab === tab.id
                                ? "bg-gradient-to-r from-primary to-secondary text-white shadow-xl transform scale-105"
                                : "text-white/70 hover:text-white hover:bg-white/10 hover:scale-102"
                            }
                          `}
                        >
                          <Icon
                            className={`mr-2.5 h-5 w-5 transition-all duration-300 ${
                              activeTab === tab.id
                                ? "scale-110 rotate-3"
                                : "group-hover:scale-105"
                            }`}
                          />
                          <span className="font-medium text-sm lg:text-base whitespace-nowrap">
                            {tab.label}
                          </span>

                          {/* Active indicator glow */}
                          {activeTab === tab.id && (
                            <>
                              <div className="absolute inset-0 rounded-lg bg-gradient-to-r from-primary/30 to-secondary/30 -z-10 blur-md"></div>
                              <div className="absolute -inset-0.5 rounded-lg bg-gradient-to-r from-primary/20 to-secondary/20 -z-20 blur-lg"></div>
                            </>
                          )}

                          {/* Hover effect */}
                          <div className="absolute inset-0 rounded-lg bg-gradient-to-r from-primary/0 to-secondary/0 group-hover:from-primary/10 group-hover:to-secondary/10 transition-all duration-300 -z-10"></div>
                        </button>
                      );
                    })}
                  </div>
                </div>
              </div>

              {/* Tab Content Count Indicator */}
              <div className="flex justify-center mt-4">
                <div className="text-center">
                  <span className="text-sm text-white/60">
                    {getEventsByTab().length}{" "}
                    {getEventsByTab().length === 1 ? "event" : "events"}
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Events Grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 sm:gap-8">
            {getEventsByTab().map((event) => (
              <Card key={event.id} hover className="p-6 sm:p-8">
                <div className="flex items-start justify-between mb-4 sm:mb-6">
                  <div className="flex-1">
                    <h3 className="text-lg sm:text-xl font-semibold mb-2">
                      {event.title}
                    </h3>
                    <p
                      className={`text-sm font-medium ${getStatusColor(
                        event.status
                      )}`}
                    >
                      {event.status.charAt(0).toUpperCase() +
                        event.status.slice(1)}
                    </p>
                  </div>
                  <div className="text-right">
                    <div className="text-xl sm:text-2xl font-bold text-primary">
                      {event.checkInCount}
                    </div>
                    <div className="text-xs text-white/60">Check-ins</div>
                  </div>
                </div>

                <div className="space-y-3 mb-6">
                  <div className="flex items-center text-white/70">
                    <Calendar className="mr-2 h-4 w-4 flex-shrink-0" />
                    <span className="text-sm">{formatDate(event.date)}</span>
                  </div>

                  <div className="flex items-center text-white/70">
                    <MapPin className="mr-2 h-4 w-4 flex-shrink-0" />
                    <span className="text-sm truncate">{event.location}</span>
                  </div>

                  <div className="flex items-center text-white/70">
                    <Users className="mr-2 h-4 w-4 flex-shrink-0" />
                    <span className="text-sm">
                      {event.currentAttendees}
                      {event.maxAttendees && ` / ${event.maxAttendees}`}{" "}
                      attendees
                    </span>
                  </div>
                </div>

                {/* Progress Bar */}
                <div className="mb-6">
                  <div className="flex justify-between text-xs text-white/60 mb-1">
                    <span>Attendance Progress</span>
                    <span>
                      {Math.round(
                        (event.checkInCount / event.currentAttendees) * 100
                      )}
                      %
                    </span>
                  </div>
                  <div className="w-full bg-white/10 rounded-full h-2">
                    <div
                      className="bg-gradient-to-r from-primary to-secondary h-2 rounded-full transition-all duration-300"
                      style={{
                        width: `${
                          (event.checkInCount / event.currentAttendees) * 100
                        }%`,
                      }}
                    />
                  </div>
                </div>

                {/* Action Buttons */}
                <div className="space-y-2">
                  {activeTab === "hosted" && event.status === "upcoming" && (
                    <Button size="sm" className="w-full">
                      <QrCode className="mr-2 h-4 w-4" />
                      Show QR Code
                    </Button>
                  )}

                  {activeTab === "attending" && event.status === "upcoming" && (
                    <Button variant="outline" size="sm" className="w-full">
                      <Calendar className="mr-2 h-4 w-4" />
                      View Details
                    </Button>
                  )}

                  {activeTab === "completed" && (
                    <div className="space-y-2">
                      <Button variant="outline" size="sm" className="w-full">
                        <Trophy className="mr-2 h-4 w-4" />
                        View NFT
                      </Button>
                      <div className="text-center">
                        <span className="text-xs text-green-400">
                          ✓ Event Completed
                        </span>
                      </div>
                    </div>
                  )}

                  <Button
                    variant="ghost"
                    size="sm"
                    className="w-full"
                    onClick={() => navigate(`/event/${event.id}`)}
                  >
                    View Event Details
                  </Button>
                </div>
              </Card>
            ))}
          </div>

          {/* Empty State */}
          {getEventsByTab().length === 0 && (
            <div className="text-center py-12 sm:py-16">
              <div className="mb-6">
                {activeTab === "hosted" && (
                  <Users className="h-16 w-16 mx-auto text-white/30" />
                )}
                {activeTab === "attending" && (
                  <Calendar className="h-16 w-16 mx-auto text-white/30" />
                )}
                {activeTab === "completed" && (
                  <Trophy className="h-16 w-16 mx-auto text-white/30" />
                )}
              </div>
              <h3 className="text-xl font-semibold mb-2 text-white/70">
                No {activeTab} events yet
              </h3>
              <p className="text-white/50 mb-6 max-w-md mx-auto">
                {activeTab === "hosted" &&
                  "Start creating events to build your community"}
                {activeTab === "attending" &&
                  "Discover and join events in your area"}
                {activeTab === "completed" &&
                  "Complete events to see them here with your NFT rewards"}
              </p>
              {activeTab === "hosted" && (
                <Button onClick={() => navigate("/event/create")}>
                  <Calendar className="mr-2 h-4 w-4" />
                  Create Your First Event
                </Button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default MyEvents;
