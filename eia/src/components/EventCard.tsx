import { Calendar, MapPin, Users, Trophy, QrCode } from 'lucide-react';
import { Link } from 'react-router-dom';
import Card from './Card';
import Button from './Button';
import type { Event } from '../types';

interface EventCardProps {
  event: Event;
  showActions?: boolean;
  variant?: 'grid' | 'list';
}

const EventCard = ({ event, showActions = true, variant = 'grid' }: EventCardProps) => {
  const formatDate = (date: Date) => {
    return date.toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    });
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      hour12: true,
    });
  };

  const getStatusColor = (status: Event['status']) => {
    switch (status) {
      case 'upcoming': return 'text-accent bg-accent/20';
      case 'ongoing': return 'text-secondary bg-secondary/20';
      case 'completed': return 'text-primary bg-primary/20';
      case 'cancelled': return 'text-red-400 bg-red-400/20';
      default: return 'text-white/70 bg-white/10';
    }
  };

  const attendancePercentage = event.currentAttendees > 0 
    ? (event.checkInCount / event.currentAttendees) * 100 
    : 0;

  if (variant === 'list') {
    return (
      <Card hover className="p-4">
        <div className="flex items-center space-x-4">
          {/* Event Image */}
          <div className="flex-shrink-0">
            {event.bannerImage ? (
              <img 
                src={event.bannerImage} 
                alt={event.title}
                className="w-20 h-20 rounded-lg object-cover"
              />
            ) : (
              <div className="w-20 h-20 rounded-lg bg-gradient-to-br from-primary to-secondary flex items-center justify-center">
                <Calendar className="h-8 w-8 text-white" />
              </div>
            )}
          </div>

          {/* Event Info */}
          <div className="flex-1 min-w-0">
            <div className="flex items-start justify-between mb-2">
              <div className="flex-1">
                <Link 
                  to={`/event/${event.id}`}
                  className="text-lg font-semibold hover:text-primary transition-colors"
                >
                  {event.title}
                </Link>
                <span className={`ml-2 px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(event.status)}`}>
                  {event.status.charAt(0).toUpperCase() + event.status.slice(1)}
                </span>
              </div>
              <div className="text-right">
                <div className="text-lg font-bold text-primary">{event.checkInCount}</div>
                <div className="text-xs text-white/60">check-ins</div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-2 text-sm text-white/70 mb-3">
              <div className="flex items-center">
                <Calendar className="mr-1 h-4 w-4" />
                <span>{formatDate(event.date)} {formatTime(event.date)}</span>
              </div>
              <div className="flex items-center">
                <MapPin className="mr-1 h-4 w-4" />
                <span className="truncate">{event.location}</span>
              </div>
              <div className="flex items-center">
                <Users className="mr-1 h-4 w-4" />
                <span>{event.currentAttendees}{event.maxAttendees && ` / ${event.maxAttendees}`}</span>
              </div>
            </div>

            {/* Progress bar */}
            <div className="mb-3">
              <div className="flex justify-between text-xs text-white/60 mb-1">
                <span>Attendance Progress</span>
                <span>{Math.round(attendancePercentage)}%</span>
              </div>
              <div className="w-full bg-white/10 rounded-full h-1.5">
                <div 
                  className="bg-gradient-to-r from-primary to-secondary h-1.5 rounded-full transition-all duration-300"
                  style={{ width: `${attendancePercentage}%` }}
                />
              </div>
            </div>
          </div>

          {/* Actions */}
          {showActions && (
            <div className="flex-shrink-0">
              <Button size="sm" variant="outline">
                View Details
              </Button>
            </div>
          )}
        </div>
      </Card>
    );
  }

  // Grid variant (default)
  return (
    <Card hover className="p-6 h-full flex flex-col">
      {/* Event Image */}
      <div className="mb-4">
        {event.bannerImage ? (
          <img 
            src={event.bannerImage} 
            alt={event.title}
            className="w-full h-48 rounded-lg object-cover"
          />
        ) : (
          <div className="w-full h-48 rounded-lg bg-gradient-to-br from-primary to-secondary flex items-center justify-center">
            <Calendar className="h-16 w-16 text-white" />
          </div>
        )}
      </div>

      {/* Event Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex-1">
          <Link 
            to={`/event/${event.id}`}
            className="text-xl font-semibold hover:text-primary transition-colors block"
          >
            {event.title}
          </Link>
          <span className={`inline-block mt-1 px-3 py-1 rounded-full text-xs font-medium ${getStatusColor(event.status)}`}>
            {event.status.charAt(0).toUpperCase() + event.status.slice(1)}
          </span>
        </div>
        <div className="text-right ml-4">
          <div className="text-2xl font-bold text-primary">{event.checkInCount}</div>
          <div className="text-xs text-white/60">check-ins</div>
        </div>
      </div>

      {/* Event Details */}
      <div className="space-y-2 mb-4 flex-1">
        <div className="flex items-center text-white/70">
          <Calendar className="mr-2 h-4 w-4 flex-shrink-0" />
          <span className="text-sm">{formatDate(event.date)} at {formatTime(event.date)}</span>
        </div>
        
        <div className="flex items-center text-white/70">
          <MapPin className="mr-2 h-4 w-4 flex-shrink-0" />
          <span className="text-sm truncate">{event.location}</span>
        </div>
        
        <div className="flex items-center text-white/70">
          <Users className="mr-2 h-4 w-4 flex-shrink-0" />
          <span className="text-sm">
            {event.currentAttendees}
            {event.maxAttendees && ` / ${event.maxAttendees}`} attendees
          </span>
        </div>

        {event.completionNFT && (
          <div className="flex items-center text-accent">
            <Trophy className="mr-2 h-4 w-4 flex-shrink-0" />
            <span className="text-sm">NFT Reward Available</span>
          </div>
        )}
      </div>

      {/* Progress Bar */}
      <div className="mb-4">
        <div className="flex justify-between text-xs text-white/60 mb-1">
          <span>Attendance Progress</span>
          <span>{Math.round(attendancePercentage)}%</span>
        </div>
        <div className="w-full bg-white/10 rounded-full h-2">
          <div 
            className="bg-gradient-to-r from-primary to-secondary h-2 rounded-full transition-all duration-300"
            style={{ width: `${attendancePercentage}%` }}
          />
        </div>
      </div>

      {/* Action Buttons */}
      {showActions && (
        <div className="space-y-2">
          {event.status === 'upcoming' && (
            <Button size="sm" className="w-full">
              <QrCode className="mr-2 h-4 w-4" />
              Show QR Code
            </Button>
          )}
          
          {event.status === 'completed' && event.completionNFT && (
            <Button size="sm" variant="outline" className="w-full">
              <Trophy className="mr-2 h-4 w-4" />
              View NFT
            </Button>
          )}

          <Link to={`/event/${event.id}`}>
            <Button variant="ghost" size="sm" className="w-full">
              View Details
            </Button>
          </Link>
        </div>
      )}
    </Card>
  );
};

export default EventCard; 