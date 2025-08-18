import { MOTIVATIONAL_MESSAGES } from './constants';

export interface Habit {
  id: string;
  name: string;
  streak: number;
  completedToday: boolean;
  weeklyProgress: number;
  category: string;
  photos?: { url: string; takenAt: string }[];
  dailyCompletions?: Record<string, { completed: boolean; photoUrl?: string; timestamp: string }>;
  createdAt: string;
  targetNumber?: number;
  targetPeriod?: 'day' | 'week' | 'month';
}

export const getRandomMessage = () => {
  return MOTIVATIONAL_MESSAGES[Math.floor(Math.random() * MOTIVATIONAL_MESSAGES.length)];
};

export const calculateTargetProgress = (habit: Habit) => {
  if (!habit.targetNumber || !habit.targetPeriod || !habit.dailyCompletions) {
    return { current: 0, target: habit.targetNumber || 1, percentage: 0, text: `${habit.targetNumber || 1} times/${habit.targetPeriod || 'day'}` };
  }

  const now = new Date();
  const completions = habit.dailyCompletions;
  let periodStart: Date;
  let current = 0;
  
  // Calculate period start based on target period
  switch (habit.targetPeriod) {
    case 'day':
      periodStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      break;
    case 'week':
      const dayOfWeek = now.getDay();
      const daysFromMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
      periodStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() - daysFromMonday);
      break;
    case 'month':
      periodStart = new Date(now.getFullYear(), now.getMonth(), 1);
      break;
    default:
      periodStart = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }

  // Count completions in the current period
  Object.entries(completions).forEach(([dateKey, completion]) => {
    const completionDate = new Date(dateKey);
    if (completionDate >= periodStart && completionDate <= now && completion.completed) {
      current++;
    }
  });

  const target = habit.targetNumber;
  const percentage = Math.min((current / target) * 100, 100);
  const text = `${target} times/${habit.targetPeriod}`;

  return { current, target, percentage, text };
};