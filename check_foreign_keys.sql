-- Check foreign key constraints on captures table
SELECT 
    'Foreign key constraints on captures table:' as info,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name = 'captures';

-- Check what's currently in trending_habits_view
SELECT 
    'Current trending habits:' as info,
    id,
    name,
    category,
    participants,
    avg_streak,
    total_captures,
    trend_score
FROM trending_habits_view
ORDER BY trend_score DESC;

-- Check captures for the 10,000 Steps habit template
SELECT 
    'Captures for 10,000 Steps habit template:' as info,
    c.id,
    c.habit_id,
    c.habit_template_id,
    c.user_id,
    c.is_public,
    c.created_at
FROM captures c
WHERE c.habit_template_id = 'CE31EF1D-1219-4E1B-AD75-CCC9435DCEB3'
ORDER BY c.created_at DESC;

-- Check if the habit_id exists in the referenced table
SELECT 
    'Checking if habit_id exists in user_habits:' as info,
    id,
    habit_template_id,
    user_id,
    current_streak,
    is_active
FROM user_habits 
WHERE id = '7E3FC55C-995F-49B1-9F13-98D6693CC145';

-- Check all user_habits for this user
SELECT 
    'All user_habits for this user:' as info,
    id,
    habit_template_id,
    user_id,
    current_streak,
    is_active
FROM user_habits 
WHERE user_id = 'bedf1fa0-75ce-4c6f-82fa-29b51f0cb500'
ORDER BY created_at DESC;

-- Check captures table structure
SELECT 
    'Captures table columns:' as info,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'captures'
ORDER BY ordinal_position;
