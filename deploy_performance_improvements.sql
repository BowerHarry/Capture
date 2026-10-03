-- Deploy Performance Improvements for Capture App
-- This script implements recommendations 2, 4, and 5 in the correct order

-- ====================
-- DEPLOYMENT ORDER:
-- 1. Consolidate Trending Logic (Recommendation 2)
-- 2. Add Performance Indexes (Recommendation 4)  
-- 3. Create Materialized Views (Recommendation 5)
-- ====================

-- Start transaction for atomic deployment
BEGIN;

-- ====================
-- STEP 1: CONSOLIDATE TRENDING LOGIC
-- ====================

DO $$ 
BEGIN
    RAISE NOTICE 'Step 1: Consolidating trending logic...';
END $$;

-- Create unified trending score function
CREATE OR REPLACE FUNCTION calculate_trending_score(
  recent_captures_count INTEGER,
  active_participants_count INTEGER,
  recent_likes_count INTEGER
) RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  -- Unified trending score calculation
  -- Weights: recent captures (10x), active participants (1x), recent likes (2x)
  RETURN (
    (recent_captures_count * 10.0) + 
    (active_participants_count * 1.0) + 
    (recent_likes_count * 2.0)
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION calculate_trending_score(INTEGER, INTEGER, INTEGER) TO authenticated;

-- Update trending habits view to use unified function
DROP VIEW IF EXISTS trending_habits_view CASCADE;

CREATE VIEW trending_habits_view AS
WITH habit_stats AS (
  SELECT 
    ht.id,
    ht.name,
    ht.category,
    ht.description,
    ht.target_frequency,
    ht.target_count,
    ht.is_active,
    ht.created_at,
    COUNT(DISTINCT CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN uh.user_id END) as active_participants,
    AVG(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN uh.current_streak END) as active_avg_streak,
    COUNT(captures.id) as total_captures,
    COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
    COALESCE(SUM(
      CASE 
        WHEN captures.created_at >= NOW() - INTERVAL '7 days' 
        THEN COALESCE((SELECT like_count FROM capture_like_counts WHERE capture_id = captures.id), 0)
        ELSE 0 
      END
    ), 0) as recent_likes
  FROM habit_templates ht
  LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
  LEFT JOIN captures captures ON uh.id = captures.habit_id AND captures.is_public = true
  WHERE ht.is_active = true
  GROUP BY ht.id, ht.name, ht.category, ht.description, ht.target_frequency, ht.target_count, ht.is_active, ht.created_at
),
trending_scores AS (
  SELECT 
    *,
    calculate_trending_score(recent_captures, active_participants, recent_likes) as trend_score
  FROM habit_stats
  WHERE recent_captures > 0
),
habit_captures AS (
  SELECT 
    ht.id as habit_template_id,
    ARRAY_AGG(
      captures.image_url ORDER BY captures.created_at DESC
    ) FILTER (WHERE captures.image_url IS NOT NULL) as captures
  FROM habit_templates ht
  JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
  JOIN captures captures ON uh.id = captures.habit_id 
  WHERE captures.is_public = true 
    AND captures.image_url IS NOT NULL
    AND captures.created_at >= NOW() - INTERVAL '7 days'
    AND captures.habit_id IS NOT NULL
  GROUP BY ht.id
)
SELECT 
  ts.id,
  ts.name,
  ts.category,
  ts.active_participants as participants,
  ROUND(COALESCE(ts.active_avg_streak, 0)::numeric, 1) as avg_streak,
  COALESCE(ts.description, 'A popular habit that many people are building.') as description,
  CASE 
    WHEN array_length(hc.captures, 1) > 4 THEN hc.captures[1:4]
    ELSE hc.captures
  END as captures,
  ts.total_captures,
  ts.recent_likes,
  ROUND(ts.trend_score::numeric, 2) as trend_score
FROM trending_scores ts
LEFT JOIN habit_captures hc ON ts.id = hc.habit_template_id
ORDER BY ts.recent_captures DESC, ts.trend_score DESC, ts.active_participants DESC
LIMIT 5;

-- Update trending captures function to use unified function
DROP FUNCTION IF EXISTS get_trending_captures_for_habits() CASCADE;

CREATE FUNCTION get_trending_captures_for_habits()
RETURNS TABLE (
  id UUID,
  capture_id UUID,
  habit_id UUID,
  user_id UUID,
  image_url TEXT,
  caption TEXT,
  is_public BOOLEAN,
  capture_created_at TIMESTAMPTZ,
  habit_name TEXT,
  habit_category TEXT,
  user_display_name TEXT,
  user_avatar_url TEXT,
  like_count BIGINT,
  total_captures BIGINT,
  trend_score NUMERIC
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  WITH capture_likes_summary AS (
    SELECT 
      clc.capture_id,
      COUNT(*) as like_count
    FROM capture_like_counts clc
    GROUP BY clc.capture_id
  ),
  trending_habits AS (
    SELECT 
      ht.id as habit_template_id,
      ht.name as habit_name,
      ht.category as habit_category,
      COUNT(DISTINCT CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN uh.user_id END) as active_participants,
      COUNT(captures.id) as total_captures,
      COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
      COALESCE(SUM(
        CASE 
          WHEN captures.created_at >= NOW() - INTERVAL '7 days' 
          THEN COALESCE(cls.like_count, 0)
          ELSE 0 
        END
      ), 0) as recent_likes
    FROM habit_templates ht
    LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
    LEFT JOIN captures captures ON uh.id = captures.habit_id AND captures.is_public = true
    LEFT JOIN capture_likes_summary cls ON captures.id = cls.capture_id
    WHERE ht.is_active = true
    GROUP BY ht.id, ht.name, ht.category
    HAVING COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) > 0
  ),
  trending_habits_with_scores AS (
    SELECT 
      *,
      calculate_trending_score(recent_captures, active_participants, recent_likes) as trend_score
    FROM trending_habits
    ORDER BY recent_captures DESC, trend_score DESC
    LIMIT 5
  ),
  trending_captures AS (
    SELECT 
      c.id,
      c.id as capture_id,
      uh.habit_template_id as habit_id,
      c.user_id,
      c.image_url,
      COALESCE(c.caption, '') as caption,
      c.is_public,
      c.created_at as capture_created_at,
      th.habit_name,
      th.habit_category,
      COALESCE(p.display_name, 'Anonymous User') as user_display_name,
      p.avatar_url as user_avatar_url,
      COALESCE(cls.like_count, 0) as like_count,
      th.total_captures,
      th.trend_score
    FROM trending_habits_with_scores th
    JOIN user_habits uh ON th.habit_template_id = uh.habit_template_id AND uh.is_active = true
    JOIN captures c ON uh.id = c.habit_id
    LEFT JOIN capture_likes_summary cls ON c.id = cls.capture_id
    LEFT JOIN profiles p ON c.user_id = p.id
    WHERE c.is_public = true 
      AND c.image_url IS NOT NULL
      AND c.created_at >= NOW() - INTERVAL '7 days'
      AND c.habit_id IS NOT NULL
    ORDER BY th.habit_template_id, c.created_at DESC, COALESCE(cls.like_count, 0) DESC
  )
  SELECT 
    tc.id,
    tc.capture_id,
    tc.habit_id,
    tc.user_id,
    tc.image_url,
    tc.caption,
    tc.is_public,
    tc.capture_created_at,
    tc.habit_name,
    tc.habit_category,
    tc.user_display_name,
    tc.user_avatar_url,
    tc.like_count,
    tc.total_captures,
    tc.trend_score
  FROM trending_captures tc
  ORDER BY tc.habit_id, tc.capture_created_at DESC, tc.like_count DESC
  LIMIT 100;
END;
$$;

GRANT EXECUTE ON FUNCTION get_trending_captures_for_habits() TO authenticated;

-- ====================
-- STEP 2: ADD PERFORMANCE INDEXES
-- ====================

DO $$ 
BEGIN
    RAISE NOTICE 'Step 2: Adding performance indexes...';
END $$;

-- Captures table indexes
CREATE INDEX IF NOT EXISTS idx_captures_created_at_public 
ON captures(created_at) 
WHERE is_public = true;

CREATE INDEX IF NOT EXISTS idx_captures_user_id_created_at 
ON captures(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_captures_habit_id_created_at 
ON captures(habit_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_captures_public_habit_created 
ON captures(is_public, habit_id, created_at DESC) 
WHERE is_public = true;

CREATE INDEX IF NOT EXISTS idx_captures_public_image_created 
ON captures(is_public, created_at DESC) 
WHERE is_public = true AND image_url IS NOT NULL;

-- User_habits table indexes
CREATE INDEX IF NOT EXISTS idx_user_habits_active_template 
ON user_habits(habit_template_id, is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_user_habits_user_active 
ON user_habits(user_id, is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_user_habits_template_user 
ON user_habits(habit_template_id, user_id, is_active);

-- Habit_templates table indexes
CREATE INDEX IF NOT EXISTS idx_habit_templates_active 
ON habit_templates(is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_habit_templates_category_active 
ON habit_templates(category, is_active) 
WHERE is_active = true;

-- Capture_likes table indexes
CREATE INDEX IF NOT EXISTS idx_capture_likes_capture_id 
ON capture_likes(capture_id);

CREATE INDEX IF NOT EXISTS idx_capture_likes_user_id 
ON capture_likes(user_id);

CREATE INDEX IF NOT EXISTS idx_capture_likes_capture_user 
ON capture_likes(capture_id, user_id);

-- Profiles table indexes
CREATE INDEX IF NOT EXISTS idx_profiles_display_name 
ON profiles(display_name);

CREATE INDEX IF NOT EXISTS idx_profiles_bio_gin 
ON profiles USING gin(to_tsvector('english', bio));

-- Available_habits table indexes
CREATE INDEX IF NOT EXISTS idx_available_habits_default 
ON available_habits(is_default) 
WHERE is_default = true;

CREATE INDEX IF NOT EXISTS idx_available_habits_category 
ON available_habits(category);

-- Composite indexes
CREATE INDEX IF NOT EXISTS idx_captures_trending_composite 
ON captures(habit_id, is_public, created_at DESC) 
WHERE is_public = true;

CREATE INDEX IF NOT EXISTS idx_captures_social_feed 
ON captures(is_public, created_at DESC, user_id) 
WHERE is_public = true;

-- Partial indexes
CREATE INDEX IF NOT EXISTS idx_captures_recent_public 
ON captures(created_at DESC, habit_id) 
WHERE is_public = true AND created_at >= NOW() - INTERVAL '30 days';

CREATE INDEX IF NOT EXISTS idx_user_habits_active_recent 
ON user_habits(habit_template_id, user_id, is_active) 
WHERE is_active = true;

-- Update table statistics
ANALYZE captures;
ANALYZE user_habits;
ANALYZE habit_templates;
ANALYZE capture_likes;
ANALYZE profiles;
ANALYZE available_habits;

-- ====================
-- STEP 3: CREATE MATERIALIZED VIEWS
-- ====================

DO $$ 
BEGIN
    RAISE NOTICE 'Step 3: Creating materialized views...';
END $$;

-- Materialized view for trending habits
DROP MATERIALIZED VIEW IF EXISTS mv_trending_habits CASCADE;

CREATE MATERIALIZED VIEW mv_trending_habits AS
SELECT * FROM trending_habits_view;

CREATE INDEX idx_mv_trending_habits_trend_score ON mv_trending_habits(trend_score DESC);

-- Materialized view for social feed
DROP MATERIALIZED VIEW IF EXISTS mv_social_feed CASCADE;

CREATE MATERIALIZED VIEW mv_social_feed AS
SELECT 
  c.id as capture_id,
  c.habit_id,
  c.user_id as capture_user_id,
  c.image_url,
  c.caption,
  c.is_public,
  c.created_at as capture_created_at,
  ht.name as habit_name,
  ht.category as habit_category,
  p.display_name as user_display_name,
  p.avatar_url as user_avatar_url,
  COALESCE(like_counts.like_count, 0) as like_count,
  like_counts.liked_by_user_ids
FROM captures c
JOIN user_habits uh ON c.habit_id = uh.id
JOIN habit_templates ht ON uh.habit_template_id = ht.id
JOIN profiles p ON c.user_id = p.id
LEFT JOIN (
  SELECT 
    cl.capture_id,
    COUNT(*) as like_count,
    ARRAY_AGG(cl.user_id) as liked_by_user_ids
  FROM capture_likes cl
  GROUP BY cl.capture_id
) like_counts ON c.id = like_counts.capture_id
WHERE c.is_public = true
  AND c.habit_id IS NOT NULL
ORDER BY c.created_at DESC
LIMIT 1000;

CREATE INDEX idx_mv_social_feed_created_at ON mv_social_feed(capture_created_at DESC);
CREATE INDEX idx_mv_social_feed_user_id ON mv_social_feed(capture_user_id);
CREATE INDEX idx_mv_social_feed_habit_id ON mv_social_feed(habit_id);

-- Materialized view for user statistics
DROP MATERIALIZED VIEW IF EXISTS mv_user_stats CASCADE;

CREATE MATERIALIZED VIEW mv_user_stats AS
SELECT 
  p.id as user_id,
  p.display_name,
  p.avatar_url,
  COUNT(DISTINCT uh.id) as total_habits,
  COUNT(DISTINCT CASE WHEN uh.is_active = true THEN uh.id END) as active_habits,
  COUNT(c.id) as total_captures,
  COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
  MAX(uh.current_streak) as best_streak,
  AVG(uh.current_streak) as avg_streak,
  COUNT(DISTINCT CASE WHEN c.is_public = true THEN c.id END) as public_captures,
  NOW() as last_updated
FROM profiles p
LEFT JOIN user_habits uh ON p.id = uh.user_id
LEFT JOIN captures c ON p.id = c.user_id
GROUP BY p.id, p.display_name, p.avatar_url;

CREATE INDEX idx_mv_user_stats_user_id ON mv_user_stats(user_id);
CREATE INDEX idx_mv_user_stats_best_streak ON mv_user_stats(best_streak DESC);
CREATE INDEX idx_mv_user_stats_recent_captures ON mv_user_stats(recent_captures DESC);

-- Materialized view for habit category stats
DROP MATERIALIZED VIEW IF EXISTS mv_habit_category_stats CASCADE;

CREATE MATERIALIZED VIEW mv_habit_category_stats AS
SELECT 
  ht.category,
  COUNT(DISTINCT ht.id) as total_habits,
  COUNT(DISTINCT uh.user_id) as total_participants,
  COUNT(DISTINCT CASE WHEN uh.is_active = true THEN uh.user_id END) as active_participants,
  COUNT(c.id) as total_captures,
  COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
  AVG(uh.current_streak) as avg_streak,
  NOW() as last_updated
FROM habit_templates ht
LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id
LEFT JOIN captures c ON uh.id = c.habit_id AND c.is_public = true
WHERE ht.is_active = true
GROUP BY ht.category
ORDER BY recent_captures DESC;

CREATE INDEX idx_mv_habit_category_stats_category ON mv_habit_category_stats(category);
CREATE INDEX idx_mv_habit_category_stats_recent ON mv_habit_category_stats(recent_captures DESC);

-- Refresh functions
CREATE OR REPLACE FUNCTION refresh_trending_habits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_trending_habits;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_social_feed()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_social_feed;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_user_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_stats;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_habit_category_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_habit_category_stats;
END;
$$;

CREATE OR REPLACE FUNCTION refresh_all_materialized_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM refresh_trending_habits();
  PERFORM refresh_social_feed();
  PERFORM refresh_user_stats();
  PERFORM refresh_habit_category_stats();
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION refresh_trending_habits() TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_social_feed() TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_user_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_habit_category_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_all_materialized_views() TO authenticated;

-- Auto-refresh triggers
CREATE OR REPLACE FUNCTION trigger_materialized_view_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_TABLE_NAME = 'captures' THEN
    PERFORM refresh_trending_habits();
    PERFORM refresh_social_feed();
    PERFORM refresh_user_stats();
  END IF;
  
  IF TG_TABLE_NAME = 'user_habits' THEN
    PERFORM refresh_trending_habits();
    PERFORM refresh_user_stats();
    PERFORM refresh_habit_category_stats();
  END IF;
  
  IF TG_TABLE_NAME = 'capture_likes' THEN
    PERFORM refresh_social_feed();
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trigger_refresh_mv_captures ON captures;
CREATE TRIGGER trigger_refresh_mv_captures
  AFTER INSERT OR UPDATE OR DELETE ON captures
  FOR EACH ROW
  EXECUTE FUNCTION trigger_materialized_view_refresh();

DROP TRIGGER IF EXISTS trigger_refresh_mv_user_habits ON user_habits;
CREATE TRIGGER trigger_refresh_mv_user_habits
  AFTER INSERT OR UPDATE OR DELETE ON user_habits
  FOR EACH ROW
  EXECUTE FUNCTION trigger_materialized_view_refresh();

DROP TRIGGER IF EXISTS trigger_refresh_mv_capture_likes ON capture_likes;
CREATE TRIGGER trigger_refresh_mv_capture_likes
  AFTER INSERT OR UPDATE OR DELETE ON capture_likes
  FOR EACH ROW
  EXECUTE FUNCTION trigger_materialized_view_refresh();

-- Initial refresh
SELECT refresh_all_materialized_views();

-- ====================
-- DEPLOYMENT COMPLETE
-- ====================

DO $$ 
BEGIN
    RAISE NOTICE 'All performance improvements deployed successfully!';
    RAISE NOTICE '1. Trending logic consolidated into unified function';
    RAISE NOTICE '2. Performance indexes added for optimal query performance';
    RAISE NOTICE '3. Materialized views created with auto-refresh triggers';
END $$;

COMMIT;

-- ====================
-- VERIFICATION QUERIES
-- ====================

-- Check indexes were created
SELECT COUNT(*) as total_indexes_created
FROM pg_indexes 
WHERE tablename IN ('captures', 'user_habits', 'habit_templates', 'capture_likes', 'profiles', 'available_habits')
AND indexname LIKE 'idx_%';

-- Check materialized views were created
SELECT COUNT(*) as total_materialized_views
FROM pg_matviews 
WHERE matviewname LIKE 'mv_%';

-- Check functions were created
SELECT COUNT(*) as total_functions
FROM pg_proc 
WHERE proname IN ('calculate_trending_score', 'refresh_trending_habits', 'refresh_social_feed', 'refresh_user_stats', 'refresh_habit_category_stats', 'refresh_all_materialized_views');

SELECT 'Performance improvements deployment complete! Your app should now be significantly faster.' as message;
