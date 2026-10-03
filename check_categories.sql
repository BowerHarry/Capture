-- Check categories in habit_templates table
SELECT 'habit_templates categories:' as info;
SELECT DISTINCT category FROM habit_templates ORDER BY category;

-- Check categories in trending_habits_view
SELECT 'trending_habits_view categories:' as info;
SELECT DISTINCT category FROM trending_habits_view ORDER BY category;

-- Check sample data from trending_habits_view
SELECT 'trending_habits_view sample data:' as info;
SELECT id, name, category, participants, total_captures 
FROM trending_habits_view 
ORDER BY participants DESC, total_captures DESC 
LIMIT 10;
