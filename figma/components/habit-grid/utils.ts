import { MONTH_NAMES } from './constants';
import type { HabitGridDay } from './types';

// Generate a GitHub-style weekly grid (7 rows x N columns) that includes current week
export const generateResponsiveWeeklyGrid = (
  habit: any,
  numWeeks: number = 23 // Increased default by 3
): { grid: HabitGridDay[][]; totalWeeks: number; currentWeekIndex: number } => {
  const today = new Date();
  const grid: HabitGridDay[][] = [[], [], [], [], [], [], []]; // 7 rows for days of week
  
  // Find the Monday of the current week
  const currentWeekStart = new Date(today);
  const dayOfWeek = today.getDay();
  const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1; // Sunday = 0, Monday = 1
  currentWeekStart.setDate(today.getDate() - daysToMonday);
  currentWeekStart.setHours(0, 0, 0, 0);
  
  // Calculate start date: go back (numWeeks - 1) weeks from current week start
  // This ensures current week is the last (rightmost) column
  const startDate = new Date(currentWeekStart);
  startDate.setDate(currentWeekStart.getDate() - ((numWeeks - 1) * 7));
  
  // Generate grid data
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
      
      // Count completion intensity (for multiple completions in a day)
      const completionCount = completion?.completed ? 1 : 0;
      
      grid[dayIndex].push({
        date: dateStr,
        completed: isCompleted,
        completionCount,
        isToday,
        isFuture,
        photoUrl: completion?.photoUrl,
        dayOfMonth: currentDate.getDate(),
        month: currentDate.getMonth(),
        completion,
        week,
        dayOfWeek: dayIndex
      });
    }
  }
  
  // Current week should be the last column (index: numWeeks - 1)
  const currentWeekIndex = numWeeks - 1;
  
  return { grid, totalWeeks: numWeeks, currentWeekIndex };
};

// Legacy function for backwards compatibility
export const generateWeeklyGrid = (
  habit: any
): { grid: HabitGridDay[][]; totalWeeks: number } => {
  const result = generateResponsiveWeeklyGrid(habit, 23); // Increased default by 3
  return { grid: result.grid, totalWeeks: result.totalWeeks };
};

// Generate a simple date grid (flattened for legacy compatibility)
export const generateDateGrid = (
  habit: any
): HabitGridDay[] => {
  const { grid } = generateResponsiveWeeklyGrid(habit, 23); // Increased default by 3
  return grid.flat(); // Flatten to 1D array for legacy compatibility
};

// Calculate optimal number of weeks based on viewport width
export const calculateOptimalWeeks = (viewportWidth: number = window.innerWidth): number => {
  // Each square is 12px (w-3) + 4px gap = 16px per week
  // Account for card padding and margins
  const availableWidth = viewportWidth - 64; // Account for padding and margins
  const weeksToShow = Math.max(18, Math.floor(availableWidth / 16)); // Minimum 18 weeks (increased by 3)
  return Math.min(33, weeksToShow); // Maximum 33 weeks (increased by 3)
};

// Get habit-specific color for squares
export const getHabitSquareColor = (
  day: HabitGridDay, 
  habitCategory: string,
  isDarkMode: boolean = false
): React.CSSProperties => {
  // Use CSS custom properties for colors
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

  const habitColor = getCategoryColor(habitCategory);
  
  if (day.isFuture) {
    return {
      backgroundColor: 'transparent',
      borderColor: 'var(--border)',
      borderWidth: '1px',
      opacity: 0.5
    };
  }
  
  if (!day.completed) {
    return {
      backgroundColor: 'transparent',
      borderColor: 'var(--border)',
      borderWidth: '1px'
    };
  }
  
  // Use habit-specific color for completed days
  return {
    backgroundColor: habitColor,
    borderColor: habitColor,
    borderWidth: '1px'
  };
};

export const getSquareColor = (day: HabitGridDay): string => {
  if (day.isFuture) {
    return 'bg-transparent border-border opacity-50';
  }
  if (!day.completed) {
    return 'bg-transparent border-border';
  }
  
  // This will be overridden by habit-specific colors
  return 'bg-green-500';
};

