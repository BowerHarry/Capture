-- =====================================================
-- FIX TRENDING CATEGORY FUNCTION V2
-- =====================================================

-- Drop and recreate the function with corrected logic
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
        -- Calculate basic stats for each habit template in the specified category
        SELECT 
            ht.id,
            ht.name,
            hc.name as category,
            hc.color as category_color,
            -- Count participants (try both possible relationships)
            COALESCE(
                COUNT(DISTINCT uh.user_id), 
                COUNT(DISTINCT c2.user_id)
            ) as participants,
            -- Average streak (from user_habits if available)
            AVG(uh.current_streak) as avg_streak,
            -- Count total captures (try both possible relationships)
            COALESCE(
                COUNT(c1.id), 
                COUNT(c2.id)
            ) as total_captures,
            -- Count recent captures
            COALESCE(
                COUNT(CASE WHEN c1.created_at >= NOW() - INTERVAL '7 days' THEN 1 END),
                COUNT(CASE WHEN c2.created_at >= NOW() - INTERVAL '7 days' THEN 1 END)
            ) as recent_captures,
            -- Count new participants
            COUNT(CASE WHEN uh.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as new_participants,
            -- Calculate total likes for this habit in the last 7 days
            COALESCE(SUM(
                CASE 
                    WHEN c1.created_at >= NOW() - INTERVAL '7 days' 
                    THEN (SELECT like_count FROM capture_like_counts WHERE capture_id = c1.id)
                    WHEN c2.created_at >= NOW() - INTERVAL '7 days' 
                    THEN (SELECT like_count FROM capture_like_counts WHERE capture_id = c2.id)
                    ELSE 0 
                END
            ), 0) as recent_likes
        FROM habit_templates ht
        JOIN habit_categories hc ON ht.category_id = hc.id
        -- Try user_habits relationship first
        LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
        LEFT JOIN captures c1 ON uh.id = c1.habit_id AND c1.is_public = true
        -- Try direct relationship as fallback
        LEFT JOIN captures c2 ON ht.id = c2.habit_template_id AND c2.is_public = true
        WHERE hc.id = category_id_param AND ht.is_active = true
        GROUP BY ht.id, ht.name, hc.name, hc.color
    ),
    trending_scores AS (
        -- Calculate trending score based on multiple factors
        SELECT 
            hs.*,
            -- Enhanced trending score calculation with likes
            (
                (hs.recent_captures * 2.0) +      -- Recent activity weight
                (hs.new_participants * 3.0) +     -- New user adoption weight
                (hs.participants * 1.0) +         -- Total participants weight
                (COALESCE(hs.avg_streak, 0) * 0.5) +  -- Average streak weight
                (hs.recent_likes * 1.5) +         -- Recent likes weight (high engagement)
                -- Recency bonus (newer habits get slight boost)
                (CASE 
                    WHEN ht.created_at >= NOW() - INTERVAL '30 days' THEN 5.0
                    WHEN ht.created_at >= NOW() - INTERVAL '90 days' THEN 2.0
                    ELSE 0.0
                END)
            ) as trend_score
        FROM habit_stats hs
        JOIN habit_templates ht ON hs.id = ht.id
        WHERE hs.total_captures > 0  -- Only include habits with at least one capture
    ),
    habit_captures AS (
        -- Get top 4 most liked captures for each habit in the last 7 days
        SELECT 
            ht.id as habit_template_id,
            ARRAY_AGG(
                COALESCE(c1.image_url, c2.image_url) ORDER BY 
                    COALESCE(
                        (SELECT like_count FROM capture_like_counts WHERE capture_id = c1.id),
                        (SELECT like_count FROM capture_like_counts WHERE capture_id = c2.id)
                    ) DESC,
                    COALESCE(c1.created_at, c2.created_at) DESC
            ) FILTER (WHERE COALESCE(c1.image_url, c2.image_url) IS NOT NULL) as captures
        FROM habit_templates ht
        JOIN habit_categories hc ON ht.category_id = hc.id
        -- Try user_habits relationship first
        LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
        LEFT JOIN captures c1 ON uh.id = c1.habit_id AND c1.is_public = true AND c1.created_at >= NOW() - INTERVAL '7 days'
        -- Try direct relationship as fallback
        LEFT JOIN captures c2 ON ht.id = c2.habit_template_id AND c2.is_public = true AND c2.created_at >= NOW() - INTERVAL '7 days'
        WHERE hc.id = category_id_param
        GROUP BY ht.id
    )
    SELECT 
        ts.id,
        ts.name::text,
        ts.category::text,
        ts.category_color::text,
        ts.participants,
        ROUND(COALESCE(ts.avg_streak, 0)::numeric, 1) as avg_streak,
        COALESCE(hd.description, 'A popular habit that many people are building.')::text as description,
        -- Limit to 4 most liked captures
        CASE 
            WHEN array_length(hc.captures, 1) > 4 THEN hc.captures[1:4]
            ELSE hc.captures
        END as captures,
        ts.total_captures
    FROM trending_scores ts
    LEFT JOIN habit_descriptions hd ON ts.id = hd.habit_template_id
    LEFT JOIN habit_captures hc ON ts.id = hc.habit_template_id
    ORDER BY ts.trend_score DESC, ts.recent_likes DESC, ts.participants DESC
    LIMIT 5;  -- Top 5 trending habits for this category
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT 'Category trending function V2 created successfully!' as status;

-- Test with a sample category (replace with actual category ID)
-- SELECT * FROM get_trending_habits_by_category('C0493F57-39C0-4AB1-84B7-B6DA470381C0');
