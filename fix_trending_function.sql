-- Check the get_trending_captures_for_habits function definition
SELECT 'Function definition:' as info;
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'get_trending_captures_for_habits';

-- Test the function to see the exact error
SELECT 'Testing function:' as info;
SELECT * FROM get_trending_captures_for_habits() LIMIT 3;

-- Check what columns the function is trying to return
SELECT 'Function return type:' as info;
SELECT 
    p.proname,
    pg_get_function_result(p.oid) as result_type,
    pg_get_function_arguments(p.oid) as arguments
FROM pg_proc p
WHERE p.proname = 'get_trending_captures_for_habits';

-- Check the captures table structure to see what columns exist
SELECT 'Captures table structure:' as info;
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'captures' 
ORDER BY ordinal_position;

-- Drop the existing function first
DROP FUNCTION IF EXISTS get_trending_captures_for_habits();

-- Create a simple trending function that works with the current schema
CREATE OR REPLACE FUNCTION get_trending_captures_for_habits()
RETURNS TABLE (
    id uuid,
    habit_template_id uuid,
    user_id uuid,
    image_url text,
    caption text,
    is_public boolean,
    created_at timestamptz,
    like_count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.habit_template_id,
        c.user_id,
        c.image_url,
        c.caption,
        c.is_public,
        c.created_at,
        COALESCE(l.like_count, 0) as like_count
    FROM captures c
    LEFT JOIN (
        SELECT 
            capture_id,
            COUNT(*) as like_count
        FROM capture_likes
        GROUP BY capture_id
    ) l ON c.id = l.capture_id
    WHERE c.is_public = true
    AND c.created_at >= NOW() - INTERVAL '7 days'
    ORDER BY c.created_at DESC
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;
