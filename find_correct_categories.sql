-- =====================================================
-- FIND CORRECT CATEGORIES
-- =====================================================

-- Find which categories the habit templates with recent captures belong to
SELECT 'Habit templates with captures and their categories:' as debug_step;
SELECT 
    ht.id as habit_template_id,
    ht.name as habit_name,
    ht.category_id,
    hc.name as category_name,
    hc.color as category_color,
    COUNT(c.id) as capture_count
FROM habit_templates ht
LEFT JOIN habit_categories hc ON ht.category_id = hc.id
LEFT JOIN captures c ON ht.id = c.habit_template_id 
    AND c.is_public = true 
    AND c.created_at >= NOW() - INTERVAL '7 days'
WHERE ht.is_active = true
GROUP BY ht.id, ht.name, ht.category_id, hc.name, hc.color
HAVING COUNT(c.id) > 0
ORDER BY capture_count DESC;

-- Find all categories that have habit templates with captures
SELECT 'Categories with active habit templates:' as debug_step;
SELECT 
    hc.id as category_id,
    hc.name as category_name,
    hc.color as category_color,
    COUNT(DISTINCT ht.id) as habit_template_count,
    COUNT(c.id) as total_captures
FROM habit_categories hc
JOIN habit_templates ht ON hc.id = ht.category_id AND ht.is_active = true
LEFT JOIN captures c ON ht.id = c.habit_template_id 
    AND c.is_public = true 
    AND c.created_at >= NOW() - INTERVAL '7 days'
GROUP BY hc.id, hc.name, hc.color
HAVING COUNT(c.id) > 0
ORDER BY total_captures DESC;

-- Test the function with a category that actually has data
-- (Replace the UUID below with one from the results above)
SELECT 'Testing with a category that has data:' as test_step;
-- SELECT * FROM get_trending_habits_by_category('REPLACE_WITH_ACTUAL_CATEGORY_ID');
