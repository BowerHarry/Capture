-- =====================================================
-- HABIT CATEGORIES SYSTEM MIGRATION
-- =====================================================

-- Step 1: Create the habit_categories table
CREATE TABLE IF NOT EXISTS habit_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    color VARCHAR(20) DEFAULT 'gray',
    icon VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 2: Insert default habit categories
INSERT INTO habit_categories (name, description, color, icon, sort_order) VALUES
('Fitness', 'Physical exercise and movement habits', 'green', 'dumbbell', 1),
('Wellness', 'Mental health and mindfulness habits', 'purple', 'heart', 2),
('Learning', 'Educational and skill-building habits', 'orange', 'book', 3),
('Nutrition', 'Diet and eating habits', 'mint', 'apple', 4),
('Productivity', 'Work and efficiency habits', 'blue', 'briefcase', 5),
('Health', 'General health and medical habits', 'pink', 'cross', 6),
('Social', 'Relationship and communication habits', 'yellow', 'users', 7),
('Finance', 'Money and financial habits', 'red', 'dollar-sign', 8),
('Sleep', 'Sleep and rest habits', 'indigo', 'moon', 9),
('Creativity', 'Art and creative expression habits', 'teal', 'palette', 10)
ON CONFLICT (name) DO NOTHING;

-- Step 3: Update habit_descriptions table structure (rename habit_id to habit_template_id)
ALTER TABLE habit_descriptions 
RENAME COLUMN habit_id TO habit_template_id;

ALTER TABLE habit_descriptions 
ADD CONSTRAINT fk_habit_descriptions_habit_template 
FOREIGN KEY (habit_template_id) REFERENCES habit_templates(id) ON DELETE CASCADE;

-- Step 4: Add category_id column to habit_templates table
ALTER TABLE habit_templates 
ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES habit_categories(id);

-- Step 5: Update existing habit descriptions with better content (optional - only if needed)
-- The existing habit_descriptions table already has good descriptions, so this step is optional
-- If you want to update any descriptions, you can uncomment and modify the following:

/*
UPDATE habit_descriptions SET 
    description = 'Build healthy eating habits for lifelong wellness',
    updated_at = NOW()
WHERE habit_template_id = '13b3143b-a226-4cc0-96d8-e62eb1d5bef7';

UPDATE habit_descriptions SET 
    description = 'Maintain optimal hydration for peak performance',
    updated_at = NOW()
WHERE habit_template_id = '8c71b438-2b6f-4155-9d4f-a1ba5e388249';
*/

-- Step 6: Update existing habit_templates with category IDs based on their current category field
UPDATE habit_templates 
SET category_id = (
    SELECT hc.id 
    FROM habit_categories hc 
    WHERE LOWER(hc.name) = LOWER(habit_templates.category)
    LIMIT 1
)
WHERE category_id IS NULL;

-- Step 7: Set default category for any habits that don't have a category
UPDATE habit_templates 
SET category_id = (SELECT id FROM habit_categories WHERE name = 'General' LIMIT 1)
WHERE category_id IS NULL;

-- Step 8: Make category_id NOT NULL after setting defaults
ALTER TABLE habit_templates 
ALTER COLUMN category_id SET NOT NULL;

-- Step 9: Add category_id column to available_habits table
ALTER TABLE available_habits 
ADD COLUMN IF NOT EXISTS category_id UUID REFERENCES habit_categories(id);

-- Step 10: Update existing available_habits with category IDs
UPDATE available_habits 
SET category_id = (
    SELECT hc.id 
    FROM habit_categories hc 
    WHERE LOWER(hc.name) = LOWER(available_habits.category)
    LIMIT 1
)
WHERE category_id IS NULL;

-- Step 11: Set default category for any available_habits that don't have a category
UPDATE available_habits 
SET category_id = (SELECT id FROM habit_categories WHERE name = 'General' LIMIT 1)
WHERE category_id IS NULL;

-- Step 12: Make category_id NOT NULL for available_habits
ALTER TABLE available_habits 
ALTER COLUMN category_id SET NOT NULL;

-- Step 13: Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_habit_templates_category_id ON habit_templates(category_id);
CREATE INDEX IF NOT EXISTS idx_available_habits_category_id ON available_habits(category_id);
CREATE INDEX IF NOT EXISTS idx_habit_categories_name ON habit_categories(name);
CREATE INDEX IF NOT EXISTS idx_habit_categories_sort_order ON habit_categories(sort_order);
CREATE INDEX IF NOT EXISTS idx_habit_descriptions_habit_template_id ON habit_descriptions(habit_template_id);

-- Step 14: Update the trending_habits_view to use category_id
DROP VIEW IF EXISTS trending_habits_view;

CREATE VIEW trending_habits_view AS
SELECT
    ht.id,
    ht.name,
    hc.name as category,
    hc.color as category_color,
    COUNT(DISTINCT c.user_id) as participants,
    COALESCE(AVG(uh.current_streak), 0.0) as avg_streak,
    COALESCE(ht.description, 'Track your progress with this habit') as description,
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

-- Step 15: Update the get_trending_captures_for_habits function
DROP FUNCTION IF EXISTS get_trending_captures_for_habits();

