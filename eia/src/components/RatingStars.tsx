import { useState } from "react";
import { Star } from "lucide-react";

interface RatingStarsProps {
  rating: number;
  maxRating?: number;
  size?: "sm" | "md" | "lg";
  interactive?: boolean;
  onRatingChange?: (rating: number) => void;
  showLabel?: boolean;
  className?: string;
}

const RatingStars = ({
  rating,
  maxRating = 5,
  size = "md",
  interactive = false,
  onRatingChange,
  showLabel = false,
  className = "",
}: RatingStarsProps) => {
  const [hoverRating, setHoverRating] = useState(0);

  const sizeVariants = {
    sm: "h-4 w-4",
    md: "h-5 w-5",
    lg: "h-6 w-6",
  };

  const handleStarClick = (starRating: number) => {
    if (interactive && onRatingChange) {
      onRatingChange(starRating);
    }
  };

  const handleStarHover = (starRating: number) => {
    if (interactive) {
      setHoverRating(starRating);
    }
  };

  const handleMouseLeave = () => {
    if (interactive) {
      setHoverRating(0);
    }
  };

  const displayRating = hoverRating || rating;

  const getRatingLabel = (rating: number) => {
    if (rating === 0) return "No rating";
    if (rating <= 1) return "Poor";
    if (rating <= 2) return "Fair";
    if (rating <= 3) return "Good";
    if (rating <= 4) return "Very Good";
    return "Excellent";
  };

  return (
    <div className={`flex items-center gap-2 ${className}`}>
      {/* Stars */}
      <div className="flex items-center gap-1" onMouseLeave={handleMouseLeave}>
        {[...Array(maxRating)].map((_, index) => {
          const starRating = index + 1;
          const isFilled = starRating <= displayRating;
          const isHalfFilled =
            starRating - 0.5 <= displayRating && starRating > displayRating;

          return (
            <button
              key={index}
              className={`
                relative transition-all duration-200 
                ${
                  interactive
                    ? "cursor-pointer hover:scale-110"
                    : "cursor-default"
                }
                ${
                  interactive && hoverRating >= starRating
                    ? "transform scale-110"
                    : ""
                }
              `}
              onClick={() => handleStarClick(starRating)}
              onMouseEnter={() => handleStarHover(starRating)}
              disabled={!interactive}
            >
              <Star
                className={`
                  ${sizeVariants[size]} transition-colors duration-200
                  ${
                    isFilled || isHalfFilled
                      ? "text-accent fill-accent"
                      : interactive && hoverRating >= starRating
                      ? "text-accent/70 fill-accent/70"
                      : "text-white/30"
                  }
                `}
              />

              {/* Half star overlay */}
              {isHalfFilled && (
                <div className="absolute inset-0 overflow-hidden w-1/2">
                  <Star
                    className={`${sizeVariants[size]} text-accent fill-accent`}
                  />
                </div>
              )}
            </button>
          );
        })}
      </div>

      {/* Rating text */}
      {showLabel && (
        <div className="flex items-center gap-2 text-sm">
          <span className="font-medium text-white">
            {displayRating.toFixed(1)}
          </span>
          <span className="text-white/60">
            ({getRatingLabel(displayRating)})
          </span>
        </div>
      )}
    </div>
  );
};

export default RatingStars;
