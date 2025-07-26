import { useState, useEffect } from "react";
import { useParams, useNavigate } from "react-router-dom";
import {
  Users,
  MessageCircle,
  FileText,
  Calendar,
  Settings,
  ArrowLeft,
  Plus,
  Send,
  Star,
  Trophy,
  Award,
} from "lucide-react";
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { useAriyaSDK } from "../lib/sdk";
import { useNetworkVariable } from "../config/sui";
import { 
  CommunityPostsService, 
  CommunityResourcesService, 
  CommunityMembersService,
  type ForumPost,
  type CommunityResource,
  type CommunityMember 
} from "../lib/firebase";
import Card from "../components/Card";
import Button from "../components/Button";
import useScrollToTop from "../hooks/useScrollToTop";



const Community = () => {
  useScrollToTop();
  const { communityId } = useParams<{ communityId: string }>();
  const navigate = useNavigate();
  const currentAccount = useCurrentAccount();
  const sdk = useAriyaSDK();
  const communityRegistryId = useNetworkVariable("communityRegistryId");
  const { mutateAsync: signAndExecute } = useSignAndExecuteTransaction();

  const [activeTab, setActiveTab] = useState("overview");
  const [loading, setLoading] = useState(true);
  const [community, setCommunity] = useState<any>(null);
  const [members, setMembers] = useState<CommunityMember[]>([]);
  const [forumPosts, setForumPosts] = useState<ForumPost[]>([]);
  const [resources, setResources] = useState<CommunityResource[]>([]);
  const [newPost, setNewPost] = useState("");
  const [newResource, setNewResource] = useState({
    title: "",
    description: "",
    file: null as File | null,
  });
  const [showNewPostModal, setShowNewPostModal] = useState(false);
  const [showNewResourceModal, setShowNewResourceModal] = useState(false);

  useEffect(() => {
    const loadCommunity = async () => {
      if (!communityId || !currentAccount) return;

      try {
        setLoading(true);
        console.log("🔍 Loading community:", communityId);

        // Check if user has access to this community
        const access = await sdk.communityAccess.checkCommunityAccess(
          communityId,
          currentAccount.address,
          communityRegistryId
        );

        if (!access) {
          console.log("❌ User doesn't have access to community");
          navigate("/events");
          return;
        }

        // For now, create a mock community object since we have the ID
        const mockCommunity = {
          id: communityId,
          name: "Event Community",
          description: "Join the live community for this event",
          memberCount: 12, // Mock data
          created: Date.now() - 86400000, // 1 day ago
          isActive: true,
          features: ["forum", "resources", "directory"],
        };

        setCommunity(mockCommunity);

        // Load real data from Firebase
        console.log("📡 Loading community data from Firebase...");
        
        // Load posts
        const posts = await CommunityPostsService.getPosts(communityId);
        setForumPosts(posts);
        console.log("📝 Loaded posts:", posts.length);
        
        // Load resources
        const resources = await CommunityResourcesService.getResources(communityId);
        setResources(resources);
        console.log("📁 Loaded resources:", resources.length);
        
        // Load members
        const members = await CommunityMembersService.getMembers(communityId);
        setMembers(members);
        console.log("👥 Loaded members:", members.length);
        
        // Set up real-time listeners
        const unsubscribePosts = CommunityPostsService.subscribeToPosts(
          communityId,
          (newPosts) => {
            setForumPosts(newPosts);
            console.log("🔄 Real-time posts update:", newPosts.length);
          }
        );
        
        // Update member activity
        await CommunityMembersService.updateMemberActivity(communityId, currentAccount.address);
        
        // Cleanup function for real-time listeners
        return () => {
          unsubscribePosts();
        };
      } catch (error) {
        console.error("Error loading community:", error);
        navigate("/events");
      } finally {
        setLoading(false);
      }
    };

    loadCommunity();
  }, [communityId, currentAccount, communityRegistryId, sdk, navigate]);

  const handleNewPost = async () => {
    if (!newPost.trim() || !communityId) return;

    try {
      await CommunityPostsService.createPost({
        communityId,
        author: currentAccount!.address,
        content: newPost,
      });

      setNewPost("");
      setShowNewPostModal(false);
      console.log("✅ Post created successfully");
    } catch (error) {
      console.error("Error creating post:", error);
      alert("Failed to create post. Please try again.");
    }
  };

  const handleNewResource = async () => {
    if (!newResource.title.trim() || !newResource.file || !communityId) return;

    try {
      await CommunityResourcesService.uploadResource(
        communityId,
        newResource.file,
        newResource.title,
        newResource.description,
        currentAccount!.address
      );

      setNewResource({ title: "", description: "", file: null });
      setShowNewResourceModal(false);
      console.log("✅ Resource uploaded successfully");
    } catch (error) {
      console.error("Error uploading resource:", error);
      alert("Failed to upload resource. Please try again.");
    }
  };

  const formatDate = (timestamp: any) => {
    const date = timestamp?.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  };

  const formatAddress = (address: string) => {
    return `${address.slice(0, 8)}...${address.slice(-6)}`;
  };

  const handleToggleLike = async (postId: string) => {
    if (!currentAccount) return;
    
    try {
      await CommunityPostsService.toggleLike(postId, currentAccount.address);
      console.log("✅ Like toggled successfully");
    } catch (error) {
      console.error("Error toggling like:", error);
      alert("Failed to like post. Please try again.");
    }
  };

  const handleDownloadResource = async (resource: CommunityResource) => {
    if (!currentAccount) return;
    
    try {
      // Track download
      if (resource.id) {
        await CommunityResourcesService.trackDownload(resource.id, currentAccount.address);
      }
      
      // Download file
      const link = document.createElement('a');
      link.href = resource.fileUrl;
      link.download = resource.fileName;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      
      console.log("✅ Resource downloaded successfully");
    } catch (error) {
      console.error("Error downloading resource:", error);
      alert("Failed to download resource. Please try again.");
    }
  };

  if (!currentAccount) {
    return (
      <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
        <div className="container mx-auto px-4">
          <div className="text-center py-12">
            <h2 className="text-2xl font-semibold mb-4">Connect Your Wallet</h2>
            <p className="text-white/60">
              Please connect your wallet to access the community.
            </p>
          </div>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
        <div className="container mx-auto px-4">
          <div className="text-center py-12">
            <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto"></div>
            <p className="text-white/60 mt-4">Loading community...</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-black pt-20 pb-6 sm:pb-10">
      <div className="container mx-auto px-4">
        <div className="max-w-6xl mx-auto">
          {/* Header */}
          <div className="flex items-center gap-4 mb-8">
            <Button
              variant="ghost"
              size="sm"
              onClick={() => navigate("/my-events")}
              className="text-white/70 hover:text-white"
            >
              <ArrowLeft className="mr-2 h-4 w-4" />
              Back to Events
            </Button>
            <div className="flex-1">
              <h1 className="text-3xl sm:text-4xl font-livvic font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text">
                {community?.name || "Community"}
              </h1>
              <p className="text-white/60 text-sm sm:text-base mt-2">
                {community?.description}
              </p>
            </div>
          </div>

          {/* Community Stats */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mb-8">
            <Card className="p-4 text-center">
              <Users className="h-8 w-8 mx-auto text-primary mb-2" />
              <div className="text-2xl font-bold text-white">
                {community?.memberCount || 0}
              </div>
              <div className="text-white/60 text-sm">Members</div>
            </Card>
            <Card className="p-4 text-center">
              <MessageCircle className="h-8 w-8 mx-auto text-secondary mb-2" />
              <div className="text-2xl font-bold text-white">
                {forumPosts.length}
              </div>
              <div className="text-white/60 text-sm">Posts</div>
            </Card>
            <Card className="p-4 text-center">
              <FileText className="h-8 w-8 mx-auto text-accent mb-2" />
              <div className="text-2xl font-bold text-white">
                {resources.length}
              </div>
              <div className="text-white/60 text-sm">Resources</div>
            </Card>
          </div>

          {/* Tab Navigation */}
          <div className="flex justify-center mb-8">
            <div className="flex space-x-1 bg-white/10 rounded-lg p-1">
              <button
                onClick={() => setActiveTab("overview")}
                className={`px-4 py-2 rounded-md transition-colors ${
                  activeTab === "overview"
                    ? "bg-primary text-white"
                    : "text-white/70 hover:text-white"
                }`}
              >
                Overview
              </button>
              <button
                onClick={() => setActiveTab("forum")}
                className={`px-4 py-2 rounded-md transition-colors ${
                  activeTab === "forum"
                    ? "bg-primary text-white"
                    : "text-white/70 hover:text-white"
                }`}
              >
                Forum
              </button>
              <button
                onClick={() => setActiveTab("resources")}
                className={`px-4 py-2 rounded-md transition-colors ${
                  activeTab === "resources"
                    ? "bg-primary text-white"
                    : "text-white/70 hover:text-white"
                }`}
              >
                Resources
              </button>
              <button
                onClick={() => setActiveTab("members")}
                className={`px-4 py-2 rounded-md transition-colors ${
                  activeTab === "members"
                    ? "bg-primary text-white"
                    : "text-white/70 hover:text-white"
                }`}
              >
                Members
              </button>
            </div>
          </div>

          {/* Tab Content */}
          <div className="space-y-6">
            {/* Overview Tab */}
            {activeTab === "overview" && (
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                <Card className="p-6">
                  <h3 className="text-xl font-semibold mb-4 flex items-center">
                    <MessageCircle className="mr-2 h-5 w-5 text-primary" />
                    Recent Activity
                  </h3>
                  <div className="space-y-4">
                    {forumPosts.slice(0, 3).map((post) => (
                      <div
                        key={post.id}
                        className="p-3 bg-white/5 rounded-lg border border-white/10"
                      >
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-sm text-white/70">
                            {formatAddress(post.author)}
                          </span>
                          <span className="text-xs text-white/50">
                            {formatDate(post.timestamp)}
                          </span>
                        </div>
                        <p className="text-white/90 text-sm">{post.content}</p>
                      </div>
                    ))}
                  </div>
                </Card>

                <Card className="p-6">
                  <h3 className="text-xl font-semibold mb-4 flex items-center">
                    <FileText className="mr-2 h-5 w-5 text-secondary" />
                    Latest Resources
                  </h3>
                  <div className="space-y-4">
                    {resources.slice(0, 3).map((resource) => (
                      <div
                        key={resource.id}
                        className="p-3 bg-white/5 rounded-lg border border-white/10"
                      >
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-sm font-medium text-white">
                            {resource.title}
                          </span>
                          <span className="text-xs text-white/50">
                            {formatDate(resource.uploadedAt)}
                          </span>
                        </div>
                        <p className="text-white/70 text-sm mb-2">
                          {resource.description}
                        </p>
                        <div className="flex items-center justify-between">
                          <span className="text-xs text-white/50">
                            by {formatAddress(resource.uploadedBy)}
                          </span>
                          <span className="text-xs text-white/50">
                            {resource.downloads} downloads
                          </span>
                        </div>
                      </div>
                    ))}
                  </div>
                </Card>
              </div>
            )}

            {/* Forum Tab */}
            {activeTab === "forum" && (
              <Card className="p-6">
                <div className="flex items-center justify-between mb-6">
                  <h3 className="text-xl font-semibold flex items-center">
                    <MessageCircle className="mr-2 h-5 w-5 text-primary" />
                    Community Forum
                  </h3>
                  <Button
                    onClick={() => setShowNewPostModal(true)}
                    className="flex items-center"
                  >
                    <Plus className="mr-2 h-4 w-4" />
                    New Post
                  </Button>
                </div>

                <div className="space-y-4">
                  {forumPosts.map((post) => (
                    <div
                      key={post.id}
                      className="p-4 bg-white/5 rounded-lg border border-white/10"
                    >
                      <div className="flex items-center justify-between mb-3">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 bg-primary/20 rounded-full flex items-center justify-center">
                            <span className="text-primary text-sm font-medium">
                              {post.author.slice(2, 4).toUpperCase()}
                            </span>
                          </div>
                          <div>
                            <div className="text-sm font-medium text-white">
                              {formatAddress(post.author)}
                            </div>
                            <div className="text-xs text-white/50">
                              {formatDate(post.timestamp)}
                            </div>
                          </div>
                        </div>
                                                 <div className="flex items-center gap-2">
                           <button 
                             className="text-white/50 hover:text-white"
                             onClick={() => handleToggleLike(post.id!)}
                           >
                             <Star className={`h-4 w-4 ${post.likes?.includes(currentAccount?.address || '') ? 'text-yellow-400 fill-current' : ''}`} />
                           </button>
                           <span className="text-xs text-white/50">
                             {post.likes?.length || 0}
                           </span>
                         </div>
                      </div>
                      <p className="text-white/90">{post.content}</p>
                    </div>
                  ))}
                </div>
              </Card>
            )}

            {/* Resources Tab */}
            {activeTab === "resources" && (
              <Card className="p-6">
                <div className="flex items-center justify-between mb-6">
                  <h3 className="text-xl font-semibold flex items-center">
                    <FileText className="mr-2 h-5 w-5 text-secondary" />
                    Community Resources
                  </h3>
                  <Button
                    onClick={() => setShowNewResourceModal(true)}
                    className="flex items-center"
                  >
                    <Plus className="mr-2 h-4 w-4" />
                    Share Resource
                  </Button>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  {resources.map((resource) => (
                    <div
                      key={resource.id}
                      className="p-4 bg-white/5 rounded-lg border border-white/10 hover:border-white/20 transition-colors"
                    >
                      <div className="flex items-start justify-between mb-3">
                        <h4 className="font-medium text-white">
                          {resource.title}
                        </h4>
                        <span className="text-xs text-white/50">
                          {formatDate(resource.uploadedAt)}
                        </span>
                      </div>
                      <p className="text-white/70 text-sm mb-3">
                        {resource.description}
                      </p>
                      <div className="flex items-center justify-between">
                        <span className="text-xs text-white/50">
                          by {formatAddress(resource.uploadedBy)}
                        </span>
                        <div className="flex items-center gap-2">
                                                     <span className="text-xs text-white/50">
                             {resource.downloads || 0} downloads
                           </span>
                           <Button 
                             size="sm" 
                             variant="outline"
                             onClick={() => handleDownloadResource(resource)}
                           >
                             Download
                           </Button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </Card>
            )}

            {/* Members Tab */}
            {activeTab === "members" && (
              <Card className="p-6">
                <h3 className="text-xl font-semibold mb-6 flex items-center">
                  <Users className="mr-2 h-5 w-5 text-accent" />
                  Community Members
                </h3>

                <div className="space-y-4">
                  {members.map((member, index) => (
                    <div
                      key={member.address}
                      className="flex items-center justify-between p-4 bg-white/5 rounded-lg border border-white/10"
                    >
                      <div className="flex items-center gap-4">
                        <div className="w-10 h-10 bg-accent/20 rounded-full flex items-center justify-center">
                          <span className="text-accent text-sm font-medium">
                            {member.address.slice(2, 4).toUpperCase()}
                          </span>
                        </div>
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-medium text-white">
                              {formatAddress(member.address)}
                            </span>
                            {member.isModerator && (
                              <span className="px-2 py-1 bg-primary/20 text-primary text-xs rounded-full">
                                Moderator
                              </span>
                            )}
                            {index === 0 && (
                              <span className="px-2 py-1 bg-yellow-500/20 text-yellow-400 text-xs rounded-full">
                                You
                              </span>
                            )}
                          </div>
                          <div className="text-sm text-white/50">
                            Joined {formatDate(member.joinedAt)}
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-4">
                        <div className="text-right">
                          <div className="text-sm font-medium text-white">
                            {member.contributionScore}
                          </div>
                          <div className="text-xs text-white/50">Points</div>
                        </div>
                        <div className="text-right">
                          <div className="text-sm text-white/50">
                            {formatDate(member.lastActive)}
                          </div>
                          <div className="text-xs text-white/50">
                            Last Active
                          </div>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </Card>
            )}
          </div>
        </div>
      </div>

      {/* New Post Modal */}
      {showNewPostModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80">
          <div className="bg-white/10 backdrop-blur-xl border border-white/20 rounded-lg p-6 max-w-md w-full mx-4">
            <h3 className="text-xl font-semibold mb-4 text-white">
              Create New Post
            </h3>
            <textarea
              value={newPost}
              onChange={(e) => setNewPost(e.target.value)}
              placeholder="Share your thoughts with the community..."
              className="w-full h-32 p-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-white/50 resize-none focus:outline-none focus:border-primary"
            />
            <div className="flex gap-3 mt-4">
              <Button onClick={handleNewPost} className="flex-1">
                <Send className="mr-2 h-4 w-4" />
                Post
              </Button>
              <Button
                variant="outline"
                onClick={() => setShowNewPostModal(false)}
                className="flex-1"
              >
                Cancel
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* New Resource Modal */}
      {showNewResourceModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80">
          <div className="bg-white/10 backdrop-blur-xl border border-white/20 rounded-lg p-6 max-w-md w-full mx-4">
            <h3 className="text-xl font-semibold mb-4 text-white">
              Share Resource
            </h3>
            <div className="space-y-4">
              <input
                type="text"
                value={newResource.title}
                onChange={(e) =>
                  setNewResource({ ...newResource, title: e.target.value })
                }
                placeholder="Resource title"
                className="w-full p-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-white/50 focus:outline-none focus:border-primary"
              />
              <textarea
                value={newResource.description}
                onChange={(e) =>
                  setNewResource({
                    ...newResource,
                    description: e.target.value,
                  })
                }
                placeholder="Resource description"
                className="w-full h-20 p-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-white/50 resize-none focus:outline-none focus:border-primary"
              />
                             <input
                 type="file"
                 onChange={(e) =>
                   setNewResource({ 
                     ...newResource, 
                     file: e.target.files ? e.target.files[0] : null 
                   })
                 }
                 className="w-full p-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-white/50 focus:outline-none focus:border-primary"
                 accept=".pdf,.doc,.docx,.txt,.jpg,.jpeg,.png,.gif,.mp4,.mp3"
               />
            </div>
            <div className="flex gap-3 mt-4">
              <Button onClick={handleNewResource} className="flex-1">
                <Plus className="mr-2 h-4 w-4" />
                Share
              </Button>
              <Button
                variant="outline"
                onClick={() => setShowNewResourceModal(false)}
                className="flex-1"
              >
                Cancel
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Community;
