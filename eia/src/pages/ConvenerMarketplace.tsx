import { useState } from "react";
import { Search, Star, Users, Calendar, MapPin, Verified } from "lucide-react";
import Card from "../components/Card";
import Button from "../components/Button";
import UserAvatarBadge from "../components/UserAvatarBadge";
import RatingStars from "../components/RatingStars";
import useScrollToTop from "../hooks/useScrollToTop";

interface Organizer {
  id: string;
  name: string;
  location: string;
  eventsHosted: number;
  totalAttendees: number;
  rating: number;
  specialties: string[];
  verified: boolean;
  badge?: {
    type: "verified" | "organizer" | "sponsor" | "vip" | "premium";
    level?: number;
  };
  description: string;
  priceRange: string;
  responseTime: string;
}

const ConvenerMarketplace = () => {
  useScrollToTop();

  const [searchTerm, setSearchTerm] = useState("");
  const [selectedFilter, setSelectedFilter] = useState("all");
  const [sortBy, setSortBy] = useState("rating");

  const [organizers] = useState<Organizer[]>([
    {
      id: "1",
      name: "Alice Chen",
      location: "San Francisco, CA",
      eventsHosted: 25,
      totalAttendees: 2340,
      rating: 4.9,
      specialties: ["Tech Conferences", "Web3 Events", "Developer Meetups"],
      verified: true,
      badge: { type: "organizer", level: 5 },
      description:
        "Experienced tech event organizer specializing in blockchain and Web3 conferences with 5+ years of experience building developer communities.",
      priceRange: "$2,000 - $10,000",
      responseTime: "< 2 hours",
    },
    {
      id: "2",
      name: "Marcus Johnson",
      location: "New York, NY",
      eventsHosted: 18,
      totalAttendees: 1850,
      rating: 4.7,
      specialties: ["Corporate Events", "Networking", "DeFi Summits"],
      verified: true,
      badge: { type: "verified", level: 3 },
      description:
        "Corporate event specialist with expertise in high-profile DeFi events. Known for seamless execution and attention to detail.",
      priceRange: "$3,000 - $15,000",
      responseTime: "< 4 hours",
    },
  ]);

  const filteredOrganizers = organizers
    .filter((organizer) => {
      const matchesSearch =
        organizer.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
        organizer.specialties.some((spec) =>
          spec.toLowerCase().includes(searchTerm.toLowerCase())
        );

      if (selectedFilter === "all") return matchesSearch;
      if (selectedFilter === "verified")
        return matchesSearch && organizer.verified;

      return matchesSearch;
    })
    .sort((a, b) => {
      switch (sortBy) {
        case "rating":
          return b.rating - a.rating;
        case "events":
          return b.eventsHosted - a.eventsHosted;
        default:
          return 0;
      }
    });

  return (
    <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-black">
      {/* Fixed navbar spacing */}
      <div className="pt-24 pb-8">
        <div className="container mx-auto px-4 sm:px-6 lg:px-8 max-w-7xl">
          {/* Header */}
          <div className="text-center mb-8 lg:mb-12">
            <h1 className="text-3xl sm:text-4xl lg:text-5xl xl:text-6xl font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text mb-3 lg:mb-4">
              Convener Marketplace
            </h1>
            <p className="text-base sm:text-lg lg:text-xl text-white/70 max-w-3xl mx-auto leading-relaxed">
              Discover and connect with top-rated event organizers in the Web3
              space
            </p>
          </div>

          {/* Search and Filters */}
          <Card className="p-4 sm:p-6 mb-6 lg:mb-8">
            <div className="flex flex-col gap-4">
              <div className="relative">
                <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-white/40" />
                <input
                  type="text"
                  placeholder="Search organizers or specialties..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 sm:py-4 bg-white/5 border border-white/20 rounded-lg text-white placeholder-white/40 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                />
              </div>

              <div className="flex flex-col sm:flex-row gap-3">
                <select
                  value={selectedFilter}
                  onChange={(e) => setSelectedFilter(e.target.value)}
                  className="flex-1 px-4 py-3 sm:py-4 bg-white/5 border border-white/20 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                >
                  <option value="all">All Organizers</option>
                  <option value="verified">Verified Only</option>
                </select>
                <select
                  value={sortBy}
                  onChange={(e) => setSortBy(e.target.value)}
                  className="flex-1 px-4 py-3 sm:py-4 bg-white/5 border border-white/20 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                >
                  <option value="rating">Sort by Rating</option>
                  <option value="events">Sort by Events</option>
                </select>
              </div>
            </div>
          </Card>

          {/* Results Count */}
          <div className="mb-6">
            <p className="text-white/60 text-sm sm:text-base">
              {filteredOrganizers.length} organizer
              {filteredOrganizers.length !== 1 ? "s" : ""} found
            </p>
          </div>

          {/* Organizer Grid */}
          <div className="grid grid-cols-1 xl:grid-cols-2 gap-4 sm:gap-6 lg:gap-8">
            {filteredOrganizers.map((organizer) => (
              <Card
                key={organizer.id}
                className="group overflow-hidden border border-white/10 hover:border-primary/30 hover:shadow-2xl hover:shadow-primary/10 transition-all duration-500 transform hover:-translate-y-1"
              >
                <div className="p-4 sm:p-6 lg:p-8">
                  {/* Mobile Header - Stack vertically */}
                  <div className="block sm:hidden mb-6">
                    <div className="flex items-center justify-between mb-3">
                      <UserAvatarBadge
                        name={organizer.name}
                        badge={organizer.badge}
                        reputation={organizer.rating}
                        size="md"
                      />
                      {organizer.verified && (
                        <div className="flex items-center gap-1 px-2 py-1 rounded-full bg-blue-500/20 text-blue-400 text-xs border border-blue-500/30">
                          <Verified className="h-3 w-3" />
                        </div>
                      )}
                    </div>
                    <div className="flex items-center gap-2 text-white/60 ml-1">
                      <MapPin className="h-4 w-4 flex-shrink-0" />
                      <span className="text-sm">{organizer.location}</span>
                    </div>
                  </div>

                  {/* Desktop Header - Side by side */}
                  <div className="hidden sm:flex items-start justify-between mb-6">
                    <div className="flex items-center gap-4">
                      <UserAvatarBadge
                        name={organizer.name}
                        badge={organizer.badge}
                        reputation={organizer.rating}
                        size="lg"
                      />
                      <div className="flex flex-col">
                        <div className="flex items-center gap-2 mb-1">
                          <h3 className="text-xl font-bold text-white group-hover:text-primary transition-colors">
                            {organizer.name}
                          </h3>
                          {organizer.verified && (
                            <div className="flex items-center gap-1 px-2 py-1 rounded-full bg-blue-500/20 text-blue-400 text-xs border border-blue-500/30">
                              <Verified className="h-3 w-3" />
                              <span>Verified</span>
                            </div>
                          )}
                        </div>
                        <div className="flex items-center gap-2 text-white/60">
                          <MapPin className="h-4 w-4 flex-shrink-0" />
                          <span className="text-sm">{organizer.location}</span>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Stats - Mobile optimized */}
                  <div className="grid grid-cols-3 gap-2 sm:gap-3 mb-6">
                    <div className="text-center p-2 sm:p-3 rounded-lg bg-gradient-to-br from-primary/5 to-primary/10 border border-primary/20">
                      <Calendar className="h-4 w-4 sm:h-5 sm:w-5 text-primary mx-auto mb-1 sm:mb-2" />
                      <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-0.5 sm:mb-1">
                        {organizer.eventsHosted}
                      </div>
                      <div className="text-xs text-white/60 font-medium">
                        Events
                      </div>
                    </div>
                    <div className="text-center p-2 sm:p-3 rounded-lg bg-gradient-to-br from-secondary/5 to-secondary/10 border border-secondary/20">
                      <Users className="h-4 w-4 sm:h-5 sm:w-5 text-secondary mx-auto mb-1 sm:mb-2" />
                      <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-0.5 sm:mb-1">
                        {organizer.totalAttendees.toLocaleString()}
                      </div>
                      <div className="text-xs text-white/60 font-medium">
                        Attendees
                      </div>
                    </div>
                    <div className="text-center p-2 sm:p-3 rounded-lg bg-gradient-to-br from-accent/5 to-accent/10 border border-accent/20">
                      <Star className="h-4 w-4 sm:h-5 sm:w-5 text-accent mx-auto mb-1 sm:mb-2 fill-current" />
                      <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-0.5 sm:mb-1">
                        {organizer.rating}
                      </div>
                      <div className="text-xs text-white/60 font-medium">
                        Rating
                      </div>
                    </div>
                  </div>

                  {/* Rating Stars */}
                  <div className="flex items-center justify-center mb-4 sm:mb-6">
                    <RatingStars
                      rating={organizer.rating}
                      size="sm"
                      showLabel
                    />
                  </div>

                  {/* Description */}
                  <p className="text-white/80 text-sm leading-relaxed mb-4 sm:mb-6">
                    {organizer.description}
                  </p>

                  {/* Specialties */}
                  <div className="mb-4 sm:mb-6">
                    <h4 className="text-sm font-semibold text-white/80 mb-2 sm:mb-3">
                      Specialties
                    </h4>
                    <div className="flex flex-wrap gap-1.5 sm:gap-2">
                      {organizer.specialties.map((specialty, index) => (
                        <span
                          key={index}
                          className="px-2 sm:px-3 py-1 sm:py-1.5 rounded-full bg-gradient-to-r from-primary/20 to-secondary/20 text-primary text-xs font-medium border border-primary/30 hover:border-primary/50 transition-colors"
                        >
                          {specialty}
                        </span>
                      ))}
                    </div>
                  </div>

                  {/* Price and Response - Mobile stacked */}
                  <div className="grid grid-cols-1 gap-3 mb-4 sm:mb-6 sm:grid-cols-2 sm:gap-4">
                    <div className="p-3 rounded-lg bg-white/5 border border-white/10">
                      <div className="text-xs text-white/60 font-medium mb-1">
                        Price Range
                      </div>
                      <div className="text-white font-bold text-sm sm:text-base">
                        {organizer.priceRange}
                      </div>
                    </div>
                    <div className="p-3 rounded-lg bg-green-400/10 border border-green-400/20">
                      <div className="text-xs text-white/60 font-medium mb-1">
                        Response Time
                      </div>
                      <div className="text-green-400 font-bold text-sm sm:text-base">
                        {organizer.responseTime}
                      </div>
                    </div>
                  </div>

                  {/* Actions - Mobile full width */}
                  <div className="flex flex-col gap-3 sm:flex-row">
                    <Button className="flex-1 group-hover:scale-105 transition-transform py-3 sm:py-2">
                      Contact Organizer
                    </Button>
                    <Button
                      variant="outline"
                      className="flex-1 group-hover:scale-105 transition-transform py-3 sm:py-2"
                    >
                      View Portfolio
                    </Button>
                  </div>
                </div>
              </Card>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default ConvenerMarketplace;
