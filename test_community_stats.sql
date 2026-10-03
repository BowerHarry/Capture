-- =====================================================
-- TEST COMMUNITY STATS FUNCTION
-- =====================================================

-- Test the community stats function
SELECT 'Testing get_community_stats() function:' as test_step;
SELECT * FROM get_community_stats();

-- Check individual tables to see what data we have
SELECT 'Checking profiles table:' as debug_step;
SELECT COUNT(*) as total_profiles, 
       COUNT(*) FILTER (WHERE is_active = true) as active_profiles
FROM profiles;

SELECT 'Checking user_habits table:' as debug_step;
SELECT COUNT(*) as total_user_habits,
       COUNT(*) FILTER (WHERE is_active = true) as active_user_habits
FROM user_habits;

SELECT 'Checking captures table:' as debug_step;
SELECT COUNT(*) as total_captures FROM captures;

-- Check if the is_active column exists in profiles
SELECT 'Checking if is_active column exists in profiles:' as debug_step;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'profiles' AND column_name = 'is_active';
