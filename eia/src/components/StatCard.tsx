import { type ElementType } from "react";
import Card from "./Card";

interface StatCardProps {
  title: string;
  value: string | number;
  icon: ElementType;
  trend?: {
    value: number;
    isPositive: boolean;
  };
  description?: string;
  color?: "primary" | "secondary" | "accent" | "success" | "warning" | "danger";
}

const StatCard = ({
  title,
  value,
  icon: Icon,
  trend,
  description,
  color = "primary",
}: StatCardProps) => {
  const colorVariants = {
    primary: {
      gradient: "from-primary/20 via-primary/10 to-transparent",
      iconBg: "from-primary to-primary/80",
      trendColor: "text-primary",
    },
    secondary: {
      gradient: "from-secondary/20 via-secondary/10 to-transparent",
      iconBg: "from-secondary to-secondary/80",
      trendColor: "text-secondary",
    },
    accent: {
      gradient: "from-accent/20 via-accent/10 to-transparent",
      iconBg: "from-accent to-accent/80",
      trendColor: "text-accent",
    },
    success: {
      gradient: "from-green-400/20 via-green-400/10 to-transparent",
      iconBg: "from-green-400 to-green-500",
      trendColor: "text-green-400",
    },
    warning: {
      gradient: "from-yellow-400/20 via-yellow-400/10 to-transparent",
      iconBg: "from-yellow-400 to-yellow-500",
      trendColor: "text-yellow-400",
    },
    danger: {
      gradient: "from-red-400/20 via-red-400/10 to-transparent",
      iconBg: "from-red-400 to-red-500",
      trendColor: "text-red-400",
    },
  };

  const colorConfig = colorVariants[color];

  return (
    <Card className="p-6 relative overflow-hidden group hover:shadow-lg transition-all duration-300">
      {/* Background gradient */}
      <div
        className={`absolute inset-0 bg-gradient-to-br ${colorConfig.gradient} opacity-50 group-hover:opacity-70 transition-opacity`}
      />

      {/* Content */}
      <div className="relative z-10">
        <div className="flex items-start justify-between mb-4">
          <div className="flex-1">
            <p className="text-sm text-white/70 mb-1 font-open-sans">{title}</p>
            <p className="text-3xl font-bold text-white font-livvic">{value}</p>
          </div>

          {/* Icon */}
          <div
            className={`w-12 h-12 rounded-xl bg-gradient-to-r ${colorConfig.iconBg} flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform`}
          >
            <Icon className="h-6 w-6 text-white" />
          </div>
        </div>

        {/* Description and trend */}
        <div className="flex items-center justify-between">
          {description && (
            <p className="text-sm text-white/60 flex-1 font-open-sans">{description}</p>
          )}

          {trend && (
            <div
              className={`flex items-center text-sm font-medium font-open-sans ${
                trend.isPositive ? "text-green-400" : "text-red-400"
              }`}
            >
              <span className="mr-1">{trend.isPositive ? "↗" : "↘"}</span>
              {Math.abs(trend.value)}%
            </div>
          )}
        </div>
      </div>
    </Card>
  );
};

export default StatCard;
