-- Migrate to Habit Template IDs for Trending and Discovery
-- This migration moves the system to use habit_template_id for trending, discovery, and social features
-- while keeping habit_id for user-specific operations like streaks

-- ====================
-- 1. ADD HABIT_TEMPLATE_ID TO CAPTURES TABLE
-- ====================

-- Add habit_template_id column to captures table
ALTER TABLE captures 
ADD COLUMN IF NOT EXISTS habit_template_id UUID;

-- Update existing captures to have habit_template_id
UPDATE captures 
SET habit_template_id = (
    SELECT uh.habit_template_id 
    FROM user_habits uh 
    WHERE uh.id = captures.habit_id
)
WHERE habit_template_id IS NULL;

-- Make habit_template_id NOT NULL after populating
ALTER TABLE captures 
ALTER COLUMN habit_template_id SET NOT NULL;

-- Add index for habit_template_id queries
CREATE INDEX IF NOT EXISTS idx_captures_habit_template_id 
ON captures(habit_template_id);

CREATE INDEX IF NOT EXISTS idx_captures_template_public_created 
ON captures(habit_template_id, is_public, created_at DESC) 
WHERE is_public = true;

-- ====================
-- 2. UPDATE TRENDING IMAGES TABLE
-- ====================

-- Drop existing trending_images table if it exists
DROP TABLE IF EXISTS trending_images CASCADE;

