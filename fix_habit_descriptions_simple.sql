-- =====================================================
-- FIX HABIT DESCRIPTIONS TABLE STRUCTURE (SIMPLE VERSION)
-- =====================================================

-- Step 1: Rename habit_id column to habit_template_id in habit_descriptions table
ALTER TABLE habit_descriptions 
RENAME COLUMN habit_id TO habit_template_id;

-- Step 2: Skip foreign key constraint for now (we'll handle data cleanup separately)
-- ALTER TABLE habit_descriptions 
-- ADD CONSTRAINT fk_habit_descriptions_habit_template 
-- FOREIGN KEY (habit_template_id) REFERENCES habit_templates(id) ON DELETE CASCADE;

-- Step 3: Update the trending_habits_view to use the existing habit_descriptions table
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

-- Step 5: Add index for better performance
CREATE INDEX IF NOT EXISTS idx_habit_descriptions_habit_template_id ON habit_descriptions(habit_template_id);

-- Step 6: Add RLS policies for habit_descriptions (if not already present)
ALTER TABLE habit_descriptions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "habit_descriptions_select_policy" ON habit_descriptions;
CREATE POLICY "habit_descriptions_select_policy" ON habit_descriptions
    FOR SELECT USING (true);

-- Step 7: Create trigger for updated_at timestamp (if not already present)
CREATE OR REPLACE FUNCTION update_habit_descriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS habit_descriptions_updated_at_trigger ON habit_descriptions;
CREATE TRIGGER habit_descriptions_updated_at_trigger
    BEFORE UPDATE ON habit_descriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_habit_descriptions_updated_at();

-- Verification queries
SELECT 'Migration completed successfully!' as status;
SELECT 'habit_descriptions table structure updated' as info;
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
