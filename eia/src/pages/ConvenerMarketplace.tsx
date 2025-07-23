import { useState, useEffect } from "react";
import { Search, Star, Users, Calendar, Loader2 } from "lucide-react";
import Card from "../components/Card";
import Button from "../components/Button";
import { useNavigate } from "react-router-dom";
import { useAriyaSDK } from "../lib/sdk";
import useScrollToTop from "../hooks/useScrollToTop";

interface OrganizerProfile {
  id: string;
  address: string;
  name: string;
  bio: string;
  total_events: number;
  successful_events: number;
  total_attendees_served: number;
  avg_rating: number;
  created_at: number;
}

const ConvenerMarketplace = () => {
  useScrollToTop();
  const navigate = useNavigate();
  const sdk = useAriyaSDK();

  const [organizers, setOrganizers] = useState<OrganizerProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  useEffect(() => {
    const loadOrganizers = async () => {
      try {
        setLoading(true);
        const fetchedOrganizers = await sdk.eventManagement.getAllOrganizers();
        setOrganizers(fetchedOrganizers);
      } catch (error) {
        console.error("Error loading organizers:", error);
      } finally {
        setLoading(false);
      }
    };

    loadOrganizers();
  }, [sdk]);

  const filteredOrganizers = organizers.filter(
    (organizer) =>
        organizer.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      organizer.bio.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const formatDate = (timestamp: number) => {
    return new Date(timestamp).toLocaleDateString("en-US", {
      month: "short",
      year: "numeric",
    });
  };

  const getRatingStars = (rating: number) => {
    const stars = [];
    const fullStars = Math.floor(rating / 100);
    const hasHalfStar = rating % 100 >= 50;

    for (let i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.push(
          <Star key={i} className="h-4 w-4 fill-yellow-400 text-yellow-400" />
        );
      } else if (i === fullStars && hasHalfStar) {
        stars.push(
          <Star
            key={i}
            className="h-4 w-4 fill-yellow-400/50 text-yellow-400"
          />
        );
      } else {
        stars.push(<Star key={i} className="h-4 w-4 text-gray-400" />);
      }
    }
    return stars;
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
        <div className="container mx-auto px-4">
          <div className="max-w-6xl mx-auto">
            <div className="flex items-center justify-center min-h-[400px]">
              <div className="flex items-center gap-2">
                <Loader2 className="h-6 w-6 animate-spin text-primary" />
                <span className="text-white">Loading organizers...</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-black">
      {/* Fixed navbar spacing */}
      <div className="pt-24 pb-8">
        <div className="container mx-auto px-4 sm:px-6 lg:px-8 max-w-7xl">
          {/* Header */}
          <div className="text-center mb-8 lg:mb-12">
            <h1 className="text-3xl sm:text-4xl lg:text-5xl xl:text-6xl font-livvic font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text mb-3 lg:mb-4">
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
                  placeholder="Search organizers..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 sm:py-4 bg-white/5 border border-white/20 rounded-lg text-white placeholder-white/40 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 transition-all"
                />
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
                  {/* Header */}
                  <div className="flex items-start justify-between mb-6">
                    <div className="flex items-center gap-4">
                      <div className="w-12 h-12 rounded-full bg-gradient-to-r from-primary to-secondary flex items-center justify-center text-white font-bold text-lg">
                        {organizer.name.charAt(0).toUpperCase()}
                      </div>
                      <div className="flex flex-col">
                          <h3 className="text-xl font-bold text-white group-hover:text-primary transition-colors">
                            {organizer.name}
                          </h3>
                        <div className="flex items-center gap-2 text-white/60">
                          <span className="text-sm">
                            {organizer.address.slice(0, 8)}...
                            {organizer.address.slice(-6)}
                          </span>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Stats */}
                  <div className="grid grid-cols-3 gap-2 sm:gap-3 mb-6">
                    <div className="text-center p-2 sm:p-3 rounded-lg bg-gradient-to-br from-primary/5 to-primary/10 border border-primary/20">
                      <Calendar className="h-4 w-4 sm:h-5 sm:w-5 text-primary mx-auto mb-1 sm:mb-2" />
                      <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-0.5 sm:mb-1">
                        {organizer.total_events}
                      </div>
                      <div className="text-xs text-white/60 font-medium">
                        Events
                      </div>
                    </div>
                    <div className="text-center p-2 sm:p-3 rounded-lg bg-gradient-to-br from-secondary/5 to-secondary/10 border border-secondary/20">
                      <Users className="h-4 w-4 sm:h-5 sm:w-5 text-secondary mx-auto mb-1 sm:mb-2" />
                      <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-0.5 sm:mb-1">
                        {organizer.total_attendees_served.toLocaleString()}
                      </div>
                      <div className="text-xs text-white/60 font-medium">
                        Attendees
                      </div>
                    </div>
                    <div className="text-center p-2 sm:p-3 rounded-lg bg-gradient-to-br from-accent/5 to-accent/10 border border-accent/20">
                      <Star className="h-4 w-4 sm:h-5 sm:w-5 text-accent mx-auto mb-1 sm:mb-2 fill-current" />
                      <div className="text-lg sm:text-xl lg:text-2xl font-bold text-white mb-0.5 sm:mb-1">
                        {(organizer.avg_rating / 100).toFixed(1)}
                      </div>
                      <div className="text-xs text-white/60 font-medium">
                        Rating
                      </div>
                    </div>
                  </div>

                  {/* Rating Stars */}
                  <div className="flex items-center justify-center mb-4 sm:mb-6">
                    <div className="flex items-center gap-1">
                      {getRatingStars(organizer.avg_rating)}
                    </div>
                  </div>

                  {/* Description */}
                  <p className="text-white/80 text-sm leading-relaxed mb-4 sm:mb-6">
                    {organizer.bio}
                  </p>

                  {/* Stats */}
                  <div className="grid grid-cols-1 gap-3 mb-4 sm:mb-6 sm:grid-cols-2 sm:gap-4">
                    <div className="p-3 rounded-lg bg-white/5 border border-white/10">
                      <div className="text-xs text-white/60 font-medium mb-1">
                        Successful Events
                      </div>
                      <div className="text-white font-bold text-sm sm:text-base">
                        {organizer.successful_events}
                      </div>
                    </div>
                    <div className="p-3 rounded-lg bg-green-400/10 border border-green-400/20">
                      <div className="text-xs text-white/60 font-medium mb-1">
                        Member Since
                      </div>
                      <div className="text-green-400 font-bold text-sm sm:text-base">
                        {formatDate(organizer.created_at)}
                      </div>
                    </div>
                  </div>

                  {/* Actions */}
                  {/* Removed View Events and Contact buttons */}
                </div>
              </Card>
            ))}
          </div>

          {/* Empty State */}
          {filteredOrganizers.length === 0 && (
            <div className="text-center py-12 sm:py-16">
              <div className="mb-6">
                <Users className="h-16 w-16 mx-auto text-white/30" />
              </div>
              <h3 className="text-xl font-semibold mb-2 text-white/70">
                No organizers found
              </h3>
              <p className="text-white/50 mb-6 max-w-md mx-auto">
                {searchTerm
                  ? "Try adjusting your search terms"
                  : "Be the first to create an organizer profile"}
              </p>
              {!searchTerm && (
                <Button onClick={() => navigate("/profile/organizer/create")}>
                  <Users className="mr-2 h-4 w-4" />
                  Create Organizer Profile
                </Button>
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default ConvenerMarketplace;
