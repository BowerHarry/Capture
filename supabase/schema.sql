-- =============================================================================
-- Capture: consolidated Supabase schema
-- =============================================================================
--
-- WHAT THIS IS
--   A single ordered schema file consolidated from the ~87 iterative .sql
--   scripts in the repository root (setup_trending_*, fix_*, create_*,
--   migrate_*, social_feed_schema_*, performance_optimizations.sql, ...) and
--   from the root *.md notes. The original Supabase project is lost.
--   Those scripts and notes have since been removed from the working tree;
--   they remain in git history (the commit titled "Track the SQL scripts and
--   working notes that were git-ignored") for reference.
--
-- IMPORTANT CAVEATS
--   * THIS FILE HAS NEVER BEEN RUN AGAINST A DATABASE. No database was
--     available while it was assembled. Expect to fix things when you run it.
--   * It is intended for a FRESH Supabase project (auth and storage schemas
--     present, Postgres 15+). It is not idempotent: plain CREATE POLICY /
--     CREATE TRIGGER / CREATE VIEW statements will fail on a second run.
--   * For every object the definition was taken from the latest script that
--     defines it (by file modification time, then by _final/_corrected/_v2
--     naming). Copied blocks are verbatim and are preceded by a
--     "-- Source: <file> (lines a-b)" comment.
--   * The base tables were created in the Supabase dashboard and appear in NO
--     script. They are rebuilt here from column references in the scripts and
--     from the Swift models, and each is marked "-- RECONSTRUCTED". Column
--     types, defaults, constraints and RLS policies on those tables are
--     best guesses.
--
-- OBJECTS COPIED FROM THE ORIGINAL SCRIPTS
--   Tables
--     habit_categories (+ seed rows)        create_habit_categories_system.sql
--     habit_descriptions                    fix_trending_performance_and_crash.sql
--     capture_reactions, capture_comments   social_feed_schema_final.sql
--     trending_images                       migrate_to_habit_templates.sql
--   Indexes                                 add_performance_indexes.sql,
--                                           create_habit_categories_system.sql,
--                                           fix_trending_performance_and_crash.sql,
--                                           migrate_to_habit_templates.sql,
--                                           performance_optimizations.sql,
--                                           progress_grid_view.sql,
--                                           social_feed_schema_corrected.sql
--   Trigger functions and triggers
--     update_habit_categories_updated_at    create_habit_categories_system.sql
--     update_habit_descriptions_updated_at  fix_trending_performance_and_crash.sql
--     update_updated_at_column              social_feed_schema_final.sql
--     create_trending_thumbnail             migrate_to_habit_templates.sql
--   RLS policies
--     habit_categories                      create_habit_categories_system.sql
--     habit_descriptions                    fix_trending_performance_and_crash.sql
--     trending_images                       migrate_to_habit_templates.sql
--     capture_reactions, capture_comments   social_feed_schema_final.sql
--     captures                              supabase_rls_policies.sql
--   Storage
--     trending-images bucket + policies     create_storage_bucket.sql
--   Views
--     trending_habits_view                  fix_trending_performance_and_crash.sql
--     social_feed_with_likes                migrate_to_habit_templates.sql
--     progress_grid_data                    progress_grid_view.sql
--     available_habits_with_categories      create_habit_categories_system.sql
--   Functions
--     get_habit_categories                  fix_get_habit_categories_function.sql
--     get_trending_habits_by_category       fix_trending_category_function_final.sql
--     get_trending_captures_for_habits      fix_trending_captures_function.sql
--     get_community_stats                   create_community_stats_function.sql
--     get_or_create_habit_description       fix_trending_performance_and_crash.sql
--     toggle_capture_reaction               social_feed_schema_final.sql
--     get_social_feed_groups                social_feed_schema_final.sql
--     get_capture_reactions                 social_feed_schema_final.sql
--     test_reaction_function                social_feed_schema_final.sql
--     get_captures_with_metadata            performance_optimizations.sql
--     get_user_progress_grid_data           progress_grid_view.sql
--     get_user_habits_with_progress         performance_optimizations.sql
--                                           (ADJUSTED, see the note at the function)
--
-- OBJECTS RECONSTRUCTED (no definition in any script)
--   Tables: profiles, habit_templates, available_habits, user_habits,
--           captures, capture_likes, user_follows
--   RLS policies on those tables (except the two captures policies above)
--   Trigger: handle_new_user / on_auth_user_created (profile row on signup)
--   View: capture_like_counts (referenced by get_trending_habits_by_category)
--   Functions: toggle_capture_like, is_capture_liked_by_user
--   Storage buckets + policies: avatars, captures_public, captures
--
-- CLIENT RPCs THAT ARE NOT IN THIS FILE
--   add_capture_to_trending(capture_uuid, user_uuid)
--   remove_capture_from_trending(capture_uuid)
--     Neither is defined or even mentioned in any script or note. The Swift
--     wrappers have no call sites and their semantics cannot be inferred, so
--     they were NOT reconstructed.
--
-- DELIBERATELY LEFT OUT
--   * Legacy tables the client is dropping: habits, social_posts, likes,
--     comments (and the habits policies in supabase_rls_policies.sql).
--   * Materialized views mv_trending_habits, mv_social_feed, mv_user_stats,
--     mv_habit_category_stats, social_feed_materialized, their refresh
--     functions/triggers, calculate_trending_score and the *_optimized
--     functions (get_social_feed_optimized, get_trending_habits_optimized,
--     get_community_stats_optimized, get_capture_reaction_users). The client
--     calls none of them, and several depend on superseded definitions.
--   * All check_*/diagnose_*/debug_*/test_* queries and the verification
--     SELECTs at the end of the scripts.
--   * One-off data migrations (backfills of captures.habit_template_id and
--     category_id, deletion of orphaned captures) which only made sense
--     against the old data.
--   * The habit_descriptions seed rows in fix_trending_performance_and_crash.sql:
--     they reference habit_templates UUIDs that only existed in the lost
--     database and would violate the foreign key here.
--   * Indexes on captures(habit_id ...) from add_performance_indexes.sql
--     (legacy column), and idx_captures_recent_public, whose predicate uses
--     NOW() and cannot be created (index predicates must be immutable).
--
-- KNOWN CONTRADICTIONS / GAPS (search for "NOTE:" below)
--   * No seed data for habit_templates or available_habits survives.
--   * Nothing in the scripts or the client maintains user_habits.current_streak;
--     if a trigger did that, it is lost.
--   * habit_templates.category_id / available_habits.category_id were made
--     NOT NULL by create_habit_categories_system.sql, but the client inserts
--     rows without category_id. They are nullable here.
--   * captures.habit_id vs captures.user_habit_id: older scripts use habit_id
--     (= user_habits.id), newer scripts and the client use user_habit_id.
--   * Two parallel "like" systems exist: capture_likes and capture_reactions.
--   * The client reads trending_images columns (habit_id, is_active) that the
--     table definition does not have.
--   * The client inserts capture_comments without user_id, which the table
--     and its RLS policy require.
-- =============================================================================


-- =============================================================================
-- 1. EXTENSIONS
-- =============================================================================
-- None of the original scripts creates an extension. gen_random_uuid() is
-- built into Postgres 13+ and pgcrypto is enabled by default on Supabase.
-- performance_optimizations.sql mentions pg_cron only in a commented-out line
-- for a materialized view that is not included here.


-- =============================================================================
-- 2. TABLES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- profiles
-- RECONSTRUCTED: not present in the original scripts; inferred from
--   Capture/SupabaseManager.swift (ProfileRow, NewProfilePayload,
--   UpdateProfilePayload), Capture/Models.swift (UserProfile),
--   HabitManager (update of best_streak), SocialManager (search on username
--   and display_name), create_community_stats_function.sql (is_active) and
--   APP_FUNCTIONALITY_OVERVIEW.md.
-- -----------------------------------------------------------------------------
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT,
    username TEXT,
    display_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    best_streak INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,  -- added by create_community_stats_function.sql
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- habit_categories
-- -----------------------------------------------------------------------------
-- Source: create_habit_categories_system.sql (lines 6-16)
CREATE TABLE IF NOT EXISTS habit_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    color VARCHAR(20) DEFAULT 'gray',
    icon VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- habit_templates
-- RECONSTRUCTED: not present in the original scripts; inferred from
--   Capture/Models.swift (HabitTemplate), SupabaseManager.createHabitDirect
--   (CreateHabitTemplate payload), progress_grid_view.sql and
--   create_habit_categories_system.sql (category_id).
-- NOTE: create_habit_categories_system.sql ended with
--   "ALTER COLUMN category_id SET NOT NULL", but the client inserts templates
--   with only the text `category`. category_id is left nullable so those
--   inserts work. trending_habits_view and get_trending_habits_by_category
--   inner-join habit_categories on category_id, so templates without a
--   category_id will not appear in trending results. The original backfill
--   matched LOWER(habit_categories.name) = LOWER(habit_templates.category).
-- -----------------------------------------------------------------------------
CREATE TABLE habit_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    category TEXT NOT NULL,
    category_id UUID REFERENCES habit_categories(id),
    target_frequency TEXT NOT NULL DEFAULT 'daily',
    target_count INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- habit_descriptions
-- -----------------------------------------------------------------------------
-- Source: fix_trending_performance_and_crash.sql (lines 9-17)
CREATE TABLE habit_descriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    habit_template_id UUID NOT NULL REFERENCES habit_templates(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    is_ai_generated BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(habit_template_id)
);

-- -----------------------------------------------------------------------------
-- available_habits
-- RECONSTRUCTED: not present in the original scripts; inferred from
--   Capture/Models.swift (AvailableHabit), SupabaseManager (InsertAvailable
--   payload; ordering by is_default, created_at, name),
--   create_habit_categories_system.sql (category_id, and the columns used by
--   available_habits_with_categories) and add_performance_indexes.sql.
-- NOTE: category_id is nullable here for the same reason as on
--   habit_templates (the client insert does not send it).
-- -----------------------------------------------------------------------------
CREATE TABLE available_habits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,  -- NULL for built-in suggestions
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    category_id UUID REFERENCES habit_categories(id),
    description TEXT,
    icon TEXT,
    color TEXT,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- user_habits
-- RECONSTRUCTED: not present in the original scripts; inferred from
--   Capture/Models.swift (UserHabit), the CreateUserHabit payloads in
--   SupabaseManager/HabitManager, and progress_grid_view.sql.
-- The foreign key to habit_templates is required by the client's embedded
-- select `habit_templates!inner(...)`.
-- NOTE: nothing in the surviving scripts or in the client updates
--   current_streak.
-- -----------------------------------------------------------------------------
CREATE TABLE user_habits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    habit_template_id UUID NOT NULL REFERENCES habit_templates(id),
    current_streak INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- captures
-- RECONSTRUCTED: not present in the original scripts; inferred from
--   Capture/Models.swift (HabitCapture), SupabaseManager (InsertCapture
--   payload), migrate_to_habit_templates.sql (habit_template_id, NOT NULL),
--   progress_grid_view.sql and performance_optimizations.sql (user_habit_id,
--   updated_at).
-- NOTE: habit_id is the legacy column (it held user_habits.id). The client no
--   longer writes it, but social_feed_with_likes still selects it, so it is
--   kept as a nullable column with no constraint. user_habit_id replaces it.
-- -----------------------------------------------------------------------------
CREATE TABLE captures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    habit_id UUID,  -- legacy, see note above
    user_habit_id UUID REFERENCES user_habits(id) ON DELETE CASCADE,
    habit_template_id UUID NOT NULL REFERENCES habit_templates(id),
    image_url TEXT,
    caption TEXT,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- capture_likes
-- RECONSTRUCTED: not present in the original scripts; inferred from
--   Capture/Models.swift (CaptureLike), APP_FUNCTIONALITY_OVERVIEW.md
--   ("Key Fields: id, capture_id, user_id, created_at") and its use in
--   social_feed_with_likes and get_trending_captures_for_habits.
-- The UNIQUE constraint is an assumption (one like per user per capture).
-- -----------------------------------------------------------------------------
CREATE TABLE capture_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(capture_id, user_id)
);

