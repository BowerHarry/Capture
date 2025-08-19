-- RLS Policy Modifications for Public Data Access
-- Run these commands in your Supabase SQL Editor

-- 1. Drop existing restrictive policies (if they exist)
DROP POLICY IF EXISTS "Users can view own habits" ON habits;
DROP POLICY IF EXISTS "Users can view own captures" ON captures;

-- 2. Create new policies that allow viewing all public data
-- For Habits table
CREATE POLICY "Allow public read access to habits" ON habits
    FOR SELECT
    USING (true); -- Allow reading all habits

-- For Captures table  
CREATE POLICY "Allow public read access to captures" ON captures
    FOR SELECT
    USING (true); -- Allow reading all captures

-- 3. Keep existing policies for INSERT, UPDATE, DELETE (users can only modify their own data)
-- These should already exist, but if not, create them:

-- Habits: Users can only insert/update/delete their own habits
CREATE POLICY "Users can manage own habits" ON habits
    FOR ALL
    USING (auth.uid()::text = user_id::text)
    WITH CHECK (auth.uid()::text = user_id::text);

-- Captures: Users can only insert/update/delete their own captures
CREATE POLICY "Users can manage own captures" ON captures
    FOR ALL
    USING (auth.uid()::text = user_id::text)
    WITH CHECK (auth.uid()::text = user_id::text);

-- 4. Verify the policies are working
-- You can test with:
-- SELECT * FROM habits; -- Should return all habits
-- SELECT * FROM captures; -- Should return all captures
