-- Fix the trending_habits_view to match Swift TrendingHabit model expectations

-- Drop the existing view
DROP VIEW IF EXISTS trending_habits_view;

-- Create a new trending_habits_view that matches the Swift model
CREATE VIEW trending_habits_view AS
SELECT
    ht.id,
    ht.name,
    COALESCE(ht.category, 'General') as category,
    COUNT(DISTINCT c.user_id) as participants,
    COALESCE(AVG(uh.current_streak), 0.0) as avg_streak,
    COALESCE(ht.description, 'Track your progress with this habit') as description,
    COUNT(c.id) as total_captures,
    ht.created_at
FROM habit_templates ht
LEFT JOIN captures c ON ht.id = c.habit_template_id
    AND c.created_at >= NOW() - INTERVAL '7 days'
    AND c.is_public = TRUE
LEFT JOIN user_habits uh ON c.user_habit_id = uh.id
GROUP BY ht.id, ht.name, ht.category, ht.description, ht.created_at
HAVING COUNT(c.id) > 0
ORDER BY participants DESC, total_captures DESC
LIMIT 10;
