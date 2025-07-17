import { useState } from "react";
import { useParams } from "react-router-dom";
import {
  Calendar,
  MapPin,
  Users,
  QrCode,
  Share2,
  Trophy,
  Star,
} from "lucide-react";
import Card from "../components/Card";
import Button from "../components/Button";
import type { Event } from "../types";
import useScrollToTop from "../hooks/useScrollToTop";

const EventDetails = () => {
  useScrollToTop();
  const { id } = useParams();
  const [isRegistered, setIsRegistered] = useState(false);
  const [showQR, setShowQR] = useState(false);

  // Mock event data - replace with real data fetching
  const event: Event = {
    id: id || "1",
    title: "Web3 Developer Meetup",
    description:
      "Join us for an exciting evening of Web3 development discussions, networking, and learning about the latest trends in blockchain technology. This event is perfect for developers of all levels who are interested in decentralized applications, smart contracts, and the future of the web.",
    location: "Tech Hub San Francisco, 123 Market Street, San Francisco, CA",
    date: new Date("2024-02-15T18:00:00"),
    bannerImage: "/api/placeholder/800/400",
    organizerId: "org1",
    organizer: {
      id: "org1",
      walletAddress: "0x123...456",
      username: "TechMeetupSF",
      reputation: 4.8,
      avatar: "/api/placeholder/100/100",
    } as any,
    status: "upcoming",
    currentAttendees: 85,
    checkInCount: 0,
    maxAttendees: 150,
    completionNFT: {
      id: "nft1",
      name: "Web3 Meetup Completion Badge",
      description: "Proof of attendance for Web3 Developer Meetup",
      image: "/api/placeholder/300/300",
      attributes: [
        { trait_type: "Event Type", value: "Meetup" },
        { trait_type: "Location", value: "San Francisco" },
        { trait_type: "Date", value: "2024-02-15" },
      ],
    },
  };

  const formatDate = (date: Date) => {
    return date.toLocaleDateString("en-US", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
    });
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString("en-US", {
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    });
  };

  const handleRegister = () => {
    setIsRegistered(!isRegistered);
    // TODO: Implement registration logic
  };

  const handleCheckIn = () => {
    setShowQR(true);
    // TODO: Implement check-in logic
  };

  return (
    <div className="min-h-screen bg-black pt-16">
      {/* Hero Section */}
      <div className="relative h-96 overflow-hidden">
        <div
          className="absolute inset-0 bg-gradient-to-r from-black/70 to-black/30 z-10"
          style={{
            backgroundImage: `linear-gradient(rgba(0,0,0,0.7), rgba(0,0,0,0.3)), url(${event.bannerImage})`,
            backgroundSize: "cover",
            backgroundPosition: "center",
          }}
        />
        <div className="relative z-20 container mx-auto px-4 h-full flex items-end pb-8">
          <div className="text-white">
            <div className="flex items-center mb-4">
              <span
                className={`
                px-3 py-1 rounded-full text-xs font-medium
                ${
                  event.status === "upcoming"
                    ? "bg-accent/20 text-accent"
                    : event.status === "ongoing"
                    ? "bg-secondary/20 text-secondary"
                    : event.status === "completed"
                    ? "bg-primary/20 text-primary"
                    : "bg-red-500/20 text-red-400"
                }
              `}
              >
                {event.status.charAt(0).toUpperCase() + event.status.slice(1)}
              </span>
            </div>
            <h1 className="text-4xl md:text-6xl font-satoshi font-bold mb-4">
              {event.title}
            </h1>
            <div className="flex flex-wrap items-center gap-6 text-white/80">
              <div className="flex items-center">
                <Calendar className="mr-2 h-5 w-5" />
                <span>
                  {formatDate(event.date)} at {formatTime(event.date)}
                </span>
              </div>
              <div className="flex items-center">
                <MapPin className="mr-2 h-5 w-5" />
                <span>{event.location}</span>
              </div>
              <div className="flex items-center">
                <Users className="mr-2 h-5 w-5" />
                <span>
                  {event.currentAttendees}/{event.maxAttendees} attendees
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
                <img
                  src={event.organizer.avatar}
                  alt={event.organizer.username}
                  className="w-16 h-16 rounded-full mr-4"
                />
                <div className="flex-1">
                  <h3 className="text-lg font-medium">
                    {event.organizer.username}
                  </h3>
                  <p className="text-white/60 text-sm">
                    {event.organizer.walletAddress}
                  </p>
                  <div className="flex items-center mt-1">
                    <Star className="h-4 w-4 text-accent mr-1" />
                    <span className="text-sm">
                      {event.organizer.reputation} rating
                    </span>
                  </div>
                </div>
                <Button variant="outline" size="sm">
                  View Profile
                </Button>
              </div>
            </Card>

            {/* NFT Completion Badge */}
            {event.completionNFT && (
              <Card className="p-6">
                <h2 className="text-2xl font-semibold mb-4">
                  Completion Reward
                </h2>
                <div className="flex items-start space-x-4">
                  <img
                    src={event.completionNFT.image}
                    alt={event.completionNFT.name}
                    className="w-24 h-24 rounded-lg"
                  />
                  <div className="flex-1">
                    <h3 className="text-lg font-medium mb-2">
                      {event.completionNFT.name}
                    </h3>
                    <p className="text-white/70 text-sm mb-3">
                      {event.completionNFT.description}
                    </p>
                    <div className="flex items-center text-accent">
                      <Trophy className="mr-2 h-4 w-4" />
                      <span className="text-sm">
                        Complete the event to mint this NFT
                      </span>
                    </div>
                  </div>
                </div>
              </Card>
            )}
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Action Card */}
            <Card className="p-6">
              <div className="text-center mb-6">
                <div className="text-3xl font-bold text-primary mb-1">
                  {event.currentAttendees}
                </div>
                <div className="text-white/60">attending</div>
              </div>

              <div className="space-y-3 mb-6">
                {!isRegistered ? (
                  <Button size="lg" className="w-full" onClick={handleRegister}>
                    <Users className="mr-2 h-5 w-5" />
                    Join Event
                  </Button>
                ) : (
                  <div className="space-y-3">
                    <Button
                      size="lg"
                      className="w-full"
                      onClick={handleCheckIn}
                    >
                      <QrCode className="mr-2 h-5 w-5" />
                      Check In
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
                  <span className="text-white/60">Check-ins</span>
                  <span className="font-medium">{event.checkInCount}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-white/60">Completion Rate</span>
                  <span className="font-medium">95%</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-white/60">Event Rating</span>
                  <span className="font-medium">4.8 ⭐</span>
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
                    {formatDate(event.date)}
                    <br />
                    {formatTime(event.date)}
                  </div>
                </div>

                <div>
                  <div className="text-white/60 text-sm mb-1">Location</div>
                  <div className="font-medium">{event.location}</div>
                </div>

                <div>
                  <div className="text-white/60 text-sm mb-1">Capacity</div>
                  <div className="font-medium">
                    {event.currentAttendees} / {event.maxAttendees} people
                  </div>
                </div>
              </div>
            </Card>
          </div>
        </div>
      </div>

      {/* QR Code Modal */}
      {showQR && (
        <div
          className="fixed inset-0 bg-black/80 flex items-center justify-center z-50"
          onClick={() => setShowQR(false)}
        >
          <div onClick={(e) => e.stopPropagation()}>
            <Card className="p-8 max-w-sm mx-4">
              <div className="text-center">
                <h3 className="text-xl font-semibold mb-4">Check-in QR Code</h3>
                <div className="bg-white p-4 rounded-lg mb-4">
                  <div className="w-48 h-48 bg-gray-200 rounded flex items-center justify-center">
                    QR CODE
                  </div>
                </div>
                <p className="text-white/70 text-sm mb-4">
                  Show this QR code to the event organizer for check-in
                </p>
                <Button onClick={() => setShowQR(false)}>Close</Button>
              </div>
            </Card>
          </div>
        </div>
      )}
    </div>
  );
};

export default EventDetails;
