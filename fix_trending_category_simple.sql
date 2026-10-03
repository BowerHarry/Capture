-- =====================================================
-- FIX TRENDING CATEGORY FUNCTION SIMPLE
-- =====================================================

-- Drop and recreate the function with simplified logic
DROP FUNCTION IF EXISTS get_trending_habits_by_category(UUID);

CREATE OR REPLACE FUNCTION get_trending_habits_by_category(category_id_param UUID)
RETURNS TABLE (
    id uuid,
    name text,
    category text,
    category_color text,
    participants bigint,
    avg_streak numeric,
    description text,
    captures text[],
    total_captures bigint
) AS $$
BEGIN
    RETURN QUERY
    WITH habit_stats AS (
        -- Simple stats calculation
        SELECT 
            ht.id,
            ht.name,
            hc.name as category,
            hc.color as category_color,
            -- Count participants (unique users who captured this habit)
            COUNT(DISTINCT c.user_id) as participants,
            -- Set avg_streak to 0 since we don't have user_habits data
            0.0 as avg_streak,
            -- Count total captures
            COUNT(c.id) as total_captures,
            -- Count recent captures
            COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
            -- Count new participants (simplified)
            COUNT(DISTINCT c.user_id) as new_participants,
            -- Calculate total likes for this habit in the last 7 days
            COALESCE(SUM(
                CASE 
                    WHEN c.created_at >= NOW() - INTERVAL '7 days' 
                    THEN (SELECT like_count FROM capture_like_counts WHERE capture_id = c.id)
                    ELSE 0 
                END
            ), 0) as recent_likes
        FROM habit_templates ht
        JOIN habit_categories hc ON ht.category_id = hc.id
        -- Join captures directly to habit templates
        LEFT JOIN captures c ON c.habit_template_id = ht.id AND c.is_public = true
        WHERE hc.id = category_id_param AND ht.is_active = true
        GROUP BY ht.id, ht.name, hc.name, hc.color
    ),
    habit_captures AS (
        -- Get captures for each habit
        SELECT 
            ht.id as habit_template_id,
            ARRAY_AGG(
                c.image_url ORDER BY c.created_at DESC
            ) FILTER (WHERE c.image_url IS NOT NULL) as captures
        FROM habit_templates ht
        JOIN habit_categories hc ON ht.category_id = hc.id
        -- Join captures directly to habit templates
        LEFT JOIN captures c ON c.habit_template_id = ht.id 
            AND c.is_public = true 
            AND c.created_at >= NOW() - INTERVAL '7 days'
        WHERE hc.id = category_id_param
        GROUP BY ht.id
    )
    SELECT 
        hs.id,
        hs.name::text,
        hs.category::text,
        hs.category_color::text,
        hs.participants,
        ROUND(COALESCE(hs.avg_streak, 0)::numeric, 1) as avg_streak,
        COALESCE(hd.description, 'A popular habit that many people are building.')::text as description,
        -- Limit to 4 captures
        CASE 
            WHEN array_length(hc.captures, 1) > 4 THEN hc.captures[1:4]
            ELSE hc.captures
        END as captures,
        hs.total_captures
    FROM habit_stats hs
    LEFT JOIN habit_descriptions hd ON hs.id = hd.habit_template_id
    LEFT JOIN habit_captures hc ON hs.id = hc.habit_template_id
    WHERE hs.total_captures > 0  -- Only include habits with captures
    ORDER BY hs.recent_captures DESC, hs.participants DESC, hs.total_captures DESC
    LIMIT 5;  -- Top 5 trending habits for this category
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT 'Category trending function SIMPLE created successfully!' as status;

-- Test with the problematic category
SELECT 'Testing with category F3162109-EE51-47A9-B25A-00B3ACA3CB53:' as test_step;
SELECT * FROM get_trending_habits_by_category('F3162109-EE51-47A9-B25A-00B3ACA3CB53');
