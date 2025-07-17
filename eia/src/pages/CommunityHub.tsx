import { useState } from 'react';
import { MessageSquare, Shield, Users, Crown, Lock, Send, Heart, Reply } from 'lucide-react';
import Card from '../components/Card';
import Button from '../components/Button';
import UserAvatarBadge from '../components/UserAvatarBadge';
import useScrollToTop from '../hooks/useScrollToTop';

interface Message {
  id: string;
  author: {
    name: string;
    badge?: {
      type: 'verified' | 'organizer' | 'sponsor' | 'vip' | 'premium';
      level?: number;
    };
  };
  content: string;
  timestamp: string;
  likes: number;
  replies: number;
}

const CommunityHub = () => {
  useScrollToTop();
  
  const [hasAccess, setHasAccess] = useState(false);
  const [newMessage, setNewMessage] = useState('');
  
  const [messages] = useState<Message[]>([
    {
      id: '1',
      author: {
        name: 'Alice Chen',
        badge: { type: 'organizer', level: 5 }
      },
      content: 'Just finished organizing an amazing Web3 conference! The energy from the community was incredible. Thanks to everyone who attended! ���',
      timestamp: '2 hours ago',
      likes: 24,
      replies: 8
    },
    {
      id: '2',
      author: {
        name: 'Marcus Johnson',
        badge: { type: 'sponsor', level: 3 }
      },
      content: 'Looking for feedback on sponsorship packages for upcoming DeFi events. What value propositions matter most to organizers?',
      timestamp: '4 hours ago',
      likes: 12,
      replies: 15
    },
    {
      id: '3',
      author: {
        name: 'Sarah Williams',
        badge: { type: 'premium', level: 4 }
      },
      content: 'Pro tip: Always have a backup plan for outdoor events. Weather can be unpredictable, but great planning makes all the difference! ⛈️→☀️',
      timestamp: '6 hours ago',
      likes: 18,
      replies: 5
    }
  ]);

  const handlePostMessage = () => {
    if (newMessage.trim()) {
      setNewMessage('');
    }
  };

  const mockNFTCheck = () => {
    setHasAccess(true);
  };

  if (!hasAccess) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-black">
        {/* Fixed navbar spacing */}
        <div className="pt-24 pb-8 flex items-center justify-center min-h-screen">
          <div className="container mx-auto px-4 sm:px-6 lg:px-8">
            <Card className="max-w-md mx-auto p-6 sm:p-8 text-center">
              <div className="mb-6">
                <div className="w-20 h-20 mx-auto mb-4 rounded-full bg-gradient-to-r from-accent/20 to-primary/20 flex items-center justify-center border border-accent/30">
                  <Lock className="h-10 w-10 text-accent" />
                </div>
                <h2 className="text-2xl font-bold text-white mb-2">Token-Gated Access</h2>
                <p className="text-white/60 leading-relaxed">
                  This community hub is exclusive to EIA Protocol badge holders. Connect your wallet to verify your membership.
                </p>
              </div>

              <div className="bg-gradient-to-r from-accent/10 to-primary/10 rounded-xl p-4 mb-6 border border-accent/20">
                <Crown className="h-8 w-8 text-accent mx-auto mb-2" />
                <div className="text-sm text-white/80 mb-1">Required Badge</div>
                <div className="font-semibold text-accent">EIA Community Member NFT</div>
              </div>

              <div className="space-y-3">
                <Button onClick={mockNFTCheck} className="w-full">
                  <Shield className="mr-2 h-4 w-4" />
                  Verify NFT Badge
                </Button>
                <Button variant="outline" className="w-full">
                  Learn About Badges
                </Button>
              </div>

              <div className="mt-6 pt-6 border-t border-white/10">
                <p className="text-xs text-white/50">
                  New to EIA Protocol? Attend an event to earn your first badge!
                </p>
              </div>
            </Card>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-black via-gray-900 to-black">
      {/* Fixed navbar spacing */}
      <div className="pt-24 pb-8">
        <div className="container mx-auto px-4 sm:px-6 lg:px-8 max-w-4xl">
          {/* Header */}
          <div className="text-center mb-8">
            <div className="flex items-center justify-center gap-3 mb-4">
              <Crown className="h-6 w-6 sm:h-8 sm:w-8 text-accent" />
              <h1 className="text-3xl sm:text-4xl lg:text-5xl font-bold bg-gradient-to-r from-primary to-secondary text-transparent bg-clip-text">
                Community Hub
              </h1>
              <Crown className="h-6 w-6 sm:h-8 sm:w-8 text-accent" />
            </div>
            <p className="text-white/60 text-sm sm:text-base">
              Exclusive space for EIA Protocol badge holders
            </p>
          </div>

          {/* Access Status */}
          <Card className="p-4 sm:p-6 mb-6 bg-gradient-to-r from-green-400/10 to-accent/10 border-green-400/20">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
              <div className="flex items-center gap-3">
                <Shield className="h-5 w-5 text-green-400 flex-shrink-0" />
                <span className="text-green-400 font-medium">Access Verified</span>
                <span className="px-2 py-1 rounded-full bg-accent/20 text-accent text-xs font-medium">
                  Community Member
                </span>
              </div>
              <div className="flex items-center gap-2 text-sm text-white/60">
                <Users className="h-4 w-4" />
                <span>247 active members</span>
              </div>
            </div>
          </Card>

          {/* Post New Message */}
          <Card className="p-4 sm:p-6 mb-6">
            <div className="flex flex-col sm:flex-row items-start gap-4">
              <div className="flex-shrink-0">
                <UserAvatarBadge
                  name="You"
                  badge={{ type: 'premium', level: 1 }}
                  size="md"
                />
              </div>
              <div className="flex-1 w-full">
                <textarea
                  value={newMessage}
                  onChange={(e) => setNewMessage(e.target.value)}
                  placeholder="Share your thoughts with the community..."
                  className="w-full p-3 sm:p-4 bg-white/5 border border-white/20 rounded-lg text-white placeholder-white/40 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary/50 resize-none transition-all"
                  rows={3}
                />
                <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 mt-3">
                  <div className="text-xs text-white/50">
                    Remember to keep discussions respectful and on-topic
                  </div>
                  <Button 
                    onClick={handlePostMessage}
                    disabled={!newMessage.trim()}
                    size="sm"
                    className="sm:w-auto w-full"
                  >
                    <Send className="mr-2 h-4 w-4" />
                    Post
                  </Button>
                </div>
              </div>
            </div>
          </Card>

          {/* Message Board */}
          <div className="space-y-4 sm:space-y-6">
            {messages.map((message) => (
              <Card key={message.id} className="p-4 sm:p-6 hover:shadow-lg hover:shadow-primary/5 transition-all duration-300 border border-white/10 hover:border-primary/20">
                <div className="flex flex-col sm:flex-row items-start gap-4">
                  <div className="flex-shrink-0">
                    <UserAvatarBadge
                      name={message.author.name}
                      badge={message.author.badge}
                      size="md"
                    />
                  </div>
                  
                  <div className="flex-1 w-full min-w-0">
                    <div className="flex flex-col sm:flex-row sm:items-center gap-2 mb-3">
                      <span className="font-medium text-white">{message.author.name}</span>
                      <span className="text-white/40 hidden sm:inline">•</span>
                      <span className="text-sm text-white/60">{message.timestamp}</span>
                    </div>
                    
                    <p className="text-white/80 mb-4 leading-relaxed break-words">
                      {message.content}
                    </p>
                    
                    <div className="flex items-center gap-4 sm:gap-6">
                      <button className="flex items-center gap-2 text-white/60 hover:text-red-400 transition-colors group">
                        <Heart className="h-4 w-4 group-hover:scale-110 transition-transform" />
                        <span className="text-sm font-medium">{message.likes}</span>
                      </button>
                      
                      <button className="flex items-center gap-2 text-white/60 hover:text-primary transition-colors group">
                        <Reply className="h-4 w-4 group-hover:scale-110 transition-transform" />
                        <span className="text-sm font-medium">{message.replies} replies</span>
                      </button>
                    </div>
                  </div>
                </div>
              </Card>
            ))}
          </div>

          {/* Community Guidelines */}
          <Card className="p-4 sm:p-6 mt-8 bg-gradient-to-r from-primary/5 to-secondary/5 border-primary/20">
            <h3 className="text-lg font-semibold text-white mb-3 flex items-center gap-2">
              <MessageSquare className="h-5 w-5 text-primary" />
              Community Guidelines
            </h3>
            <ul className="text-sm text-white/70 space-y-2 leading-relaxed">
              <li>• Be respectful and constructive in all interactions</li>
              <li>• Share valuable insights about event organization and Web3</li>
              <li>• No spam, self-promotion, or off-topic content</li>
              <li>• Help fellow community members grow and succeed</li>
            </ul>
          </Card>
        </div>
      </div>
    </div>
  );
};

export default CommunityHub;
