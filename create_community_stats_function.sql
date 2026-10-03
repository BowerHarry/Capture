-- =====================================================
-- CREATE COMMUNITY STATS FUNCTION
-- =====================================================

-- First, add the isActive column to profiles table if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'profiles' AND column_name = 'is_active') THEN
        ALTER TABLE profiles ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
        UPDATE profiles SET is_active = TRUE WHERE is_active IS NULL;
    END IF;
END $$;

-- Create function to get community stats
DROP FUNCTION IF EXISTS get_community_stats();

CREATE OR REPLACE FUNCTION get_community_stats()
RETURNS TABLE (
    active_users bigint,
    total_habits bigint,
    total_captures bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        -- Active users: count of profiles with is_active = true
        (SELECT COUNT(*) FROM profiles WHERE is_active = true) as active_users,
        
        -- Total habits: count of active user_habits
        (SELECT COUNT(*) FROM user_habits WHERE is_active = true) as total_habits,
        
        -- Total captures: count of all captures
        (SELECT COUNT(*) FROM captures) as total_captures;
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT 'Community stats function created successfully!' as status;

-- Test the function
SELECT 'Testing community stats function:' as test_step;
SELECT * FROM get_community_stats();

-- Also test individual queries to see what data we get
SELECT 'Individual stat queries:' as debug_step;

SELECT 'Active users count:' as stat_name, COUNT(*) as count FROM profiles WHERE is_active = true
UNION ALL
SELECT 'Active habits count:' as stat_name, COUNT(*) as count FROM user_habits WHERE is_active = true
UNION ALL
SELECT 'Total captures count:' as stat_name, COUNT(*) as count FROM captures;
