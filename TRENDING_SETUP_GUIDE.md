# Trending System Setup Guide

This guide will help you set up the complete trending system for your Capture app with real database views, functions, and storage buckets.

## 📋 Overview

The trending system consists of:
1. **trending_habits_view** - Calculates trending metrics for habits with engagement
2. **get_trending_captures_for_habits()** - RPC function for trending captures
3. **captures_public** storage bucket - Uses existing public captures
4. **trending_images** table - Optional thumbnail metadata
5. **Updated Swift code** - Uses real trending data with fallbacks

## 🚀 Step 1: Run the Database Setup

1. Go to your Supabase Dashboard
2. Navigate to **SQL Editor**
3. Run the complete setup script:

```sql
-- Copy and paste the contents of setup_trending_complete.sql
```

This will create:
- ✅ trending_habits_view
- ✅ get_trending_captures_for_habits() function
- ✅ trending_images table
- ✅ Automatic thumbnail trigger
- ✅ RLS policies

## 🗂️ Step 2: Storage Bucket (Already Exists!)

✅ **No setup required!** The system uses your existing `captures_public` storage bucket.

Your public captures are already stored in the `captures_public` bucket, so the trending system will automatically use those images.

## 📱 Step 3: Swift Code Updates

The Swift code has been updated to:
- ✅ Try real trending_habits_view first
- ✅ Fall back to available_habits if view doesn't exist
- ✅ Try get_trending_captures_for_habits() RPC function
- ✅ Fall back to recent captures if function doesn't exist
- ✅ Enhanced logging for debugging

## 🔧 How It Works

### Trending Habits Calculation

The `trending_habits_view` calculates trending scores based on:
- **Recent captures** (last 7 days) - Weight: 2.0
- **New participants** (last 7 days) - Weight: 3.0  
- **Total participants** - Weight: 1.0
- **Average streak** - Weight: 0.5
- **Recent likes** (last 7 days) - Weight: 1.5 (high engagement)
- **Recency bonus** for newer habits

### Trending Captures Function

The `get_trending_captures_for_habits()` function:
- Gets top 20 trending habits by score
- Fetches most liked captures (last 7 days)
- Includes user metadata (display name, avatar)
- Includes engagement metrics (like counts)
- Returns up to 100 trending captures ordered by likes

### Automatic Thumbnails

When captures are made public:
1. Trigger automatically creates `trending_images` entry (optional)
2. Uses existing `captures_public` bucket for images
3. Shows most liked captures from the last 7 days
4. Thumbnail URLs are cached for fast loading

## 🧪 Testing the Setup

1. **Build and run** your iOS app
2. **Check logs** for trending data loading:
   ```
   [SupabaseManager] getTrendingHabits: fetching trending habits from trending_habits_view
   [SupabaseManager] getTrendingCapturesForHabits: fetching trending captures from RPC function
   ```
3. **Navigate to Discovery → Trending** to see results
4. **Create public captures** to populate trending data

## 🔍 Troubleshooting

### If trending view fails:
- App automatically falls back to available_habits
- Check Supabase logs for SQL errors
- Verify all referenced tables exist

### If RPC function fails:
- App automatically falls back to recent captures
- Check function permissions in Supabase
- Verify function was created successfully

### If images don't load:
- Check trending-images bucket exists and is public
- Verify RLS policies allow public read access
- Check image URLs in database

## 📊 Expected Results

With proper setup, you should see:
- **Real trending habits** with actual engagement metrics
- **Image grids** showing up to 4 recent captures per habit
- **Fast thumbnail loading** with caching
- **Smooth fallback** behavior if database isn't ready

## 🔄 Migration Path

The system is designed for **zero-downtime migration**:
1. ✅ Current fallback system works with existing data
2. ✅ Run database setup when ready
3. ✅ App automatically switches to real trending data
4. ✅ Fallbacks ensure no breaking changes

## 📈 Performance Features

- **Efficient queries** with proper indexing
- **Cached thumbnails** for fast loading  
- **Limited result sets** (50 habits, 100 captures)
- **Recent data focus** (7-30 day windows)
- **Automatic cleanup** with cascading deletes

---

## 🎯 Next Steps

1. **Run the SQL setup** in Supabase Dashboard
2. **Test the app** to see trending data
3. **Add some public captures** to populate trending content
4. **Monitor logs** to ensure everything works

**No storage bucket setup required!** 🎉

Your trending system is now ready for real engagement-based trending content! 🚀
