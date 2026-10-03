-- =====================================================
-- DEBUG TRENDING CATEGORY FUNCTION
-- =====================================================

-- First, let's check what data exists for a specific category
-- Replace 'C0493F57-39C0-4AB1-84B7-B6DA470381C0' with your actual category ID

-- 1. Check if the category exists
SELECT 'Category check:' as debug_step;
SELECT id, name, color FROM habit_categories WHERE id = 'C0493F57-39C0-4AB1-84B7-B6DA470381C0';

-- 2. Check habit templates in this category
SELECT 'Habit templates in category:' as debug_step;
SELECT ht.id, ht.name, ht.category_id, ht.is_active 
FROM habit_templates ht 
WHERE ht.category_id = 'C0493F57-39C0-4AB1-84B7-B6DA470381C0';

-- 3. Check user_habits for these templates
SELECT 'User habits for category templates:' as debug_step;
SELECT uh.id, uh.habit_template_id, uh.user_id, uh.is_active, uh.current_streak
FROM user_habits uh
JOIN habit_templates ht ON uh.habit_template_id = ht.id
WHERE ht.category_id = 'C0493F57-39C0-4AB1-84B7-B6DA470381C0'
AND uh.is_active = true;

-- 4. Check captures for these user_habits
SELECT 'Captures for category habits:' as debug_step;
SELECT c.id, c.habit_id, c.user_id, c.is_public, c.created_at, c.image_url
FROM captures c
JOIN user_habits uh ON c.habit_id = uh.id
JOIN habit_templates ht ON uh.habit_template_id = ht.id
WHERE ht.category_id = 'C0493F57-39C0-4AB1-84B7-B6DA470381C0'
AND c.is_public = true
AND c.created_at >= NOW() - INTERVAL '7 days';

-- 5. Check if there are any captures directly linked to habit_templates (alternative relationship)
SELECT 'Captures directly linked to habit_templates:' as debug_step;
SELECT c.id, c.habit_template_id, c.user_id, c.is_public, c.created_at
FROM captures c
JOIN habit_templates ht ON c.habit_template_id = ht.id
WHERE ht.category_id = 'C0493F57-39C0-4AB1-84B7-B6DA470381C0'
AND c.is_public = true
AND c.created_at >= NOW() - INTERVAL '7 days';

-- Now let's create a simplified version of the function to test
DROP FUNCTION IF EXISTS get_trending_habits_by_category_debug(UUID);

CREATE OR REPLACE FUNCTION get_trending_habits_by_category_debug(category_id_param UUID)
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
        -- Simplified stats calculation
        SELECT 
            ht.id,
            ht.name,
            hc.name as category,
            hc.color as category_color,
            -- Count participants (try both relationships)
            COALESCE(
                COUNT(DISTINCT uh.user_id), 
                COUNT(DISTINCT c2.user_id)
            ) as participants,
            -- Average streak (from user_habits if available)
            AVG(uh.current_streak) as avg_streak,
            -- Count total captures (try both relationships)
            COALESCE(
                COUNT(c1.id), 
                COUNT(c2.id)
            ) as total_captures
        FROM habit_templates ht
        JOIN habit_categories hc ON ht.category_id = hc.id
        -- Try user_habits relationship
        LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
        LEFT JOIN captures c1 ON uh.id = c1.habit_id AND c1.is_public = true
        -- Try direct relationship
        LEFT JOIN captures c2 ON ht.id = c2.habit_template_id AND c2.is_public = true
        WHERE hc.id = category_id_param AND ht.is_active = true
        GROUP BY ht.id, ht.name, hc.name, hc.color
    ),
    habit_captures AS (
        -- Get captures (try both relationships)
        SELECT 
            ht.id as habit_template_id,
            ARRAY_AGG(
                COALESCE(c1.image_url, c2.image_url) ORDER BY 
                COALESCE(c1.created_at, c2.created_at) DESC
            ) FILTER (WHERE COALESCE(c1.image_url, c2.image_url) IS NOT NULL) as captures
        FROM habit_templates ht
        JOIN habit_categories hc ON ht.category_id = hc.id
        -- Try user_habits relationship
        LEFT JOIN user_habits uh ON ht.id = uh.habit_template_id AND uh.is_active = true
        LEFT JOIN captures c1 ON uh.id = c1.habit_id AND c1.is_public = true AND c1.created_at >= NOW() - INTERVAL '7 days'
        -- Try direct relationship
        LEFT JOIN captures c2 ON ht.id = c2.habit_template_id AND c2.is_public = true AND c2.created_at >= NOW() - INTERVAL '7 days'
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
        hc.captures,
        hs.total_captures
    FROM habit_stats hs
    LEFT JOIN habit_descriptions hd ON hs.id = hd.habit_template_id
    LEFT JOIN habit_captures hc ON hs.id = hc.habit_template_id
    WHERE hs.total_captures > 0  -- Only include habits with captures
    ORDER BY hs.participants DESC, hs.total_captures DESC
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT 'Debug function created successfully!' as status;

-- Test with the specific category ID
SELECT 'Testing debug function:' as test_step;
SELECT * FROM get_trending_habits_by_category_debug('C0493F57-39C0-4AB1-84B7-B6DA470381C0');
