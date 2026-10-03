-- Check what trending-related objects exist in the database
SELECT 'Trending-related tables:' as info;
SELECT 
    schemaname,
    tablename
FROM pg_tables 
WHERE tablename LIKE '%trending%' OR tablename LIKE '%habit%'
ORDER BY tablename;

-- Check for views
SELECT 'Trending-related views:' as info;
SELECT 
    schemaname,
    viewname
FROM pg_views 
WHERE viewname LIKE '%trending%' OR viewname LIKE '%habit%'
ORDER BY viewname;

-- Check for materialized views
SELECT 'Trending-related materialized views:' as info;
SELECT 
    schemaname,
    matviewname
FROM pg_matviews 
WHERE matviewname LIKE '%trending%' OR matviewname LIKE '%habit%'
ORDER BY matviewname;

-- Check for functions
SELECT 'Trending-related functions:' as info;
SELECT 
    proname
FROM pg_proc 
WHERE proname LIKE '%trending%' OR proname LIKE '%habit%'
ORDER BY proname;

-- Check the raw data that should be trending
SELECT 'Raw capture counts by habit_template_id (last 7 days):' as info;
SELECT 
    c.habit_template_id,
    ht.name,
    COUNT(*) as total_captures,
    COUNT(DISTINCT c.user_id) as unique_users
FROM captures c
JOIN habit_templates ht ON c.habit_template_id = ht.id
WHERE c.created_at >= NOW() - INTERVAL '7 days'
GROUP BY c.habit_template_id, ht.name
ORDER BY total_captures DESC;
