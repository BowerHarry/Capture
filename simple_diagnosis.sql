-- Simple Database Diagnosis
-- Run each section separately to identify the issue

-- 1. Check if habit_template_id column exists in captures table
SELECT 
    'Captures table columns:' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'captures' 
  AND column_name IN ('habit_id', 'habit_template_id', 'user_id', 'image_url');

-- 2. Check recent captures
SELECT 
    'Recent captures:' as info,
    id,
    habit_id,
    habit_template_id,
    user_id,
    image_url IS NOT NULL as has_image,
    is_public,
    created_at
FROM captures 
ORDER BY created_at DESC 
LIMIT 5;

-- 3. Check user_habits table structure
SELECT 
    'User_habits table columns:' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'user_habits' 
  AND column_name IN ('id', 'user_id', 'habit_template_id', 'current_streak');

-- 4. Check recent user_habits
SELECT 
    'Recent user_habits:' as info,
    uh.id as user_habit_id,
    uh.user_id,
    uh.habit_template_id,
    uh.current_streak,
    uh.is_active,
    ht.name as habit_name
FROM user_habits uh
LEFT JOIN habit_templates ht ON uh.habit_template_id = ht.id
ORDER BY uh.created_at DESC
LIMIT 5;

-- 5. Check if trending_habits_view exists
SELECT 
    'Trending view exists:' as info,
    COUNT(*) as view_count
FROM information_schema.views 
WHERE table_name = 'trending_habits_view';

-- 6. Check trending_habits_view data
SELECT 
    'Trending habits count:' as info,
    COUNT(*) as count
FROM trending_habits_view;
