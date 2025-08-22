-- Create get_trending_captures_for_habits RPC function
-- This function returns trending captures for habits with proper metadata

CREATE OR REPLACE FUNCTION get_trending_captures_for_habits()
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
      -- Simple trending score
      (
        (COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) * 2.0) +
        (COUNT(DISTINCT uh.user_id) * 1.0)
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
    -- Get recent captures for trending habits
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
      AND c.created_at >= NOW() - INTERVAL '30 days'  -- Only recent captures
    ORDER BY c.id, c.created_at DESC
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
  ORDER BY tc.trend_score DESC, tc.capture_created_at DESC
  LIMIT 100;  -- Return up to 100 trending captures
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_trending_captures_for_habits() TO authenticated;

-- Add comment explaining the function
COMMENT ON FUNCTION get_trending_captures_for_habits() IS 'Returns trending captures for habits with user and engagement metadata';
