# Capture App - Complete Technical Specification

## App Overview

**Capture** is a modern, camera-first habit-tracking app inspired by BeReal's authenticity approach. The app focuses on social accountability through photo-based habit completion and community engagement.

### Core Concept
- **Camera-first design**: Users capture photos to mark habit completion
- **Social accountability**: Friends can see and interact with habit progress
- **Gamified experience**: GitHub-style contribution graph and achievement system
- **Community discovery**: Explore trending habits and join popular challenges

---

## App Architecture

### Navigation Structure
- **Tab-based navigation** with 5 main sections:
  1. **Dashboard** (Home) - Habit overview and tracking
  2. **Social** - Friends' activities and social features
  3. **Capture** (Camera) - Photo capture functionality
  4. **Discover** - Explore popular habits and community
  5. **Profile** - User profile and personal stats

### Screen Flow
```
App Launch → Authentication → Dashboard → Tab Navigation
                ↓
           Camera Modal (overlay)
                ↓
           Social Feed (after capture)
```

---

## Design System

### Color Palette

#### Primary Colors
- **Background**: `#ffffff` (light), `oklch(0.145 0 0)` (dark)
- **Primary**: `#030213` (dark blue-black)
- **Foreground**: `oklch(0.145 0 0)` (light), `oklch(0.985 0 0)` (dark)

#### Habit Categories (Gamified Colors)
- **Fitness**: `#ef4444` (Red) - 💪
- **Wellness**: `#22c55e` (Green) - 🧘
- **Learning**: `#3b82f6` (Blue) - 📚
- **Nutrition**: `#f97316` (Orange) - 🥗
- **Productivity**: `#8b5cf6` (Purple) - ⚡
- **Health**: `#ec4899` (Pink) - 🏥
- **Social**: `#eab308` (Yellow) - 🤝

#### UI Colors
- **Card**: `#ffffff` with subtle gradients
- **Muted**: `#ececf0` (backgrounds), `#717182` (text)
- **Accent**: `#e9ebef`
- **Border**: `rgba(0, 0, 0, 0.1)`

### Typography
- **Base font size**: `14px`
- **Font weights**: Normal (400), Medium (500)
- **Headings**: Gradient text using primary colors
- **Body text**: Base size with 1.5 line height

### Visual Style
- **Modern gradients**: Subtle color transitions on cards
- **Rounded corners**: `0.625rem` base radius
- **Shadows**: Subtle with backdrop blur effects
- **Icons**: Lucide React icon set
- **Animations**: Bounce-in effects, glowing elements

---

## Screen-by-Screen Breakdown

### 1. Authentication Screen (`AuthScreen.tsx`)
**Functionality:**
- Email/password sign up and login
- Form validation
- Error handling with toast notifications
- Supabase authentication integration

**Design:**
- Clean, centered form layout
- Gradient backgrounds
- Modern input styling with focus states
- Primary action buttons

