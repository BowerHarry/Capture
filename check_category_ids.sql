-- =====================================================
-- CHECK CATEGORY IDS
-- =====================================================

-- Check what categories exist in the database
SELECT 'Categories in database:' as debug_step;
SELECT id, name, color FROM habit_categories ORDER BY name;

-- Check if the problematic category ID exists
SELECT 'Check if F3162109-EE51-47A9-B25A-00B3ACA3CB53 exists:' as debug_step;
SELECT id, name, color FROM habit_categories WHERE id = 'F3162109-EE51-47A9-B25A-00B3ACA3CB53';

-- Check if the correct Fitness category ID exists
SELECT 'Check if 1842a309-7d7a-4871-a3e0-873dc9bed29f exists:' as debug_step;
SELECT id, name, color FROM habit_categories WHERE id = '1842a309-7d7a-4871-a3e0-873dc9bed29f';

-- Check what the get_habit_categories RPC function returns
SELECT 'Testing get_habit_categories RPC function:' as debug_step;
SELECT * FROM get_habit_categories();

-- Test the trending function with the correct Fitness category ID
SELECT 'Testing trending function with correct Fitness category:' as debug_step;
SELECT * FROM get_trending_habits_by_category('1842a309-7d7a-4871-a3e0-873dc9bed29f');
