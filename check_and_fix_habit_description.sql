-- =====================================================
-- CHECK AND FIX HABIT DESCRIPTION TABLE
-- =====================================================

-- Step 1: Check what tables exist with "habit" and "description" in the name
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND (table_name LIKE '%habit%' OR table_name LIKE '%description%')
ORDER BY table_name;

-- Step 2: Check the structure of the habit description table (whatever it's called)
-- Let's look for tables that might contain the data you showed
SELECT 
    table_name,
    column_name,
    data_type
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name IN (
    SELECT table_name 
    FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND (table_name LIKE '%habit%' OR table_name LIKE '%description%')
)
ORDER BY table_name, ordinal_position;

-- Step 3: Check if there's a table with habit_id column
SELECT 
    table_name,
    column_name
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND column_name = 'habit_id'
ORDER BY table_name;

-- Step 4: If we find the table, let's see its current structure
-- (This will be executed after we identify the correct table name)
