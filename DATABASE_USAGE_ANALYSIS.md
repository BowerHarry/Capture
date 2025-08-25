# Database Usage Analysis - Capture App

## Database Objects Status

### ✅ **ACTIVELY USED**

#### Tables
1. **profiles** - ✅ Core user data
2. **habit_templates** - ✅ Habit definitions
3. **user_habits** - ✅ User-habit relationships
4. **captures** - ✅ Core feature (habit progress photos)
5. **available_habits** - ✅ Habit suggestions
6. **capture_likes** - ✅ Social like system

#### Views
7. **trending_habits_view** - ✅ Discovery feature
8. **social_feed_with_likes** - ✅ Social feed

#### Functions
9. **get_trending_captures_for_habits()** - ✅ Discovery feature
10. **toggle_capture_like()** - ✅ Social like system
11. **is_capture_liked_by_user()** - ✅ Social like system

#### Storage Buckets
12. **captures_public** - ✅ Main image storage
13. **avatars** - ✅ Profile pictures

### ⚠️ **POTENTIALLY UNUSED/DUPLICATED**

#### Tables
1. **social_posts** - ⚠️ **LIKELY UNUSED**
   - **Evidence**: App uses `captures` table for social features
   - **Code Reference**: `SocialManager` references this but actual social feed uses `captures`
   - **Recommendation**: Remove if confirmed unused

#### Storage Buckets
2. **trending-images** - ⚠️ **DUPLICATED STORAGE**
   - **Purpose**: Optimized thumbnails for discovery
   - **Issue**: Stores duplicate images from `captures_public`
   - **Code Reference**: `SupabaseManager.uploadTrendingImage()`, `copyImageToTrending()`
   - **Recommendation**: Consider if this optimization is worth the storage cost

### ❓ **NEEDS VERIFICATION**

#### Tables
1. **trending_images** - ❓ **UNCLEAR USAGE**
   - **Purpose**: Metadata for trending thumbnails
   - **Code Reference**: `create_trending_thumbnail()` trigger
   - **Recommendation**: Verify if this table is actually used

## Duplication Analysis

### 1. **Trending Logic Duplication**
**Issue**: Both `trending_habits_view` and `get_trending_captures_for_habits()` calculate trending scores

**Current Implementation**:
```sql
-- In trending_habits_view
(recent_captures * 10.0) + (active_participants * 1.0) + (recent_likes * 2.0)

-- In get_trending_captures_for_habits()
(COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) * 10.0) +
(COUNT(DISTINCT CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN uh.user_id END) * 1.0) +
(COALESCE(SUM(...), 0) * 2.0)
```

**Recommendation**: Create a single function `calculate_trending_score()` and use it in both places.

### 2. **Image Storage Duplication**
**Issue**: `trending-images` bucket duplicates images from `captures_public`

**Current Flow**:
1. User uploads to `captures_public`
2. App copies to `trending-images` for optimization
3. Both buckets store the same image

**Recommendation**: 
- Option A: Use only `captures_public` and implement client-side image resizing
- Option B: Keep `trending-images` but implement automatic cleanup of old images

### 3. **Streak Calculation Duplication**
**Issue**: Streak logic exists in both app (`HabitManager`) and database

**Current Implementation**:
- App calculates streaks in `computeStreaksAndCompletion()`
- Database stores `current_streak` in `user_habits` table
- Potential for inconsistency

**Recommendation**: Move streak calculation to database functions for consistency.

## Performance Issues

### 1. **Complex Trending Queries**
**Issue**: Multiple joins and aggregations in trending calculations

**Current Queries**:
```sql
-- trending_habits_view has multiple LEFT JOINs
FROM habit_templates ht
LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
LEFT JOIN captures captures ON uh.id = captures.habit_id AND captures.is_public = true
```

**Recommendation**: Consider materialized views for trending data that updates periodically.

### 2. **Social Feed Aggregation**
**Issue**: `social_feed_with_likes` view performs complex joins on every query

**Recommendation**: Consider caching or materialized views for frequently accessed social data.

## Storage Optimization Opportunities

### 1. **Image Storage**
- **Current**: Two buckets storing similar images
- **Opportunity**: Implement image compression and single storage location
- **Impact**: Reduce storage costs and complexity

### 2. **Database Indexes**
**Missing Indexes** (based on query patterns):
```sql
-- For trending queries
CREATE INDEX idx_captures_created_at_public ON captures(created_at) WHERE is_public = true;
CREATE INDEX idx_user_habits_active ON user_habits(habit_template_id, is_active);

-- For social feed
CREATE INDEX idx_capture_likes_capture_id ON capture_likes(capture_id);
```

## Recommendations

### Immediate Actions
1. **Remove `social_posts` table** if confirmed unused
2. **Consolidate trending logic** into single function
3. **Add missing database indexes** for performance

### Medium-term Improvements
1. **Implement materialized views** for trending data
2. **Centralize streak calculations** in database
3. **Optimize image storage** strategy

### Long-term Considerations
1. **Database partitioning** for captures table as it grows
2. **Caching layer** for frequently accessed data
3. **Analytics optimization** for trending calculations

## Code References

### SupabaseManager.swift
- Lines 700-800: Trending captures function calls
- Lines 900-1000: Social feed with likes
- Lines 1200-1300: Image storage operations

### HabitManager.swift
- Lines 200-300: Streak calculations
- Lines 400-500: Progress computation
- Lines 600-700: Trending habits loading

### SocialManager.swift
- Lines 100-200: Social posts (potentially unused)
- Lines 300-400: Feed item loading

## Summary
The app has a well-structured database with clear separation of concerns. Main issues are:
1. **Unused `social_posts` table** - should be removed
2. **Duplicated trending logic** - should be consolidated
3. **Duplicated image storage** - should be optimized
4. **Missing indexes** - should be added for performance

The core functionality is solid with good use of views and functions for complex aggregations.
