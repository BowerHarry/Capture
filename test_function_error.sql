-- Test the function and see the exact error
DO $$
BEGIN
    RAISE NOTICE 'Testing get_trending_captures_for_habits function...';
    PERFORM * FROM get_trending_captures_for_habits() LIMIT 1;
    RAISE NOTICE 'Function executed successfully!';
EXCEPTION 
    WHEN OTHERS THEN
        RAISE NOTICE 'Error occurred: %', SQLERRM;
        RAISE NOTICE 'Error detail: %', SQLSTATE;
END $$;
