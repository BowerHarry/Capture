-- =====================================================
-- FIX TRENDING HABITS VIEW ISSUES
-- =====================================================

-- Step 1: Create habit_description table if it doesn't exist
CREATE TABLE IF NOT EXISTS habit_descriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    habit_template_id UUID NOT NULL REFERENCES habit_templates(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(habit_template_id)
);

-- Step 2: Insert meaningful descriptions for existing habit templates
INSERT INTO habit_descriptions (habit_template_id, description) VALUES
-- These UUIDs should match your actual habit template IDs
('13b3143b-a226-4cc0-96d8-e62eb1d5bef7', 'Build healthy eating habits and maintain a balanced diet'),
('8c71b438-2b6f-4155-9d4f-a1ba5e388249', 'Stay hydrated throughout the day for better health'),
('bf03fd3b-5a2c-493e-8056-c0816447d8a1', 'Learn a new language and expand your communication skills'),
('ce31ef1d-1219-4e1b-ad75-ccc9435dceb3', 'Get your daily steps in for better fitness and health'),
('f71692e3-32f9-416f-a386-50209a7cafe6', 'Practice daily journaling for mental clarity and self-reflection'),
('febf3638-ba66-4e1d-83b1-213c97977b41', 'Read for 30 minutes daily to expand knowledge and reduce stress')
ON CONFLICT (habit_template_id) DO UPDATE SET
    description = EXCLUDED.description,
    updated_at = NOW();

-- Step 3: Update the trending_habits_view to use habit_descriptions and limit to 5
DROP VIEW IF EXISTS trending_habits_view;

CREATE VIEW trending_habits_view AS
SELECT
    ht.id,
    ht.name,
    hc.name as category,
    hc.color as category_color,
    COUNT(DISTINCT c.user_id) as participants,
    COALESCE(AVG(uh.current_streak), 0.0) as avg_streak,
    COALESCE(hd.description, 'Track your progress with this habit') as description,
    COUNT(c.id) as total_captures,
    ht.created_at
FROM habit_templates ht
JOIN habit_categories hc ON ht.category_id = hc.id
LEFT JOIN habit_descriptions hd ON ht.id = hd.habit_template_id
LEFT JOIN captures c ON ht.id = c.habit_template_id
    AND c.created_at >= NOW() - INTERVAL '7 days'
    AND c.is_public = TRUE
LEFT JOIN user_habits uh ON c.user_habit_id = uh.id
GROUP BY ht.id, ht.name, hc.name, hc.color, hd.description, ht.created_at
HAVING COUNT(c.id) > 0
ORDER BY participants DESC, total_captures DESC
LIMIT 5;

-- Step 4: Update the get_trending_habits_by_category function to use habit_descriptions
DROP FUNCTION IF EXISTS get_trending_habits_by_category(UUID);

CREATE OR REPLACE FUNCTION get_trending_habits_by_category(category_id_param UUID)
RETURNS TABLE (
    id uuid,
    name text,
    category text,
    category_color text,
    participants bigint,
    avg_streak numeric,
    description text,
    total_captures bigint,
    created_at timestamptz
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ht.id,
        ht.name,
        hc.name as category,
        hc.color as category_color,
        COUNT(DISTINCT c.user_id) as participants,
        COALESCE(AVG(uh.current_streak), 0.0) as avg_streak,
        COALESCE(hd.description, 'Track your progress with this habit') as description,
        COUNT(c.id) as total_captures,
        ht.created_at
    FROM habit_templates ht
    JOIN habit_categories hc ON ht.category_id = hc.id
    LEFT JOIN habit_descriptions hd ON ht.id = hd.habit_template_id
    LEFT JOIN captures c ON ht.id = c.habit_template_id
        AND c.created_at >= NOW() - INTERVAL '7 days'
        AND c.is_public = TRUE
    LEFT JOIN user_habits uh ON c.user_habit_id = uh.id
    WHERE hc.id = category_id_param
    GROUP BY ht.id, ht.name, hc.name, hc.color, hd.description, ht.created_at
    HAVING COUNT(c.id) > 0
    ORDER BY participants DESC, total_captures DESC
    LIMIT 5;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_habit_descriptions_habit_template_id ON habit_descriptions(habit_template_id);

-- Step 6: Add RLS policies for habit_descriptions
ALTER TABLE habit_descriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "habit_descriptions_select_policy" ON habit_descriptions
    FOR SELECT USING (true);

-- Step 7: Create a trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_habit_descriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER habit_descriptions_updated_at_trigger
    BEFORE UPDATE ON habit_descriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_habit_descriptions_updated_at();

-- Verification queries
SELECT 'Migration completed successfully!' as status;
SELECT 'habit_descriptions count:' as info, COUNT(*) as count FROM habit_descriptions;
SELECT 'trending_habits_view should now return max 5 results' as info;
