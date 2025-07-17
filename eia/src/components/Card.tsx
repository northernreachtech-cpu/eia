import React from 'react';
import { cn } from '../utils/cn';

interface CardProps {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
}

const Card = ({ children, className, hover = false }: CardProps) => {
  return (
    <div
      className={cn(
        'card-glass p-6',
        hover && 'hover:bg-white/10 hover:scale-105 cursor-pointer transition-all duration-300',
        className
      )}
    >
      {children}
    </div>
  );
};

export default Card; 