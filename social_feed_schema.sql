-- Social Feed Database Schema
-- This file contains all the database changes needed for the social feed feature

-- 1. Create new tables for reactions and comments

-- Capture reactions table
CREATE TABLE IF NOT EXISTS capture_reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL DEFAULT 'fire',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(capture_id, user_id)
);

-- Capture comments table
CREATE TABLE IF NOT EXISTS capture_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_capture_reactions_capture_id ON capture_reactions(capture_id);
CREATE INDEX IF NOT EXISTS idx_capture_reactions_user_id ON capture_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_capture_comments_capture_id ON capture_comments(capture_id);
CREATE INDEX IF NOT EXISTS idx_capture_comments_user_id ON capture_comments(user_id);

-- 3. Create function to toggle capture reactions
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
    
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'User not authenticated';
    END IF;
    
    -- Check if reaction already exists
    SELECT id INTO existing_reaction_id
    FROM capture_reactions
    WHERE capture_id = capture_id_param AND user_id = current_user_id;
    
    -- Toggle reaction
    IF existing_reaction_id IS NOT NULL THEN
        -- Remove existing reaction
        DELETE FROM capture_reactions WHERE id = existing_reaction_id;
        is_liked := FALSE;
    ELSE
        -- Add new reaction
        INSERT INTO capture_reactions (capture_id, user_id, reaction_type)
        VALUES (capture_id_param, current_user_id, 'fire');
        is_liked := TRUE;
    END IF;
    
    -- Get updated reaction count
    SELECT COUNT(*) INTO reaction_count
    FROM capture_reactions
    WHERE capture_id = capture_id_param;
    
    -- Return result
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
    
    RETURN QUERY
    WITH user_habit_groups AS (
        -- Group captures by user and habit template
        SELECT 
            uh.user_id,
            ht.id as habit_template_id,
            ht.name as habit_name,
            ht.category as habit_category,
            NULL as habit_category_color,
            p.display_name as user_display_name,
            p.avatar_url as user_avatar_url,
            p.username as user_username,
            uh.current_streak,
            -- Get the most recent capture for this user+habit combination
            FIRST_VALUE(hc2.id) OVER (
                PARTITION BY uh.user_id, ht.id 
                ORDER BY hc2.created_at DESC
            ) as last_capture_id,
            FIRST_VALUE(hc2.image_url) OVER (
                PARTITION BY uh.user_id, ht.id 
                ORDER BY hc2.created_at DESC
            ) as last_capture_image_url,
            FIRST_VALUE(hc2.created_at) OVER (
                PARTITION BY uh.user_id, ht.id 
                ORDER BY hc2.created_at DESC
            ) as last_capture_created_at,
            COUNT(hc2.id) as total_captures
        FROM user_habits uh
        JOIN habit_templates ht ON uh.habit_template_id = ht.id
        JOIN profiles p ON uh.user_id = p.id
        LEFT JOIN captures hc2 ON hc2.user_habit_id = uh.id AND hc2.is_public = true
        WHERE uh.is_active = true
        GROUP BY uh.user_id, ht.id, ht.name, ht.category, p.display_name, p.avatar_url, p.username, uh.current_streak
        HAVING COUNT(hc2.id) > 0
    ),
    capture_reactions AS (
        -- Get reaction counts and check if current user has reacted
        SELECT 
            hc.id as capture_id,
            COUNT(cr.id) as reaction_count,
            BOOL_OR(cr.user_id = current_user_id) as is_liked_by_current_user
        FROM captures hc
        LEFT JOIN capture_reactions cr ON hc.id = cr.capture_id
        GROUP BY hc.id
    ),
    capture_comments AS (
        -- Get comment counts
        SELECT 
            hc.id as capture_id,
            COUNT(cc.id) as comment_count
        FROM captures hc
        LEFT JOIN capture_comments cc ON hc.id = cc.capture_id
        GROUP BY hc.id
    ),
    recent_captures_data AS (
        -- Get recent captures with reactions and comments
        SELECT 
            uh.user_id,
            ht.id as habit_template_id,
            json_agg(
                json_build_object(
                    'id', hc.id,
                    'image_url', hc.image_url,
                    'caption', hc.caption,
                    'created_at', hc.created_at,
                    'reaction_count', COALESCE(cr.reaction_count, 0),
                    'comment_count', COALESCE(cc.comment_count, 0),
                    'is_liked_by_current_user', COALESCE(cr.is_liked_by_current_user, false),
                    'reaction_users', (
                        SELECT json_agg(
                            json_build_object(
                                'id', p2.id,
                                'display_name', p2.display_name,
                                'avatar_url', p2.avatar_url,
                                'username', p2.username
                            )
                        )
                        FROM capture_reactions cr2
                        JOIN profiles p2 ON cr2.user_id = p2.id
                        WHERE cr2.capture_id = hc.id
                        LIMIT 4
                    )
                ) ORDER BY hc.created_at DESC
            ) as recent_captures
        FROM user_habits uh
        JOIN habit_templates ht ON uh.habit_template_id = ht.id
        JOIN captures hc ON hc.user_habit_id = uh.id AND hc.is_public = true
        LEFT JOIN capture_reactions cr ON hc.id = cr.capture_id
        LEFT JOIN capture_comments cc ON hc.id = cc.capture_id
        WHERE uh.is_active = true
        GROUP BY uh.user_id, ht.id
    )
    SELECT 
        ug.user_id || '-' || ug.habit_template_id as id,
        ug.user_id,
        ug.habit_template_id,
        ug.habit_name,
        ug.habit_category,
        ug.habit_category_color,
        ug.user_display_name,
        ug.user_avatar_url,
        ug.user_username,
        ug.current_streak,
        ug.last_capture_id,
        ug.last_capture_image_url,
        ug.last_capture_created_at,
        ug.total_captures,
        COALESCE(cr.reaction_count, 0) as reaction_count,
        COALESCE(cc.comment_count, 0) as comment_count,
        COALESCE(cr.is_liked_by_current_user, false) as is_liked_by_current_user,
        COALESCE(rcd.recent_captures, '[]'::json) as recent_captures
    FROM user_habit_groups ug
    LEFT JOIN capture_reactions cr ON ug.last_capture_id = cr.capture_id
    LEFT JOIN capture_comments cc ON ug.last_capture_id = cc.capture_id
    LEFT JOIN recent_captures_data rcd ON ug.user_id = rcd.user_id AND ug.habit_template_id = rcd.habit_template_id
    ORDER BY ug.last_capture_created_at DESC
    LIMIT limit_param
    OFFSET offset_param;
END;
$$;

-- 5. Create RLS policies for the new tables

-- Enable RLS on capture_reactions
ALTER TABLE capture_reactions ENABLE ROW LEVEL SECURITY;

-- Policy for capture_reactions - users can see all reactions, but only manage their own
CREATE POLICY "Users can view all capture reactions" ON capture_reactions
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own capture reactions" ON capture_reactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own capture reactions" ON capture_reactions
    FOR DELETE USING (auth.uid() = user_id);

-- Enable RLS on capture_comments
ALTER TABLE capture_comments ENABLE ROW LEVEL SECURITY;

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

CREATE TRIGGER update_capture_comments_updated_at 
    BEFORE UPDATE ON capture_comments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7. Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON capture_reactions TO authenticated;
GRANT ALL ON capture_comments TO authenticated;
GRANT EXECUTE ON FUNCTION toggle_capture_reaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_social_feed_groups(INTEGER, INTEGER) TO authenticated;
