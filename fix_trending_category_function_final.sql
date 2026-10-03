-- =====================================================
-- FIX TRENDING CATEGORY FUNCTION FINAL
-- =====================================================

-- Drop and recreate the function with the correct logic
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
            -- Count participants (unique users who captured this habit)
            COUNT(DISTINCT c.user_id) as participants,
            -- Average streak (we'll set to 0 since we don't have user_habits data)
            0.0 as avg_streak,
            -- Count total captures
            COUNT(DISTINCT c.id) as total_captures,
            -- Count recent captures
            COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
            -- Count new participants (users who first captured this habit in last 7 days)
            COUNT(DISTINCT CASE WHEN c.user_id NOT IN (
                SELECT DISTINCT c2.user_id 
                FROM captures c2 
                WHERE c2.habit_template_id = ht.id 
                AND c2.created_at < NOW() - INTERVAL '7 days'
            ) THEN c.user_id END) as new_participants,
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
    trending_scores AS (
        -- Calculate trending score based on multiple factors
        SELECT 
            hs.*,
            -- Enhanced trending score calculation with likes
            (
                (hs.recent_captures * 2.0) +      -- Recent activity weight
                (hs.new_participants * 3.0) +     -- New user adoption weight
                (hs.participants * 1.0) +         -- Total participants weight
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
                c.image_url ORDER BY 
                    COALESCE((SELECT like_count FROM capture_like_counts WHERE capture_id = c.id), 0) DESC,
                    c.created_at DESC
            ) FILTER (WHERE c.image_url IS NOT NULL) as captures
        FROM habit_templates ht
        JOIN habit_categories hc ON ht.category_id = hc.id
        -- Join captures directly to habit templates
        JOIN captures c ON c.habit_template_id = ht.id 
            AND c.is_public = true 
            AND c.created_at >= NOW() - INTERVAL '7 days'
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
SELECT 'Category trending function FINAL created successfully!' as status;

-- Test with the Fitness category that we know has data
SELECT 'Testing with Fitness category:' as test_step;
SELECT * FROM get_trending_habits_by_category('1842a309-7d7a-4871-a3e0-873dc9bed29f');
