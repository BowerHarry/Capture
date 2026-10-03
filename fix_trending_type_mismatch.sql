-- =====================================================
-- FIX TRENDING TYPE MISMATCH ERROR
-- =====================================================

-- Fix the get_trending_habits_by_category function with proper type casting
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
    total_captures bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ht.id,
        ht.name::text,
        hc.name::text as category,
        hc.color::text as category_color,
        COALESCE(COUNT(DISTINCT c.user_id), 0) as participants,
        COALESCE(AVG(uh.current_streak), 0.0) as avg_streak,
        COALESCE(hd.description, 'Track your progress with this habit')::text as description,
        COALESCE(COUNT(c.id), 0) as total_captures
    FROM habit_templates ht
    JOIN habit_categories hc ON ht.category_id = hc.id
    LEFT JOIN habit_descriptions hd ON ht.id = hd.habit_template_id
    LEFT JOIN captures c ON ht.id = c.habit_template_id
        AND c.created_at >= NOW() - INTERVAL '7 days'
        AND c.is_public = TRUE
    LEFT JOIN user_habits uh ON c.user_habit_id = uh.id
    WHERE hc.id = category_id_param
    GROUP BY ht.id, ht.name, hc.name, hc.color, hd.description
    ORDER BY participants DESC, total_captures DESC
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- Fix the trending_habits_view with proper type casting
DROP VIEW IF EXISTS trending_habits_view;

CREATE VIEW trending_habits_view AS
SELECT
    ht.id,
    ht.name::text,
    hc.name::text as category,
    hc.color::text as category_color,
    COALESCE(COUNT(DISTINCT c.user_id), 0) as participants,
    COALESCE(AVG(uh.current_streak), 0.0) as avg_streak,
    COALESCE(hd.description, 'Track your progress with this habit')::text as description,
    COALESCE(COUNT(c.id), 0) as total_captures
FROM habit_templates ht
JOIN habit_categories hc ON ht.category_id = hc.id
LEFT JOIN habit_descriptions hd ON ht.id = hd.habit_template_id
LEFT JOIN captures c ON ht.id = c.habit_template_id
    AND c.created_at >= NOW() - INTERVAL '7 days'
    AND c.is_public = TRUE
LEFT JOIN user_habits uh ON c.user_habit_id = uh.id
GROUP BY ht.id, ht.name, hc.name, hc.color, hd.description
ORDER BY participants DESC, total_captures DESC
LIMIT 5;

-- Verification
SELECT 'Type mismatch fixes applied successfully!' as status;