-- -----------------------------------------------------------------------------
-- user_follows
-- RECONSTRUCTED: not present in the original scripts or notes; inferred only
--   from Capture/Models.swift (Follow) and the queries in SocialManager,
--   AuthManager and UserProfileView. The client sends id and created_at
--   itself on insert. The UNIQUE and CHECK constraints are assumptions.
-- -----------------------------------------------------------------------------
CREATE TABLE user_follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    following_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK (follower_id <> following_id)
);

-- -----------------------------------------------------------------------------
-- capture_reactions, capture_comments
-- NOTE: SupabaseManager.addCaptureComment inserts only capture_id and content.
--   With user_id NOT NULL and the insert policy auth.uid() = user_id, that
--   insert fails as written. The lost database may have had a column default;
--   if so it would have been:
--     ALTER TABLE capture_comments ALTER COLUMN user_id SET DEFAULT auth.uid();
--   That statement is NOT in any script and is left commented out here.
-- -----------------------------------------------------------------------------
-- Source: social_feed_schema_final.sql (lines 5-22)
CREATE TABLE IF NOT EXISTS capture_reactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reaction_type TEXT NOT NULL DEFAULT 'fire',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(capture_id, user_id)
);

-- 2. Create capture_comments table
CREATE TABLE IF NOT EXISTS capture_comments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- -----------------------------------------------------------------------------
-- trending_images
-- NOTE: SupabaseManager.populateTrendingImages selects
--   "habit_id, capture_id, user_id, image_path" with is_active = true. This
--   table (latest definition) has habit_template_id and no is_active column,
--   so that query cannot work against it. The function has no call sites.
-- -----------------------------------------------------------------------------
-- Source: migrate_to_habit_templates.sql (lines 42-58)
CREATE TABLE trending_images (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  capture_id UUID NOT NULL REFERENCES captures(id) ON DELETE CASCADE,
  habit_template_id UUID NOT NULL REFERENCES habit_templates(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  original_image_url TEXT NOT NULL,
  thumbnail_url TEXT NOT NULL,
  image_path TEXT NOT NULL,  -- Path in trending-images bucket
  width INTEGER,
  height INTEGER,
  file_size INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Ensure unique thumbnail per capture
  UNIQUE(capture_id)
);


-- =============================================================================
-- 2b. INDEXES
-- =============================================================================

-- Source: create_habit_categories_system.sql (lines 103-106)
CREATE INDEX IF NOT EXISTS idx_habit_templates_category_id ON habit_templates(category_id);
CREATE INDEX IF NOT EXISTS idx_available_habits_category_id ON available_habits(category_id);
CREATE INDEX IF NOT EXISTS idx_habit_categories_name ON habit_categories(name);
CREATE INDEX IF NOT EXISTS idx_habit_categories_sort_order ON habit_categories(sort_order);

-- Source: fix_trending_performance_and_crash.sql (lines 20-21)
CREATE INDEX idx_habit_descriptions_habit_template_id ON habit_descriptions(habit_template_id);
CREATE INDEX idx_habit_descriptions_is_ai_generated ON habit_descriptions(is_ai_generated);

-- Source: migrate_to_habit_templates.sql (lines 61-63)
CREATE INDEX IF NOT EXISTS idx_trending_images_habit_template ON trending_images(habit_template_id);
CREATE INDEX IF NOT EXISTS idx_trending_images_user ON trending_images(user_id);
CREATE INDEX IF NOT EXISTS idx_trending_images_created_at ON trending_images(created_at);

-- Source: migrate_to_habit_templates.sql (lines 27-32)
CREATE INDEX IF NOT EXISTS idx_captures_habit_template_id 
ON captures(habit_template_id);

CREATE INDEX IF NOT EXISTS idx_captures_template_public_created 
ON captures(habit_template_id, is_public, created_at DESC) 
WHERE is_public = true;

-- Source: fix_trending_performance_and_crash.sql (lines 181-183)
CREATE INDEX IF NOT EXISTS idx_captures_habit_template_id_created_at ON captures(habit_template_id, created_at);
CREATE INDEX IF NOT EXISTS idx_captures_is_public_created_at ON captures(is_public, created_at);
CREATE INDEX IF NOT EXISTS idx_user_habits_current_streak ON user_habits(current_streak);

-- Source: performance_optimizations.sql (lines 5-12)
CREATE INDEX IF NOT EXISTS idx_user_habits_user_id_active ON user_habits(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_captures_user_habit_id_created_at ON captures(user_habit_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_captures_user_id_public_created_at ON captures(user_id, is_public, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_capture_reactions_capture_id ON capture_reactions(capture_id);
CREATE INDEX IF NOT EXISTS idx_capture_reactions_user_id ON capture_reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_capture_comments_capture_id ON capture_comments(capture_id);
CREATE INDEX IF NOT EXISTS idx_profiles_display_name ON profiles(display_name);
CREATE INDEX IF NOT EXISTS idx_habit_templates_category ON habit_templates(category);

-- Source: progress_grid_view.sql (lines 34-36)
CREATE INDEX IF NOT EXISTS idx_captures_user_habit_id ON captures(user_habit_id);
CREATE INDEX IF NOT EXISTS idx_user_habits_active ON user_habits(is_active, user_id);
CREATE INDEX IF NOT EXISTS idx_habit_templates_active ON habit_templates(is_active);

-- Source: social_feed_schema_corrected.sql (lines 31-31)
CREATE INDEX IF NOT EXISTS idx_capture_comments_user_id ON capture_comments(user_id);

-- Source: add_performance_indexes.sql (the same statements also appear in
-- deploy_performance_improvements.sql). Only the indexes that are still valid
-- are kept: the captures(habit_id ...) indexes target the legacy column,
-- idx_captures_recent_public has a NOW() predicate that Postgres rejects, and
-- idx_habit_templates_active / idx_profiles_display_name are superseded by the
-- later definitions above.
CREATE INDEX IF NOT EXISTS idx_captures_created_at_public 
ON captures(created_at) 
WHERE is_public = true;

CREATE INDEX IF NOT EXISTS idx_captures_user_id_created_at 
ON captures(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_captures_public_image_created 
ON captures(is_public, created_at DESC) 
WHERE is_public = true AND image_url IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_captures_social_feed 
ON captures(is_public, created_at DESC, user_id) 
WHERE is_public = true;

CREATE INDEX IF NOT EXISTS idx_user_habits_active_template 
ON user_habits(habit_template_id, is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_user_habits_user_active 
ON user_habits(user_id, is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_user_habits_template_user 
ON user_habits(habit_template_id, user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_user_habits_active_recent 
ON user_habits(habit_template_id, user_id, is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_habit_templates_category_active 
ON habit_templates(category, is_active) 
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_capture_likes_capture_id 
ON capture_likes(capture_id);

CREATE INDEX IF NOT EXISTS idx_capture_likes_user_id 
ON capture_likes(user_id);

CREATE INDEX IF NOT EXISTS idx_capture_likes_capture_user 
ON capture_likes(capture_id, user_id);

CREATE INDEX IF NOT EXISTS idx_profiles_bio_gin 
ON profiles USING gin(to_tsvector('english', bio));

CREATE INDEX IF NOT EXISTS idx_available_habits_default 
ON available_habits(is_default) 
WHERE is_default = true;

CREATE INDEX IF NOT EXISTS idx_available_habits_category 
ON available_habits(category);


-- =============================================================================
-- 3. TRIGGER FUNCTIONS AND TRIGGERS
-- =============================================================================

-- updated_at on habit_categories
-- Source: create_habit_categories_system.sql (lines 307-318)
CREATE OR REPLACE FUNCTION update_habit_categories_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER habit_categories_updated_at_trigger
    BEFORE UPDATE ON habit_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_habit_categories_updated_at();

-- updated_at on habit_descriptions
-- Source: fix_trending_performance_and_crash.sql (lines 36-47)
CREATE OR REPLACE FUNCTION update_habit_descriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER habit_descriptions_updated_at_trigger
    BEFORE UPDATE ON habit_descriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_habit_descriptions_updated_at();

-- updated_at on capture_comments
-- Source: social_feed_schema_final.sql (lines 205-211)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Source: social_feed_schema_final.sql (lines 216-218)
CREATE TRIGGER update_capture_comments_updated_at 
    BEFORE UPDATE ON capture_comments 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- NOTE: the scripts attach an updated_at trigger only to the three tables
-- above. Whether profiles, habit_templates, user_habits, captures and
-- available_habits had one in the lost database is unknown; none is added.

-- Mirror every public capture into trending_images
-- Source: migrate_to_habit_templates.sql (lines 397-428)
CREATE OR REPLACE FUNCTION create_trending_thumbnail()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only process public captures with images
  IF NEW.is_public = true AND NEW.image_url IS NOT NULL THEN
    -- Insert into trending_images table using habit_template_id
    INSERT INTO trending_images (
      capture_id,
      habit_template_id,
      user_id,
      original_image_url,
      thumbnail_url,
      image_path
    ) VALUES (
      NEW.id,
      NEW.habit_template_id,
      NEW.user_id,
      NEW.image_url,
      NEW.image_url,  -- Will be updated with thumbnail URL by app
      'thumbnails/' || NEW.user_id::text || '/' || NEW.id::text || '.jpg'
    )
    ON CONFLICT (capture_id) DO UPDATE SET
      original_image_url = NEW.image_url,
      updated_at = NOW();
  END IF;
  
  RETURN NEW;
END;
$$;

-- Source: migrate_to_habit_templates.sql (lines 432-435)
CREATE TRIGGER trigger_create_trending_thumbnail
  AFTER INSERT OR UPDATE ON captures
  FOR EACH ROW
  EXECUTE FUNCTION create_trending_thumbnail();

-- -----------------------------------------------------------------------------
-- Profile row on signup
-- RECONSTRUCTED: not present in the original scripts; inferred from the comment
--   in SupabaseManager.signUp ("attach username metadata for profile trigger")
--   and from fetchCurrentProfile, which falls back to inserting
--   (id, email, display_name = metadata.username, avatar_url, bio) when the
--   row is missing. This is the standard Supabase pattern; the function and
--   trigger names are the conventional ones, not known originals. Whether the
--   original filled username, display_name or both is unknown; both are set.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, email, username, display_name, avatar_url)
    VALUES (
        NEW.id,
        NEW.email,
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'username',
        NEW.raw_user_meta_data->>'avatar_url'
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();


-- =============================================================================
-- 4. ROW LEVEL SECURITY
-- =============================================================================

-- habit_categories
-- Source: create_habit_categories_system.sql (lines 295-298)
ALTER TABLE habit_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "habit_categories_select_policy" ON habit_categories
    FOR SELECT USING (is_active = TRUE);

-- habit_descriptions
-- Source: fix_trending_performance_and_crash.sql (lines 24-33)
ALTER TABLE habit_descriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "habit_descriptions_select_policy" ON habit_descriptions
    FOR SELECT USING (true);

CREATE POLICY "habit_descriptions_insert_policy" ON habit_descriptions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "habit_descriptions_update_policy" ON habit_descriptions
    FOR UPDATE USING (true);

-- trending_images
-- NOTE: the UPDATE policy below has WITH CHECK but no USING clause. As far as
-- can be told without a database, Postgres then matches no existing rows for
-- UPDATE, so client updates to trending_images are effectively denied.
-- Copied as written.
-- Source: migrate_to_habit_templates.sql (lines 66-79)
ALTER TABLE trending_images ENABLE ROW LEVEL SECURITY;

-- RLS policies for trending_images table
CREATE POLICY "Public can read trending images" ON trending_images
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can insert trending images" ON trending_images
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Users can update own trending images" ON trending_images
  FOR UPDATE WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own trending images" ON trending_images
  FOR DELETE USING (auth.uid() = user_id);

-- capture_reactions, capture_comments
-- Source: social_feed_schema_final.sql (lines 165-202)
ALTER TABLE capture_reactions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view all capture reactions" ON capture_reactions;
DROP POLICY IF EXISTS "Users can insert their own capture reactions" ON capture_reactions;
DROP POLICY IF EXISTS "Users can delete their own capture reactions" ON capture_reactions;

-- Policy for capture_reactions - users can see all reactions, but only manage their own
CREATE POLICY "Users can view all capture reactions" ON capture_reactions
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own capture reactions" ON capture_reactions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own capture reactions" ON capture_reactions
    FOR DELETE USING (auth.uid() = user_id);

-- Enable RLS on capture_comments
ALTER TABLE capture_comments ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view all capture comments" ON capture_comments;
DROP POLICY IF EXISTS "Users can insert their own capture comments" ON capture_comments;
DROP POLICY IF EXISTS "Users can update their own capture comments" ON capture_comments;
DROP POLICY IF EXISTS "Users can delete their own capture comments" ON capture_comments;

-- Policy for capture_comments - users can see all comments, but only manage their own
CREATE POLICY "Users can view all capture comments" ON capture_comments
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own capture comments" ON capture_comments
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own capture comments" ON capture_comments
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own capture comments" ON capture_comments
    FOR DELETE USING (auth.uid() = user_id);

-- captures
-- The two policies are copied; the ENABLE statement is not in any script
-- (supabase_rls_policies.sql assumed RLS was already on) and is added here.
-- NOTE: the SELECT policy exposes every capture row, including is_public = false.
ALTER TABLE captures ENABLE ROW LEVEL SECURITY;

-- Source: supabase_rls_policies.sql (lines 15-17)
CREATE POLICY "Allow public read access to captures" ON captures
    FOR SELECT
    USING (true); -- Allow reading all captures

-- Source: supabase_rls_policies.sql (lines 29-32)
CREATE POLICY "Users can manage own captures" ON captures
    FOR ALL
    USING (auth.uid()::text = user_id::text)
    WITH CHECK (auth.uid()::text = user_id::text);

-- -----------------------------------------------------------------------------
-- RECONSTRUCTED: RLS for the reconstructed tables. Not present in the original
--   scripts; these are the minimum policies that let the client's queries and
--   the SECURITY INVOKER functions below work (public read, owner write).
--   Without them a table created through SQL is either wide open (RLS off) or
--   unreadable (RLS on, no policy). Review before relying on them.
-- -----------------------------------------------------------------------------
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Profiles are viewable by everyone" ON profiles
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

ALTER TABLE habit_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Habit templates are viewable by everyone" ON habit_templates
    FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create habit templates" ON habit_templates
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

ALTER TABLE available_habits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Available habits are viewable by everyone" ON available_habits
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own available habits" ON available_habits
    FOR INSERT WITH CHECK (auth.uid() = user_id);

ALTER TABLE user_habits ENABLE ROW LEVEL SECURITY;

-- get_community_stats (SECURITY INVOKER) counts every user's active habits,
-- so SELECT has to be open.
CREATE POLICY "User habits are viewable by everyone" ON user_habits
    FOR SELECT USING (true);

CREATE POLICY "Users can manage own user habits" ON user_habits
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

ALTER TABLE capture_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Capture likes are viewable by everyone" ON capture_likes
    FOR SELECT USING (true);

CREATE POLICY "Users can insert their own capture likes" ON capture_likes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own capture likes" ON capture_likes
    FOR DELETE USING (auth.uid() = user_id);

ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Follows are viewable by everyone" ON user_follows
    FOR SELECT USING (true);

CREATE POLICY "Users can follow as themselves" ON user_follows
    FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "Users can remove their own follows" ON user_follows
    FOR DELETE USING (auth.uid() = follower_id);

-- Table grants
-- Source: social_feed_schema_final.sql (lines 221-223)
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON capture_reactions TO authenticated;
GRANT ALL ON capture_comments TO authenticated;


-- =============================================================================
-- 5. STORAGE BUCKETS AND POLICIES
-- =============================================================================

-- trending-images
-- NOTE: as with trending_images, the UPDATE policy has WITH CHECK only.
-- The client uploads to this bucket with upsert: true.
-- Source: create_storage_bucket.sql (lines 8-38)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'trending-images',
  'trending-images', 
  true,  -- Public bucket for fast access
  5242880,  -- 5MB file size limit
  ARRAY['image/jpeg', 'image/png', 'image/webp']  -- Allowed image types
)
ON CONFLICT (id) DO NOTHING;

-- Create RLS policies for the trending-images bucket
CREATE POLICY "Public Access" ON storage.objects
  FOR SELECT USING (bucket_id = 'trending-images');

CREATE POLICY "Authenticated users can upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'trending-images' 
    AND auth.role() = 'authenticated'
  );

CREATE POLICY "Users can update own images" ON storage.objects
  FOR UPDATE WITH CHECK (
    bucket_id = 'trending-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own images" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'trending-images' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- -----------------------------------------------------------------------------
-- RECONSTRUCTED: avatars, captures_public and captures buckets. Not present in
--   the original scripts (TRENDING_SETUP_GUIDE.md says captures_public
--   "already exists"); inferred from the storage calls in SupabaseManager:
--     avatars          path "avatars/{userId}_avatar.jpg"; remove, upload,
--                      getPublicURL
--     captures_public  path "{lowercased user id}/{uuid}.jpg"; upload with
--                      upsert: true; described as public in the notes
--     captures         createSignedURL and download only (legacy private
--                      bucket; the client never uploads to it)
--   Size limits and MIME restrictions are unknown and not set. The policies
--   follow the trending-images pattern above and the client's paths.
-- -----------------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('avatars', 'avatars', true),
  ('captures_public', 'captures_public', true),
  ('captures', 'captures', false)
ON CONFLICT (id) DO NOTHING;

-- avatars
CREATE POLICY "Avatars are publicly readable" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

CREATE POLICY "Users can upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars'
    AND lower(name) = 'avatars/' || auth.uid()::text || '_avatar.jpg'
  );

CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'avatars'
    AND lower(name) = 'avatars/' || auth.uid()::text || '_avatar.jpg'
  );

CREATE POLICY "Users can delete own avatar" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars'
    AND lower(name) = 'avatars/' || auth.uid()::text || '_avatar.jpg'
  );

-- captures_public
CREATE POLICY "Public captures are publicly readable" ON storage.objects
  FOR SELECT USING (bucket_id = 'captures_public');

CREATE POLICY "Users can upload own captures" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'captures_public'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can update own captures" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'captures_public'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own captures" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'captures_public'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- captures (legacy, private)
CREATE POLICY "Authenticated users can read captures bucket" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'captures'
    AND auth.role() = 'authenticated'
  );


-- =============================================================================
-- 6. VIEWS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- capture_like_counts
-- RECONSTRUCTED: not present in the original scripts. It is read as
--   (SELECT like_count FROM capture_like_counts WHERE capture_id = c.id)
--   by get_trending_habits_by_category (fix_trending_category_function_final.sql)
--   and by several setup_trending_* scripts. Only capture_id and like_count
--   are certain. The other columns follow Capture/Models.swift
--   (CaptureLikeCount) and may not match the original; whether it was a view
--   or a table is also unknown.
-- -----------------------------------------------------------------------------
CREATE VIEW capture_like_counts AS
SELECT
    c.id AS capture_id,
    c.habit_id,
    c.user_id AS capture_user_id,
    c.image_url,
    c.caption,
    c.created_at AS capture_created_at,
    COUNT(cl.id) AS like_count,
    COALESCE(ARRAY_AGG(cl.user_id) FILTER (WHERE cl.user_id IS NOT NULL), '{}') AS liked_by_user_ids
FROM captures c
LEFT JOIN capture_likes cl ON cl.capture_id = c.id
GROUP BY c.id, c.habit_id, c.user_id, c.image_url, c.caption, c.created_at;

-- -----------------------------------------------------------------------------
-- trending_habits_view
-- Latest of ~25 definitions. It has no `captures` image array (TrendingHabit
-- decodes that field as optional).
-- -----------------------------------------------------------------------------
-- Source: fix_trending_performance_and_crash.sql (lines 65-84)
CREATE VIEW trending_habits_view AS
SELECT
    ht.id,
    ht.name::text,
    hc.name::text as category,
    hc.color::text as category_color,
    COALESCE(COUNT(DISTINCT c.user_id), 0) as participants,
    COALESCE(AVG(uh.current_streak), 0.0) as avg_streak,
    COALESCE(hd.description, 'Track your progress with this habit')::text as description,
    COALESCE(COUNT(c.id), 0) as total_captures
FROM habit_templates ht
JOIN habit_categories hc ON ht.category_id = hc.id
LEFT JOIN habit_descriptions hd ON ht.id = hd.habit_template_id
LEFT JOIN captures c ON ht.id = c.habit_template_id
    AND c.created_at >= NOW() - INTERVAL '7 days'
    AND c.is_public = TRUE
LEFT JOIN user_habits uh ON c.user_habit_id = uh.id
GROUP BY ht.id, ht.name, hc.name, hc.color, hd.description
ORDER BY participants DESC, total_captures DESC
LIMIT 5;

-- -----------------------------------------------------------------------------
-- social_feed_with_likes
-- Only definition in the scripts. Uses capture_likes and the legacy
-- captures.habit_id column.
-- -----------------------------------------------------------------------------
-- Source: migrate_to_habit_templates.sql (lines 292-321)
CREATE VIEW social_feed_with_likes AS
SELECT 
  c.id as capture_id,
  c.habit_id,
  c.habit_template_id,
  c.user_id as capture_user_id,
  c.image_url,
  c.caption,
  c.is_public,
  c.created_at as capture_created_at,
  ht.name as habit_name,
  ht.category as habit_category,
  p.display_name as user_display_name,
  p.avatar_url as user_avatar_url,
  COALESCE(like_counts.like_count, 0) as like_count,
  like_counts.liked_by_user_ids
FROM captures c
JOIN habit_templates ht ON c.habit_template_id = ht.id
JOIN profiles p ON c.user_id = p.id
LEFT JOIN (
  SELECT 
    cl.capture_id,
    COUNT(*) as like_count,
    ARRAY_AGG(cl.user_id) as liked_by_user_ids
  FROM capture_likes cl
  GROUP BY cl.capture_id
) like_counts ON c.id = like_counts.capture_id
WHERE c.is_public = true
  AND c.habit_template_id IS NOT NULL
ORDER BY c.created_at DESC;

-- progress_grid_data (not queried by the client directly; companion to get_user_progress_grid_data)
-- Source: progress_grid_view.sql (lines 4-31)
CREATE OR REPLACE VIEW progress_grid_data AS
SELECT 
    uh.id as user_habit_id,
    uh.user_id,
    uh.habit_template_id,
    uh.current_streak,
    uh.is_active,
    uh.created_at as user_habit_created_at,
    uh.updated_at as user_habit_updated_at,
    ht.name as habit_name,
    ht.description as habit_description,
    ht.category as habit_category,
    ht.target_frequency,
    ht.target_count,
    ht.is_active as template_is_active,
    ht.created_at as template_created_at,
    ht.updated_at as template_updated_at,
    c.id as capture_id,
    c.image_url,
    c.caption,
    c.is_public,
    c.created_at as capture_created_at,
    c.updated_at as capture_updated_at
FROM user_habits uh
JOIN habit_templates ht ON uh.habit_template_id = ht.id
LEFT JOIN captures c ON uh.id = c.user_habit_id
WHERE uh.is_active = true
  AND ht.is_active = true;

-- Source: progress_grid_view.sql (lines 102-102)
GRANT SELECT ON progress_grid_data TO authenticated;

-- available_habits_with_categories (not queried by the client)
-- Source: create_habit_categories_system.sql (lines 349-363)
CREATE OR REPLACE VIEW available_habits_with_categories AS
SELECT
    ah.id,
    ah.name,
    hc.description as category_description,
    hc.name as category,
    hc.color as category_color,
    hc.id as category_id,
    ah.is_default,
    ah.created_at,
    ah.updated_at
FROM available_habits ah
JOIN habit_categories hc ON ah.category_id = hc.id
WHERE hc.is_active = TRUE
ORDER BY ah.is_default DESC, ah.name;


-- =============================================================================
-- 7. FUNCTIONS (RPC)
-- =============================================================================

-- get_habit_categories
-- Source: fix_get_habit_categories_function.sql (lines 8-30)
CREATE OR REPLACE FUNCTION get_habit_categories()
RETURNS TABLE (
    id uuid,
    name text,
    description text,
    color text,
    icon text,
    sort_order integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        hc.id,
        hc.name::text,
        hc.description::text,
        hc.color::text,
        hc.icon::text,
        hc.sort_order
    FROM habit_categories hc
    WHERE hc.is_active = TRUE
    ORDER BY hc.sort_order, hc.name;
END;
$$ LANGUAGE plpgsql;

-- get_trending_habits_by_category (reads the reconstructed capture_like_counts view)
-- Source: fix_trending_category_function_final.sql (lines 8-118)
CREATE OR REPLACE FUNCTION get_trending_habits_by_category(category_id_param UUID)
RETURNS TABLE (
    id uuid,
    name text,
    category text,
    category_color text,
    participants bigint,
    avg_streak numeric,
    description text,
    captures text[],
    total_captures bigint
) AS $$
BEGIN
    RETURN QUERY
    WITH habit_stats AS (
        -- Calculate basic stats for each habit template in the specified category
        SELECT 
            ht.id,
            ht.name,
            hc.name as category,
            hc.color as category_color,
            -- Count participants (unique users who captured this habit)
            COUNT(DISTINCT c.user_id) as participants,
            -- Average streak (we'll set to 0 since we don't have user_habits data)
            0.0 as avg_streak,
            -- Count total captures
            COUNT(DISTINCT c.id) as total_captures,
            -- Count recent captures
            COUNT(CASE WHEN c.created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as recent_captures,
            -- Count new participants (users who first captured this habit in last 7 days)
            COUNT(DISTINCT CASE WHEN c.user_id NOT IN (
                SELECT DISTINCT c2.user_id 
                FROM captures c2 
                WHERE c2.habit_template_id = ht.id 
                AND c2.created_at < NOW() - INTERVAL '7 days'
            ) THEN c.user_id END) as new_participants,
            -- Calculate total likes for this habit in the last 7 days
            COALESCE(SUM(
                CASE 
                    WHEN c.created_at >= NOW() - INTERVAL '7 days' 
                    THEN (SELECT like_count FROM capture_like_counts WHERE capture_id = c.id)
                    ELSE 0 
                END
            ), 0) as recent_likes
        FROM habit_templates ht
        JOIN habit_categories hc ON ht.category_id = hc.id
        -- Join captures directly to habit templates
        LEFT JOIN captures c ON c.habit_template_id = ht.id AND c.is_public = true
        WHERE hc.id = category_id_param AND ht.is_active = true
        GROUP BY ht.id, ht.name, hc.name, hc.color
    ),
    trending_scores AS (
        -- Calculate trending score based on multiple factors
        SELECT 
            hs.*,
            -- Enhanced trending score calculation with likes
            (
                (hs.recent_captures * 2.0) +      -- Recent activity weight
                (hs.new_participants * 3.0) +     -- New user adoption weight
                (hs.participants * 1.0) +         -- Total participants weight
                (hs.recent_likes * 1.5) +         -- Recent likes weight (high engagement)
                -- Recency bonus (newer habits get slight boost)
                (CASE 
                    WHEN ht.created_at >= NOW() - INTERVAL '30 days' THEN 5.0
                    WHEN ht.created_at >= NOW() - INTERVAL '90 days' THEN 2.0
                    ELSE 0.0
                END)
            ) as trend_score
        FROM habit_stats hs
        JOIN habit_templates ht ON hs.id = ht.id
        WHERE hs.total_captures > 0  -- Only include habits with at least one capture
    ),
    habit_captures AS (
        -- Get top 4 most liked captures for each habit in the last 7 days
        SELECT 
            ht.id as habit_template_id,
            ARRAY_AGG(
                c.image_url ORDER BY 
                    COALESCE((SELECT like_count FROM capture_like_counts WHERE capture_id = c.id), 0) DESC,
                    c.created_at DESC
            ) FILTER (WHERE c.image_url IS NOT NULL) as captures
        FROM habit_templates ht
        JOIN habit_categories hc ON ht.category_id = hc.id
        -- Join captures directly to habit templates
        JOIN captures c ON c.habit_template_id = ht.id 
            AND c.is_public = true 
            AND c.created_at >= NOW() - INTERVAL '7 days'
        WHERE hc.id = category_id_param
        GROUP BY ht.id
    )
    SELECT 
        ts.id,
        ts.name::text,
        ts.category::text,
        ts.category_color::text,
        ts.participants,
        ROUND(COALESCE(ts.avg_streak, 0)::numeric, 1) as avg_streak,
        COALESCE(hd.description, 'A popular habit that many people are building.')::text as description,
        -- Limit to 4 most liked captures
        CASE 
            WHEN array_length(hc.captures, 1) > 4 THEN hc.captures[1:4]
            ELSE hc.captures
        END as captures,
        ts.total_captures
    FROM trending_scores ts
    LEFT JOIN habit_descriptions hd ON ts.id = hd.habit_template_id
    LEFT JOIN habit_captures hc ON ts.id = hc.habit_template_id
    ORDER BY ts.trend_score DESC, ts.recent_likes DESC, ts.participants DESC
    LIMIT 5;  -- Top 5 trending habits for this category
END;
$$ LANGUAGE plpgsql;

-- get_trending_captures_for_habits (reads the reconstructed capture_likes table)
-- Source: fix_trending_captures_function.sql (lines 8-97)
CREATE OR REPLACE FUNCTION get_trending_captures_for_habits()
RETURNS TABLE (
    id uuid,
    capture_id uuid,
    habit_template_id uuid,
    user_id uuid,
    image_url text,
    caption text,
    is_public boolean,
    capture_created_at timestamptz,
    habit_name text,
    habit_category text,
    habit_category_id uuid,
    user_display_name text,
    user_avatar_url text,
    like_count bigint,
    total_captures bigint,
    trend_score numeric
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        gen_random_uuid() as id,  -- Generate a unique ID for the trending capture
        c.id as capture_id,
        c.habit_template_id,
        c.user_id,
        c.image_url,
        c.caption,
        c.is_public,
        c.created_at as capture_created_at,
        ht.name as habit_name,
        COALESCE(ht.category, 'General') as habit_category,
        hc.id as habit_category_id,  -- Add the missing habit_category_id field
        COALESCE(p.display_name, 'Anonymous') as user_display_name,
        p.avatar_url as user_avatar_url,
        COALESCE(l.like_count, 0) as like_count,
        capture_counts.total_captures,
        (COALESCE(l.like_count, 0) * 2 + 
         EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 3600) as trend_score
    FROM captures c
    JOIN habit_templates ht ON c.habit_template_id = ht.id
    LEFT JOIN habit_categories hc ON ht.category_id = hc.id  -- Join to get category ID
    LEFT JOIN profiles p ON c.user_id = p.id
    LEFT JOIN (
        SELECT
            cl.capture_id,
            COUNT(*) as like_count
        FROM capture_likes cl
        WHERE cl.created_at >= NOW() - INTERVAL '7 days'
        GROUP BY cl.capture_id
    ) l ON c.id = l.capture_id
    JOIN (
        SELECT 
            c_counts.habit_template_id,
            COUNT(*) as total_captures
        FROM captures c_counts
        WHERE c_counts.is_public = TRUE 
        AND c_counts.created_at >= NOW() - INTERVAL '7 days'
        GROUP BY c_counts.habit_template_id
    ) capture_counts ON c.habit_template_id = capture_counts.habit_template_id
    WHERE c.is_public = TRUE
    AND c.created_at >= NOW() - INTERVAL '7 days'
    AND (
        -- For habits with less than 4 captures, only show 1 capture
        (capture_counts.total_captures < 4 AND 
         c.id = (
             SELECT c2.id 
             FROM captures c2 
             WHERE c2.habit_template_id = c.habit_template_id 
             AND c2.is_public = TRUE 
             AND c2.created_at >= NOW() - INTERVAL '7 days'
             ORDER BY c2.created_at DESC 
             LIMIT 1
         ))
        OR
        -- For habits with 4+ captures, show up to 4 captures
        (capture_counts.total_captures >= 4 AND 
         c.id IN (
             SELECT c3.id 
             FROM captures c3 
             WHERE c3.habit_template_id = c.habit_template_id 
             AND c3.is_public = TRUE 
             AND c3.created_at >= NOW() - INTERVAL '7 days'
             ORDER BY c3.created_at DESC 
             LIMIT 4
         ))
    )
    ORDER BY c.habit_template_id, c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- get_community_stats (the script's DO block adding profiles.is_active is folded into the table above)
-- Source: create_community_stats_function.sql (lines 18-36)
CREATE OR REPLACE FUNCTION get_community_stats()
RETURNS TABLE (
    active_users bigint,
    total_habits bigint,
    total_captures bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        -- Active users: count of profiles with is_active = true
        (SELECT COUNT(*) FROM profiles WHERE is_active = true) as active_users,
        
        -- Total habits: count of active user_habits
        (SELECT COUNT(*) FROM user_habits WHERE is_active = true) as total_habits,
        
        -- Total captures: count of all captures
        (SELECT COUNT(*) FROM captures) as total_captures;
END;
$$ LANGUAGE plpgsql;

-- get_or_create_habit_description (not called by the client)
-- Source: fix_trending_performance_and_crash.sql (lines 126-178)
CREATE OR REPLACE FUNCTION get_or_create_habit_description(habit_template_id_param UUID)
RETURNS TEXT AS $$
DECLARE
    existing_description TEXT;
    habit_name TEXT;
    habit_category TEXT;
    new_description TEXT;
BEGIN
    -- Check if description already exists
    SELECT description INTO existing_description
    FROM habit_descriptions
    WHERE habit_template_id = habit_template_id_param;
    
    IF existing_description IS NOT NULL THEN
        RETURN existing_description;
    END IF;
    
    -- Get habit template info
    SELECT ht.name, hc.name INTO habit_name, habit_category
    FROM habit_templates ht
    LEFT JOIN habit_categories hc ON ht.category_id = hc.id
    WHERE ht.id = habit_template_id_param;
    
    IF habit_name IS NULL THEN
        RETURN 'Track your progress with this habit';
    END IF;
    
    -- Generate description based on category
    CASE 
        WHEN habit_category = 'Fitness' THEN
            new_description := 'Build strength and improve your fitness with ' || habit_name;
        WHEN habit_category = 'Health' THEN
            new_description := 'Maintain good health and wellness with ' || habit_name;
        WHEN habit_category = 'Learning' THEN
            new_description := 'Expand your knowledge and skills with ' || habit_name;
        WHEN habit_category = 'Wellness' THEN
            new_description := 'Improve your mental and emotional well-being with ' || habit_name;
        WHEN habit_category = 'Nutrition' THEN
            new_description := 'Build healthy eating habits with ' || habit_name;
        WHEN habit_category = 'Productivity' THEN
            new_description := 'Boost your productivity and efficiency with ' || habit_name;
        ELSE
            new_description := 'Track your progress with ' || habit_name;
    END CASE;
    
    -- Insert the new description
    INSERT INTO habit_descriptions (habit_template_id, description, is_ai_generated)
    VALUES (habit_template_id_param, new_description, FALSE)
    ON CONFLICT (habit_template_id) DO NOTHING;
    
    RETURN new_description;
END;
$$ LANGUAGE plpgsql;

-- toggle_capture_reaction (the client toggles reactions with direct table
-- calls instead, but the function is part of the final social schema)
-- Source: social_feed_schema_final.sql (lines 26-67)
CREATE OR REPLACE FUNCTION toggle_capture_reaction(capture_id_param UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
    existing_reaction_id UUID;
    is_liked BOOLEAN;
    reaction_count INTEGER;
BEGIN
    -- Get current user ID
    current_user_id := auth.uid();
    
    -- Check if user already reacted
    SELECT id INTO existing_reaction_id
    FROM capture_reactions
    WHERE capture_id = capture_id_param AND user_id = current_user_id;
    
    IF existing_reaction_id IS NOT NULL THEN
        -- Remove existing reaction
        DELETE FROM capture_reactions WHERE id = existing_reaction_id;
        is_liked := false;
    ELSE
        -- Add new reaction
        INSERT INTO capture_reactions (capture_id, user_id, reaction_type)
        VALUES (capture_id_param, current_user_id, 'fire');
        is_liked := true;
    END IF;
    
    -- Get updated reaction count
    SELECT COUNT(*) INTO reaction_count
    FROM capture_reactions
    WHERE capture_id = capture_id_param;
    
    -- Return result as JSON
    RETURN json_build_object(
        'is_liked', is_liked,
        'reaction_count', reaction_count
    );
END;
$$;

-- get_social_feed_groups
-- social_feed_schema_final.sql and social_feed_schema_corrected.sql have the
-- same modification time. The _final version is used: it is the only one that
-- also defines get_capture_reactions and test_reaction_function, both of which
-- the client calls. It returns 0 / false for the reaction and comment fields;
-- the client fetches reactions separately.
-- Source: social_feed_schema_final.sql (lines 70-160)
CREATE OR REPLACE FUNCTION get_social_feed_groups(limit_param INTEGER DEFAULT 20, offset_param INTEGER DEFAULT 0)
RETURNS TABLE (
    id TEXT,
    user_id UUID,
    habit_template_id UUID,
    habit_name TEXT,
    habit_category TEXT,
    habit_category_color TEXT,
    user_display_name TEXT,
    user_avatar_url TEXT,
    user_username TEXT,
    current_streak INTEGER,
    last_capture_id UUID,
    last_capture_image_url TEXT,
    last_capture_created_at TIMESTAMP WITH TIME ZONE,
    total_captures INTEGER,
    reaction_count INTEGER,
    comment_count INTEGER,
    is_liked_by_current_user BOOLEAN,
    recent_captures JSON
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id UUID;
BEGIN
    -- Get current user ID
    current_user_id := auth.uid();
    
    -- Get real data with recent_captures and filter out current user
    RETURN QUERY
    SELECT 
        uh.user_id || '-' || ht.id as id,
        uh.user_id,
        ht.id as habit_template_id,
        ht.name as habit_name,
        ht.category as habit_category,
        NULL as habit_category_color,
        p.display_name as user_display_name,
        p.avatar_url as user_avatar_url,
        p.display_name as user_username,
        uh.current_streak,
        hc.id as last_capture_id,
        hc.image_url as last_capture_image_url,
        hc.created_at as last_capture_created_at,
        (SELECT COUNT(*)::INTEGER FROM captures c WHERE c.user_habit_id = uh.id AND c.is_public = true) as total_captures,
        0 as reaction_count,
        0 as comment_count,
        false as is_liked_by_current_user,
        (
            SELECT COALESCE(
                json_agg(
                    json_build_object(
                        'id', c2.id,
                        'image_url', c2.image_url,
                        'caption', c2.caption,
                        'created_at', c2.created_at,
                        'reaction_count', 0,
                        'comment_count', 0,
                        'is_liked_by_current_user', false,
                        'reaction_users', '[]'::json
                    )
                ),
                '[]'::json
            )
            FROM (
                SELECT c2.id, c2.image_url, c2.caption, c2.created_at
                FROM captures c2 
                WHERE c2.user_habit_id = uh.id 
                AND c2.is_public = true
                ORDER BY c2.created_at DESC
                LIMIT 5
            ) c2
        ) as recent_captures
    FROM user_habits uh
    JOIN habit_templates ht ON uh.habit_template_id = ht.id
    JOIN profiles p ON uh.user_id = p.id
    JOIN captures hc ON hc.user_habit_id = uh.id AND hc.is_public = true
    WHERE uh.is_active = true
    AND uh.user_id != current_user_id  -- Filter out current user's posts
    AND hc.created_at = (
        SELECT MAX(c2.created_at) 
        FROM captures c2 
        WHERE c2.user_habit_id = uh.id AND c2.is_public = true
    )
    ORDER BY hc.created_at DESC
    LIMIT limit_param
    OFFSET offset_param;
END;
$$;

-- get_capture_reactions
-- Source: social_feed_schema_final.sql (lines 278-299)
CREATE OR REPLACE FUNCTION get_capture_reactions(capture_id_param UUID)
RETURNS TABLE (
    user_id UUID,
    user_avatar_url TEXT,
    user_display_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cr.user_id,
        p.avatar_url,
        p.display_name
    FROM capture_reactions cr
    JOIN profiles p ON cr.user_id = p.id
    WHERE cr.capture_id = capture_id_param
    ORDER BY cr.created_at DESC
    LIMIT 4;
END;
$$;

-- test_reaction_function (a connectivity probe, kept because the client calls it)
-- Source: social_feed_schema_final.sql (lines 265-275)
CREATE OR REPLACE FUNCTION test_reaction_function()
RETURNS JSON
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN json_build_object(
        'test', true,
        'message', 'Function is working'
    );
END;
$$;

-- Source: social_feed_schema_final.sql (lines 224-225)
GRANT EXECUTE ON FUNCTION toggle_capture_reaction(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_social_feed_groups(INTEGER, INTEGER) TO authenticated;

-- get_captures_with_metadata
-- Source: performance_optimizations.sql (lines 190-225)
CREATE OR REPLACE FUNCTION get_captures_with_metadata(
    user_id_param UUID,
    since_date TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
    capture_id UUID,
    user_habit_id UUID,
    image_url TEXT,
    caption TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    is_public BOOLEAN,
    habit_name TEXT,
    habit_category TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id as capture_id,
        c.user_habit_id,
        c.image_url,
        c.caption,
        c.created_at,
        c.is_public,
        ht.name as habit_name,
        ht.category as habit_category
    FROM captures c
    JOIN user_habits uh ON c.user_habit_id = uh.id
    JOIN habit_templates ht ON uh.habit_template_id = ht.id
    WHERE c.user_id = user_id_param
    AND c.created_at >= since_date
    ORDER BY c.created_at DESC;
END;
$$;

-- get_user_progress_grid_data
-- Source: progress_grid_view.sql (lines 39-99)
CREATE OR REPLACE FUNCTION get_user_progress_grid_data(
    p_user_id UUID,
    p_since_date TIMESTAMPTZ
)
RETURNS TABLE (
    user_habit_id UUID,
    user_id UUID,
    habit_template_id UUID,
    current_streak INTEGER,
    is_active BOOLEAN,
    user_habit_created_at TIMESTAMPTZ,
    user_habit_updated_at TIMESTAMPTZ,
    habit_name TEXT,
    habit_description TEXT,
    habit_category TEXT,
    target_frequency TEXT,
    target_count INTEGER,
    template_is_active BOOLEAN,
    template_created_at TIMESTAMPTZ,
    template_updated_at TIMESTAMPTZ,
    capture_id UUID,
    image_url TEXT,
    caption TEXT,
    is_public BOOLEAN,
    capture_created_at TIMESTAMPTZ,
    capture_updated_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uh.id as user_habit_id,
        uh.user_id,
        uh.habit_template_id,
        uh.current_streak,
        uh.is_active,
        uh.created_at as user_habit_created_at,
        uh.updated_at as user_habit_updated_at,
        ht.name as habit_name,
        ht.description as habit_description,
        ht.category as habit_category,
        ht.target_frequency,
        ht.target_count,
        ht.is_active as template_is_active,
        ht.created_at as template_created_at,
        ht.updated_at as template_updated_at,
        c.id as capture_id,
        c.image_url,
        c.caption,
        c.is_public,
        c.created_at as capture_created_at,
        c.updated_at as capture_updated_at
    FROM user_habits uh
    JOIN habit_templates ht ON uh.habit_template_id = ht.id
    LEFT JOIN captures c ON uh.id = c.user_habit_id 
        AND c.created_at >= p_since_date
    WHERE uh.user_id = p_user_id 
        AND uh.is_active = true
        AND ht.is_active = true
    ORDER BY uh.created_at ASC, c.created_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Source: progress_grid_view.sql (lines 103-103)
GRANT EXECUTE ON FUNCTION get_user_progress_grid_data TO authenticated;

-- -----------------------------------------------------------------------------
-- get_user_habits_with_progress
-- Source: performance_optimizations.sql (lines 149-187), ADJUSTED.
-- The original cannot run against the schema the rest of the scripts and the
-- client describe, so three lines were changed. The originals are kept in
-- trailing comments:
--   * uh.target_frequency / uh.target_count: every other source puts these
--     columns on habit_templates, not user_habits.
--   * the two COUNT(*) subqueries return BIGINT but the function declares
--     INTEGER, which plpgsql rejects at run time.
-- NOTE: habit_templates.target_count is nullable while the client's
--   HabitProgressData decodes target_count as a non-optional Int.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_user_habits_with_progress(
    user_id_param UUID,
    since_date TIMESTAMP WITH TIME ZONE
)
RETURNS TABLE (
    habit_id UUID,
    habit_name TEXT,
    habit_category TEXT,
    target_frequency TEXT,
    target_count INTEGER,
    current_streak INTEGER,
    total_captures INTEGER,
    captures_since_date INTEGER,
    last_capture_date TIMESTAMP WITH TIME ZONE,
    habit_template_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uh.id as habit_id,
        ht.name as habit_name,
        ht.category as habit_category,
        ht.target_frequency,  -- original: uh.target_frequency,
        ht.target_count,      -- original: uh.target_count,
        uh.current_streak,
        (SELECT COUNT(*)::INTEGER FROM captures c WHERE c.user_habit_id = uh.id) as total_captures,  -- original: COUNT(*)
        (SELECT COUNT(*)::INTEGER FROM captures c WHERE c.user_habit_id = uh.id AND c.created_at >= since_date) as captures_since_date,  -- original: COUNT(*)
        (SELECT MAX(created_at) FROM captures c WHERE c.user_habit_id = uh.id) as last_capture_date,
        uh.habit_template_id
    FROM user_habits uh
    JOIN habit_templates ht ON uh.habit_template_id = ht.id
    WHERE uh.user_id = user_id_param
    AND uh.is_active = true
    ORDER BY uh.created_at DESC;
END;
$$;

-- Source: performance_optimizations.sql (lines 280-281)
GRANT EXECUTE ON FUNCTION get_user_habits_with_progress(UUID, TIMESTAMP WITH TIME ZONE) TO authenticated;
GRANT EXECUTE ON FUNCTION get_captures_with_metadata(UUID, TIMESTAMP WITH TIME ZONE) TO authenticated;

-- -----------------------------------------------------------------------------
-- toggle_capture_like, is_capture_liked_by_user
-- RECONSTRUCTED: not present in the original scripts. DATABASE_USAGE_ANALYSIS.md
--   lists both as part of the "social like system" on capture_likes, and
--   SupabaseManager calls them with (capture_uuid, user_uuid) and treats the
--   result as a boolean (true = like added / is liked). Parameter names come
--   from the client; the bodies are a best guess.
-- NOTE: the client decodes the response as [String: Bool] keyed by the function
--   name, which is not what PostgREST returns for a scalar boolean function,
--   so the original return shape may have differed.
-- They run as SECURITY INVOKER so the capture_likes RLS policies stop a caller
-- from liking on behalf of another user.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION toggle_capture_like(capture_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM capture_likes cl
        WHERE cl.capture_id = capture_uuid AND cl.user_id = user_uuid
    ) THEN
        DELETE FROM capture_likes cl
        WHERE cl.capture_id = capture_uuid AND cl.user_id = user_uuid;
        RETURN FALSE;
    ELSE
        INSERT INTO capture_likes (capture_id, user_id)
        VALUES (capture_uuid, user_uuid);
        RETURN TRUE;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION is_capture_liked_by_user(capture_uuid UUID, user_uuid UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM capture_likes cl
        WHERE cl.capture_id = capture_uuid AND cl.user_id = user_uuid
    );
$$;

GRANT EXECUTE ON FUNCTION toggle_capture_like(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION is_capture_liked_by_user(UUID, UUID) TO authenticated;

-- -----------------------------------------------------------------------------
-- NOT INCLUDED: add_capture_to_trending(capture_uuid, user_uuid) and
-- remove_capture_from_trending(capture_uuid). The client declares wrappers for
-- them (expecting [String] and [Bool] results) but no script or note defines
-- or describes them, and nothing in the client calls the wrappers.
-- -----------------------------------------------------------------------------


-- =============================================================================
-- 8. SEED DATA
-- =============================================================================

-- Habit categories
-- Source: create_habit_categories_system.sql (lines 19-30)
INSERT INTO habit_categories (name, description, color, icon, sort_order) VALUES
('Fitness', 'Physical exercise and movement habits', 'green', 'dumbbell', 1),
('Wellness', 'Mental health and mindfulness habits', 'purple', 'heart', 2),
('Learning', 'Educational and skill-building habits', 'orange', 'book', 3),
('Nutrition', 'Diet and eating habits', 'mint', 'apple', 4),
('Productivity', 'Work and efficiency habits', 'blue', 'briefcase', 5),
('Health', 'General health and medical habits', 'pink', 'cross', 6),
('Social', 'Relationship and communication habits', 'yellow', 'users', 7),
('Finance', 'Money and financial habits', 'red', 'dollar-sign', 8),
('Sleep', 'Sleep and rest habits', 'indigo', 'moon', 9),
('Creativity', 'Art and creative expression habits', 'teal', 'palette', 10)
ON CONFLICT (name) DO NOTHING;

-- Source: create_habit_categories_system.sql (lines 335-337)
INSERT INTO habit_categories (name, description, color, icon, sort_order) 
VALUES ('General', 'General habits and activities', 'gray', 'circle', 99)
ON CONFLICT (name) DO NOTHING;

-- NOTE: no seed rows for habit_templates or available_habits exist in the
-- scripts or notes. The Discovery and habit-picker screens will be empty until
-- some are inserted (remember to set category_id, see the habit_templates note).
