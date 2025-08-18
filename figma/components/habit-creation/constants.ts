export const PRESET_HABITS = [
  {
    name: "Morning Workout",
    category: "Fitness",
    emoji: "💪",
    icon: "🏃‍♂️",
    description: "Start your day with energy",
    targetNumber: 1,
    targetPeriod: "day" as const,
    color: "bg-red-100 text-red-700 border-red-200"
  },
  {
    name: "Read 30 mins",
    category: "Learning",
    emoji: "📚",
    icon: "📖",
    description: "Expand your knowledge daily",
    targetNumber: 1,
    targetPeriod: "day" as const,
    color: "bg-blue-100 text-blue-700 border-blue-200"
  },
  {
    name: "Meditation",
    category: "Wellness",
    emoji: "🧘",
    icon: "🕉️",
    description: "Find inner peace and calm",
    targetNumber: 1,
    targetPeriod: "day" as const,
    color: "bg-green-100 text-green-700 border-green-200"
  },
  {
    name: "Drink 8 glasses water",
    category: "Health",
    emoji: "💧",
    icon: "🥤",
    description: "Stay hydrated throughout the day",
    targetNumber: 8,
    targetPeriod: "day" as const,
    color: "bg-blue-100 text-blue-700 border-blue-200"
  },
  {
    name: "Journal writing",
    category: "Wellness",
    emoji: "📝",
    icon: "✍️",
    description: "Reflect and express your thoughts",
    targetNumber: 1,
    targetPeriod: "day" as const,
    color: "bg-green-100 text-green-700 border-green-200"
  },
  {
    name: "Learn language",
    category: "Learning",
    emoji: "🗣️",
    icon: "🌍",
    description: "Practice a new language",
    targetNumber: 1,
    targetPeriod: "day" as const,
    color: "bg-blue-100 text-blue-700 border-blue-200"
  },
  {
    name: "Healthy meal",
    category: "Health",
    emoji: "🥗",
    icon: "🍎",
    description: "Nourish your body with nutrition",
    targetNumber: 3,
    targetPeriod: "day" as const,
    color: "bg-pink-100 text-pink-700 border-pink-200"
  },
  {
    name: "10,000 steps",
    category: "Fitness",
    emoji: "👟",
    icon: "🚶‍♂️",
    description: "Stay active and mobile",
    targetNumber: 10000,
    targetPeriod: "day" as const,
    color: "bg-red-100 text-red-700 border-red-200"
  }
];

export const EMOJI_OPTIONS = [
  '💪', '🏃‍♂️', '🧘', '📚', '💧', '🥗', '⭐', '🎯',
  '✍️', '🌱', '🔥', '💎', '🚀', '🏆', '⚡', '🌟'
];

export const HABIT_CATEGORIES = [
  { name: 'Health', color: 'bg-pink-100 text-pink-700 border-pink-200' },
  { name: 'Wellness', color: 'bg-green-100 text-green-700 border-green-200' },
  { name: 'Fitness', color: 'bg-red-100 text-red-700 border-red-200' },
  { name: 'Learning', color: 'bg-blue-100 text-blue-700 border-blue-200' }
];

export const COLOR_OPTIONS = [
  'bg-red-500', 'bg-orange-500', 'bg-yellow-500', 'bg-green-500',
  'bg-blue-500', 'bg-purple-500', 'bg-pink-500', 'bg-gray-500'
];

export const TARGET_PERIODS = [
  { value: 'day', label: 'Daily' },
  { value: 'week', label: 'Weekly' },
  { value: 'month', label: 'Monthly' }
];