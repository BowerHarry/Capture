-- Test the function and see raw data
SELECT 
    'Function test' as test_type,
    COUNT(*) as total_rows
FROM get_trending_captures_for_habits();

-- Show sample data with explicit type checking
SELECT 
    id,
    capture_id,
    habit_id,
    user_id,
    image_url,
    caption,
    is_public,
    capture_created_at,
    habit_name,
    habit_category,
    user_display_name,
    user_avatar_url,
    like_count,
    total_captures,
    trend_score,
    -- Type checking
    pg_typeof(id) as id_type,
    pg_typeof(like_count) as like_count_type,
    pg_typeof(trend_score) as trend_score_type
FROM get_trending_captures_for_habits()
LIMIT 2;
