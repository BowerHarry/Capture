-- Performance Optimizations for Capture App
-- This file contains database optimizations for better app performance

-- 1. Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_user_habits_user_id_active ON user_habits(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_captures_user_habit_id_created_at ON captures(user_habit_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_captures_user_id_public_created_at ON captures(user_id, is_public, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_capture_reactions_capture_id ON capture_reactions(capture_id);
CREATE INDEX IF NOT EXISTS idx_capture_reactions_user_id ON capture_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_capture_comments_capture_id ON capture_comments(capture_id);
CREATE INDEX IF NOT EXISTS idx_profiles_display_name ON profiles(display_name);
CREATE INDEX IF NOT EXISTS idx_habit_templates_category ON habit_templates(category);

-- 2. Create materialized view for social feed (updated every 5 minutes)
CREATE MATERIALIZED VIEW IF NOT EXISTS social_feed_materialized AS
SELECT 
    uh.user_id || '-' || ht.id as id,
    uh.user_id,
    ht.id as habit_template_id,
    ht.name as habit_name,
    ht.category as habit_category,
    NULL as habit_category_color,
    p.display_name as user_display_name,
    p.avatar_url as user_avatar_url,
    p.display_name as user_username,
    uh.current_streak,
    hc.id as last_capture_id,
    hc.image_url as last_capture_image_url,
    hc.created_at as last_capture_created_at,
    (SELECT COUNT(*) FROM captures c WHERE c.user_habit_id = uh.id AND c.is_public = true) as total_captures,
    (SELECT COUNT(*) FROM capture_reactions cr JOIN captures c ON cr.capture_id = c.id WHERE c.user_habit_id = uh.id) as reaction_count,
    (SELECT COUNT(*) FROM capture_comments cc JOIN captures c ON cc.capture_id = c.id WHERE c.user_habit_id = uh.id) as comment_count,
    false as is_liked_by_current_user, -- Will be updated per user
    (
        SELECT COALESCE(
            json_agg(
                json_build_object(
                    'id', c2.id,
                    'image_url', c2.image_url,
                    'caption', c2.caption,
                    'created_at', c2.created_at,
                    'reaction_count', (SELECT COUNT(*) FROM capture_reactions cr WHERE cr.capture_id = c2.id),
                    'comment_count', (SELECT COUNT(*) FROM capture_comments cc WHERE cc.capture_id = c2.id),
                    'is_liked_by_current_user', false,
                    'reaction_users', '[]'::json
                )
            ),
            '[]'::json
        )
        FROM (
            SELECT c2.id, c2.image_url, c2.caption, c2.created_at
            FROM captures c2 
            WHERE c2.user_habit_id = uh.id 
            AND c2.is_public = true
            ORDER BY c2.created_at DESC
            LIMIT 5
        ) c2
    ) as recent_captures
FROM user_habits uh
JOIN habit_templates ht ON uh.habit_template_id = ht.id
JOIN profiles p ON uh.user_id = p.id
JOIN captures hc ON hc.user_habit_id = uh.id AND hc.is_public = true
WHERE uh.is_active = true
AND hc.created_at = (
    SELECT MAX(c2.created_at) 
    FROM captures c2 
    WHERE c2.user_habit_id = uh.id AND c2.is_public = true
)
ORDER BY hc.created_at DESC;

-- Create index on materialized view
CREATE INDEX IF NOT EXISTS idx_social_feed_materialized_created_at ON social_feed_materialized(last_capture_created_at DESC);

-- 3. Create function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_social_feed_materialized()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY social_feed_materialized;
END;
$$;

-- 4. Create optimized function for getting social feed with user-specific data
CREATE OR REPLACE FUNCTION get_social_feed_optimized(
    current_user_id UUID,
    limit_param INTEGER DEFAULT 10,
    offset_param INTEGER DEFAULT 0
)
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
    RETURN QUERY
    SELECT 
        sf.id,
        sf.user_id,
        sf.habit_template_id,
        sf.habit_name,
        sf.habit_category,
        sf.habit_category_color,
        sf.user_display_name,
        sf.user_avatar_url,
        sf.user_username,
        sf.current_streak,
        sf.last_capture_id,
        sf.last_capture_image_url,
        sf.last_capture_created_at,
        sf.total_captures,
        sf.reaction_count,
        sf.comment_count,
        -- Check if current user has reacted to any capture in this habit
        EXISTS(
            SELECT 1 FROM capture_reactions cr 
            JOIN captures c ON cr.capture_id = c.id 
            WHERE c.user_habit_id = sf.habit_template_id::uuid 
            AND cr.user_id = current_user_id
        ) as is_liked_by_current_user,
        sf.recent_captures
    FROM social_feed_materialized sf
    WHERE sf.user_id != current_user_id  -- Filter out current user's posts
    ORDER BY sf.last_capture_created_at DESC
    LIMIT limit_param
    OFFSET offset_param;
END;
$$;

-- 5. Create function for getting user habits with progress (optimized)
CREATE OR REPLACE FUNCTION get_user_habits_with_progress(
    user_id_param UUID,
    since_date TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
    habit_id UUID,
    habit_name TEXT,
    habit_category TEXT,
    target_frequency TEXT,
    target_count INTEGER,
    current_streak INTEGER,
    total_captures INTEGER,
    captures_since_date INTEGER,
    last_capture_date TIMESTAMP WITH TIME ZONE,
    habit_template_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uh.id as habit_id,
        ht.name as habit_name,
        ht.category as habit_category,
        uh.target_frequency,
        uh.target_count,
        uh.current_streak,
        (SELECT COUNT(*) FROM captures c WHERE c.user_habit_id = uh.id) as total_captures,
        (SELECT COUNT(*) FROM captures c WHERE c.user_habit_id = uh.id AND c.created_at >= since_date) as captures_since_date,
        (SELECT MAX(created_at) FROM captures c WHERE c.user_habit_id = uh.id) as last_capture_date,
        uh.habit_template_id
    FROM user_habits uh
    JOIN habit_templates ht ON uh.habit_template_id = ht.id
    WHERE uh.user_id = user_id_param
    AND uh.is_active = true
    ORDER BY uh.created_at DESC;
END;
$$;

-- 6. Create function for getting captures with metadata (optimized)
CREATE OR REPLACE FUNCTION get_captures_with_metadata(
    user_id_param UUID,
    since_date TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
    capture_id UUID,
    user_habit_id UUID,
    image_url TEXT,
    caption TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    is_public BOOLEAN,
    habit_name TEXT,
    habit_category TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id as capture_id,
        c.user_habit_id,
        c.image_url,
        c.caption,
        c.created_at,
        c.is_public,
        ht.name as habit_name,
        ht.category as habit_category
    FROM captures c
    JOIN user_habits uh ON c.user_habit_id = uh.id
    JOIN habit_templates ht ON uh.habit_template_id = ht.id
    WHERE c.user_id = user_id_param
    AND c.created_at >= since_date
    ORDER BY c.created_at DESC;
END;
$$;

-- 7. Create function for getting trending habits (optimized)
CREATE OR REPLACE FUNCTION get_trending_habits_optimized(limit_count INTEGER DEFAULT 5)
RETURNS TABLE (
    habit_template_id UUID,
    habit_name TEXT,
    habit_category TEXT,
    participants INTEGER,
    total_captures INTEGER,
    description TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ht.id as habit_template_id,
        ht.name as habit_name,
        ht.category as habit_category,
        COUNT(DISTINCT uh.user_id) as participants,
        COUNT(c.id) as total_captures,
        ht.description
    FROM habit_templates ht
    LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
    LEFT JOIN captures c ON uh.id = c.user_habit_id
    WHERE c.created_at >= NOW() - INTERVAL '7 days'
    GROUP BY ht.id, ht.name, ht.category, ht.description
    ORDER BY participants DESC, total_captures DESC
    LIMIT limit_count;
END;
$$;

-- 8. Create function for getting community stats (optimized)
CREATE OR REPLACE FUNCTION get_community_stats_optimized()
RETURNS TABLE (
    active_users INTEGER,
    total_habits INTEGER,
    total_captures INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(DISTINCT user_id) FROM user_habits WHERE is_active = true) as active_users,
        (SELECT COUNT(*) FROM user_habits WHERE is_active = true) as total_habits,
        (SELECT COUNT(*) FROM captures WHERE created_at >= NOW() - INTERVAL '30 days') as total_captures;
END;
$$;

-- 9. Grant permissions
GRANT EXECUTE ON FUNCTION get_social_feed_optimized(UUID, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_habits_with_progress(UUID, TIMESTAMP WITH TIME ZONE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_captures_with_metadata(UUID, TIMESTAMP WITH TIME ZONE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_trending_habits_optimized(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_community_stats_optimized() TO authenticated;
GRANT EXECUTE ON FUNCTION refresh_social_feed_materialized() TO authenticated;

-- 10. Create a cron job to refresh materialized view every 5 minutes
-- Note: This requires pg_cron extension to be enabled
-- SELECT cron.schedule('refresh-social-feed', '*/5 * * * *', 'SELECT refresh_social_feed_materialized();');

-- 11. Create function to get reaction users for a capture (optimized)
CREATE OR REPLACE FUNCTION get_capture_reaction_users(capture_id_param UUID)
RETURNS TABLE (
    user_id UUID,
    user_avatar_url TEXT,
    user_display_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cr.user_id,
        p.avatar_url,
        p.display_name
    FROM capture_reactions cr
    JOIN profiles p ON cr.user_id = p.id
    WHERE cr.capture_id = capture_id_param
    ORDER BY cr.created_at DESC
    LIMIT 4;
END;
$$;

GRANT EXECUTE ON FUNCTION get_capture_reaction_users(UUID) TO authenticated;
