-- =====================================================
-- FIND ACTUAL CATEGORIES WITH DATA
-- =====================================================

-- Find all categories that exist
SELECT 'All categories:' as debug_step;
SELECT id, name, color FROM habit_categories ORDER BY name;

-- Find categories that have habit templates
SELECT 'Categories with habit templates:' as debug_step;
SELECT 
    hc.id as category_id,
    hc.name as category_name,
    hc.color as category_color,
    COUNT(ht.id) as habit_template_count
FROM habit_categories hc
LEFT JOIN habit_templates ht ON hc.id = ht.category_id AND ht.is_active = true
GROUP BY hc.id, hc.name, hc.color
HAVING COUNT(ht.id) > 0
ORDER BY habit_template_count DESC;

-- Find categories that have habit templates with captures
SELECT 'Categories with habit templates that have captures:' as debug_step;
SELECT 
    hc.id as category_id,
    hc.name as category_name,
    hc.color as category_color,
    COUNT(DISTINCT ht.id) as habit_template_count,
    COUNT(c.id) as total_captures,
    COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures
FROM habit_categories hc
JOIN habit_templates ht ON hc.id = ht.category_id AND ht.is_active = true
LEFT JOIN captures c ON c.habit_template_id = ht.id AND c.is_public = true
GROUP BY hc.id, hc.name, hc.color
HAVING COUNT(c.id) > 0
ORDER BY recent_captures DESC, total_captures DESC;

-- Find the specific habit template CE31EF1D-1219-4E1B-AD75-CCC9435DCEB3 and its category
SELECT 'Habit template CE31EF1D-1219-4E1B-AD75-CCC9435DCEB3 details:' as debug_step;
SELECT 
    ht.id,
    ht.name,
    ht.category_id,
    hc.name as category_name,
    hc.color as category_color,
    COUNT(c.id) as total_captures,
    COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures
FROM habit_templates ht
LEFT JOIN habit_categories hc ON ht.category_id = hc.id
LEFT JOIN captures c ON c.habit_template_id = ht.id AND c.is_public = true
WHERE ht.id = 'CE31EF1D-1219-4E1B-AD75-CCC9435DCEB3'
GROUP BY ht.id, ht.name, ht.category_id, hc.name, hc.color;

-- Test the function with a category that actually has data
-- (We'll use the first category from the results above)
SELECT 'Testing with a category that has data:' as test_step;
-- SELECT * FROM get_trending_habits_by_category('REPLACE_WITH_ACTUAL_CATEGORY_ID');
