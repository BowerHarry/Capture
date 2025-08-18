# Recovered Files for Capture App

This folder contains the latest working versions of the following files that were lost from your Capture app project:

## Files Recovered

### 1. Models.swift
A comprehensive data model file containing all the core structures for the Capture app:

- **Core Models**: `Habit`, `AvailableHabit`, `Capture`
- **User Models**: `UserProfile`
- **Social Models**: `SocialPost`, `Comment`, `Like`, `Follow`
- **Enums**: `HabitCategory`, `HabitColor`
- **View Models**: `HabitStats`, `SocialFeedItem`

### 2. SocialManager.swift
A complete social management class that handles:

- **Posts**: Create, load, delete social posts
- **Likes**: Toggle likes on posts
- **Comments**: Add and load comments
- **Following**: Follow/unfollow users
- **Search**: Search for users
- **Trending**: Get trending posts
- **Feed Management**: Load and manage social feed items

### 3. DiscoveryView.swift
A comprehensive discovery view with three main sections:

- **Trending View**: Shows trending social posts
- **People View**: User discovery and suggestions
- **Habit Inspiration View**: Browse available habits by category

Includes supporting components:
- `SocialPostCard`: Displays social posts with interactions
- `UserCard`: User profile cards with follow functionality
- `HabitInspirationCard`: Habit suggestion cards
- `CategoryChip`: Category filter chips
- `EmptyStateView`: Empty state placeholders
- `SearchView`: User search functionality

### 4. Contents.json
Standard iOS asset catalog metadata file for Xcode projects.

## Key Features

### Social Features
- Real-time social feed with posts, likes, and comments
- User following system
- Post creation with habit/capture integration
- User search and discovery
- Trending posts algorithm

### Discovery Features
- Three-tab interface (Trending, People, Habits)
- Category-based habit filtering
- User search functionality
- Social post interactions
- Empty state handling

### Data Models
- Comprehensive model structure for all app features
- Codable conformance for JSON serialization
- Proper relationships between entities
- Support for images, notes, and metadata

## Integration Notes

These files are designed to work with:
- **SupabaseManager**: For database operations
- **HabitManager**: For habit-related functionality
- **SwiftUI**: For the user interface
- **Combine**: For reactive programming

## Usage

1. Copy these files to your Capture app project
2. Ensure you have the required dependencies (Supabase, SwiftUI, Combine)
3. Update any import statements or references as needed
4. Test the integration with your existing codebase

## Dependencies

- SwiftUI
- Foundation
- Combine
- Supabase Swift SDK

The files are based on the patterns observed in your existing `HabitPickerView.swift` and follow iOS/SwiftUI best practices.
