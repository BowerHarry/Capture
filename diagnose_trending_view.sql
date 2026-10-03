-- Comprehensive trending view diagnosis

-- 1. Check if trending_habits_view exists and its structure
SELECT '1. Trending view structure:' as info;
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE viewname = 'trending_habits_view';

-- 2. Check what the view currently returns
SELECT '2. Current trending_habits_view contents:' as info;
SELECT * FROM trending_habits_view ORDER BY trend_score DESC;

-- 3. Check the raw data that should be in the view
SELECT '3. Raw capture counts by habit_template_id (last 7 days):' as info;
SELECT 
    c.habit_template_id,
    ht.name,
    COUNT(*) as total_captures,
    COUNT(DISTINCT c.user_id) as unique_users,
    COUNT(*) FILTER (WHERE c.created_at >= NOW() - INTERVAL '7 days') as recent_captures
FROM captures c
JOIN habit_templates ht ON c.habit_template_id = ht.id
WHERE c.created_at >= NOW() - INTERVAL '7 days'
GROUP BY c.habit_template_id, ht.name
ORDER BY total_captures DESC;

-- 4. Check if the view definition is using the right tables
SELECT '4. Tables referenced in trending_habits_view:' as info;
SELECT 
    schemaname,
    tablename
FROM pg_tables 
WHERE tablename IN ('captures', 'habit_templates', 'user_habits', 'capture_likes');

-- 5. Check if there are any RLS policies blocking the view
SELECT '5. RLS policies on captures table:' as info;
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'captures';

-- 6. Test a simple query that should match the view logic
SELECT '6. Test query to replicate view logic:' as info;
SELECT 
    ht.id,
    ht.name,
    COUNT(c.id) as total_captures,
    COUNT(DISTINCT c.user_id) as participants,
    COUNT(c.id) FILTER (WHERE c.created_at >= NOW() - INTERVAL '7 days') as recent_captures,
    COALESCE(SUM(cl.like_count), 0) as recent_likes
FROM habit_templates ht
LEFT JOIN captures c ON ht.id = c.habit_template_id 
    AND c.created_at >= NOW() - INTERVAL '7 days'
LEFT JOIN (
    SELECT 
        capture_id,
        COUNT(*) as like_count
    FROM capture_likes
    WHERE created_at >= NOW() - INTERVAL '7 days'
    GROUP BY capture_id
) cl ON c.id = cl.capture_id
GROUP BY ht.id, ht.name
HAVING COUNT(c.id) > 0
ORDER BY total_captures DESC;
