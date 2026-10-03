-- Add Performance Indexes for Capture App
-- This script adds indexes to optimize the most common query patterns

-- ====================
-- 1. CAPTURES TABLE INDEXES
-- ====================

-- Index for trending queries (public captures by date)
CREATE INDEX IF NOT EXISTS idx_captures_created_at_public 
ON captures(created_at) 
WHERE is_public = true;

-- Index for user's captures
CREATE INDEX IF NOT EXISTS idx_captures_user_id_created_at 
ON captures(user_id, created_at DESC);

-- Index for habit-specific captures
CREATE INDEX IF NOT EXISTS idx_captures_habit_id_created_at 
ON captures(habit_id, created_at DESC);

-- Index for public captures with habit_id (for trending)
CREATE INDEX IF NOT EXISTS idx_captures_public_habit_created 
ON captures(is_public, habit_id, created_at DESC) 
WHERE is_public = true;

-- Index for captures with images (for trending)
CREATE INDEX IF NOT EXISTS idx_captures_public_image_created 
ON captures(is_public, created_at DESC) 
WHERE is_public = true AND image_url IS NOT NULL;

-- ====================
-- 2. USER_HABITS TABLE INDEXES
-- ====================

-- Index for active user habits by template
CREATE INDEX IF NOT EXISTS idx_user_habits_active_template 
ON user_habits(habit_template_id, is_active) 
WHERE is_active = true;

-- Index for user's active habits
CREATE INDEX IF NOT EXISTS idx_user_habits_user_active 
ON user_habits(user_id, is_active) 
WHERE is_active = true;

-- Index for habit template lookups
CREATE INDEX IF NOT EXISTS idx_user_habits_template_user 
ON user_habits(habit_template_id, user_id, is_active);

-- ====================
-- 3. HABIT_TEMPLATES TABLE INDEXES
-- ====================

-- Index for active habit templates
CREATE INDEX IF NOT EXISTS idx_habit_templates_active 
ON habit_templates(is_active) 
WHERE is_active = true;

-- Index for habit template categories
CREATE INDEX IF NOT EXISTS idx_habit_templates_category_active 
ON habit_templates(category, is_active) 
WHERE is_active = true;

-- ====================
-- 4. CAPTURE_LIKES TABLE INDEXES
-- ====================

-- Index for capture like counts
CREATE INDEX IF NOT EXISTS idx_capture_likes_capture_id 
ON capture_likes(capture_id);

-- Index for user's likes
CREATE INDEX IF NOT EXISTS idx_capture_likes_user_id 
ON capture_likes(user_id);

-- Index for capture-user combinations (for checking if user liked)
CREATE INDEX IF NOT EXISTS idx_capture_likes_capture_user 
ON capture_likes(capture_id, user_id);

-- ====================
-- 5. PROFILES TABLE INDEXES
-- ====================

-- Index for user search (display_name)
CREATE INDEX IF NOT EXISTS idx_profiles_display_name 
ON profiles(display_name);

-- Index for user search (bio text search)
CREATE INDEX IF NOT EXISTS idx_profiles_bio_gin 
ON profiles USING gin(to_tsvector('english', bio));

-- ====================
-- 6. AVAILABLE_HABITS TABLE INDEXES
-- ====================

-- Index for default habits
CREATE INDEX IF NOT EXISTS idx_available_habits_default 
ON available_habits(is_default) 
WHERE is_default = true;

-- Index for habit categories
CREATE INDEX IF NOT EXISTS idx_available_habits_category 
ON available_habits(category);

-- ====================
-- 7. COMPOSITE INDEXES FOR COMPLEX QUERIES
-- ====================

-- Composite index for trending habit queries
CREATE INDEX IF NOT EXISTS idx_captures_trending_composite 
ON captures(habit_id, is_public, created_at DESC) 
WHERE is_public = true;

-- Composite index for social feed queries
CREATE INDEX IF NOT EXISTS idx_captures_social_feed 
ON captures(is_public, created_at DESC, user_id) 
WHERE is_public = true;

-- ====================
-- 8. PARTIAL INDEXES FOR OPTIMIZATION
-- ====================

-- Index for recent captures only (last 30 days)
CREATE INDEX IF NOT EXISTS idx_captures_recent_public 
ON captures(created_at DESC, habit_id) 
WHERE is_public = true AND created_at >= NOW() - INTERVAL '30 days';

-- Index for active user habits with recent activity
CREATE INDEX IF NOT EXISTS idx_user_habits_active_recent 
ON user_habits(habit_template_id, user_id, is_active) 
WHERE is_active = true;

-- ====================
-- 9. ANALYZE TABLES FOR OPTIMIZATION
-- ====================

-- Update table statistics for query planner
ANALYZE captures;
ANALYZE user_habits;
ANALYZE habit_templates;
ANALYZE capture_likes;
ANALYZE profiles;
ANALYZE available_habits;

-- ====================
-- 10. VERIFICATION QUERIES
-- ====================

-- Check if indexes were created successfully
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE tablename IN ('captures', 'user_habits', 'habit_templates', 'capture_likes', 'profiles', 'available_habits')
AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- ====================
-- INDEXES COMPLETE
-- ====================

SELECT 'Performance indexes added successfully! Query performance should be significantly improved.' as message;
