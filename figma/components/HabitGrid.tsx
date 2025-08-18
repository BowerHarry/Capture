import { useState } from 'react';
import { Card, CardContent } from "./ui/card";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "./ui/tooltip";
import { Flame } from "lucide-react";
import type { HabitGridProps } from './habit-grid/types';

// Category icons mapping
const CATEGORY_ICONS = {
  'Fitness': '💪',
  'Wellness': '🧘',
  'Learning': '📚',
  'Nutrition': '🥗',
  'Productivity': '⚡',
  'Health': '❤️',
  'Social': '👥',
  'Custom': '🎯'
} as const;

// Category colors using CSS custom properties
const getCategoryColor = (category: string) => {
  const colorMap = {
    'Fitness': 'var(--habit-fitness)',
    'Wellness': 'var(--habit-wellness)',
    'Learning': 'var(--habit-learning)',
    'Nutrition': 'var(--habit-nutrition)',
    'Productivity': 'var(--habit-productivity)',
    'Health': 'var(--habit-health)',
    'Social': 'var(--habit-social)',
    'Custom': 'var(--habit-learning)'
  };
  return colorMap[category as keyof typeof colorMap] || colorMap.Custom;
};

export function HabitGrid({ habit, onDateClick }: HabitGridProps) {
  const [hoveredSquare, setHoveredSquare] = useState<string | null>(null);
  
  // Fixed number of weeks to show - this will be stretched to fill full width
  const numWeeks = 26; // 6 months of data

  // Generate GitHub-style grid: 7 rows (days of week) x N columns (weeks)
  const generateWeeklyGrid = () => {
    const today = new Date();
    const grid: Array<Array<any>> = [[], [], [], [], [], [], []]; // 7 rows for days of week
    const habitColor = getCategoryColor(habit.category);
    
    // Find the Monday of the current week
    const currentWeekStart = new Date(today);
    const dayOfWeek = today.getDay();
    const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1; // Sunday = 0, Monday = 1
    currentWeekStart.setDate(today.getDate() - daysToMonday);
    currentWeekStart.setHours(0, 0, 0, 0);
    
    // Calculate start date: go back (numWeeks - 1) weeks from current week start
    const startDate = new Date(currentWeekStart);
    startDate.setDate(currentWeekStart.getDate() - ((numWeeks - 1) * 7));
    
    // Generate grid data - iterate through weeks starting from oldest
    for (let week = 0; week < numWeeks; week++) {
      for (let dayIndex = 0; dayIndex < 7; dayIndex++) { // 0 = Monday, 6 = Sunday
        const currentDate = new Date(startDate);
        currentDate.setDate(startDate.getDate() + (week * 7) + dayIndex);
        const dateStr = currentDate.toISOString().split('T')[0];
        const todayStr = today.toISOString().split('T')[0];
        
        const completion = habit.dailyCompletions?.[dateStr];
        const isCompleted = !!completion?.completed;
        const isToday = dateStr === todayStr;
        const isFuture = currentDate > today;
        
        grid[dayIndex].push({
          date: dateStr,
          dateObj: new Date(currentDate),
          completed: isCompleted,
          isToday,
          isFuture,
          week,
          dayOfWeek: dayIndex,
          completion
        });
      }
    }
    
    return { grid, habitColor };
  };

  const { grid, habitColor } = generateWeeklyGrid();
  const completedCount = grid.flat().filter(square => square.completed && !square.isFuture).length;
  const categoryIcon = CATEGORY_ICONS[habit.category as keyof typeof CATEGORY_ICONS] || CATEGORY_ICONS.Custom;

  return (
    <Card className="bg-card border border-border/60 overflow-hidden">
      <CardContent className="p-4">
        <div className="space-y-4">
          {/* Header */}
          <div className="flex items-center justify-between">
            <div className="flex items-center space-x-3">
              <div 
                className="w-8 h-8 rounded-lg flex items-center justify-center text-lg"
                style={{ 
                  backgroundColor: `color-mix(in srgb, ${habitColor} 20%, transparent)`, 
                  color: habitColor 
                }}
              >
                {categoryIcon}
              </div>
              <div>
                <h3 className="font-semibold text-foreground">{habit.name}</h3>
                <div className="flex items-center space-x-1 text-xs text-muted-foreground">
                  <Flame className="w-3 h-3 text-orange-500" />
                  <span>{habit.streak} day streak</span>
                </div>
              </div>
            </div>
          </div>

          {/* GitHub-style Grid - Full Width using Flex */}
          <div className="w-full">
            <TooltipProvider>
              <div className="flex w-full gap-1">
                {/* Grid squares - iterate through weeks (columns) */}
                {Array.from({ length: numWeeks }, (_, weekIndex) => (
                  <div key={weekIndex} className="flex flex-col gap-1 flex-1 min-w-0">
                    {/* Iterate through days of week (rows) */}
                    {grid.map((dayRow, dayIndex) => {
                      const square = dayRow[weekIndex];
                      if (!square) return <div key={dayIndex} className="aspect-square" />;
                      
                      return (
                        <Tooltip key={`${weekIndex}-${dayIndex}`}>
                          <TooltipTrigger asChild>
                            <div
                              role="button"
                              tabIndex={square.isFuture ? -1 : 0}
                              className={`
                                aspect-square w-full rounded-sm border cursor-pointer transition-all duration-200
                                ${square.isToday ? 'ring-1 ring-blue-400 ring-offset-1' : ''}
                                ${hoveredSquare === `${weekIndex}-${dayIndex}` ? 'scale-125 z-10 relative' : ''}
                                ${square.isFuture ? 'cursor-not-allowed opacity-50' : 'hover:scale-110'}
                              `}
                              style={{
                                backgroundColor: square.completed ? habitColor : 'transparent',
                                borderColor: square.completed ? habitColor : 'var(--border)',
                                borderWidth: '1px'
                              }}
                              onMouseEnter={() => setHoveredSquare(`${weekIndex}-${dayIndex}`)}
                              onMouseLeave={() => setHoveredSquare(null)}
                              onClick={() => !square.isFuture && onDateClick?.(square.date)}
                            />
                          </TooltipTrigger>
                          <TooltipContent>
                            <div className="text-center space-y-1">
                              <p className="font-medium text-xs">
                                {square.dateObj.toLocaleDateString('en-US', { 
                                  weekday: 'short', 
                                  month: 'short', 
                                  day: 'numeric' 
                                })}
                              </p>
                              {square.completed ? (
                                <p className="text-green-400 text-xs">✅ Completed!</p>
                              ) : square.isFuture ? (
                                <p className="text-gray-400 text-xs">Future</p>
                              ) : (
                                <p className="text-gray-400 text-xs">Not completed</p>
                              )}
                              {square.isToday && (
                                <p className="text-blue-400 text-xs">Today</p>
                              )}
                            </div>
                          </TooltipContent>
                        </Tooltip>
                      );
                    })}
                  </div>
                ))}
              </div>
            </TooltipProvider>
          </div>

          {/* Simple Stats */}
          <div className="pt-2 border-t border-border/30">
            <div className="text-xs text-muted-foreground">
              <span className="text-foreground font-medium">{completedCount}</span> captures in the last {Math.floor(numWeeks / 4)} months
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}