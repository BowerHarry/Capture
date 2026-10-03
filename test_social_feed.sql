-- Test function to debug the social feed structure
CREATE OR REPLACE FUNCTION test_social_feed_structure()
RETURNS TABLE (
    id TEXT,
    user_id UUID,
    habit_template_id UUID,
    habit_name TEXT,
    habit_category TEXT,
    habit_category_color TEXT,
    user_display_name TEXT,
    user_avatar_url TEXT,
    user_username TEXT,
    current_streak INTEGER,
    last_capture_id UUID,
    last_capture_image_url TEXT,
    last_capture_created_at TIMESTAMP WITH TIME ZONE,
    total_captures INTEGER,
    reaction_count INTEGER,
    comment_count INTEGER,
    is_liked_by_current_user BOOLEAN,
    recent_captures JSON
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Return a single test row with all columns properly typed
    RETURN QUERY
    SELECT 
        'test-user-test-habit'::TEXT as id,
        '00000000-0000-0000-0000-000000000000'::UUID as user_id,
        '00000000-0000-0000-0000-000000000000'::UUID as habit_template_id,
        'Test Habit'::TEXT as habit_name,
        'Test Category'::TEXT as habit_category,
        NULL::TEXT as habit_category_color,
        'Test User'::TEXT as user_display_name,
        NULL::TEXT as user_avatar_url,
        'testuser'::TEXT as user_username,
        0::INTEGER as current_streak,
        '00000000-0000-0000-0000-000000000000'::UUID as last_capture_id,
        NULL::TEXT as last_capture_image_url,
        NOW()::TIMESTAMP WITH TIME ZONE as last_capture_created_at,
        0::INTEGER as total_captures,
        0::INTEGER as reaction_count,
        0::INTEGER as comment_count,
        false::BOOLEAN as is_liked_by_current_user,
        '[]'::JSON as recent_captures;
END;
$$;
