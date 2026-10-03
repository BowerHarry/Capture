-- Diagnose Capture Issues
-- This script helps identify why captures aren't being inserted and streaks aren't updating

-- ====================
-- 1. CHECK DATABASE SCHEMA
-- ====================

-- Check if habit_template_id column exists in captures table
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'captures' 
  AND column_name IN ('habit_id', 'habit_template_id', 'user_id', 'image_url')
ORDER BY column_name;

-- ====================
-- 2. CHECK USER_HABITS TABLE
-- ====================

-- Check if user_habits table has habit_template_id
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_habits' 
  AND column_name IN ('id', 'user_id', 'habit_template_id', 'current_streak')
ORDER BY column_name;

-- ====================
-- 3. CHECK RECENT CAPTURES
-- ====================

-- Check recent captures (last 10)
SELECT 
    id,
    habit_id,
    habit_template_id,
    user_id,
    image_url,
    is_public,
    created_at
FROM captures 
ORDER BY created_at DESC 
LIMIT 10;

-- ====================
-- 4. CHECK USER HABITS
-- ====================

-- Check user habits for the current user (replace with actual user ID)
SELECT 
    uh.id as user_habit_id,
    uh.user_id,
    uh.habit_template_id,
    uh.current_streak,
    uh.is_active,
    ht.name as habit_name,
    ht.category
FROM user_habits uh
LEFT JOIN habit_templates ht ON uh.habit_template_id = ht.id
ORDER BY uh.created_at DESC
LIMIT 10;

-- ====================
-- 5. CHECK HABIT TEMPLATES
-- ====================

-- Check habit templates
SELECT 
    id,
    name,
    category,
    is_active,
    created_at
FROM habit_templates 
ORDER BY created_at DESC
LIMIT 10;

-- ====================
-- 6. CHECK FOR ORPHANED CAPTURES
-- ====================

-- Check for captures without valid habit_id
SELECT 
    COUNT(*) as captures_without_habit_id
FROM captures 
WHERE habit_id IS NULL;

-- Check for captures without valid habit_template_id
SELECT 
    COUNT(*) as captures_without_template_id
FROM captures 
WHERE habit_template_id IS NULL;

-- Check for captures with habit_id but no corresponding user_habit
SELECT 
    COUNT(*) as orphaned_captures
FROM captures c
LEFT JOIN user_habits uh ON c.habit_id = uh.id
WHERE c.habit_id IS NOT NULL AND uh.id IS NULL;

-- ====================
-- 7. CHECK TRENDING VIEWS
-- ====================

-- Check if trending_habits_view exists and has data
SELECT 
    COUNT(*) as trending_habits_count
FROM trending_habits_view;

-- Check if get_trending_captures_for_habits function exists
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_name = 'get_trending_captures_for_habits';

-- ====================
-- 8. CHECK STORAGE BUCKETS
-- ====================

-- Check if trending-images bucket exists
SELECT 
    name,
    public
FROM storage.buckets 
WHERE name = 'trending-images';

-- ====================
-- DIAGNOSIS SUMMARY
-- ====================

SELECT 'Database diagnosis complete. Check the results above for issues.' as message;
