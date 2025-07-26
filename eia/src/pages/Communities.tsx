import { useEffect, useState } from "react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useAriyaSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import Card from "../components/Card";
import Button from "../components/Button";
import { useNavigate } from "react-router-dom";
import { AlertCircle, CheckCircle, XCircle, Clock } from "lucide-react";

const Communities = () => {
  const currentAccount = useCurrentAccount();
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();
  const sdk = useAriyaSDK();
  const communityRegistryId = useNetworkVariable("communityRegistryId");
  const nftRegistryId = useNetworkVariable("nftRegistryId");
  const [allCommunities, setAllCommunities] = useState<any[]>([]);
  const [userCommunities, setUserCommunities] = useState<any[]>([]);
  const [activeUserCommunities, setActiveUserCommunities] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState<string | null>(null);
  const [membershipChecks, setMembershipChecks] = useState<{
    [key: string]: { isActive: boolean; reason?: string };
  }>({});
  const navigate = useNavigate();

  useEffect(() => {
    const fetchCommunities = async () => {
      if (!currentAccount || !communityRegistryId || !nftRegistryId) return;
      setLoading(true);
      try {
        // Get all communities (across all events)
        const all = await sdk.communityAccess.getAllCommunities();
        setAllCommunities(all);

        // Get user's joined communities (has access objects)
        const user = await sdk.communityAccess.getUserCommunities(
          currentAccount.address,
          communityRegistryId
        );
        setUserCommunities(user);

        // Get user's active communities (verified active membership)
        const active = await sdk.communityAccess.getActiveUserCommunities(
          currentAccount.address,
          communityRegistryId,
          nftRegistryId
        );
        setActiveUserCommunities(active);

        // Check membership status for each community the user has joined
        const checks: {
          [key: string]: { isActive: boolean; reason?: string };
        } = {};
        for (const community of user) {
          const check = await sdk.communityAccess.isActiveCommunityMember(
            community.id,
            currentAccount.address,
            communityRegistryId,
            nftRegistryId
          );
          checks[community.id] = check;
        }
        setMembershipChecks(checks);
      } catch (e) {
        console.error("Error fetching communities:", e);
        setAllCommunities([]);
        setUserCommunities([]);
        setActiveUserCommunities([]);
      } finally {
        setLoading(false);
      }
    };
    fetchCommunities();
  }, [currentAccount, sdk, communityRegistryId, nftRegistryId]);

  const handleJoin = async (community: any) => {
    if (!currentAccount || !nftRegistryId || !communityRegistryId) return;
    setJoining(community.id);
    try {
      const tx = sdk.communityAccess.requestCommunityAccess(
        community.id,
        currentAccount.address,
        nftRegistryId,
        communityRegistryId
      );
      await signAndExecute({ transaction: tx });
      setUserCommunities((prev) => [...prev, community]);
      // Refresh membership checks
      const check = await sdk.communityAccess.isActiveCommunityMember(
        community.id,
        currentAccount.address,
        communityRegistryId,
        nftRegistryId
      );
      setMembershipChecks((prev) => ({ ...prev, [community.id]: check }));
    } catch (e) {
      console.error("Failed to join community:", e);
    } finally {
      setJoining(null);
    }
  };

  const isJoined = (communityId: string) =>
    userCommunities.some((c) => c.id === communityId);

  const isActiveMember = (communityId: string) =>
    activeUserCommunities.some((c) => c.id === communityId);

  const getMembershipStatus = (communityId: string) => {
    if (!isJoined(communityId))
      return { status: "not-joined", icon: null, color: "text-white/50" };

    const check = membershipChecks[communityId];
    if (!check)
      return { status: "checking", icon: Clock, color: "text-yellow-400" };

    if (check.isActive)
      return { status: "active", icon: CheckCircle, color: "text-green-400" };
    return {
      status: "inactive",
      icon: XCircle,
      color: "text-red-400",
      reason: check.reason,
    };
  };

  return (
    <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
      <div className="container mx-auto px-4 max-w-5xl">
        <div className="text-center mb-8 sm:mb-12">
          <h1 className="text-3xl sm:text-4xl font-livvic font-bold mb-3">
            Communities
          </h1>
          <p className="text-white/80 text-base sm:text-lg max-w-2xl mx-auto font-open-sans">
            Discover and join event communities. Access forums, resources, and
            connect with other attendees.
          </p>
        </div>
        {loading ? (
          <div className="text-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto"></div>
            <p className="text-white/60 mt-4">Loading communities...</p>
          </div>
        ) : allCommunities.length === 0 ? (
          <div className="text-center py-12">
            <h3 className="text-xl font-semibold mb-2 text-white/70">
              No communities found
            </h3>
            <p className="text-white/50 mb-6 max-w-md mx-auto">
              Communities will appear here as organizers create them for events.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {allCommunities.map((community) => {
              const membershipStatus = getMembershipStatus(community.id);
              const StatusIcon = membershipStatus.icon;

              return (
                <Card
                  key={community.id}
                  className="p-6 flex flex-col justify-between"
                >
                  <div>
                    <div className="flex items-start justify-between mb-2">
                      <h3 className="text-lg font-semibold mb-1 text-white font-livvic">
                        {community.name || "Untitled Community"}
                      </h3>
                      {StatusIcon && (
                        <StatusIcon
                          className={`h-5 w-5 ${membershipStatus.color}`}
                        />
                      )}
                    </div>
                    <p className="text-white/70 text-sm mb-2">
                      {community.description || "No description provided."}
                    </p>
                    <div className="text-xs text-white/50 mb-2">
                      Event: {community.event_id?.slice(0, 8)}...
                      <br />
                      Community ID: {community.id.slice(0, 8)}...
                    </div>

                    {/* Membership Status Details */}
                    {membershipStatus.status === "inactive" &&
                      membershipStatus.reason && (
                        <div className="flex items-center gap-2 p-2 bg-red-500/10 border border-red-500/20 rounded-lg mb-3">
                          <AlertCircle className="h-4 w-4 text-red-400" />
                          <span className="text-xs text-red-300">
                            {membershipStatus.reason}
                          </span>
                        </div>
                      )}

                    {membershipStatus.status === "checking" && (
                      <div className="flex items-center gap-2 p-2 bg-yellow-500/10 border border-yellow-500/20 rounded-lg mb-3">
                        <Clock className="h-4 w-4 text-yellow-400" />
                        <span className="text-xs text-yellow-300">
                          Checking membership status...
                        </span>
                      </div>
                    )}
                  </div>
                  <div className="mt-4 flex gap-2">
                    {membershipStatus.status === "active" ? (
                      <Button
                        className="flex-1"
                        onClick={() => navigate(`/community/${community.id}`)}
                      >
                        Access Community
                      </Button>
                    ) : membershipStatus.status === "inactive" ? (
                      <Button
                        className="flex-1"
                        variant="secondary"
                        onClick={() => handleJoin(community)}
                        disabled={joining === community.id}
                      >
                        {joining === community.id
                          ? "Joining..."
                          : "Rejoin Community"}
                      </Button>
                    ) : (
                      <Button
                        className="flex-1"
                        variant="secondary"
                        onClick={() => handleJoin(community)}
                        disabled={joining === community.id}
                      >
                        {joining === community.id
                          ? "Joining..."
                          : "Join Community"}
                      </Button>
                    )}
                  </div>
                </Card>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};

export default Communities;