CREATE OR REPLACE FUNCTION get_trending_captures_for_habits()
RETURNS TABLE (
    id uuid,
    capture_id uuid,
    habit_template_id uuid,
    user_id uuid,
    image_url text,
    caption text,
    is_public boolean,
    capture_created_at timestamptz,
    habit_name text,
    habit_category text,
    habit_category_id uuid,
    user_display_name text,
    user_avatar_url text,
    like_count bigint,
    total_captures bigint,
    trend_score numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        gen_random_uuid() as id,
        c.id as capture_id,
        c.habit_template_id,
        c.user_id,
        c.image_url,
        c.caption,
        c.is_public,
        c.created_at as capture_created_at,
        ht.name as habit_name,
        hc.name as habit_category,
        hc.id as habit_category_id,
        COALESCE(p.display_name, 'Anonymous') as user_display_name,
        p.avatar_url as user_avatar_url,
        COALESCE(l.like_count, 0) as like_count,
        capture_counts.total_captures,
        (COALESCE(l.like_count, 0) * 2 +
         EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 3600) as trend_score
    FROM captures c
    JOIN habit_templates ht ON c.habit_template_id = ht.id
    JOIN habit_categories hc ON ht.category_id = hc.id
    LEFT JOIN profiles p ON c.user_id = p.id
    LEFT JOIN (
        SELECT
            cl.capture_id,
            COUNT(*) as like_count
        FROM capture_likes cl
        WHERE cl.created_at >= NOW() - INTERVAL '7 days'
        GROUP BY cl.capture_id
    ) l ON c.id = l.capture_id
    JOIN (
        SELECT
            c_counts.habit_template_id,
            COUNT(*) as total_captures
        FROM captures c_counts
        WHERE c_counts.is_public = TRUE
        AND c_counts.created_at >= NOW() - INTERVAL '7 days'
        GROUP BY c_counts.habit_template_id
    ) capture_counts ON c.habit_template_id = capture_counts.habit_template_id
    WHERE c.is_public = TRUE
    AND c.created_at >= NOW() - INTERVAL '7 days'
    AND (
        -- For habits with less than 4 captures, only show 1 capture
        (capture_counts.total_captures < 4 AND
         c.id = (
             SELECT c2.id
             FROM captures c2
             WHERE c2.habit_template_id = c.habit_template_id
             AND c2.is_public = TRUE
             AND c2.created_at >= NOW() - INTERVAL '7 days'
             ORDER BY c2.created_at DESC
             LIMIT 1
         ))
        OR
        -- For habits with 4+ captures, show up to 4 captures
        (capture_counts.total_captures >= 4 AND
         c.id IN (
             SELECT c3.id
             FROM captures c3
             WHERE c3.habit_template_id = c.habit_template_id
             AND c3.is_public = TRUE
             AND c3.created_at >= NOW() - INTERVAL '7 days'
             ORDER BY c3.created_at DESC
             LIMIT 4
         ))
    )
    ORDER BY c.habit_template_id, c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Step 16: Create a function to get trending habits by category ID
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
        COALESCE(ht.description, 'Track your progress with this habit') as description,
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

-- Step 17: Create a function to get all active habit categories
CREATE OR REPLACE FUNCTION get_habit_categories()
RETURNS TABLE (
    id uuid,
    name text,
    description text,
    color text,
    icon text,
    sort_order integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        hc.id,
        hc.name,
        hc.description,
        hc.color,
        hc.icon,
        hc.sort_order
    FROM habit_categories hc
    WHERE hc.is_active = TRUE
    ORDER BY hc.sort_order, hc.name;
END;
$$ LANGUAGE plpgsql;

-- Step 18: Add RLS policies for habit_categories
ALTER TABLE habit_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "habit_categories_select_policy" ON habit_categories
    FOR SELECT USING (is_active = TRUE);

-- Add RLS policies for habit_descriptions
ALTER TABLE habit_descriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "habit_descriptions_select_policy" ON habit_descriptions
    FOR SELECT USING (true);

-- Step 19: Create a trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_habit_categories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER habit_categories_updated_at_trigger
    BEFORE UPDATE ON habit_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_habit_categories_updated_at();

-- Create trigger for habit_descriptions
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

-- Step 20: Add a "General" category if it doesn't exist (for fallback)
INSERT INTO habit_categories (name, description, color, icon, sort_order) 
VALUES ('General', 'General habits and activities', 'gray', 'circle', 99)
ON CONFLICT (name) DO NOTHING;

-- Step 21: Update any remaining habits without categories to use "General"
UPDATE habit_templates 
SET category_id = (SELECT id FROM habit_categories WHERE name = 'General')
WHERE category_id IS NULL;

UPDATE available_habits 
SET category_id = (SELECT id FROM habit_categories WHERE name = 'General')
WHERE category_id IS NULL;

-- Step 22: Create a view for available habits with categories
CREATE OR REPLACE VIEW available_habits_with_categories AS
SELECT
    ah.id,
    ah.name,
    hc.description as category_description,
    hc.name as category,
    hc.color as category_color,
    hc.id as category_id,
    ah.is_default,
    ah.created_at,
    ah.updated_at
FROM available_habits ah
JOIN habit_categories hc ON ah.category_id = hc.id
WHERE hc.is_active = TRUE
ORDER BY ah.is_default DESC, ah.name;

-- Verification queries
SELECT 'Migration completed successfully!' as status;
SELECT 'habit_categories count:' as info, COUNT(*) as count FROM habit_categories;
SELECT 'habit_templates with categories:' as info, COUNT(*) as count FROM habit_templates WHERE category_id IS NOT NULL;
SELECT 'available_habits with categories:' as info, COUNT(*) as count FROM available_habits WHERE category_id IS NOT NULL;
SELECT 'habit_descriptions count:' as info, COUNT(*) as count FROM habit_descriptions;
