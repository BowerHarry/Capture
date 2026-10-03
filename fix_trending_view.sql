-- Fix the trending_habits_view to show the correct data

-- Drop the existing broken view
DROP VIEW IF EXISTS trending_habits_view;

-- Create a new trending_habits_view with correct logic
CREATE VIEW trending_habits_view AS
SELECT 
    ht.id,
    ht.name,
    COUNT(c.id) as total_captures,
    COUNT(DISTINCT c.user_id) as participants,
    COUNT(c.id) FILTER (WHERE c.created_at >= NOW() - INTERVAL '7 days') as recent_captures,
    COALESCE(SUM(cl.like_count), 0) as recent_likes,
    -- Calculate trend score: recent_captures * 2 + recent_likes + participants
    (COUNT(c.id) FILTER (WHERE c.created_at >= NOW() - INTERVAL '7 days') * 2) + 
    COALESCE(SUM(cl.like_count), 0) + 
    COUNT(DISTINCT c.user_id) as trend_score,
    ht.created_at
FROM habit_templates ht
LEFT JOIN captures c ON ht.id = c.habit_template_id 
    AND c.created_at >= NOW() - INTERVAL '7 days'
LEFT JOIN (
    SELECT 
        capture_id,
        COUNT(*) as like_count
    FROM capture_likes
    WHERE created_at >= NOW() - INTERVAL '7 days'
    GROUP BY capture_id
) cl ON c.id = cl.capture_id
GROUP BY ht.id, ht.name, ht.created_at
HAVING COUNT(c.id) > 0
ORDER BY trend_score DESC;

-- Test the new view
SELECT 'New trending_habits_view contents:' as info;
SELECT 
    id,
    name,
    total_captures,
    participants,
    recent_captures,
    recent_likes,
    trend_score
FROM trending_habits_view 
ORDER BY trend_score DESC;
