-- Fix orphaned captures by setting user_habit_id based on habit_template_id
-- This will link captures to the correct user habit for streak calculation

-- First, let's see what orphaned captures we have
SELECT 'Orphaned captures (user_habit_id is null):' as info;
SELECT 
    id,
    habit_template_id,
    user_habit_id,
    user_id,
    created_at
FROM captures 
WHERE user_habit_id IS NULL
ORDER BY created_at DESC;

-- Update orphaned captures to link them to the correct user habit
-- We'll find the user habit that matches the user_id and habit_template_id
UPDATE captures 
SET user_habit_id = (
    SELECT uh.id 
    FROM user_habits uh 
    WHERE uh.user_id = captures.user_id 
    AND uh.habit_template_id = captures.habit_template_id
    LIMIT 1
)
WHERE user_habit_id IS NULL 
AND habit_template_id IS NOT NULL;

-- Show the results after the fix
SELECT 'Captures after fixing orphaned ones:' as info;
SELECT 
    id,
    habit_template_id,
    user_habit_id,
    user_id,
    created_at
FROM captures 
WHERE habit_template_id = 'ce31ef1d-1219-4e1b-ad75-ccc9435dceb3'  -- 10,000 Steps
ORDER BY created_at DESC;
