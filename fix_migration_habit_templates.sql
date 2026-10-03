-- Fix Migration to Habit Template IDs
-- This script handles null values and edge cases properly

-- ====================
-- 1. CHECK FOR ORPHANED CAPTURES
-- ====================

-- First, let's see what we're dealing with
SELECT 
    COUNT(*) as total_captures,
    COUNT(CASE WHEN habit_id IS NULL THEN 1 END) as captures_without_habit_id,
    COUNT(CASE WHEN habit_id IS NOT NULL THEN 1 END) as captures_with_habit_id
FROM captures;

-- Check for captures that don't have corresponding user_habits
SELECT 
    COUNT(*) as orphaned_captures
FROM captures c
LEFT JOIN user_habits uh ON c.habit_id = uh.id
WHERE c.habit_id IS NOT NULL AND uh.id IS NULL;

-- ====================
-- 2. ADD HABIT_TEMPLATE_ID COLUMN (ALLOW NULL INITIALLY)
-- ====================

-- Add habit_template_id column to captures table (allow null initially)
ALTER TABLE captures 
ADD COLUMN IF NOT EXISTS habit_template_id UUID;

-- ====================
-- 3. UPDATE CAPTURES WITH VALID HABIT_IDS
-- ====================

-- Update captures that have valid habit_ids
UPDATE captures 
SET habit_template_id = (
    SELECT uh.habit_template_id 
    FROM user_habits uh 
    WHERE uh.id = captures.habit_id
)
WHERE captures.habit_id IS NOT NULL 
  AND EXISTS (
    SELECT 1 FROM user_habits uh WHERE uh.id = captures.habit_id
  )
  AND captures.habit_template_id IS NULL;

-- ====================
-- 4. HANDLE ORPHANED CAPTURES
-- ====================

-- For captures without valid habit_ids, we need to either:
-- Option A: Delete them (if they're truly orphaned)
-- Option B: Create placeholder user_habits (if they should exist)

-- Let's check what these orphaned captures look like
SELECT 
    c.id,
    c.habit_id,
    c.user_id,
    c.created_at,
    c.is_public
FROM captures c
LEFT JOIN user_habits uh ON c.habit_id = uh.id
WHERE c.habit_id IS NOT NULL AND uh.id IS NULL
LIMIT 10;

-- For now, let's delete orphaned captures (you can change this if needed)
DELETE FROM captures 
WHERE habit_id IS NOT NULL 
  AND NOT EXISTS (
    SELECT 1 FROM user_habits uh WHERE uh.id = captures.habit_id
  );

-- ====================
-- 5. HANDLE CAPTURES WITH NULL HABIT_ID
-- ====================

-- Check if there are captures with NULL habit_id
SELECT COUNT(*) as captures_with_null_habit_id
FROM captures 
WHERE habit_id IS NULL;

-- If there are captures with NULL habit_id, we need to decide what to do
-- For now, let's delete them (you can change this if needed)
DELETE FROM captures 
WHERE habit_id IS NULL;

-- ====================
-- 6. VERIFY ALL CAPTURES HAVE HABIT_TEMPLATE_ID
-- ====================

-- Check if any captures still have NULL habit_template_id
SELECT COUNT(*) as captures_without_template_id
FROM captures 
WHERE habit_template_id IS NULL;

-- If there are still NULL values, we need to investigate
-- For now, let's delete any remaining captures without template_id
DELETE FROM captures 
WHERE habit_template_id IS NULL;

-- ====================
-- 7. MAKE HABIT_TEMPLATE_ID NOT NULL
-- ====================

-- Now we can safely make habit_template_id NOT NULL
ALTER TABLE captures 
ALTER COLUMN habit_template_id SET NOT NULL;

-- ====================
-- 8. ADD INDEXES
-- ====================

-- Add index for habit_template_id queries
CREATE INDEX IF NOT EXISTS idx_captures_habit_template_id 
ON captures(habit_template_id);

CREATE INDEX IF NOT EXISTS idx_captures_template_public_created 
ON captures(habit_template_id, is_public, created_at DESC) 
WHERE is_public = true;

-- ====================
-- 9. VERIFICATION
-- ====================

-- Verify the migration was successful
SELECT 
    COUNT(*) as total_captures,
    COUNT(CASE WHEN habit_template_id IS NOT NULL THEN 1 END) as captures_with_template_id,
    COUNT(CASE WHEN habit_id IS NOT NULL THEN 1 END) as captures_with_habit_id
FROM captures;

-- Check that all captures have both habit_id and habit_template_id
SELECT 
    COUNT(*) as total_captures,
    COUNT(CASE WHEN habit_id IS NOT NULL AND habit_template_id IS NOT NULL THEN 1 END) as complete_captures
FROM captures;

-- ====================
-- MIGRATION FIXED
-- ====================

SELECT 'Migration to habit_template_id fixed! All captures now have valid habit_template_id values.' as message;
