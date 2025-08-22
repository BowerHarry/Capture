-- Test the function return structure
SELECT 
    pg_typeof(id) as id_type,
    pg_typeof(capture_id) as capture_id_type,
    pg_typeof(habit_id) as habit_id_type,
    pg_typeof(user_id) as user_id_type,
    pg_typeof(image_url) as image_url_type,
    pg_typeof(caption) as caption_type,
    pg_typeof(is_public) as is_public_type,
    pg_typeof(capture_created_at) as capture_created_at_type,
    pg_typeof(habit_name) as habit_name_type,
    pg_typeof(habit_category) as habit_category_type,
    pg_typeof(user_display_name) as user_display_name_type,
    pg_typeof(user_avatar_url) as user_avatar_url_type,
    pg_typeof(like_count) as like_count_type,
    pg_typeof(total_captures) as total_captures_type,
    pg_typeof(trend_score) as trend_score_type
FROM get_trending_captures_for_habits()
LIMIT 1;
