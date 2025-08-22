-- Test the function and see what data it returns
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
    trend_score
FROM get_trending_captures_for_habits()
LIMIT 5;
