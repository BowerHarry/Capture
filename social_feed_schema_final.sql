-- Social Feed Schema - Final Corrected Version
-- This schema adds social features to the existing Capture app database

-- 1. Create capture_reactions table
CREATE TABLE IF NOT EXISTS capture_reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL DEFAULT 'fire',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(capture_id, user_id)
);

-- 2. Create capture_comments table
CREATE TABLE IF NOT EXISTS capture_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create function to toggle capture reactions
DROP FUNCTION IF EXISTS toggle_capture_reaction(UUID);
CREATE OR REPLACE FUNCTION toggle_capture_reaction(capture_id_param UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
    existing_reaction_id UUID;
    is_liked BOOLEAN;
    reaction_count INTEGER;
BEGIN
    -- Get current user ID
    current_user_id := auth.uid();
    
    -- Check if user already reacted
    SELECT id INTO existing_reaction_id
    FROM capture_reactions
    WHERE capture_id = capture_id_param AND user_id = current_user_id;
    
    IF existing_reaction_id IS NOT NULL THEN
        -- Remove existing reaction
        DELETE FROM capture_reactions WHERE id = existing_reaction_id;
        is_liked := false;
    ELSE
        -- Add new reaction
        INSERT INTO capture_reactions (capture_id, user_id, reaction_type)
        VALUES (capture_id_param, current_user_id, 'fire');
        is_liked := true;
    END IF;
    
    -- Get updated reaction count
    SELECT COUNT(*) INTO reaction_count
    FROM capture_reactions
    WHERE capture_id = capture_id_param;
    
    -- Return result as JSON
    RETURN json_build_object(
        'is_liked', is_liked,
        'reaction_count', reaction_count
    );
END;
$$;

-- 4. Create function to get social feed groups
CREATE OR REPLACE FUNCTION get_social_feed_groups(limit_param INTEGER DEFAULT 20, offset_param INTEGER DEFAULT 0)
RETURNS TABLE (
    id TEXT,
    user_id UUID,
    habit_template_id UUID,
    habit_name TEXT,
    habit_category TEXT,
    habit_category_color TEXT,
    user_display_name TEXT,
    user_avatar_url TEXT,
    user_username TEXT,
    current_streak INTEGER,
    last_capture_id UUID,
    last_capture_image_url TEXT,
    last_capture_created_at TIMESTAMP WITH TIME ZONE,
    total_captures INTEGER,
    reaction_count INTEGER,
    comment_count INTEGER,
    is_liked_by_current_user BOOLEAN,
    recent_captures JSON
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get current user ID
    current_user_id := auth.uid();
    
    -- Get real data with recent_captures and filter out current user
    RETURN QUERY
    SELECT 
        uh.user_id || '-' || ht.id as id,
        uh.user_id,
        ht.id as habit_template_id,
        ht.name as habit_name,
        ht.category as habit_category,
        NULL as habit_category_color,
        p.display_name as user_display_name,
        p.avatar_url as user_avatar_url,
        p.display_name as user_username,
        uh.current_streak,
        hc.id as last_capture_id,
        hc.image_url as last_capture_image_url,
        hc.created_at as last_capture_created_at,
        (SELECT COUNT(*)::INTEGER FROM captures c WHERE c.user_habit_id = uh.id AND c.is_public = true) as total_captures,
        0 as reaction_count,
        0 as comment_count,
        false as is_liked_by_current_user,
        (
            SELECT COALESCE(
                json_agg(
                    json_build_object(
                        'id', c2.id,
                        'image_url', c2.image_url,
                        'caption', c2.caption,
                        'created_at', c2.created_at,
                        'reaction_count', 0,
                        'comment_count', 0,
                        'is_liked_by_current_user', false,
                        'reaction_users', '[]'::json
                    )
                ),
                '[]'::json
            )
            FROM (
                SELECT c2.id, c2.image_url, c2.caption, c2.created_at
                FROM captures c2 
                WHERE c2.user_habit_id = uh.id 
                AND c2.is_public = true
                ORDER BY c2.created_at DESC
                LIMIT 5
            ) c2
        ) as recent_captures
    FROM user_habits uh
    JOIN habit_templates ht ON uh.habit_template_id = ht.id
    JOIN profiles p ON uh.user_id = p.id
    JOIN captures hc ON hc.user_habit_id = uh.id AND hc.is_public = true
    WHERE uh.is_active = true
    AND uh.user_id != current_user_id  -- Filter out current user's posts
    AND hc.created_at = (
        SELECT MAX(c2.created_at) 
        FROM captures c2 
        WHERE c2.user_habit_id = uh.id AND c2.is_public = true
    )
    ORDER BY hc.created_at DESC
    LIMIT limit_param
    OFFSET offset_param;
END;
$$;

-- 5. Create RLS policies for the new tables

-- Enable RLS on capture_reactions
ALTER TABLE capture_reactions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view all capture reactions" ON capture_reactions;
DROP POLICY IF EXISTS "Users can insert their own capture reactions" ON capture_reactions;
DROP POLICY IF EXISTS "Users can delete their own capture reactions" ON capture_reactions;

-- Policy for capture_reactions - users can see all reactions, but only manage their own
CREATE POLICY "Users can view all capture reactions" ON capture_reactions
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own capture reactions" ON capture_reactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own capture reactions" ON capture_reactions
    FOR DELETE USING (auth.uid() = user_id);

-- Enable RLS on capture_comments
ALTER TABLE capture_comments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view all capture comments" ON capture_comments;
DROP POLICY IF EXISTS "Users can insert their own capture comments" ON capture_comments;
DROP POLICY IF EXISTS "Users can update their own capture comments" ON capture_comments;
DROP POLICY IF EXISTS "Users can delete their own capture comments" ON capture_comments;

-- Policy for capture_comments - users can see all comments, but only manage their own
CREATE POLICY "Users can view all capture comments" ON capture_comments
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own capture comments" ON capture_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own capture comments" ON capture_comments
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own capture comments" ON capture_comments
    FOR DELETE USING (auth.uid() = user_id);

-- 6. Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_capture_comments_updated_at ON capture_comments;

CREATE TRIGGER update_capture_comments_updated_at 
    BEFORE UPDATE ON capture_comments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON capture_reactions TO authenticated;
GRANT ALL ON capture_comments TO authenticated;
GRANT EXECUTE ON FUNCTION toggle_capture_reaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_social_feed_groups(INTEGER, INTEGER) TO authenticated;

-- 8. Create debug function to compare structures
CREATE OR REPLACE FUNCTION debug_social_feed_structure()
RETURNS TABLE (
    function_name TEXT,
    column_name TEXT,
    data_type TEXT,
    is_nullable TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Get expected structure from test function
    RETURN QUERY
    SELECT 
        'test_social_feed_structure'::TEXT as function_name,
        c.column_name::TEXT,
        c.data_type::TEXT,
        c.is_nullable::TEXT
    FROM information_schema.columns c
    WHERE c.table_name = 'test_social_feed_structure'
    AND c.table_schema = 'public'
    ORDER BY c.ordinal_position;
    
    -- Get actual structure from real function
    RETURN QUERY
    SELECT 
        'get_social_feed_groups'::TEXT as function_name,
        c.column_name::TEXT,
        c.data_type::TEXT,
        c.is_nullable::TEXT
    FROM information_schema.columns c
    WHERE c.table_name = 'get_social_feed_groups'
    AND c.table_schema = 'public'
    ORDER BY c.ordinal_position;
END;
$$;

-- 9. Create a simple test function for reactions
CREATE OR REPLACE FUNCTION test_reaction_function()
RETURNS JSON
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN json_build_object(
        'test', true,
        'message', 'Function is working'
    );
END;
$$;

-- 10. Create a function to get reaction data for a capture
CREATE OR REPLACE FUNCTION get_capture_reactions(capture_id_param UUID)
RETURNS TABLE (
    user_id UUID,
    user_avatar_url TEXT,
    user_display_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cr.user_id,
        p.avatar_url,
        p.display_name
    FROM capture_reactions cr
    JOIN profiles p ON cr.user_id = p.id
    WHERE cr.capture_id = capture_id_param
    ORDER BY cr.created_at DESC
    LIMIT 4;
END;
$$;
