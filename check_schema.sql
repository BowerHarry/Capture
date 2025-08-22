-- Diagnostic Script: Check Database Schema
-- Run this to see what columns actually exist in your tables

-- Check user_habits table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'user_habits'
ORDER BY ordinal_position;

-- Check habit_templates table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'habit_templates'
ORDER BY ordinal_position;

-- Check captures table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'captures'
ORDER BY ordinal_position;

-- Check if capture_likes_count table exists
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'capture_likes_count'
ORDER BY ordinal_position;

-- Check foreign key relationships
SELECT
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM 
    information_schema.table_constraints AS tc 
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND tc.table_name IN ('user_habits', 'captures', 'capture_likes_count')
ORDER BY tc.table_name, kcu.column_name;
