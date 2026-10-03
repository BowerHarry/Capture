# Capture

A habit tracker for iOS where you complete a habit by taking a photo of it, with a social feed of other people's progress.

**Status:** Archived, kept for reference. Development stopped in August 2025 and the Supabase backend it talked to no longer exists, so the app now only runs in an offline demo mode (see [Running it](#running-it)).

<p align="center">
  <img src="docs/images/home.jpg" width="24%" alt="Home tab: streak totals, this week's progress and a list of habits">
  <img src="docs/images/feed.jpg" width="24%" alt="Feed tab: another user's habit card with recent captures and reactions">
  <img src="docs/images/discover.jpg" width="24%" alt="Discover tab: category filters and trending habits">
  <img src="docs/images/profile.jpg" width="24%" alt="Profile tab: capture and follower counts and a six-month progress grid">
</p>

<p align="center"><sub>Screenshots are from the built-in demo mode. The people and numbers are sample data, and the "photos" are generated placeholder artwork.</sub></p>

## Why it exists

Most habit trackers are a checkbox, which is easy to tick without doing the thing. Capture was an experiment in making a photo the proof: the original spec describes it as a camera-first tracker in the spirit of BeReal, using a feed of friends' captures for accountability.

## What it does

- Track daily, weekly or monthly habits, each with a target count (for example three times a week).
- Mark a habit done by taking a photo with the in-app camera, or by picking and cropping one from the library. Captures can be public or private.
- See current streaks, today's and this week's completion, and a six-month progress grid.
- Browse a feed of other users' public captures, grouped per person and habit, and react to them or comment.
- Discover trending habits by category, adopt one with a tap, search for users and follow them.
- Edit your profile and avatar.

## Technical highlights

- **Streaks are computed on the device.** `HabitManager` buckets six months of captures by day, week and month and walks backwards to work out each habit's streak and whether the current period is complete, taking per-habit targets into account.
- **Habits are shared templates, not per-user rows.** The data model separates `habit_templates` from `user_habits`, so that everyone doing "Morning Run" points at the same template. That is what makes trending and discovery possible.
- **Trending is calculated in Postgres.** A view and an RPC function rank habits using the last seven days of captures, participants and likes, so the app fetches a ready-made list.
- **A custom image pipeline.** `ImagePreloader` keeps a size-limited in-memory cache, uses an actor to de-duplicate in-flight downloads, and generates small thumbnails for the trending grid.
- **Per-type response caching.** `AppCacheManager` stores habits, captures, the feed and discovery data with separate expiry times (five minutes for the feed up to a day for categories) so tabs open with data already present.

**Stack:** Swift, SwiftUI, AVFoundation, Supabase (Auth, Postgres, Storage) via [supabase-swift](https://github.com/supabase/supabase-swift).

---

## Requirements

- Xcode with an iOS 18.5 or later simulator. The project was last built with Xcode 26.3.
- No other tools. The one dependency, supabase-swift 2.31.2, is resolved by Swift Package Manager when the project opens.

## Running it

The original backend is gone, so run the app in demo mode. Demo mode is compiled into Debug builds only. It signs in a sample user and serves fixture data and generated images locally, with no network access.

**From Xcode:** open `Capture.xcodeproj`, choose Product → Scheme → Edit Scheme → Run → Arguments, add `-demoMode` under "Arguments Passed On Launch", and run on a simulator.

**From the command line:**

```bash
xcodebuild -project Capture.xcodeproj -scheme Capture -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

```bash
xcrun simctl boot "iPhone 17 Pro"
```

```bash
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Capture.app
```

```bash
xcrun simctl launch booted com.bower.Capture -demoMode
```

Add `-demoTab <0-4>` to open on a particular tab (0 Home, 1 Feed, 2 Capture, 3 Discover, 4 Profile).

Demo mode is read-only. Anything that writes (saving a capture, following someone, commenting, adopting a habit) still tries to reach the old backend and fails.

### Running against your own backend

This is untested since the original project was lost. You would need to:

1. Create a Supabase project and put its URL and anon key in `Capture/SupabaseManager.swift`. The project URL is also hard-coded in `HabitManager.swift` and `ImagePreloader.swift`.
2. Recreate the schema. The `.sql` files in the repository root cover the storage buckets, row-level security policies and the trending view and function, but they were written iteratively and are not a complete, ordered migration. `Capture/Models.swift` and `APP_FUNCTIONALITY_OVERVIEW.md` describe the tables the app expects.

## Project structure

```
Capture/
  CaptureApp 2.swift        App entry point
  ContentView.swift         Auth gate, tab container and custom tab bar
  SupabaseManager.swift     All backend calls: auth, tables, RPC, storage
  AuthManager.swift         Session state
  HabitManager.swift        Habits, captures, streak and completion logic
  SocialManager.swift       Follows, plus an older posts/likes implementation
  AppCacheManager.swift     Response cache with per-type expiry
  ImagePreloader.swift      Image cache, preloading and thumbnails
  Models.swift              Codable models
  Theme.swift               Colours and shared styling
  *View.swift               One file per screen
  CameraManager.swift       AVFoundation capture session
  Demo/DemoMode.swift       Debug-only demo mode and fixtures
*.sql                       Supabase setup scripts
figma/                      React prototype of the same app, exported from Figma Make, and its spec
docs/images/                README screenshots
```

The three manager classes are singletons injected as environment objects. Views read their published state, and every network call goes through `SupabaseManager`, which is where demo mode swaps in fixtures.

## Tests

There are none.

## Known limitations

- The backend no longer exists, so only demo mode works.
- The Groups tab in the feed and most of the Achievements tab are "coming soon" placeholders.
- Deleting a habit and per-habit stats are stubs in `HabitManager`.
- `SocialManager` still contains an earlier posts, likes and comments implementation alongside the capture-based feed that the UI uses.
- On feed cards, the category badge sits behind the streak badge and is hard to read.
- The camera tab needs a physical device, as the simulator has no camera.

## Credits

- [supabase-swift](https://github.com/supabase/supabase-swift) for the backend client.
- The prototype in `figma/` was generated with Figma Make and includes [shadcn/ui](https://ui.shadcn.com/) components (MIT) and Unsplash photo references. See `figma/Attributions.md`.
