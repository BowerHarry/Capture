export const MONTH_NAMES = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

// Category colors matching our CSS custom properties
export const CATEGORY_COLORS = {
  'Fitness': {
    primary: 'rgb(239, 68, 68)', // red-500
    light: 'rgb(254, 226, 226)', // red-100
    class: 'bg-red-500 hover:bg-red-600 border border-red-600'
  },
  'Wellness': {
    primary: 'rgb(34, 197, 94)', // green-500
    light: 'rgb(220, 252, 231)', // green-100
    class: 'bg-green-500 hover:bg-green-600 border border-green-600'
  },
  'Learning': {
    primary: 'rgb(59, 130, 246)', // blue-500
    light: 'rgb(219, 234, 254)', // blue-100
    class: 'bg-blue-500 hover:bg-blue-600 border border-blue-600'
  },
  'Nutrition': {
    primary: 'rgb(249, 115, 22)', // orange-500
    light: 'rgb(255, 237, 213)', // orange-100
    class: 'bg-orange-500 hover:bg-orange-600 border border-orange-600'
  },
  'Productivity': {
    primary: 'rgb(139, 92, 246)', // purple-500
    light: 'rgb(237, 233, 254)', // purple-100
    class: 'bg-purple-500 hover:bg-purple-600 border border-purple-600'
  },
  'Health': {
    primary: 'rgb(236, 72, 153)', // pink-500
    light: 'rgb(252, 231, 243)', // pink-100
    class: 'bg-pink-500 hover:bg-pink-600 border border-pink-600'
  },
  'Social': {
    primary: 'rgb(234, 179, 8)', // yellow-500
    light: 'rgb(254, 249, 195)', // yellow-100
    class: 'bg-yellow-500 hover:bg-yellow-600 border border-yellow-600'
  },
  'Custom': {
    primary: 'rgb(59, 130, 246)', // blue-500
    light: 'rgb(219, 234, 254)', // blue-100
    class: 'bg-blue-500 hover:bg-blue-600 border border-blue-600'
  }
} as const;

// Category icons
export const CATEGORY_ICONS = {
  'Fitness': '💪',
  'Wellness': '🧘',
  'Learning': '📚',
  'Nutrition': '🥗',
  'Productivity': '⚡',
  'Health': '❤️',
  'Social': '👥',
  'Custom': '🎯'
} as const;

// Legacy GitHub colors for backwards compatibility
export const GITHUB_COLORS = {
  none: 'bg-gray-200 dark:bg-gray-700',
  future: 'bg-gray-100 dark:bg-gray-800 opacity-50',
  low: 'bg-green-500 dark:bg-green-400',
  high: 'bg-green-700 dark:bg-green-300'
} as const;

// CSS custom property styles for reliable color application
export const GITHUB_COLORS_INLINE = {
  none: {
    backgroundColor: 'transparent',
    borderColor: 'rgb(209, 213, 219)', // gray-300
    borderWidth: '1px'
  },
  future: {
    backgroundColor: 'rgb(243, 244, 246)', // gray-100
    opacity: 0.5
  },
  low: {
    backgroundColor: 'rgb(34, 197, 94)', // green-500
  },
  high: {
    backgroundColor: 'rgb(21, 128, 61)', // green-700
  },
  // Dark mode versions
  noneDark: {
    backgroundColor: 'transparent',
    borderColor: 'rgb(55, 65, 81)', // gray-700
    borderWidth: '1px'
  },
  futureDark: {
    backgroundColor: 'rgb(31, 41, 55)', // gray-800
    opacity: 0.5
  },
  lowDark: {
    backgroundColor: 'rgb(74, 222, 128)', // green-400
  },
  highDark: {
    backgroundColor: 'rgb(34, 197, 94)', // green-500
  }
} as const;