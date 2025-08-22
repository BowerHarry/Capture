-- Safe Trending System Setup (Handles Existing Objects)
-- Run this script in your Supabase SQL Editor to set up the complete trending system

-- ====================
-- 1. CREATE TRENDING HABITS VIEW
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
    COUNT(c.id) as total_captures,
    COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
    COUNT(CASE WHEN uh.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as new_participants,
    -- Calculate total likes for this habit in the last 7 days
    COALESCE(SUM(
      CASE 
        WHEN c.created_at >= NOW() - INTERVAL '7 days' 
        THEN (SELECT COUNT(*) FROM likes WHERE capture_id = c.id)
        ELSE 0 
      END
    ), 0) as recent_likes
  FROM habit_templates ht
  LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
  LEFT JOIN captures c ON uh.id = c.habit_id AND c.is_public = true
  WHERE ht.is_active = true
  GROUP BY ht.id, ht.name, ht.category, ht.description, ht.target_frequency, ht.target_count, ht.is_active, ht.created_at
),
trending_scores AS (
  -- Calculate trending score based on multiple factors
  SELECT 
    *,
    -- Enhanced trending score calculation with likes
    (
      (recent_captures * 2.0) +      -- Recent activity weight
      (new_participants * 3.0) +     -- New user adoption weight
      (participants * 1.0) +         -- Total participants weight
      (COALESCE(avg_streak, 0) * 0.5) +  -- Average streak weight
      (recent_likes * 1.5) +         -- Recent likes weight (high engagement)
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
  -- Get top 4 most liked captures for each habit in the last 7 days
  SELECT 
    ht.id as habit_template_id,
    ARRAY_AGG(
      c.image_url ORDER BY 
        (SELECT COUNT(*) FROM likes WHERE capture_id = c.id) DESC,
        c.created_at DESC
    ) FILTER (WHERE c.image_url IS NOT NULL) as captures
  FROM habit_templates ht
  JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
  JOIN captures c ON uh.id = c.habit_id 
  WHERE c.is_public = true 
    AND c.image_url IS NOT NULL
    AND c.created_at >= NOW() - INTERVAL '7 days'  -- Only recent captures
  GROUP BY ht.id
)
SELECT 
  ts.id,
  ts.name,
  ts.category,
  ts.participants,
  ROUND(COALESCE(ts.avg_streak, 0)::numeric, 1) as avg_streak,
  COALESCE(ts.description, 'A popular habit that many people are building.') as description,
  -- Limit to 4 most liked captures
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
ORDER BY ts.trend_score DESC, ts.recent_likes DESC, ts.participants DESC
LIMIT 50;  -- Top 50 trending habits

-- ====================
-- 2. CREATE TRENDING CAPTURES FUNCTION
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
  WITH trending_habits AS (
    -- Get trending habits with their scores
    SELECT 
      ht.id as habit_template_id,
      ht.name as habit_name,
      ht.category as habit_category,
      COUNT(DISTINCT uh.user_id) as participants,
      COUNT(c.id) as total_captures,
      COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
      -- Enhanced trending score with likes
      (
        (COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) * 2.0) +
        (COUNT(DISTINCT uh.user_id) * 1.0) +
        (COALESCE(SUM(
          CASE 
            WHEN c.created_at >= NOW() - INTERVAL '7 days' 
            THEN (SELECT COUNT(*) FROM likes WHERE capture_id = c.id)
            ELSE 0 
          END
        ), 0) * 1.5)
      ) as trend_score
    FROM habit_templates ht
    LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
    LEFT JOIN captures c ON uh.id = c.habit_id AND c.is_public = true
    WHERE ht.is_active = true
    GROUP BY ht.id, ht.name, ht.category
    HAVING COUNT(DISTINCT uh.user_id) > 0
    ORDER BY trend_score DESC
    LIMIT 20  -- Top 20 trending habits
  ),
  trending_captures AS (
    -- Get most liked captures for trending habits in the last 7 days
    SELECT DISTINCT ON (c.id)
      c.id,
      c.id as capture_id,
      uh.habit_template_id as habit_id,
      c.user_id,
      c.image_url,
      c.caption,
      c.is_public,
      c.created_at as capture_created_at,
      th.habit_name,
      th.habit_category,
      p.display_name as user_display_name,
      p.avatar_url as user_avatar_url,
      COALESCE(like_counts.like_count, 0) as like_count,
      th.total_captures::INTEGER,
      th.trend_score
    FROM trending_habits th
    JOIN user_habits uh ON th.habit_template_id = uh.habit_template_id AND uh.is_active = true
    JOIN captures c ON uh.id = c.habit_id
    LEFT JOIN profiles p ON c.user_id = p.id
    LEFT JOIN (
      -- Count likes for each capture
      SELECT 
        capture_id,
        COUNT(*) as like_count
      FROM likes
      GROUP BY capture_id
    ) like_counts ON c.id = like_counts.capture_id
    WHERE c.is_public = true 
      AND c.image_url IS NOT NULL
      AND c.created_at >= NOW() - INTERVAL '7 days'  -- Only recent captures
    ORDER BY c.id, like_counts.like_count DESC, c.created_at DESC
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
  ORDER BY tc.like_count DESC, tc.trend_score DESC, tc.capture_created_at DESC
  LIMIT 100;  -- Return up to 100 trending captures
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_trending_captures_for_habits() TO authenticated;

-- ====================
-- 3. CREATE TRENDING IMAGES TABLE (OPTIONAL - for thumbnail metadata)
-- ====================

-- Note: Since we're using the existing captures_public bucket, this table is optional
-- It can be used to store thumbnail metadata if you want to generate optimized thumbnails later

-- Create table only if it doesn't exist
CREATE TABLE IF NOT EXISTS trending_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
  habit_template_id UUID NOT NULL REFERENCES habit_templates(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  original_image_url TEXT NOT NULL,
  thumbnail_url TEXT NOT NULL,
  image_path TEXT NOT NULL,  -- Path in captures_public bucket
  width INTEGER,
  height INTEGER,
  file_size INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure unique thumbnail per capture
  UNIQUE(capture_id)
);

-- Create indexes for performance (only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_trending_images_habit_template ON trending_images(habit_template_id);
CREATE INDEX IF NOT EXISTS idx_trending_images_user ON trending_images(user_id);
CREATE INDEX IF NOT EXISTS idx_trending_images_created_at ON trending_images(created_at);

-- Enable RLS on trending_images table
ALTER TABLE trending_images ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Public can read trending images" ON trending_images;
DROP POLICY IF EXISTS "Authenticated users can insert trending images" ON trending_images;
DROP POLICY IF EXISTS "Users can update own trending images" ON trending_images;
DROP POLICY IF EXISTS "Users can delete own trending images" ON trending_images;

-- Create RLS policies for trending_images table
CREATE POLICY "Public can read trending images" ON trending_images
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert trending images" ON trending_images
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own trending images" ON trending_images
  FOR UPDATE WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own trending images" ON trending_images
  FOR DELETE USING (auth.uid() = user_id);

-- ====================
-- 4. CREATE AUTOMATIC THUMBNAIL TRIGGER (OPTIONAL)
-- ====================

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS create_trending_thumbnail() CASCADE;

CREATE FUNCTION create_trending_thumbnail()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  template_id UUID;
BEGIN
  -- Only process public captures with images
  IF NEW.is_public = true AND NEW.image_url IS NOT NULL THEN
    -- Get the habit template ID from user_habits
    SELECT uh.habit_template_id INTO template_id
    FROM user_habits uh
    WHERE uh.id = NEW.habit_id;
    
    -- Insert into trending_images table (thumbnail will be generated by app)
    INSERT INTO trending_images (
      capture_id,
      habit_template_id,
      user_id,
      original_image_url,
      thumbnail_url,
      image_path
    ) VALUES (
      NEW.id,
      template_id,
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

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_create_trending_thumbnail ON captures;

-- Create trigger to automatically create trending thumbnails
CREATE TRIGGER trigger_create_trending_thumbnail
  AFTER INSERT OR UPDATE ON captures
  FOR EACH ROW
  EXECUTE FUNCTION create_trending_thumbnail();

-- ====================
-- 5. ADD COMMENTS AND DOCUMENTATION
-- ====================

COMMENT ON VIEW trending_habits_view IS 'Calculates trending habits based on recent activity, new participants, and engagement metrics';
COMMENT ON FUNCTION get_trending_captures_for_habits() IS 'Returns trending captures for habits with user and engagement metadata';
COMMENT ON TABLE trending_images IS 'Stores metadata for trending habit capture thumbnails';
COMMENT ON FUNCTION create_trending_thumbnail() IS 'Automatically creates trending thumbnail entries when captures are made public';

-- ====================
-- SETUP COMPLETE
-- ====================

-- Note: This system uses your existing captures_public storage bucket
-- No additional storage bucket setup required!

SELECT 'Trending system setup complete! Using existing captures_public bucket for trending images.' as message;
