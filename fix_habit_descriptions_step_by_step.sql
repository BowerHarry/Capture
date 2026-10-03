-- =====================================================
-- FIX HABIT DESCRIPTIONS STEP BY STEP
-- =====================================================

-- Step 1: Check current state of habit_descriptions table
SELECT 'Current habit_descriptions data:' as info;
SELECT 
    id,
    habit_id,
    habit_name,
    description,
    category
FROM habit_descriptions
ORDER BY habit_name;

-- Step 2: Check what habit_templates exist
SELECT 'Available habit_templates:' as info;
SELECT 
    id,
    name,
    category
FROM habit_templates 
ORDER BY name;

-- Step 3: Find matches between habit_descriptions and habit_templates
SELECT 'Matching habit names:' as info;
SELECT 
    hd.habit_name as description_name,
    ht.name as template_name,
    hd.habit_id as current_id,
    ht.id as template_id,
    CASE 
        WHEN LOWER(hd.habit_name) = LOWER(ht.name) THEN 'MATCH'
        ELSE 'NO MATCH'
    END as match_status
FROM habit_descriptions hd
LEFT JOIN habit_templates ht ON LOWER(hd.habit_name) = LOWER(ht.name)
ORDER BY match_status, hd.habit_name;

-- Step 4: Update habit_id values where we have matches
SELECT 'Updating habit_id values for matching names...' as info;
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

-- Step 5: Show updated state
SELECT 'Updated habit_descriptions data:' as info;
SELECT 
    id,
    habit_id,
    habit_name,
    description,
    category
FROM habit_descriptions
ORDER BY habit_name;

-- Step 6: Check which records are now valid
SELECT 'Validation check:' as info;
SELECT 
    hd.habit_name,
    hd.habit_id,
    CASE 
        WHEN ht.id IS NOT NULL THEN 'VALID - Exists in habit_templates'
        ELSE 'INVALID - Not found in habit_templates'
    END as status
FROM habit_descriptions hd
LEFT JOIN habit_templates ht ON hd.habit_id = ht.id
ORDER BY status, hd.habit_name;

-- Step 7: Rename column to habit_template_id
SELECT 'Renaming habit_id to habit_template_id...' as info;
ALTER TABLE habit_descriptions 
RENAME COLUMN habit_id TO habit_template_id;

-- Step 8: Add foreign key constraint (only if all records are valid)
SELECT 'Adding foreign key constraint...' as info;
ALTER TABLE habit_descriptions 
ADD CONSTRAINT fk_habit_descriptions_habit_template 
FOREIGN KEY (habit_template_id) REFERENCES habit_templates(id) ON DELETE CASCADE;

-- Step 9: Final verification
SELECT 'Final state:' as info;
SELECT 
    hd.habit_template_id,
    hd.habit_name,
    hd.description,
    ht.name as template_name
FROM habit_descriptions hd
JOIN habit_templates ht ON hd.habit_template_id = ht.id
ORDER BY hd.habit_name;

SELECT 'Migration completed successfully!' as status;
