-- =====================================================
-- FIX HABIT DESCRIPTION TABLE STRUCTURE (CORRECTED)
-- =====================================================

-- Step 1: First, let's identify the correct table name
-- Based on your JSON data, the table might be called 'habit_descriptions' (plural)
-- Let's check and rename if needed

DO $$
DECLARE
    table_name_var TEXT;
BEGIN
    -- Check if habit_description exists
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'habit_description') THEN
        table_name_var := 'habit_description';
    -- Check if habit_descriptions exists
    ELSIF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'habit_descriptions') THEN
        table_name_var := 'habit_descriptions';
    ELSE
        RAISE EXCEPTION 'No habit description table found. Please check the table name.';
    END IF;
    
    RAISE NOTICE 'Found table: %', table_name_var;
    
    -- Rename table to standard name if needed
    IF table_name_var = 'habit_descriptions' THEN
        ALTER TABLE habit_descriptions RENAME TO habit_description;
        RAISE NOTICE 'Renamed habit_descriptions to habit_description';
    END IF;
END $$;

-- Step 2: Rename habit_id column to habit_template_id in habit_description table
ALTER TABLE habit_description 
RENAME COLUMN habit_id TO habit_template_id;

-- Step 3: Add foreign key constraint to habit_templates table
ALTER TABLE habit_description 
ADD CONSTRAINT fk_habit_description_habit_template 
FOREIGN KEY (habit_template_id) REFERENCES habit_templates(id) ON DELETE CASCADE;

-- Step 4: Update the trending_habits_view to use the existing habit_description table
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
LEFT JOIN habit_description hd ON ht.id = hd.habit_template_id
LEFT JOIN captures c ON ht.id = c.habit_template_id
    AND c.created_at >= NOW() - INTERVAL '7 days'
    AND c.is_public = TRUE
LEFT JOIN user_habits uh ON c.user_habit_id = uh.id
GROUP BY ht.id, ht.name, hc.name, hc.color, hd.description, ht.created_at
HAVING COUNT(c.id) > 0
ORDER BY participants DESC, total_captures DESC
LIMIT 5;

-- Step 5: Update the get_trending_habits_by_category function to use habit_description
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
    LEFT JOIN habit_description hd ON ht.id = hd.habit_template_id
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

-- Step 6: Add index for better performance
CREATE INDEX IF NOT EXISTS idx_habit_description_habit_template_id ON habit_description(habit_template_id);

-- Verification queries
SELECT 'Migration completed successfully!' as status;
SELECT 'habit_description table structure updated' as info;
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