-- Create new trending_images table based on habit_template_id
CREATE TABLE trending_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
  habit_template_id UUID NOT NULL REFERENCES habit_templates(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  original_image_url TEXT NOT NULL,
  thumbnail_url TEXT NOT NULL,
  image_path TEXT NOT NULL,  -- Path in trending-images bucket
  width INTEGER,
  height INTEGER,
  file_size INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure unique thumbnail per capture
  UNIQUE(capture_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_trending_images_habit_template ON trending_images(habit_template_id);
CREATE INDEX IF NOT EXISTS idx_trending_images_user ON trending_images(user_id);
CREATE INDEX IF NOT EXISTS idx_trending_images_created_at ON trending_images(created_at);

-- Enable RLS on trending_images table
ALTER TABLE trending_images ENABLE ROW LEVEL SECURITY;

-- RLS policies for trending_images table
CREATE POLICY "Public can read trending images" ON trending_images
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert trending images" ON trending_images
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own trending images" ON trending_images
  FOR UPDATE WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own trending images" ON trending_images
  FOR DELETE USING (auth.uid() = user_id);

-- ====================
-- 3. UPDATE TRENDING HABITS VIEW
-- ====================

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
    COUNT(DISTINCT CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN captures.user_id END) as active_participants,
    -- Only average streak from participants who have captured in the past 7 days
    AVG(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN uh.current_streak END) as active_avg_streak,
    COUNT(captures.id) as total_captures,
    COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
    -- Calculate total likes for this habit template in the last 7 days
    COALESCE(SUM(
      CASE 
        WHEN captures.created_at >= NOW() - INTERVAL '7 days' 
        THEN COALESCE((SELECT like_count FROM capture_like_counts WHERE capture_id = captures.id), 0)
        ELSE 0 
      END
    ), 0) as recent_likes
  FROM habit_templates ht
  LEFT JOIN captures captures ON ht.id = captures.habit_template_id AND captures.is_public = true
  LEFT JOIN user_habits uh ON captures.habit_id = uh.id
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
  -- Get recent captures for each habit template (up to 4, ordered by recency)
  SELECT 
    ht.id as habit_template_id,
    ARRAY_AGG(
      captures.image_url ORDER BY captures.created_at DESC
    ) FILTER (WHERE captures.image_url IS NOT NULL) as captures
  FROM habit_templates ht
  JOIN captures captures ON ht.id = captures.habit_template_id
  WHERE captures.is_public = true 
    AND captures.image_url IS NOT NULL
    AND captures.created_at >= NOW() - INTERVAL '7 days'  -- Only recent captures
    AND captures.habit_template_id IS NOT NULL  -- Filter out captures with null habit_template_id
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
-- 4. UPDATE TRENDING CAPTURES FUNCTION
-- ====================

DROP FUNCTION IF EXISTS get_trending_captures_for_habits() CASCADE;

CREATE FUNCTION get_trending_captures_for_habits()
RETURNS TABLE (
  id UUID,
  capture_id UUID,
  habit_template_id UUID,
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
    -- Get top 5 trending habit templates with most recent captures (only active participants)
    SELECT 
      ht.id as habit_template_id,
      ht.name as habit_name,
      ht.category as habit_category,
      -- Only count participants who have captured in the past 7 days
      COUNT(DISTINCT CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN captures.user_id END) as active_participants,
      COUNT(captures.id) as total_captures,
      COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
      -- Calculate total likes for this habit template in the last 7 days
      COALESCE(SUM(
        CASE 
          WHEN captures.created_at >= NOW() - INTERVAL '7 days' 
          THEN COALESCE(cls.like_count, 0)
          ELSE 0 
        END
      ), 0) as recent_likes
    FROM habit_templates ht
    LEFT JOIN captures captures ON ht.id = captures.habit_template_id AND captures.is_public = true
    LEFT JOIN capture_likes_summary cls ON captures.id = cls.capture_id
    WHERE ht.is_active = true
    GROUP BY ht.id, ht.name, ht.category
    HAVING COUNT(CASE WHEN captures.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) > 0  -- Only habits with recent captures
  ),
  trending_habits_with_scores AS (
    -- Calculate trending scores using unified function
    SELECT 
      *,
      calculate_trending_score(recent_captures, active_participants, recent_likes) as trend_score
    FROM trending_habits
    ORDER BY recent_captures DESC, trend_score DESC
    LIMIT 5  -- Top 5 trending habits
  ),
  trending_captures AS (
    -- Get recent captures for trending habit templates from ALL users (multiple captures per habit template)
    SELECT 
      c.id,
      c.id as capture_id,
      c.habit_template_id,
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
    JOIN captures c ON th.habit_template_id = c.habit_template_id
    LEFT JOIN capture_likes_summary cls ON c.id = cls.capture_id
    LEFT JOIN profiles p ON c.user_id = p.id
    WHERE c.is_public = true 
      AND c.image_url IS NOT NULL
      AND c.created_at >= NOW() - INTERVAL '7 days'
      AND c.habit_template_id IS NOT NULL  -- Filter out captures with null habit_template_id
    ORDER BY th.habit_template_id, c.created_at DESC, COALESCE(cls.like_count, 0) DESC
  )
  SELECT 
    tc.id,
    tc.capture_id,
    tc.habit_template_id,
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
  ORDER BY tc.habit_template_id, tc.capture_created_at DESC, tc.like_count DESC
  LIMIT 100;  -- Return up to 100 trending captures (enough for multiple per habit template)
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_trending_captures_for_habits() TO authenticated;

-- ====================
-- 5. UPDATE SOCIAL FEED VIEW
-- ====================

DROP VIEW IF EXISTS social_feed_with_likes CASCADE;

CREATE VIEW social_feed_with_likes AS
SELECT 
  c.id as capture_id,
  c.habit_id,
  c.habit_template_id,
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
JOIN habit_templates ht ON c.habit_template_id = ht.id
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
  AND c.habit_template_id IS NOT NULL
ORDER BY c.created_at DESC;

-- ====================
-- 6. UPDATE MATERIALIZED VIEWS
-- ====================

-- Drop existing materialized views
DROP MATERIALIZED VIEW IF EXISTS mv_trending_habits CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_social_feed CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_user_stats CASCADE;
DROP MATERIALIZED VIEW IF EXISTS mv_habit_category_stats CASCADE;

-- Recreate materialized view for trending habits
CREATE MATERIALIZED VIEW mv_trending_habits AS
SELECT * FROM trending_habits_view;

CREATE INDEX idx_mv_trending_habits_trend_score ON mv_trending_habits(trend_score DESC);

-- Recreate materialized view for social feed
CREATE MATERIALIZED VIEW mv_social_feed AS
SELECT * FROM social_feed_with_likes
LIMIT 1000;

CREATE INDEX idx_mv_social_feed_created_at ON mv_social_feed(capture_created_at DESC);
CREATE INDEX idx_mv_social_feed_user_id ON mv_social_feed(capture_user_id);
CREATE INDEX idx_mv_social_feed_habit_template_id ON mv_social_feed(habit_template_id);

-- Recreate materialized view for user statistics
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

-- Recreate materialized view for habit category stats
CREATE MATERIALIZED VIEW mv_habit_category_stats AS
SELECT 
  ht.category,
  COUNT(DISTINCT ht.id) as total_habits,
  COUNT(DISTINCT c.user_id) as total_participants,
  COUNT(DISTINCT CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN c.user_id END) as active_participants,
  COUNT(c.id) as total_captures,
  COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
  AVG(uh.current_streak) as avg_streak,
  NOW() as last_updated
FROM habit_templates ht
LEFT JOIN captures c ON ht.id = c.habit_template_id AND c.is_public = true
LEFT JOIN user_habits uh ON c.habit_id = uh.id
WHERE ht.is_active = true
GROUP BY ht.category
ORDER BY recent_captures DESC;

CREATE INDEX idx_mv_habit_category_stats_category ON mv_habit_category_stats(category);
CREATE INDEX idx_mv_habit_category_stats_recent ON mv_habit_category_stats(recent_captures DESC);

-- ====================
-- 7. UPDATE TRENDING THUMBNAIL TRIGGER
-- ====================

-- Update function to use habit_template_id
CREATE OR REPLACE FUNCTION create_trending_thumbnail()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only process public captures with images
  IF NEW.is_public = true AND NEW.image_url IS NOT NULL THEN
    -- Insert into trending_images table using habit_template_id
    INSERT INTO trending_images (
      capture_id,
      habit_template_id,
      user_id,
      original_image_url,
      thumbnail_url,
      image_path
    ) VALUES (
      NEW.id,
      NEW.habit_template_id,
      NEW.user_id,
      NEW.image_url,
      NEW.image_url,  -- Will be updated with thumbnail URL by app
      'thumbnails/' || NEW.user_id::text || '/' || NEW.id::text || '.jpg'
    )
    ON CONFLICT (capture_id) DO UPDATE SET
      original_image_url = NEW.image_url,
      updated_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS trigger_create_trending_thumbnail ON captures;
CREATE TRIGGER trigger_create_trending_thumbnail
  AFTER INSERT OR UPDATE ON captures
  FOR EACH ROW
  EXECUTE FUNCTION create_trending_thumbnail();

-- ====================
-- 8. ADD COMMENTS AND DOCUMENTATION
-- ====================

COMMENT ON COLUMN captures.habit_template_id IS 'References the habit template this capture belongs to (for trending and discovery)';
COMMENT ON VIEW trending_habits_view IS 'Shows top 5 habit templates with captures in past 7 days (based on habit_template_id)';
COMMENT ON FUNCTION get_trending_captures_for_habits() IS 'Returns trending captures for top 5 habit templates with recent activity (based on habit_template_id)';
COMMENT ON VIEW social_feed_with_likes IS 'Social feed aggregating captures with like counts and user info (based on habit_template_id)';

-- ====================
-- MIGRATION COMPLETE
-- ====================

SELECT 'Migration to habit_template_id complete! Trending and discovery now based on habit templates.' as message;