export const getSquareStyle = (day: HabitGridDay, isDarkMode: boolean = false): React.CSSProperties => {
  if (day.isFuture) {
    return {
      backgroundColor: 'transparent',
      borderColor: 'var(--border)',
      borderWidth: '1px',
      opacity: 0.5
    };
  }
  if (!day.completed) {
    return {
      backgroundColor: 'transparent',
      borderColor: 'var(--border)',
      borderWidth: '1px'
    };
  }
  
  // Default to green - will be overridden by habit-specific colors
  return {
    backgroundColor: 'var(--habit-wellness)',
    borderColor: 'var(--habit-wellness)',
    borderWidth: '1px'
  };
};

export const getStreakText = (
  streak: number, 
  targetPeriod: 'day' | 'week' | 'month' = 'day'
): string => {
  if (streak === 0) return 'No streak';
  if (streak === 1) {
    switch (targetPeriod) {
      case 'day': return '1 day streak';
      case 'week': return '1 week streak';
      case 'month': return '1 month streak';
      default: return '1 day streak';
    }
  }
  
  switch (targetPeriod) {
    case 'day': return `${streak} day streak`;
    case 'week': return `${streak} week streak`;
    case 'month': return `${streak} month streak`;
    default: return `${streak} day streak`;  
  }
};

export const calculateStats = (dateGrid: HabitGridDay[]) => {
  const completedDays = dateGrid.filter(day => day.completed).length;
  const eligibleDays = dateGrid.filter(day => !day.isFuture).length;
  const completionRate = eligibleDays > 0 ? Math.round((completedDays / eligibleDays) * 100) : 0;
  
  return { completedDays, eligibleDays, completionRate };
};

export const getCurrentMonthName = (): string => {
  return MONTH_NAMES[new Date().getMonth()];
};

// Calculate stats for responsive grid with "captures" terminology
export const calculateResponsiveStats = (dateGrid: HabitGridDay[], numWeeks: number) => {
  const completedDays = dateGrid.filter(day => day.completed && !day.isFuture).length;
  const totalDays = dateGrid.filter(day => !day.isFuture).length;
  const completionRate = totalDays > 0 ? Math.round((completedDays / totalDays) * 100) : 0;
  const monthsShown = Math.floor(numWeeks / 4);
  
  return { completedDays, totalDays, completionRate, monthsShown };
};

// Get current week index (0-based, where 0 is the oldest week)
export const getCurrentWeekIndex = (numWeeks: number): number => {
  return numWeeks - 1; // Current week should be the last (rightmost) column
};

// Check if a given date is in the current week
export const isCurrentWeek = (date: Date): boolean => {
  const today = new Date();
  const startOfWeek = new Date(today);
  startOfWeek.setDate(today.getDate() - ((today.getDay() + 6) % 7)); // Monday of current week
  startOfWeek.setHours(0, 0, 0, 0);
  
  const endOfWeek = new Date(startOfWeek);
  endOfWeek.setDate(startOfWeek.getDate() + 6); // Sunday of current week
  endOfWeek.setHours(23, 59, 59, 999);
  
  return date >= startOfWeek && date <= endOfWeek;
};

// Find which week column contains today
export const findTodayWeekIndex = (grid: HabitGridDay[][], today: Date): number => {
  const todayStr = today.toISOString().split('T')[0];
  
  for (let weekIndex = 0; weekIndex < grid[0]?.length || 0; weekIndex++) {
    for (let dayIndex = 0; dayIndex < 7; dayIndex++) {
      const square = grid[dayIndex]?.[weekIndex];
      if (square?.date === todayStr) {
        return weekIndex;
      }
    }
  }
  
  return -1; // Today not found in grid
};

// Validate that current week is properly positioned
export const validateCurrentWeekPosition = (grid: HabitGridDay[][]) => {
  const today = new Date();
  const todayWeekIndex = findTodayWeekIndex(grid, today);
  const expectedCurrentWeekIndex = (grid[0]?.length || 1) - 1; // Should be last column
  
  console.log('Today week index:', todayWeekIndex);
  console.log('Expected current week index:', expectedCurrentWeekIndex);
  console.log('Current week correctly positioned:', todayWeekIndex === expectedCurrentWeekIndex);
  
  return todayWeekIndex === expectedCurrentWeekIndex;
};

// Generate stats text with "captures" terminology
export const generateStatsText = (completedCount: number, numWeeks: number): string => {
  const monthsShown = Math.floor(numWeeks / 4);
  return `${completedCount} captures in the last ${monthsShown} months`;
};