# Capture App - Functionality & Database Overview

## App Overview
Capture is a habit tracking app that allows users to build habits by taking photos of their progress. The app features social elements, discovery of trending habits, and a comprehensive dashboard for tracking progress.

## Database Schema & Connections

### Core Tables

#### 1. **profiles** (User Management)
- **Purpose**: Stores user profile information
- **Key Fields**: `id`, `email`, `display_name`, `avatar_url`, `bio`, `best_streak`
- **Used By**: 
  - `AuthManager` - User authentication and profile management
  - `ProfileView` - Display user profile
  - `SocialFeedView` - Show user information in posts
  - `DiscoveryView` - User search and discovery

#### 2. **habit_templates** (Habit Definitions)
- **Purpose**: Stores reusable habit templates that users can adopt
- **Key Fields**: `id`, `name`, `description`, `category`, `target_frequency`, `target_count`, `is_active`
- **Used By**:
  - `HabitManager.getHabits()` - Fetch user's habits via user_habits join
  - `HabitManager.createHabitDirect()` - Create new habit templates
  - `DiscoveryView` - Show available habits to users
  - `trending_habits_view` - Calculate trending habits

#### 3. **user_habits** (User-Habit Relationships)
- **Purpose**: Links users to habit templates with personal progress data
- **Key Fields**: `id`, `user_id`, `habit_template_id`, `current_streak`, `is_active`
- **Used By**:
  - `HabitManager.getHabits()` - Get user's active habits
  - `HabitManager.createHabitDirect()` - Create user habit instances
  - `captures` table - Links captures to user habits

#### 4. **captures** (Habit Progress Photos)
- **Purpose**: Stores photos and metadata for habit progress
- **Key Fields**: `id`, `habit_id` (references user_habits.id), `user_id`, `image_url`, `caption`, `is_public`, `created_at`
- **Used By**:
  - `CameraCaptureView` - Save new captures
  - `HabitDashboardView` - Display user's captures
  - `SocialFeedView` - Show public captures in feed
  - `DiscoveryView` - Show trending captures
  - `trending_habits_view` - Calculate trending metrics

#### 5. **available_habits** (Habit Suggestions)
- **Purpose**: Pre-defined habits users can choose from
- **Key Fields**: `id`, `name`, `category`, `description`, `is_default`
- **Used By**:
  - `HabitManager.getAvailableHabits()` - Show habit suggestions
  - `HabitPickerView` - Let users select from available habits
  - `DiscoveryView` - Display habit categories

### Social Tables

#### 6. **capture_likes** (Like System)
- **Purpose**: Tracks which users liked which captures
- **Key Fields**: `id`, `capture_id`, `user_id`, `created_at`
- **Used By**:
  - `SupabaseManager.toggleCaptureLike()` - Like/unlike captures
  - `SupabaseManager.isCaptureLikedByUser()` - Check if user liked capture
  - `social_feed_with_likes` view - Calculate like counts

#### 7. **social_posts** (Social Posts)
- **Purpose**: Stores social posts (appears to be legacy/unused)
- **Key Fields**: `id`, `user_id`, `habit_id`, `capture_id`, `content`, `image_url`
- **Used By**: `SocialManager` (but may be deprecated in favor of captures)

### Views & Functions

#### 8. **trending_habits_view** (Trending Analysis)
- **Purpose**: Shows top 5 trending habits based on recent activity
- **Logic**: 
  - Counts active participants (users who captured in past 7 days)
  - Calculates average streaks for active participants
  - Considers recent captures and likes
  - Filters out habits with no recent activity
- **Used By**:
  - `HabitManager.getTrendingHabits()` - Discovery tab
  - `DiscoveryView` - Show trending habits

#### 9. **social_feed_with_likes** (Social Feed)
- **Purpose**: Aggregates captures with like counts and user info
- **Logic**: Joins captures with profiles and like counts
- **Used By**:
  - `SupabaseManager.getSocialFeedWithLikes()` - Social feed
  - `SocialFeedView` - Display social posts

#### 10. **get_trending_captures_for_habits()** (RPC Function)
- **Purpose**: Returns trending captures for top habits
- **Logic**:
  - Identifies top 5 trending habits
  - Returns recent captures from those habits
  - Includes like counts and user information
- **Used By**:
  - `HabitManager.getTrendingCapturesForHabits()` - Discovery tab
  - `DiscoveryView` - Show trending captures

### Storage Buckets

#### 11. **captures_public** (Image Storage)
- **Purpose**: Stores capture images with public access
- **Structure**: `{user_id}/{capture_id}.jpg`
- **Used By**:
  - `CameraCaptureView` - Upload new captures
  - All views displaying capture images

#### 12. **avatars** (Profile Images)
- **Purpose**: Stores user profile pictures
- **Structure**: `avatars/{user_id}_avatar.jpg`
- **Used By**:
  - `ProfileView` - User avatars
  - `SocialFeedView` - User avatars in posts

