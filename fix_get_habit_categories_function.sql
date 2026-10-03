-- =====================================================
-- FIX GET HABIT CATEGORIES FUNCTION
-- =====================================================

-- Drop and recreate the function with correct return types
DROP FUNCTION IF EXISTS get_habit_categories();

CREATE OR REPLACE FUNCTION get_habit_categories()
RETURNS TABLE (
    id uuid,
    name text,
    description text,
    color text,
    icon text,
    sort_order integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        hc.id,
        hc.name::text,
        hc.description::text,
        hc.color::text,
        hc.icon::text,
        hc.sort_order
    FROM habit_categories hc
    WHERE hc.is_active = TRUE
    ORDER BY hc.sort_order, hc.name;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT 'get_habit_categories function fixed successfully!' as status;

-- Test the function
SELECT 'Testing get_habit_categories function:' as test_step;
SELECT * FROM get_habit_categories();
