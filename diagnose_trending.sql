-- Diagnostic script to check trending system status
-- Run this in your Supabase SQL Editor

-- ====================
-- 1. CHECK CURRENT FUNCTION DEFINITION
-- ====================

SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
    AND p.proname = 'get_trending_captures_for_habits';

-- ====================
-- 2. CHECK IF VIEW EXISTS
-- ====================

SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE viewname = 'trending_habits_view';

-- ====================
-- 3. CHECK TABLE STRUCTURES
-- ====================

-- Check captures table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'captures' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- Check capture_like_counts table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'capture_like_counts' 
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- ====================
-- 4. TEST THE FUNCTION MANUALLY
-- ====================

-- Try to call the function and see the exact error
DO $$
BEGIN
    PERFORM * FROM get_trending_captures_for_habits() LIMIT 1;
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'Error: %', SQLERRM;
END $$;

-- ====================
-- 5. CHECK FOR ANY EXISTING FUNCTIONS WITH SIMILAR NAMES
-- ====================

SELECT 
    p.proname as function_name,
    n.nspname as schema_name
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.proname LIKE '%trending%' OR p.proname LIKE '%capture%'
ORDER BY p.proname;
