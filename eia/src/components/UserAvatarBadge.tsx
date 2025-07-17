import { Crown, Shield, Star, Award, Zap } from 'lucide-react';

interface UserAvatarBadgeProps {
  name: string;
  address?: string;
  avatar?: string;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  badge?: {
    type: 'verified' | 'organizer' | 'sponsor' | 'vip' | 'premium';
    level?: number;
  };
  reputation?: number;
  showAddress?: boolean;
  className?: string;
}

const UserAvatarBadge = ({
  name,
  address,
  avatar,
  size = 'md',
  badge,
  reputation,
  showAddress = false,
  className = ''
}: UserAvatarBadgeProps) => {
  const sizeVariants = {
    sm: {
      avatar: 'h-8 w-8',
      text: 'text-sm',
      badge: 'h-4 w-4 -top-1 -right-1'
    },
    md: {
      avatar: 'h-10 w-10',
      text: 'text-base',
      badge: 'h-5 w-5 -top-1.5 -right-1.5'
    },
    lg: {
      avatar: 'h-12 w-12',
      text: 'text-lg',
      badge: 'h-6 w-6 -top-2 -right-2'
    },
    xl: {
      avatar: 'h-16 w-16',
      text: 'text-xl',
      badge: 'h-8 w-8 -top-2 -right-2'
    }
  };

  const badgeConfig = {
    verified: {
      icon: Shield,
      color: 'from-blue-400 to-blue-600',
      bgColor: 'bg-blue-500',
      title: 'Verified User'
    },
    organizer: {
      icon: Star,
      color: 'from-primary to-primary/80',
      bgColor: 'bg-primary',
      title: 'Event Organizer'
    },
    sponsor: {
      icon: Crown,
      color: 'from-accent to-accent/80',
      bgColor: 'bg-accent',
      title: 'Premium Sponsor'
    },
    vip: {
      icon: Award,
      color: 'from-purple-400 to-purple-600',
      bgColor: 'bg-purple-500',
      title: 'VIP Member'
    },
    premium: {
      icon: Zap,
      color: 'from-secondary to-secondary/80',
      bgColor: 'bg-secondary',
      title: 'Premium Member'
    }
  };

  const formatAddress = (addr: string) => {
    return `${addr.slice(0, 6)}...${addr.slice(-4)}`;
  };

  const getInitials = (name: string) => {
    return name
      .split(' ')
      .map(word => word[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);
  };

  const getReputationColor = (rep?: number) => {
    if (!rep) return 'text-white/60';
    if (rep < 3) return 'text-red-400';
    if (rep < 4) return 'text-yellow-400';
    return 'text-green-400';
  };

  const currentSize = sizeVariants[size];
  const badgeInfo = badge ? badgeConfig[badge.type] : null;

  return (
    <div className={`flex items-center gap-3 ${className}`}>
      {/* Avatar with badge */}
      <div className="relative">
        <div className={`${currentSize.avatar} rounded-full overflow-hidden ring-2 ring-white/20 relative`}>
          {avatar ? (
            <img 
              src={avatar} 
              alt={name}
              className="w-full h-full object-cover"
            />
          ) : (
            <div className="w-full h-full bg-gradient-to-r from-primary to-secondary flex items-center justify-center">
              <span className={`font-bold text-white ${size === 'sm' ? 'text-xs' : size === 'lg' ? 'text-lg' : size === 'xl' ? 'text-xl' : 'text-sm'}`}>
                {getInitials(name)}
              </span>
            </div>
          )}
        </div>

        {/* Badge */}
        {badgeInfo && (
          <div 
            className={`absolute ${currentSize.badge} rounded-full ${badgeInfo.bgColor} flex items-center justify-center ring-2 ring-black shadow-lg`}
            title={`${badgeInfo.title}${badge?.level ? ` - Level ${badge.level}` : ''}`}
          >
            <badgeInfo.icon className={`${size === 'sm' ? 'h-2 w-2' : size === 'xl' ? 'h-5 w-5' : 'h-3 w-3'} text-white`} />
          </div>
        )}
      </div>

      {/* User info */}
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className={`font-semibold text-white truncate ${currentSize.text}`}>
            {name}
          </span>
          
          {reputation && (
            <div className="flex items-center gap-1">
              <Star className={`h-3 w-3 ${getReputationColor(reputation)} fill-current`} />
              <span className={`text-xs ${getReputationColor(reputation)}`}>
                {reputation.toFixed(1)}
              </span>
            </div>
          )}
        </div>

        {showAddress && address && (
          <div className="text-xs text-white/60 font-mono mt-0.5">
            {formatAddress(address)}
          </div>
        )}

        {badge && (
          <div className="text-xs text-white/60 mt-0.5">
            {badgeInfo?.title}
            {badge.level && ` • Level ${badge.level}`}
          </div>
        )}
      </div>
    </div>
  );
};

export default UserAvatarBadge; 