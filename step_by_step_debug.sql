-- =====================================================
-- STEP BY STEP DEBUG
-- =====================================================

-- Step 1: Check if the category exists
SELECT 'Step 1: Category exists?' as debug_step;
SELECT id, name, color FROM habit_categories WHERE id = 'F3162109-EE51-47A9-B25A-00B3ACA3CB53';

-- Step 2: Check habit templates in this category
SELECT 'Step 2: Habit templates in category' as debug_step;
SELECT ht.id, ht.name, ht.category_id, ht.is_active 
FROM habit_templates ht 
WHERE ht.category_id = 'F3162109-EE51-47A9-B25A-00B3ACA3CB53';

-- Step 3: Check if there are any captures at all for habit templates in this category
SELECT 'Step 3: All captures for habit templates in this category' as debug_step;
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
ORDER BY c.created_at DESC;

-- Step 4: Check public captures for habit templates in this category
SELECT 'Step 4: Public captures for habit templates in this category' as debug_step;
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

-- Step 5: Check recent public captures for habit templates in this category
SELECT 'Step 5: Recent public captures (last 7 days) for habit templates in this category' as debug_step;
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

-- Step 6: Test the habit_stats CTE logic
SELECT 'Step 6: Testing habit_stats CTE logic' as debug_step;
SELECT 
    ht.id,
    ht.name,
    hc.name as category,
    hc.color as category_color,
    COUNT(DISTINCT c.user_id) as participants,
    COUNT(c.id) as total_captures,
    COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures
FROM habit_templates ht
JOIN habit_categories hc ON ht.category_id = hc.id
LEFT JOIN captures c ON c.habit_template_id = ht.id AND c.is_public = true
WHERE hc.id = 'F3162109-EE51-47A9-B25A-00B3ACA3CB53' AND ht.is_active = true
GROUP BY ht.id, ht.name, hc.name, hc.color;

-- Step 7: Test the habit_captures CTE logic
SELECT 'Step 7: Testing habit_captures CTE logic' as debug_step;
SELECT 
    ht.id as habit_template_id,
    ARRAY_AGG(
        c.image_url ORDER BY c.created_at DESC
    ) FILTER (WHERE c.image_url IS NOT NULL) as captures
FROM habit_templates ht
JOIN habit_categories hc ON ht.category_id = hc.id
LEFT JOIN captures c ON c.habit_template_id = ht.id 
    AND c.is_public = true 
    AND c.created_at >= NOW() - INTERVAL '7 days'
WHERE hc.id = 'F3162109-EE51-47A9-B25A-00B3ACA3CB53'
GROUP BY ht.id;
