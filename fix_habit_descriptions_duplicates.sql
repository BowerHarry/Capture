-- =====================================================
-- FIX HABIT DESCRIPTIONS DUPLICATES
-- =====================================================

-- Step 1: Check for duplicate habit_id values
SELECT 'Checking for duplicate habit_id values:' as info;
SELECT 
    habit_id,
    COUNT(*) as count,
    STRING_AGG(habit_name, ', ') as habit_names,
    STRING_AGG(description, ' | ') as descriptions
FROM habit_descriptions
GROUP BY habit_id
HAVING COUNT(*) > 1
ORDER BY count DESC;

-- Step 2: Show all records with duplicates
SELECT 'All records with duplicate habit_id values:' as info;
SELECT 
    id,
    habit_id,
    habit_name,
    description,
    category,
    created_at,
    updated_at
FROM habit_descriptions
WHERE habit_id IN (
    SELECT habit_id 
    FROM habit_descriptions 
    GROUP BY habit_id 
    HAVING COUNT(*) > 1
)
ORDER BY habit_id, created_at;

-- Step 3: Keep only the most recent record for each habit_id
-- (or the one with the best description)
SELECT 'Removing duplicate records, keeping the most recent...' as info;

-- First, let's see which records we'll keep
WITH ranked_records AS (
    SELECT 
        id,
        habit_id,
        habit_name,
        description,
        category,
        created_at,
        updated_at,
        ROW_NUMBER() OVER (
            PARTITION BY habit_id 
            ORDER BY updated_at DESC, created_at DESC
        ) as rn
    FROM habit_descriptions
)
SELECT 
    'Will keep:' as action,
    id,
    habit_id,
    habit_name,
    description,
    updated_at
FROM ranked_records
WHERE rn = 1
ORDER BY habit_id;

-- Step 4: Delete duplicate records, keeping only the most recent
DELETE FROM habit_descriptions
WHERE id NOT IN (
    SELECT id FROM (
        SELECT 
            id,
            ROW_NUMBER() OVER (
                PARTITION BY habit_id 
                ORDER BY updated_at DESC, created_at DESC
            ) as rn
        FROM habit_descriptions
    ) ranked
    WHERE rn = 1
);

-- Step 5: Verify duplicates are gone
SELECT 'Verifying duplicates are removed:' as info;
SELECT 
    habit_id,
    COUNT(*) as count
FROM habit_descriptions
GROUP BY habit_id
HAVING COUNT(*) > 1;

-- Step 6: Show final state
SELECT 'Final habit_descriptions data:' as info;
SELECT 
    id,
    habit_id,
    habit_name,
    description,
    category,
    created_at,
    updated_at
FROM habit_descriptions
ORDER BY habit_name;

-- Step 7: Now we can proceed with the original fix
SELECT 'Now proceeding with habit_id to habit_template_id rename...' as info;

-- Update habit_id values where we have matches
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

-- Rename column to habit_template_id
ALTER TABLE habit_descriptions 
RENAME COLUMN habit_id TO habit_template_id;

-- Add foreign key constraint
ALTER TABLE habit_descriptions 
ADD CONSTRAINT fk_habit_descriptions_habit_template 
FOREIGN KEY (habit_template_id) REFERENCES habit_templates(id) ON DELETE CASCADE;

-- Step 8: Final verification
SELECT 'Final verification:' as info;
SELECT 
    hd.habit_template_id,
    hd.habit_name,
    hd.description,
    ht.name as template_name
FROM habit_descriptions hd
JOIN habit_templates ht ON hd.habit_template_id = ht.id
ORDER BY hd.habit_name;

SELECT 'Migration completed successfully!' as status;
