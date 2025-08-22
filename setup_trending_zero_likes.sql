-- Trending System Setup (Works with Zero Likes)
-- Run this script in your Supabase SQL Editor to set up the complete trending system

-- ====================
-- 1. CREATE TRENDING HABITS VIEW (Zero Likes Compatible)
-- ====================

-- Drop existing view if it exists
DROP VIEW IF EXISTS trending_habits_view CASCADE;

CREATE VIEW trending_habits_view AS
WITH habit_stats AS (
  -- Calculate basic stats for each habit template
  SELECT 
    ht.id,
    ht.name,
    ht.category,
    ht.description,
    ht.target_frequency,
    ht.target_count,
    ht.is_active,
    ht.created_at,
    COUNT(DISTINCT uh.user_id) as participants,
    AVG(uh.current_streak) as avg_streak,
    COUNT(captures.id) as total_captures,
    COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
    COUNT(CASE WHEN uh.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as new_participants,
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
  -- Calculate trending score based on multiple factors (likes are optional)
  SELECT 
    *,
    -- Enhanced trending score calculation (likes are bonus, not required)
    (
      (recent_captures * 3.0) +      -- Recent activity weight (increased)
      (new_participants * 4.0) +     -- New user adoption weight (increased)
      (participants * 2.0) +         -- Total participants weight (increased)
      (COALESCE(avg_streak, 0) * 1.0) +  -- Average streak weight
      (recent_likes * 1.0) +         -- Recent likes weight (bonus, not required)
      -- Recency bonus (newer habits get slight boost)
      (CASE 
        WHEN created_at >= NOW() - INTERVAL '30 days' THEN 5.0
        WHEN created_at >= NOW() - INTERVAL '90 days' THEN 2.0
        ELSE 0.0
      END)
    ) as trend_score
  FROM habit_stats
  WHERE participants > 0  -- Only include habits with at least one participant
),
habit_captures AS (
  -- Get recent captures for each habit (up to 4, ordered by recency since no likes)
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
  ts.participants,
  ROUND(COALESCE(ts.avg_streak, 0)::numeric, 1) as avg_streak,
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
WHERE ts.trend_score > 0  -- Only include habits with some activity
ORDER BY ts.trend_score DESC, ts.recent_captures DESC, ts.participants DESC
LIMIT 50;  -- Top 50 trending habits

-- ====================
-- 2. CREATE TRENDING CAPTURES FUNCTION (Zero Likes Compatible)
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
  like_count INTEGER,
  total_captures INTEGER,
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
    -- Get trending habits with their scores (likes are optional)
    SELECT 
      ht.id as habit_template_id,
      ht.name as habit_name,
      ht.category as habit_category,
      COUNT(DISTINCT uh.user_id) as participants,
      COUNT(captures.id) as total_captures,
      COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
      -- Enhanced trending score (likes are bonus, not required)
      (
        (COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) * 3.0) +
        (COUNT(DISTINCT uh.user_id) * 2.0) +
        (COALESCE(SUM(
          CASE 
            WHEN captures.created_at >= NOW() - INTERVAL '7 days' 
            THEN COALESCE(cls.like_count, 0)
            ELSE 0 
          END
        ), 0) * 1.0)
      ) as trend_score
    FROM habit_templates ht
    LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
    LEFT JOIN captures captures ON uh.id = captures.habit_id AND captures.is_public = true
    LEFT JOIN capture_likes_summary cls ON captures.id = cls.capture_id
    WHERE ht.is_active = true
    GROUP BY ht.id, ht.name, ht.category
    HAVING COUNT(DISTINCT uh.user_id) > 0
    ORDER BY trend_score DESC
    LIMIT 20  -- Top 20 trending habits
  ),
  capture_with_likes AS (
    -- Get captures with their like counts (default to 0 if no likes)
    SELECT 
      c.id as capture_id,
      c.user_id as capture_user_id,
      c.image_url as capture_image_url,
      c.caption as capture_caption,
      c.is_public as capture_is_public,
      c.created_at as capture_created_at,
      c.habit_id as capture_habit_id,
      COALESCE(cls.like_count, 0) as capture_like_count
    FROM captures c
    LEFT JOIN capture_likes_summary cls ON c.id = cls.capture_id
    WHERE c.is_public = true 
      AND c.image_url IS NOT NULL
      AND c.created_at >= NOW() - INTERVAL '7 days'
  ),
  trending_captures AS (
    -- Get recent captures for trending habits (ordered by recency since no likes)
    SELECT DISTINCT ON (cwl.capture_id)
      cwl.capture_id as id,
      cwl.capture_id,
      uh.habit_template_id as habit_id,
      cwl.capture_user_id as user_id,
      cwl.capture_image_url as image_url,
      COALESCE(cwl.capture_caption, '') as caption,
      cwl.capture_is_public as is_public,
      cwl.capture_created_at as capture_created_at,
      th.habit_name,
      th.habit_category,
      COALESCE(p.display_name, 'Anonymous User') as user_display_name,
      p.avatar_url as user_avatar_url,
      cwl.capture_like_count as like_count,
      th.total_captures::INTEGER as total_captures,
      th.trend_score
    FROM trending_habits th
    JOIN user_habits uh ON th.habit_template_id = uh.habit_template_id AND uh.is_active = true
    JOIN capture_with_likes cwl ON uh.id = cwl.capture_habit_id
    LEFT JOIN profiles p ON cwl.capture_user_id = p.id
    ORDER BY cwl.capture_id, cwl.capture_created_at DESC, cwl.capture_like_count DESC
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
  ORDER BY tc.capture_created_at DESC, tc.like_count DESC, tc.trend_score DESC
  LIMIT 100;  -- Return up to 100 trending captures
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_trending_captures_for_habits() TO authenticated;

-- ====================
-- 3. ADD COMMENTS AND DOCUMENTATION
-- ====================

COMMENT ON VIEW trending_habits_view IS 'Calculates trending habits based on recent activity and participation (works with zero likes)';
COMMENT ON FUNCTION get_trending_captures_for_habits() IS 'Returns trending captures for habits with user metadata (works with zero likes)';

-- ====================
-- SETUP COMPLETE
-- ====================

-- Note: This system uses your existing captures_public storage bucket
-- No additional storage bucket setup required!

SELECT 'Zero-likes trending system setup complete! Using existing captures_public bucket for trending images.' as message;