#### 13. **trending-images** (Optimized Thumbnails)
- **Purpose**: Stores compressed thumbnails for trending display
- **Structure**: `{user_id}/{capture_id}.jpg`
- **Used By**:
  - `DiscoveryView` - Fast loading of trending thumbnails
  - `ImagePreloader` - Preload trending images

## App Views & Database Connections

### 1. **ContentView** (Main Navigation)
- **Purpose**: Main tab navigation and app structure
- **Database Connections**: None directly, orchestrates other views
- **Key Features**:
  - Tab navigation (Home, Feed, Capture, Discover, Profile)
  - Image preloading for performance
  - Authentication state management

### 2. **HabitDashboardView** (Home Tab)
- **Purpose**: Main dashboard showing user's habits and progress
- **Database Connections**:
  - `user_habits` + `habit_templates` → User's habits
  - `captures` → Recent captures for each habit
  - `profiles` → User stats (best streak)
- **Key Features**:
  - Habit progress tracking with streaks
  - Weekly/monthly completion percentages
  - Quick capture buttons for each habit
  - Progress grid view

### 3. **SocialFeedView** (Feed Tab)
- **Purpose**: Social feed showing other users' captures
- **Database Connections**:
  - `social_feed_with_likes` → Public captures with like counts
  - `capture_likes` → Like/unlike functionality
  - `profiles` → User information
- **Key Features**:
  - Three tabs: Following, For You, Trending
  - Like/unlike captures
  - User following system
  - Capture sharing

### 4. **CameraCaptureView** (Capture Tab)
- **Purpose**: Camera interface for capturing habit progress
- **Database Connections**:
  - `captures` → Save new captures
  - `captures_public` storage → Upload images
- **Key Features**:
  - Live camera preview
  - Photo library integration
  - Image cropping
  - Public/private toggle
  - Habit selection

### 5. **DiscoveryView** (Discover Tab)
- **Purpose**: Discover trending habits and users
- **Database Connections**:
  - `trending_habits_view` → Trending habits
  - `get_trending_captures_for_habits()` → Trending captures
  - `available_habits` → Habit suggestions
  - `profiles` → User search
- **Key Features**:
  - Three tabs: Trending, Habits, Users
  - Search functionality
  - Habit adoption
  - User following

### 6. **ProfileView** (Profile Tab)
- **Purpose**: User profile and settings
- **Database Connections**:
  - `profiles` → User profile data
  - `captures` → User's captures
  - `avatars` storage → Profile pictures
- **Key Features**:
  - Profile editing
  - Avatar upload
  - Habit statistics
  - Capture history

## Data Flow & Complex Logic

### Habit Progress Calculation
1. **Data Sources**: `user_habits` (streaks) + `captures` (completions)
2. **Logic**: 
   - Daily habits: Count captures per day, calculate consecutive days
   - Weekly habits: Count captures per week, calculate consecutive weeks
   - Monthly habits: Count captures per month, calculate consecutive months
3. **Used By**: `HabitManager.computeStreaksAndCompletion()`

### Trending Algorithm
1. **Data Sources**: `captures`, `capture_likes`, `user_habits`, `habit_templates`
2. **Logic**:
   - Only considers captures from past 7 days
   - Weights recent captures heavily (10x)
   - Considers active participants (1x)
   - Includes recent likes (2x)
3. **Used By**: `trending_habits_view`, `get_trending_captures_for_habits()`

### Social Feed Aggregation
1. **Data Sources**: `captures`, `profiles`, `capture_likes`
2. **Logic**:
   - Joins public captures with user profiles
   - Calculates like counts per capture
   - Orders by recency
3. **Used By**: `social_feed_with_likes` view

## Potential Issues & Improvements

### 1. **Duplicate Logic**
- **Issue**: Both `trending_habits_view` and `get_trending_captures_for_habits()` calculate trending scores
- **Solution**: Consolidate trending logic into a single function

### 2. **Unused Database Objects**
- **Issue**: `social_posts` table appears unused (app uses `captures` for social features)
- **Solution**: Remove if confirmed unused

### 3. **Performance Considerations**
- **Issue**: Multiple joins in trending calculations
- **Solution**: Consider materialized views for complex aggregations

### 4. **Data Consistency**
- **Issue**: Streak calculations happen in both app and database
- **Solution**: Centralize streak logic in database functions

## Storage Usage
- **captures_public**: Main image storage for all captures
- **avatars**: Profile pictures (smaller files)
- **trending-images**: Optimized thumbnails for discovery (duplicates of captures_public)

## Authentication & Security
- Uses Supabase Auth with RLS policies
- Users can only modify their own data
- Public read access for social features
- Storage bucket policies for image access
