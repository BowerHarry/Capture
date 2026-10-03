-- =====================================================
-- DEBUG SPECIFIC CATEGORY
-- =====================================================

-- Check if this specific category exists
SELECT '1. Category check:' as debug_step;
SELECT id, name, color FROM habit_categories WHERE id = 'F3162109-EE51-47A9-B25A-00B3ACA3CB53';

-- Check what habit templates exist in this category
SELECT '2. Habit templates in this category:' as debug_step;
SELECT ht.id, ht.name, ht.category_id, ht.is_active 
FROM habit_templates ht 
WHERE ht.category_id = 'F3162109-EE51-47A9-B25A-00B3ACA3CB53';

-- Check if there are any captures for habit templates in this category
SELECT '3. Captures for habit templates in this category:' as debug_step;
SELECT 
    c.id as capture_id,
    c.habit_template_id,
    c.user_id,
    c.is_public,
    c.created_at,
    ht.name as habit_name
FROM captures c
JOIN habit_templates ht ON c.habit_template_id = ht.id
WHERE ht.category_id = 'F3162109-EE51-47A9-B25A-00B3ACA3CB53'
AND c.is_public = true
ORDER BY c.created_at DESC;

-- Check recent captures for habit templates in this category
SELECT '4. Recent captures (last 7 days) for habit templates in this category:' as debug_step;
SELECT 
    c.id as capture_id,
    c.habit_template_id,
    c.user_id,
    c.is_public,
    c.created_at,
    ht.name as habit_name
FROM captures c
JOIN habit_templates ht ON c.habit_template_id = ht.id
WHERE ht.category_id = 'F3162109-EE51-47A9-B25A-00B3ACA3CB53'
AND c.is_public = true
AND c.created_at >= NOW() - INTERVAL '7 days'
ORDER BY c.created_at DESC;

-- Check what category the habit template CE31EF1D-1219-4E1B-AD75-CCC9435DCEB3 belongs to
SELECT '5. Check habit template CE31EF1D-1219-4E1B-AD75-CCC9435DCEB3:' as debug_step;
SELECT 
    ht.id,
    ht.name,
    ht.category_id,
    hc.name as category_name,
    hc.color as category_color
FROM habit_templates ht
LEFT JOIN habit_categories hc ON ht.category_id = hc.id
WHERE ht.id = 'CE31EF1D-1219-4E1B-AD75-CCC9435DCEB3';

-- Check captures for this specific habit template
SELECT '6. Captures for habit template CE31EF1D-1219-4E1B-AD75-CCC9435DCEB3:' as debug_step;
SELECT 
    c.id as capture_id,
    c.habit_template_id,
    c.user_id,
    c.is_public,
    c.created_at
FROM captures c
WHERE c.habit_template_id = 'CE31EF1D-1219-4E1B-AD75-CCC9435DCEB3'
AND c.is_public = true
ORDER BY c.created_at DESC;

-- Test the function with this category to see what happens
SELECT '7. Testing function with this category:' as debug_step;
SELECT * FROM get_trending_habits_by_category('F3162109-EE51-47A9-B25A-00B3ACA3CB53');
