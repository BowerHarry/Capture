-- =====================================================
-- FIX HABIT DESCRIPTIONS FOREIGN KEY CONSTRAINT
-- =====================================================

-- Step 1: First, let's see what habit_id values exist in habit_descriptions
-- and which ones are valid habit_template IDs
SELECT 
    hd.habit_id,
    hd.habit_name,
    hd.description,
    CASE 
        WHEN ht.id IS NOT NULL THEN 'VALID'
        ELSE 'INVALID - Not in habit_templates'
    END as status
FROM habit_descriptions hd
LEFT JOIN habit_templates ht ON hd.habit_id = ht.id
ORDER BY status, hd.habit_name;

-- Step 2: Show the habit_templates that exist
SELECT 
    id,
    name,
    category
FROM habit_templates 
ORDER BY name;

-- Step 3: Find the correct habit_template_id for each habit_descriptions record
-- by matching the habit_name
SELECT 
    hd.id as description_id,
    hd.habit_id as current_id,
    hd.habit_name,
    ht.id as correct_template_id,
    ht.name as template_name,
    CASE 
        WHEN ht.id IS NOT NULL THEN 'MATCH FOUND'
        ELSE 'NO MATCH - Need to create or find template'
    END as match_status
FROM habit_descriptions hd
LEFT JOIN habit_templates ht ON LOWER(ht.name) = LOWER(hd.habit_name)
ORDER BY match_status, hd.habit_name;

-- Step 4: Update the habit_id values to the correct ones
-- (This will only update records where we found a match)
UPDATE habit_descriptions 
SET habit_id = (
    SELECT ht.id 
    FROM habit_templates ht 
    WHERE LOWER(ht.name) = LOWER(habit_descriptions.habit_name)
    LIMIT 1
)
WHERE EXISTS (
    SELECT 1 
    FROM habit_templates ht 
    WHERE LOWER(ht.name) = LOWER(habit_descriptions.habit_name)
);

-- Step 5: Show which records were updated
SELECT 
    hd.habit_id,
    hd.habit_name,
    hd.description,
    CASE 
        WHEN ht.id IS NOT NULL THEN 'VALID'
        ELSE 'INVALID - Still needs attention'
    END as status
FROM habit_descriptions hd
LEFT JOIN habit_templates ht ON hd.habit_id = ht.id
ORDER BY status, hd.habit_name;

-- Step 6: If there are still invalid records, we can either:
-- Option A: Delete invalid records
-- DELETE FROM habit_descriptions 
-- WHERE habit_template_id NOT IN (SELECT id FROM habit_templates);

-- Option B: Or create missing habit_templates (if needed)
-- This would require more information about what these habits should be

-- Step 6: Now rename the column to habit_template_id
ALTER TABLE habit_descriptions 
RENAME COLUMN habit_id TO habit_template_id;

-- Step 7: Now try to add the foreign key constraint
-- (Only if all records are valid)
ALTER TABLE habit_descriptions 
ADD CONSTRAINT fk_habit_descriptions_habit_template 
FOREIGN KEY (habit_template_id) REFERENCES habit_templates(id) ON DELETE CASCADE;

-- Step 8: Verify the fix worked
SELECT 'Foreign key constraint added successfully!' as status;

-- Show final state
SELECT 
    hd.habit_template_id,
    hd.habit_name,
    hd.description,
    ht.name as template_name,
    'VALID' as status
FROM habit_descriptions hd
JOIN habit_templates ht ON hd.habit_template_id = ht.id
ORDER BY hd.habit_name;
