-- Create trending_habits_view that calculates actual trending metrics
-- This view calculates trending habits based on recent activity, user engagement, and growth

CREATE OR REPLACE VIEW trending_habits_view AS
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
    COUNT(CASE WHEN uh.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as new_participants
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
    -- Trending score calculation (weighted formula)
    (
      (recent_captures * 2.0) +  -- Recent activity weight
      (new_participants * 3.0) +  -- New user adoption weight
      (participants * 1.0) +      -- Total participants weight
      (COALESCE(avg_streak, 0) * 0.5) +  -- Average streak weight
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
  -- Get recent public capture URLs for each habit (up to 4)
  SELECT 
    ht.id as habit_template_id,
    ARRAY_AGG(c.image_url ORDER BY c.created_at DESC) FILTER (WHERE c.image_url IS NOT NULL) as captures
  FROM habit_templates ht
  JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
  JOIN captures c ON uh.id = c.habit_id 
  WHERE c.is_public = true 
    AND c.image_url IS NOT NULL
    AND c.created_at >= NOW() - INTERVAL '30 days'  -- Only recent captures
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
  ROUND(ts.trend_score::numeric, 2) as trend_score
FROM trending_scores ts
LEFT JOIN habit_captures hc ON ts.id = hc.habit_template_id
WHERE ts.trend_score > 0  -- Only include habits with some activity
ORDER BY ts.trend_score DESC, ts.participants DESC
LIMIT 50;  -- Top 50 trending habits

-- Add comment explaining the view
COMMENT ON VIEW trending_habits_view IS 'Calculates trending habits based on recent activity, new participants, and engagement metrics';