### 2. Dashboard (`Dashboard.tsx`)
**Functionality:**
- **Header Section:**
  - Time-based greeting (morning/afternoon/evening with icons)
  - Motivational quotes rotation
  - Stats cards (Total Streaks, Best Streak, Today's Progress)
  - Weekly summary with progress bar

- **Habit Grid:**
  - GitHub-style contribution graph
  - Color-coded by habit category
  - Hover effects with tooltips
  - Collapsible sections
  - Interactive squares for each day

- **Habit Management:**
  - Add new habit button
  - Habit creation dialog (preset or custom)
  - Category selection
  - Target setting (frequency per day/week/month)

**Design:**
- **Header**: Gradient background with stats cards
- **Grid**: Visual contribution graph with category colors
- **Cards**: Modern with subtle shadows and gradients
- **Animations**: Bounce-in effects, counter animations

### 3. Camera Capture (`CameraCapture.tsx`)
**Functionality:**
- Full-screen camera modal overlay
- Photo capture with front/rear camera toggle
- Timer countdown (BeReal-style)
- Photo preview and confirmation
- Habit association

**Design:**
- **Full-screen overlay**: Dark background
- **Camera viewfinder**: Rounded corners
- **Controls**: Floating action buttons
- **Timer**: Prominent countdown display

### 4. Social Feed (`SocialFeed.tsx`)
**Functionality:**
- **Following Tab:**
  - Friends' recent habit completions
  - Photo grid displays
  - Like/comment interactions
  - Real-time updates

- **Groups Tab:**
  - Habit-based group challenges
  - Group activity feeds
  - Member participation stats
  - Join/leave functionality

**Design:**
- **Feed cards**: Photo grids with habit details
- **User avatars**: Circular with gradient borders
- **Interaction buttons**: Heart icons, comment counts
- **Group cards**: Member count, activity indicators

### 5. Discovery (`Discovery.tsx`)
**Functionality:**
- **Search**: Global habit and user search
- **Categories**: Popular habit categories with counts
- **Trending Habits**: Community-driven popular habits
- **Stats**: Global community metrics
- **Join habits**: One-click habit adoption

**Design:**
- **Search bar**: Prominent with search icon
- **Category badges**: Color-coded with counts
- **Habit cards**: Photo previews, participant counts
- **"Capture" buttons**: Camera icon with black outline

### 6. Profile (`Profile.tsx`)
**Functionality:**
- **Header Section:**
  - Profile photo with camera overlay for updates
  - Display name and username (@email prefix)
  - Bio text (150 character limit)
  - Join date badge
  - Stats grid (Habits, Captures, Followers)

- **Three-tab interface:**
  - **Overview**: Performance metrics, today's progress
  - **Achievements**: Earned badges with animated icons
  - **My Habits**: Personal habit list with streaks

**Design:**
- **Header**: Gradient background with avatar
- **Stats cards**: Color-coded with icons
- **Tabs**: Clean tab interface
- **Achievement cards**: Golden gradient backgrounds

---

## Component Architecture

### Shared Components
- **BottomNav**: 5-tab navigation with active states
- **PullToRefresh**: iOS-style pull-to-refresh functionality
- **ImageWithFallback**: Fallback for broken images
- **Toast notifications**: Success/error messages with Sonner

### UI Components (ShadCN/UI)
- Full component library with consistent styling
- Custom variants for habit categories
- Responsive design patterns

---

## Data Models

### User
```typescript
interface User {
  id: string;
  email: string;
  name: string;
  bio?: string;
  avatar?: string;
  createdAt: string;
  totalHabits: number;
  totalCaptures: number;
  followers: string[];
  following: string[];
}
```

### Habit
```typescript
interface Habit {
  id: string;
  name: string;
  category: string;
  description?: string;
  streak: number;
  completedToday: boolean;
  targetNumber: number; // 1-10
  targetPeriod: 'day' | 'week' | 'month';
  photos?: { url: string; takenAt: string }[];
  weeklyProgress: number; // 0-100%
}
```

### Community Stats
```typescript
interface CommunityStats {
  activeUsers: number;
  totalHabits: number;
  totalCaptures: number;
}
```

---

## Backend Integration

### Supabase Setup
- **Authentication**: Email/password with session management
- **Database**: PostgreSQL with real-time subscriptions
- **Storage**: Photo uploads to private buckets
- **Edge Functions**: Server-side API endpoints

### API Endpoints
- `GET /habits` - User's habits
- `POST /habits` - Create new habit
- `POST /capture` - Upload photo and mark completion
- `GET /popular-habits` - Community trending habits
- `GET /profile` - User profile data
- `GET /social-feed` - Friends' activities

### Key-Value Store
- Used for flexible data storage
- Handles user preferences, achievements, community stats
- Simple get/set/delete operations

---

## Mockup vs Production Differences

### Current Mockup Limitations
1. **Static data**: Some community stats are calculated/mocked
2. **Photo storage**: Uses temporary URLs in development
3. **Real-time features**: Simulated with local state
4. **Push notifications**: Not implemented
5. **Social features**: Friend requests/follows are simplified

### Production Requirements
1. **Real photo capture**: Native camera API integration
2. **Push notifications**: Habit reminders and social notifications
3. **Real-time sync**: Live updates for social features
4. **Offline support**: Local caching and sync
5. **Performance optimization**: Image compression, lazy loading

---

## User Flows

### Primary Flow: Complete a Habit
1. User opens Dashboard
2. Sees habit grid with today's incomplete habits
3. Taps habit or "Capture" button
4. Camera modal opens
5. Takes photo with timer
6. Photo saved, habit marked complete
7. Redirected to Social tab to see community

### Secondary Flow: Discover New Habits
1. User taps Discovery tab
2. Browses trending habits or searches
3. Sees popular habit with photo examples
4. Taps "Capture" button to adopt habit
5. Habit added to dashboard
6. Can immediately capture first photo

---

## Styling Patterns

### Card Design
```css
/* Modern card with gradient and shadow */
background: gradient-to-br from-card to-accent/10
border: subtle border with opacity
border-radius: 0.625rem
backdrop-blur: subtle blur effect
```

### Interactive Elements
```css
/* Buttons and interactive items */
transition: all 0.2s ease
hover: transform scale(1.05) + shadow increase
active: slight scale down
```

### Color Application
- **Habit categories**: Use predefined color variables
- **Status indicators**: Green for completed, gray for pending
- **Progress bars**: Gradient fills matching category colors

---

## Icon Usage (Lucide React)

### Navigation Icons
- **Home**: `Home`
- **Social**: `Users`
- **Capture**: `Camera`
- **Discover**: `Search`
- **Profile**: `User`

### Feature Icons
- **Streaks**: `Flame` (orange)
- **Achievements**: `Trophy`, `Award`, `Star`
- **Progress**: `Target`, `TrendingUp`
- **Time**: `Calendar`, `Clock`
- **Actions**: `Plus`, `Edit3`, `Upload`

### Status Icons
- **Completed**: Checkmark or filled circle
- **Pending**: Empty circle
- **Categories**: Emoji + lucide icon combinations

---

## Animation Details

### Keyframes
```css
bounce-in: 0% scale(0.8) → 50% scale(1.05) → 100% scale(1)
glow: alternating box-shadow with blue tint
```

### Usage
- **New achievements**: Bounce-in animation
- **Important CTAs**: Glow animation
- **Grid squares**: Hover scale transformation
- **Stats counters**: Animated counting up

---

## Performance Considerations

### Image Handling
- Compress photos before upload
- Use WebP format where possible
- Lazy load social feed images
- Cache profile avatars

### Data Loading
- Skeleton screens during load
- Pull-to-refresh for manual updates
- Optimistic UI updates
- Error boundaries with retry options

---

## Accessibility Features

### Screen Reader Support
- Semantic HTML structure
- ARIA labels on interactive elements
- Alt text for all images
- Keyboard navigation support

### Visual Accessibility
- Sufficient color contrast ratios
- Focus indicators on all interactive elements
- Text scaling support
- Dark mode support

---

This specification provides the complete blueprint for recreating the Capture app in Swift, including all design decisions, functionality, and technical requirements established in the React prototype.