export interface HabitGridDay {
  date: string;
  completed: boolean;
  completionCount: number;
  isToday: boolean;
  isFuture: boolean;
  photoUrl?: string;
  dayOfMonth: number;
  month: number;
  completion?: {
    completed: boolean;
    photoUrl?: string;
    timestamp: string;
  };
  // New properties for weekly grid
  week?: number; // Which week column this day belongs to
  dayOfWeek?: number; // 0 = Monday, 6 = Sunday
}

export interface HabitGridProps {
  habit: {
    id: string;
    name: string;
    category: string;
    streak: number;
    dailyCompletions?: Record<string, { 
      completed: boolean; 
      photoUrl?: string; 
      timestamp: string 
    }>;
    createdAt: string;
    targetPeriod?: 'day' | 'week' | 'month';
  };
  onDateClick?: (date: string) => void;
}

// New interface for weekly grid structure
export interface WeeklyHabitGrid {
  grid: HabitGridDay[][]; // 7 rows (days of week) x N columns (weeks)
  totalWeeks: number;
  startDate: Date;
  endDate: Date;
}

// GitHub-style contribution levels
export type ContributionLevel = 'none' | 'low' | 'medium' | 'high';

export interface GitHubSquare {
  date: string;
  level: ContributionLevel;
  count: number;
  isToday: boolean;
  isFuture: boolean;
}