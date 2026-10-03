-- =====================================================
-- CREATE NEW HABIT DESCRIPTIONS TABLE
-- =====================================================

-- Step 1: Drop the old habit_descriptions table
DROP TABLE IF EXISTS habit_descriptions CASCADE;

-- Step 2: Create the new habit_descriptions table
CREATE TABLE habit_descriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    habit_template_id UUID NOT NULL REFERENCES habit_templates(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    is_ai_generated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(habit_template_id)
);

-- Step 3: Add indexes for better performance
CREATE INDEX idx_habit_descriptions_habit_template_id ON habit_descriptions(habit_template_id);
CREATE INDEX idx_habit_descriptions_is_ai_generated ON habit_descriptions(is_ai_generated);

-- Step 4: Add RLS policies
ALTER TABLE habit_descriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "habit_descriptions_select_policy" ON habit_descriptions
    FOR SELECT USING (true);

CREATE POLICY "habit_descriptions_insert_policy" ON habit_descriptions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "habit_descriptions_update_policy" ON habit_descriptions
    FOR UPDATE USING (true);

-- Step 5: Create trigger for updated_at timestamp
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

-- Step 6: Insert descriptions for existing habit templates
-- Using the 5 descriptions per category approach you mentioned

-- Fitness category descriptions
INSERT INTO habit_descriptions (habit_template_id, description) VALUES
('ce31ef1d-1219-4e1b-ad75-ccc9435dceb3', 'Get your daily steps in for better fitness and health'),
('ce4a2d40-f2cd-4cff-8665-93b4f492866d', 'Transform your body and boost your energy levels')
ON CONFLICT (habit_template_id) DO UPDATE SET
    description = EXCLUDED.description,
    updated_at = NOW();

-- Health category descriptions
INSERT INTO habit_descriptions (habit_template_id, description) VALUES
('13b3143b-a226-4cc0-96d8-e62eb1d5bef7', 'Build healthy eating habits for lifelong wellness'),
('8c71b438-2b6f-4155-9d4f-a1ba5e388249', 'Stay hydrated throughout the day for better health')
ON CONFLICT (habit_template_id) DO UPDATE SET
    description = EXCLUDED.description,
    updated_at = NOW();

-- Learning category descriptions
INSERT INTO habit_descriptions (habit_template_id, description) VALUES
('bf03fd3b-5a2c-493e-8056-c0816447d8a1', 'Expand your knowledge and grow your skills'),
('febf3638-ba66-4e1d-83b1-213c97977b41', 'Build a mindset of continuous learning and development')
ON CONFLICT (habit_template_id) DO UPDATE SET
    description = EXCLUDED.description,
    updated_at = NOW();

-- Wellness category descriptions
INSERT INTO habit_descriptions (habit_template_id, description) VALUES
('f71692e3-32f9-416f-a386-50209a7cafe6', 'Practice daily journaling for mental clarity and self-reflection')
ON CONFLICT (habit_template_id) DO UPDATE SET
    description = EXCLUDED.description,
    updated_at = NOW();

-- Step 7: Update the trending_habits_view to use the new table
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

-- Step 8: Update the get_trending_habits_by_category function
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

-- Step 9: Create a function to get or create description for a habit template
CREATE OR REPLACE FUNCTION get_or_create_habit_description(habit_template_id_param UUID)
RETURNS TEXT AS $$
DECLARE
    existing_description TEXT;
    habit_name TEXT;
    habit_category TEXT;
    new_description TEXT;
BEGIN
    -- Check if description already exists
    SELECT description INTO existing_description
    FROM habit_descriptions
    WHERE habit_template_id = habit_template_id_param;
    
    IF existing_description IS NOT NULL THEN
        RETURN existing_description;
    END IF;
    
    -- Get habit template info
    SELECT ht.name, hc.name INTO habit_name, habit_category
    FROM habit_templates ht
    LEFT JOIN habit_categories hc ON ht.category_id = hc.id
    WHERE ht.id = habit_template_id_param;
    
    IF habit_name IS NULL THEN
        RETURN 'Track your progress with this habit';
    END IF;
    
    -- Generate description based on category (placeholder for future AI generation)
    CASE 
        WHEN habit_category = 'Fitness' THEN
            new_description := 'Build strength and improve your fitness with ' || habit_name;
        WHEN habit_category = 'Health' THEN
            new_description := 'Maintain good health and wellness with ' || habit_name;
        WHEN habit_category = 'Learning' THEN
            new_description := 'Expand your knowledge and skills with ' || habit_name;
        WHEN habit_category = 'Wellness' THEN
            new_description := 'Improve your mental and emotional well-being with ' || habit_name;
        WHEN habit_category = 'Nutrition' THEN
            new_description := 'Build healthy eating habits with ' || habit_name;
        WHEN habit_category = 'Productivity' THEN
            new_description := 'Boost your productivity and efficiency with ' || habit_name;
        ELSE
            new_description := 'Track your progress with ' || habit_name;
    END CASE;
    
    -- Insert the new description
    INSERT INTO habit_descriptions (habit_template_id, description, is_ai_generated)
    VALUES (habit_template_id_param, new_description, FALSE)
    ON CONFLICT (habit_template_id) DO NOTHING;
    
    RETURN new_description;
END;
$$ LANGUAGE plpgsql;

-- Step 10: Verification queries
SELECT 'New habit_descriptions table created successfully!' as status;
SELECT 'habit_descriptions count:' as info, COUNT(*) as count FROM habit_descriptions;
SELECT 'trending_habits_view should now return max 5 results with proper descriptions' as info;

-- Show sample data from updated view
SELECT 
    name,
    category,
    description,
    participants,
    total_captures
FROM trending_habits_view
LIMIT 5;
