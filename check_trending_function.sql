-- Check the get_trending_captures_for_habits function
SELECT 'Function definition:' as info;
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'get_trending_captures_for_habits';

-- Test the function directly
SELECT 'Function test result:' as info;
SELECT * FROM get_trending_captures_for_habits() LIMIT 3;

-- Check the captures table structure
SELECT 'Captures table structure:' as info;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'captures' 
ORDER BY ordinal_position;

-- Check recent captures with habit_template_id
SELECT 'Recent captures with template_id:' as info;
SELECT 
    id,
    habit_template_id,
    user_habit_id,
    user_id,
    image_url,
    created_at
FROM captures 
WHERE habit_template_id IS NOT NULL
ORDER BY created_at DESC 
LIMIT 5;
