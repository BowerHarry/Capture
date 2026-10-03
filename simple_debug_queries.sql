-- =====================================================
-- SIMPLE DEBUG QUERIES
-- =====================================================

-- 1. Check if the category exists
SELECT '1. Category check:' as debug_step;
SELECT id, name, color FROM habit_categories WHERE id = 'C0493F57-39C0-4AB1-84B7-B6DA470381C0';

-- 2. Check all habit categories to see what exists
SELECT '2. All habit categories:' as debug_step;
SELECT id, name, color FROM habit_categories LIMIT 10;

-- 3. Check habit templates in this specific category
SELECT '3. Habit templates in category:' as debug_step;
SELECT ht.id, ht.name, ht.category_id, ht.is_active 
FROM habit_templates ht 
WHERE ht.category_id = 'C0493F57-39C0-4AB1-84B7-B6DA470381C0';

-- 4. Check all habit templates to see what categories they belong to
SELECT '4. Sample habit templates with categories:' as debug_step;
SELECT ht.id, ht.name, ht.category_id, hc.name as category_name, ht.is_active 
FROM habit_templates ht 
LEFT JOIN habit_categories hc ON ht.category_id = hc.id
WHERE ht.is_active = true
LIMIT 10;

-- 5. Check if there are any captures at all
SELECT '5. Sample captures:' as debug_step;
SELECT c.id, c.habit_template_id, c.habit_id, c.user_id, c.is_public, c.created_at
FROM captures c
WHERE c.is_public = true
LIMIT 5;

-- 6. Check captures for any habit templates (not just this category)
SELECT '6. Captures with habit_template_id:' as debug_step;
SELECT c.id, c.habit_template_id, ht.name as habit_name, c.created_at
FROM captures c
JOIN habit_templates ht ON c.habit_template_id = ht.id
WHERE c.is_public = true
AND c.created_at >= NOW() - INTERVAL '7 days'
LIMIT 5;

-- 7. Check user_habits
SELECT '7. Sample user_habits:' as debug_step;
SELECT uh.id, uh.habit_template_id, uh.user_id, uh.is_active, ht.name as habit_name
FROM user_habits uh
JOIN habit_templates ht ON uh.habit_template_id = ht.id
WHERE uh.is_active = true
LIMIT 5;

-- 8. Check captures linked through user_habits
SELECT '8. Captures through user_habits:' as debug_step;
SELECT c.id, c.habit_id, uh.habit_template_id, ht.name as habit_name, c.created_at
FROM captures c
JOIN user_habits uh ON c.habit_id = uh.id
JOIN habit_templates ht ON uh.habit_template_id = ht.id
WHERE c.is_public = true
AND c.created_at >= NOW() - INTERVAL '7 days'
LIMIT 5;
