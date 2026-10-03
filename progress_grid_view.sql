-- Optimized view for progress grid data
-- This view combines user_habits, habit_templates, and captures data to reduce query overhead

CREATE OR REPLACE VIEW progress_grid_data AS
SELECT 
    uh.id as user_habit_id,
    uh.user_id,
    uh.habit_template_id,
    uh.current_streak,
    uh.is_active,
    uh.created_at as user_habit_created_at,
    uh.updated_at as user_habit_updated_at,
    ht.name as habit_name,
    ht.description as habit_description,
    ht.category as habit_category,
    ht.target_frequency,
    ht.target_count,
    ht.is_active as template_is_active,
    ht.created_at as template_created_at,
    ht.updated_at as template_updated_at,
    c.id as capture_id,
    c.image_url,
    c.caption,
    c.is_public,
    c.created_at as capture_created_at,
    c.updated_at as capture_updated_at
FROM user_habits uh
JOIN habit_templates ht ON uh.habit_template_id = ht.id
LEFT JOIN captures c ON uh.id = c.user_habit_id
WHERE uh.is_active = true
  AND ht.is_active = true;

-- Create indexes to optimize the join performance
CREATE INDEX IF NOT EXISTS idx_captures_user_habit_id ON captures(user_habit_id);
CREATE INDEX IF NOT EXISTS idx_user_habits_active ON user_habits(is_active, user_id);
CREATE INDEX IF NOT EXISTS idx_habit_templates_active ON habit_templates(is_active);

-- Function to get progress grid data for a specific user and date range
CREATE OR REPLACE FUNCTION get_user_progress_grid_data(
    p_user_id UUID,
    p_since_date TIMESTAMPTZ
)
RETURNS TABLE (
    user_habit_id UUID,
    user_id UUID,
    habit_template_id UUID,
    current_streak INTEGER,
    is_active BOOLEAN,
    user_habit_created_at TIMESTAMPTZ,
    user_habit_updated_at TIMESTAMPTZ,
    habit_name TEXT,
    habit_description TEXT,
    habit_category TEXT,
    target_frequency TEXT,
    target_count INTEGER,
    template_is_active BOOLEAN,
    template_created_at TIMESTAMPTZ,
    template_updated_at TIMESTAMPTZ,
    capture_id UUID,
    image_url TEXT,
    caption TEXT,
    is_public BOOLEAN,
    capture_created_at TIMESTAMPTZ,
    capture_updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uh.id as user_habit_id,
        uh.user_id,
        uh.habit_template_id,
        uh.current_streak,
        uh.is_active,
        uh.created_at as user_habit_created_at,
        uh.updated_at as user_habit_updated_at,
        ht.name as habit_name,
        ht.description as habit_description,
        ht.category as habit_category,
        ht.target_frequency,
        ht.target_count,
        ht.is_active as template_is_active,
        ht.created_at as template_created_at,
        ht.updated_at as template_updated_at,
        c.id as capture_id,
        c.image_url,
        c.caption,
        c.is_public,
        c.created_at as capture_created_at,
        c.updated_at as capture_updated_at
    FROM user_habits uh
    JOIN habit_templates ht ON uh.habit_template_id = ht.id
    LEFT JOIN captures c ON uh.id = c.user_habit_id 
        AND c.created_at >= p_since_date
    WHERE uh.user_id = p_user_id 
        AND uh.is_active = true
        AND ht.is_active = true
    ORDER BY uh.created_at ASC, c.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant necessary permissions
GRANT SELECT ON progress_grid_data TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_progress_grid_data TO authenticated;
