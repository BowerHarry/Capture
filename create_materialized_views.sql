-- Create Materialized Views for Complex Aggregations
-- This script creates materialized views to improve performance for complex queries

-- ====================
-- 1. MATERIALIZED VIEW FOR TRENDING HABITS
-- ====================

-- Drop existing materialized view if it exists
DROP MATERIALIZED VIEW IF EXISTS mv_trending_habits CASCADE;

CREATE MATERIALIZED VIEW mv_trending_habits AS
WITH habit_stats AS (
  -- Calculate basic stats for each habit template (only active participants)
  SELECT 
    ht.id,
    ht.name,
    ht.category,
    ht.description,
    ht.target_frequency,
    ht.target_count,
    ht.is_active,
    ht.created_at,
    -- Only count participants who have captured in the past 7 days
    COUNT(DISTINCT CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN uh.user_id END) as active_participants,
    -- Only average streak from participants who have captured in the past 7 days
    AVG(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN uh.current_streak END) as active_avg_streak,
    COUNT(captures.id) as total_captures,
    COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
    -- Calculate total likes for this habit in the last 7 days (default to 0 if no likes)
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
  -- Calculate trending score using unified function
  SELECT 
    *,
    calculate_trending_score(recent_captures, active_participants, recent_likes) as trend_score
  FROM habit_stats
  WHERE recent_captures > 0  -- Only include habits with captures in the past 7 days
),
habit_captures AS (
  -- Get recent captures for each habit (up to 4, ordered by recency)
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
    AND captures.created_at >= NOW() - INTERVAL '7 days'  -- Only recent captures
    AND captures.habit_id IS NOT NULL  -- Filter out captures with null habit_id
  GROUP BY ht.id
)
SELECT 
  ts.id,
  ts.name,
  ts.category,
  ts.active_participants as participants,
  ROUND(COALESCE(ts.active_avg_streak, 0)::numeric, 1) as avg_streak,
  COALESCE(ts.description, 'A popular habit that many people are building.') as description,
  -- Limit to 4 most recent captures
  CASE 
    WHEN array_length(hc.captures, 1) > 4 THEN hc.captures[1:4]
    ELSE hc.captures
  END as captures,
  ts.total_captures,
  ts.recent_likes,
  ROUND(ts.trend_score::numeric, 2) as trend_score,
  NOW() as last_updated
FROM trending_scores ts
LEFT JOIN habit_captures hc ON ts.id = hc.habit_template_id
ORDER BY ts.recent_captures DESC, ts.trend_score DESC, ts.active_participants DESC
LIMIT 5;  -- Top 5 trending habits

-- Create index on materialized view
CREATE INDEX idx_mv_trending_habits_trend_score ON mv_trending_habits(trend_score DESC);

-- ====================
-- 2. MATERIALIZED VIEW FOR SOCIAL FEED
-- ====================

-- Drop existing materialized view if it exists
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
LIMIT 1000;  -- Limit to most recent 1000 captures

-- Create indexes on materialized view
CREATE INDEX idx_mv_social_feed_created_at ON mv_social_feed(capture_created_at DESC);
CREATE INDEX idx_mv_social_feed_user_id ON mv_social_feed(capture_user_id);
CREATE INDEX idx_mv_social_feed_habit_id ON mv_social_feed(habit_id);

-- ====================
-- 3. MATERIALIZED VIEW FOR USER STATISTICS
-- ====================

-- Drop existing materialized view if it exists
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

-- Create indexes on materialized view
CREATE INDEX idx_mv_user_stats_user_id ON mv_user_stats(user_id);
CREATE INDEX idx_mv_user_stats_best_streak ON mv_user_stats(best_streak DESC);
CREATE INDEX idx_mv_user_stats_recent_captures ON mv_user_stats(recent_captures DESC);

-- ====================
-- 4. MATERIALIZED VIEW FOR HABIT CATEGORY STATS
-- ====================

-- Drop existing materialized view if it exists
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

-- Create index on materialized view
CREATE INDEX idx_mv_habit_category_stats_category ON mv_habit_category_stats(category);
CREATE INDEX idx_mv_habit_category_stats_recent ON mv_habit_category_stats(recent_captures DESC);

-- ====================
-- 5. REFRESH FUNCTIONS
-- ====================

-- Function to refresh trending habits materialized view
CREATE OR REPLACE FUNCTION refresh_trending_habits()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_trending_habits;
END;
$$;

-- Function to refresh social feed materialized view
CREATE OR REPLACE FUNCTION refresh_social_feed()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_social_feed;
END;
$$;

-- Function to refresh user stats materialized view
CREATE OR REPLACE FUNCTION refresh_user_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_user_stats;
END;
$$;

-- Function to refresh habit category stats materialized view
CREATE OR REPLACE FUNCTION refresh_habit_category_stats()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY mv_habit_category_stats;
END;
$$;

-- Function to refresh all materialized views
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

-- ====================
-- 6. TRIGGERS FOR AUTO-REFRESH
-- ====================

-- Function to trigger materialized view refresh
CREATE OR REPLACE FUNCTION trigger_materialized_view_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Refresh trending habits when captures change
  IF TG_TABLE_NAME = 'captures' THEN
    PERFORM refresh_trending_habits();
    PERFORM refresh_social_feed();
    PERFORM refresh_user_stats();
  END IF;
  
  -- Refresh user stats when user_habits change
  IF TG_TABLE_NAME = 'user_habits' THEN
    PERFORM refresh_trending_habits();
    PERFORM refresh_user_stats();
    PERFORM refresh_habit_category_stats();
  END IF;
  
  -- Refresh social feed when likes change
  IF TG_TABLE_NAME = 'capture_likes' THEN
    PERFORM refresh_social_feed();
  END IF;
  
  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Create triggers for auto-refresh
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

-- ====================
-- 7. INITIAL REFRESH
-- ====================

-- Perform initial refresh of all materialized views
SELECT refresh_all_materialized_views();

-- ====================
-- 8. VERIFICATION
-- ====================

-- Check materialized views were created
SELECT 
    schemaname,
    matviewname,
    definition
FROM pg_matviews 
WHERE matviewname LIKE 'mv_%'
ORDER BY matviewname;

-- ====================
-- MATERIALIZED VIEWS COMPLETE
-- ====================

SELECT 'Materialized views created successfully! Complex aggregations will now be much faster.' as message;
