-- Diagnose trending view decoding issues
-- Check the structure of trending_habits_view
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'trending_habits_view'
ORDER BY ordinal_position;

-- Check what data is actually in the trending_habits_view
SELECT * FROM trending_habits_view LIMIT 5;

-- Check if there are any null values or data type issues
SELECT 
    id,
    name,
    total_captures,
    participants,
    recent_captures,
    recent_likes,
    trend_score,
    created_at
FROM trending_habits_view 
WHERE id IS NULL 
   OR name IS NULL 
   OR total_captures IS NULL 
   OR participants IS NULL
LIMIT 10;

-- Check the actual data types being returned
SELECT 
    pg_typeof(id) as id_type,
    pg_typeof(name) as name_type,
    pg_typeof(total_captures) as total_captures_type,
    pg_typeof(participants) as participants_type,
    pg_typeof(recent_captures) as recent_captures_type,
    pg_typeof(recent_likes) as recent_likes_type,
    pg_typeof(trend_score) as trend_score_type,
    pg_typeof(created_at) as created_at_type
FROM trending_habits_view 
LIMIT 1;
