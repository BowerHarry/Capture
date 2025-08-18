import { GITHUB_COLORS_INLINE } from './constants';

interface HabitGridLegendProps {
  className?: string;
}

export function HabitGridLegend({ className = "" }: HabitGridLegendProps) {
  // Check if we're in dark mode
  const isDarkMode = document.documentElement.classList.contains('dark');

  return (
    <div className={`flex items-center space-x-3 text-xs text-muted-foreground ${className}`}>
      <span className="font-medium">Activity:</span>
      <div className="flex items-center space-x-1">
        <div 
          className="w-3 h-3 rounded-sm border border-gray-300 dark:border-gray-600"
          style={isDarkMode ? GITHUB_COLORS_INLINE.noneDark : GITHUB_COLORS_INLINE.none}
        ></div>
        <span>None</span>
      </div>
      <div className="flex items-center space-x-1">
        <div 
          className="w-3 h-3 rounded-sm"
          style={isDarkMode ? GITHUB_COLORS_INLINE.lowDark : GITHUB_COLORS_INLINE.low}
        ></div>
        <span>Low</span>
      </div>
      <div className="flex items-center space-x-1">
        <div 
          className="w-3 h-3 rounded-sm"
          style={isDarkMode ? GITHUB_COLORS_INLINE.highDark : GITHUB_COLORS_INLINE.high}
        ></div>
        <span>High</span>
      </div>
    </div>
  );
}