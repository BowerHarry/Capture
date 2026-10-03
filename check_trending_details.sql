-- Check Trending Details
-- This will show us what's actually in the trending view

-- 1. Check what's in the trending_habits_view
SELECT 
    'Trending habits details:' as info,
    id,
    name,
    category,
    participants,
    avg_streak,
    total_captures,
    trend_score
FROM trending_habits_view
ORDER BY trend_score DESC;

-- 2. Check your specific habits and their stats
SELECT 
    'Your habits stats:' as info,
    ht.name,
    ht.category,
    COUNT(DISTINCT c.user_id) as participants,
    AVG(uh.current_streak) as avg_streak,
    COUNT(c.id) as total_captures,
    COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures
FROM habit_templates ht
JOIN user_habits uh ON ht.id = uh.habit_template_id
LEFT JOIN captures c ON ht.id = c.habit_template_id AND c.is_public = true
WHERE uh.user_id = 'bedf1fa0-75ce-4c6f-82fa-29b51f0cb500'  -- Your user ID
GROUP BY ht.id, ht.name, ht.category
ORDER BY recent_captures DESC;

-- 3. Check if your habit template is in the top 5 by recent captures
SELECT 
    'Top 5 habit templates by recent captures:' as info,
    ht.name,
    ht.category,
    COUNT(DISTINCT c.user_id) as participants,
    COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures
FROM habit_templates ht
LEFT JOIN captures c ON ht.id = c.habit_template_id AND c.is_public = true
WHERE ht.is_active = true
GROUP BY ht.id, ht.name, ht.category
HAVING COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) > 0
ORDER BY recent_captures DESC
LIMIT 5;

-- 4. Check your most recent capture
SELECT 
    'Your most recent capture:' as info,
    c.id,
    c.habit_id,
    c.habit_template_id,
    ht.name as habit_name,
    c.created_at,
    c.is_public
FROM captures c
JOIN habit_templates ht ON c.habit_template_id = ht.id
WHERE c.user_id = 'bedf1fa0-75ce-4c6f-82fa-29b51f0cb500'  -- Your user ID
ORDER BY c.created_at DESC
LIMIT 1;
