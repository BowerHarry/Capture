-- Trending System Setup (Active Participants Only)
-- Run this script in your Supabase SQL Editor to set up the complete trending system

-- ====================
-- 1. CREATE TRENDING HABITS VIEW (Active Participants Only)
-- ====================

-- Drop existing view if it exists
DROP VIEW IF EXISTS trending_habits_view CASCADE;

CREATE VIEW trending_habits_view AS
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
  -- Calculate trending score based on recent captures (only active participants)
  SELECT 
    *,
    -- Simplified trending score focused on recent captures
    (
      (recent_captures * 10.0) +      -- Recent activity weight (heavily weighted)
      (active_participants * 1.0) +   -- Active participants weight (lower weight)
      (recent_likes * 2.0)            -- Recent likes weight (bonus)
    ) as trend_score
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
  GROUP BY ht.id
)
SELECT 
  ts.id,
  ts.name,
  ts.category,
  ts.active_participants as participants,  -- Use active participants count
  ROUND(COALESCE(ts.active_avg_streak, 0)::numeric, 1) as avg_streak,  -- Use active average streak
  COALESCE(ts.description, 'A popular habit that many people are building.') as description,
  -- Limit to 4 most recent captures
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
LIMIT 5;  -- Top 5 trending habits

-- ====================
-- 2. CREATE TRENDING CAPTURES FUNCTION (Active Participants Only)
-- ====================

-- Drop existing function if it exists
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
    -- Pre-calculate like counts for all captures (default to 0 if no likes)
    SELECT 
      clc.capture_id,
      COUNT(*) as like_count
    FROM capture_like_counts clc
    GROUP BY clc.capture_id
  ),
  trending_habits AS (
    -- Get top 5 trending habits with most recent captures (only active participants)
    SELECT 
      ht.id as habit_template_id,
      ht.name as habit_name,
      ht.category as habit_category,
      -- Only count participants who have captured in the past 7 days
      COUNT(DISTINCT CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN uh.user_id END) as active_participants,
      COUNT(captures.id) as total_captures,
      COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
      -- Simplified trending score focused on recent captures
      (
        (COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) * 10.0) +
        (COUNT(DISTINCT CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN uh.user_id END) * 1.0) +
        (COALESCE(SUM(
          CASE 
            WHEN captures.created_at >= NOW() - INTERVAL '7 days' 
            THEN COALESCE(cls.like_count, 0)
            ELSE 0 
          END
        ), 0) * 2.0)
      ) as trend_score
    FROM habit_templates ht
    LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
    LEFT JOIN captures captures ON uh.id = captures.habit_id AND captures.is_public = true
    LEFT JOIN capture_likes_summary cls ON captures.id = cls.capture_id
    WHERE ht.is_active = true
    GROUP BY ht.id, ht.name, ht.category
    HAVING COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) > 0  -- Only habits with recent captures
    ORDER BY COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) DESC, trend_score DESC
    LIMIT 5  -- Top 5 trending habits
  ),
  trending_captures AS (
    -- Get recent captures for trending habits from ALL users (multiple captures per habit)
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
    FROM trending_habits th
    JOIN user_habits uh ON th.habit_template_id = uh.habit_template_id AND uh.is_active = true
    JOIN captures c ON uh.id = c.habit_id
    LEFT JOIN capture_likes_summary cls ON c.id = cls.capture_id
    LEFT JOIN profiles p ON c.user_id = p.id
    WHERE c.is_public = true 
      AND c.image_url IS NOT NULL
      AND c.created_at >= NOW() - INTERVAL '7 days'
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
  LIMIT 100;  -- Return up to 100 trending captures (enough for multiple per habit)
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_trending_captures_for_habits() TO authenticated;

-- ====================
-- 3. ADD COMMENTS AND DOCUMENTATION
-- ====================

COMMENT ON VIEW trending_habits_view IS 'Shows top 5 habits with captures in past 7 days (active participants only)';
COMMENT ON FUNCTION get_trending_captures_for_habits() IS 'Returns trending captures for top 5 habits with recent activity (active participants only)';

-- ====================
-- SETUP COMPLETE
-- ====================

-- Note: This system uses your existing captures_public storage bucket
-- No additional storage bucket setup required!

SELECT 'Active participants trending system setup complete! Using existing captures_public bucket for trending images.' as message;
