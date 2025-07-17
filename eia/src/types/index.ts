import React from 'react';

// User and Authentication Types
export interface User {
  id: string;
  walletAddress: string;
  email?: string;
  username?: string;
  avatar?: string;
  reputation?: number;
}

// Event Types
export interface Event {
  id: string;
  title: string;
  description: string;
  location: string;
  date: Date;
  bannerImage?: string;
  organizerId: string;
  organizer: User;
  status: 'upcoming' | 'ongoing' | 'completed' | 'cancelled';
  maxAttendees?: number;
  currentAttendees: number;
  checkInCount: number;
  completionNFT?: NFTMetadata;
  sponsors?: Sponsor[];
  isTokenGated?: boolean;
  requiredToken?: string;
}

// NFT Types
export interface NFTMetadata {
  id: string;
  name: string;
  description: string;
  image: string;
  attributes: Array<{
    trait_type: string;
    value: string | number;
  }>;
}

// Sponsor Types
export interface Sponsor {
  id: string;
  name: string;
  logo: string;
  targetKPIs: KPI[];
  escrowAmount: number;
  escrowStatus: 'pending' | 'locked' | 'released' | 'refunded';
}

export interface KPI {
  id: string;
  name: string;
  target: number;
  current: number;
  unit: string;
  type: 'attendance' | 'completion' | 'rating' | 'custom';
}

// Attendance Types
export interface Attendance {
  id: string;
  userId: string;
  eventId: string;
  status: 'registered' | 'checked-in' | 'completed';
  checkInTime?: Date;
  completionTime?: Date;
  rating?: number;
  qrCode?: string;
}

// Component Props Types
export interface ButtonProps {
  children: React.ReactNode;
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  loading?: boolean;
  onClick?: () => void;
  className?: string;
  type?: 'button' | 'submit' | 'reset';
}

export interface CardProps {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
}

export interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  size?: 'sm' | 'md' | 'lg' | 'xl';
} 