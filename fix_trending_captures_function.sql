-- =====================================================
-- FIX TRENDING CAPTURES FUNCTION
-- =====================================================

-- Drop and recreate the function to match TrendingCapture model structure
DROP FUNCTION IF EXISTS get_trending_captures_for_habits();

CREATE OR REPLACE FUNCTION get_trending_captures_for_habits()
RETURNS TABLE (
    id uuid,
    capture_id uuid,
    habit_template_id uuid,
    user_id uuid,
    image_url text,
    caption text,
    is_public boolean,
    capture_created_at timestamptz,
    habit_name text,
    habit_category text,
    habit_category_id uuid,
    user_display_name text,
    user_avatar_url text,
    like_count bigint,
    total_captures bigint,
    trend_score numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        gen_random_uuid() as id,  -- Generate a unique ID for the trending capture
        c.id as capture_id,
        c.habit_template_id,
        c.user_id,
        c.image_url,
        c.caption,
        c.is_public,
        c.created_at as capture_created_at,
        ht.name as habit_name,
        COALESCE(ht.category, 'General') as habit_category,
        hc.id as habit_category_id,  -- Add the missing habit_category_id field
        COALESCE(p.display_name, 'Anonymous') as user_display_name,
        p.avatar_url as user_avatar_url,
        COALESCE(l.like_count, 0) as like_count,
        capture_counts.total_captures,
        (COALESCE(l.like_count, 0) * 2 + 
         EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 3600) as trend_score
    FROM captures c
    JOIN habit_templates ht ON c.habit_template_id = ht.id
    LEFT JOIN habit_categories hc ON ht.category_id = hc.id  -- Join to get category ID
    LEFT JOIN profiles p ON c.user_id = p.id
    LEFT JOIN (
        SELECT
            cl.capture_id,
            COUNT(*) as like_count
        FROM capture_likes cl
        WHERE cl.created_at >= NOW() - INTERVAL '7 days'
        GROUP BY cl.capture_id
    ) l ON c.id = l.capture_id
    JOIN (
        SELECT 
            c_counts.habit_template_id,
            COUNT(*) as total_captures
        FROM captures c_counts
        WHERE c_counts.is_public = TRUE 
        AND c_counts.created_at >= NOW() - INTERVAL '7 days'
        GROUP BY c_counts.habit_template_id
    ) capture_counts ON c.habit_template_id = capture_counts.habit_template_id
    WHERE c.is_public = TRUE
    AND c.created_at >= NOW() - INTERVAL '7 days'
    AND (
        -- For habits with less than 4 captures, only show 1 capture
        (capture_counts.total_captures < 4 AND 
         c.id = (
             SELECT c2.id 
             FROM captures c2 
             WHERE c2.habit_template_id = c.habit_template_id 
             AND c2.is_public = TRUE 
             AND c2.created_at >= NOW() - INTERVAL '7 days'
             ORDER BY c2.created_at DESC 
             LIMIT 1
         ))
        OR
        -- For habits with 4+ captures, show up to 4 captures
        (capture_counts.total_captures >= 4 AND 
         c.id IN (
             SELECT c3.id 
             FROM captures c3 
             WHERE c3.habit_template_id = c.habit_template_id 
             AND c3.is_public = TRUE 
             AND c3.created_at >= NOW() - INTERVAL '7 days'
             ORDER BY c3.created_at DESC 
             LIMIT 4
         ))
    )
    ORDER BY c.habit_template_id, c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT 'Trending captures function created successfully!' as status;

-- Test with sample data
-- SELECT * FROM get_trending_captures_for_habits() LIMIT 3;
