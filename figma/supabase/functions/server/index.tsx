import { Hono } from 'npm:hono';
import { cors } from 'npm:hono/cors';
import { logger } from 'npm:hono/logger';
import { createClient } from 'npm:@supabase/supabase-js@2';
import * as kv from './kv_store.tsx';

const app = new Hono();

// CORS and logging middleware
app.use('*', cors({
  origin: '*',
  allowHeaders: ['*'],
  allowMethods: ['*'],
}));
app.use('*', logger(console.log));

// Initialize Supabase client - Use anon key for user token validation
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!,
);

// Initialize admin client for admin operations (user creation, storage)
const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

// Create storage buckets on startup
const initializeStorage = async () => {
  try {
    const bucketName = 'make-22c67a59-habit-photos';
    const { data: buckets } = await supabaseAdmin.storage.listBuckets();
    const bucketExists = buckets?.some(bucket => bucket.name === bucketName);
    
    if (!bucketExists) {
      await supabaseAdmin.storage.createBucket(bucketName, { public: false });
      console.log(`Created storage bucket: ${bucketName}`);
    }
  } catch (error) {
    console.log('Storage initialization error:', error);
  }
};

// FIXED: Helper function to verify user authorization - Use exact same approach as working debug test
const getAuthorizedUser = async (request: Request) => {
  console.log('=== GETTING AUTHORIZED USER ===');
  
  try {
    const authHeader = request.headers.get('Authorization');
    console.log('Auth header exists:', !!authHeader);
    
    if (!authHeader) {
      console.log('❌ No auth header found');
      return null;
    }
    
    if (!authHeader.startsWith('Bearer ')) {
      console.log('❌ Auth header does not start with Bearer');
      return null;
    }
    
    const token = authHeader.split(' ')[1];
    if (!token) {
      console.log('❌ No token found in auth header');
      return null;
    }

    console.log('Token length:', token.length);
    console.log('Token preview:', token.substring(0, 20) + '...');
    
    // Check if this is the anon key (which shouldn't be used for user auth)
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    if (token === anonKey) {
      console.log('❌ Received anon key instead of user access token');
      return null;
    }
    
    console.log('Token is not anon key ✓');
    
    // Use the EXACT same approach that works in debug tests
    console.log('Validating token with supabase.auth.getUser(token)...');
    const { data: userData, error } = await supabase.auth.getUser(token);
    
    if (error) {
      console.log('❌ Token validation error:', error.message);
      return null;
    }
    
    if (!userData?.user?.id) {
      console.log('❌ No user found for token');
      return null;
    }
    
    console.log('✅ Auth success! User ID:', userData.user.id);
    console.log('✅ User email:', userData.user.email);
    return userData.user;
    
  } catch (error) {
    console.log('❌ Exception during auth:', error);
    return null;
  }
};

// Enhanced debug endpoint
app.get('/make-server-22c67a59/debug-auth-comprehensive', async (c) => {
  console.log('=== COMPREHENSIVE AUTH DEBUG START ===');
  
  try {
    const authHeader = c.req.header('Authorization');
    console.log('Auth header exists:', !!authHeader);
    
    if (!authHeader) {
      return c.json({ step: 'no-header', error: 'No auth header' });
    }
    
    const token = authHeader.split(' ')[1];
    console.log('Token length:', token?.length);
    
    if (!token) {
      return c.json({ step: 'no-token', error: 'No token in header' });
    }
    
    // Test 1: Try with regular client (this approach works according to debug)
    console.log('Test 1: Regular supabase client...');
    const { data: userData1, error: error1 } = await supabase.auth.getUser(token);
    console.log('Regular client result:', { hasUser: !!userData1?.user, error: error1?.message });
    
    // Test 2: Try with user-specific client
    console.log('Test 2: User-specific supabase client...');
    const userSupabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      {
        global: {
          headers: {
            Authorization: `Bearer ${token}`
          }
        }
      }
    );
    
    const { data: userData2, error: error2 } = await userSupabase.auth.getUser();
    console.log('User-specific client result:', { hasUser: !!userData2?.user, error: error2?.message });
    
    // Test 3: Try actual auth flow - should now work!
    console.log('Test 3: Full auth validation...');
    const user = await getAuthorizedUser(c.req.raw);
    console.log('Full auth result:', !!user);
    if (user) {
      console.log('✅ getAuthorizedUser returned user:', user.id);
    } else {
      console.log('❌ getAuthorizedUser returned null');
    }
    
    return c.json({
      success: true,
      tests: {
        regularClient: { hasUser: !!userData1?.user, error: error1?.message },
        userSpecificClient: { hasUser: !!userData2?.user, error: error2?.message },
        fullAuthFlow: { hasUser: !!user }
      },
      tokenLength: token.length,
      tokenPreview: token.substring(0, 20) + '...'
    });
    
  } catch (error) {
    console.log('Debug error:', error);
    return c.json({ success: false, error: error.toString() });
  }
});

// Auth Routes
app.post('/make-server-22c67a59/auth/signup', async (c) => {
  try {
    const { email, password, name } = await c.req.json();
    console.log('Signup request for email:', email);
    
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      user_metadata: { name },
      email_confirm: true
    });
    
    if (error) {
      console.log('Signup error from Supabase:', error);
      return c.json({ error: error.message }, 400);
    }
    
    console.log('User created successfully:', data.user.id);
    
    // Create user profile in KV store
    try {
      await kv.set(`user:${data.user.id}`, {
        id: data.user.id,
        email: data.user.email,
        name,
        createdAt: new Date().toISOString(),
        totalHabits: 0,
        totalStreak: 0,
        followers: [],
        following: []
      });
      console.log('User profile created in KV store');
    } catch (kvError) {
      console.log('Error creating user profile in KV store:', kvError);
    }
    
    return c.json({ user: data.user });
  } catch (error) {
    console.log('Signup error during user creation:', error);
    return c.json({ error: 'Failed to create user' }, 500);
  }
});

// Habits Routes - Now should work!
app.get('/make-server-22c67a59/habits', async (c) => {
  console.log('=== GET HABITS REQUEST ===');
  try {
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) {
      console.log('❌ Unauthorized request to /habits');
      return c.json({ error: 'Unauthorized' }, 401);
    }
    
    console.log('✅ Fetching habits for user:', user.id);
    const habits = await kv.getByPrefix(`habit:${user.id}:`);
    console.log('Found habits count:', habits?.length || 0);
    
    // Ensure we return an array
    const habitsArray = Array.isArray(habits) ? habits : [];
    
    // Add some sample habits for testing if none exist
    if (habitsArray.length === 0) {
      console.log('No habits found, creating sample habits...');
      
      const sampleHabits = [
        {
          id: 'sample-1',
          userId: user.id,
          name: 'Morning Exercise',
          category: 'Fitness',
          description: 'Start the day with energy',
          streak: 5,
          completedToday: false,
          weeklyProgress: 71,
          createdAt: new Date().toISOString(),
          lastCompletedAt: null,
          photos: [],
          dailyCompletions: {}
        },
        {
          id: 'sample-2',
          userId: user.id,
          name: 'Read for 30 minutes',
          category: 'Learning',
          description: 'Expand knowledge daily',
          streak: 12,
          completedToday: true,
          weeklyProgress: 85,
          createdAt: new Date().toISOString(),
          lastCompletedAt: new Date().toISOString(),
          photos: [],
          dailyCompletions: {
            [new Date().toISOString().split('T')[0]]: {
              completed: true,
              timestamp: new Date().toISOString()
            }
          }
        }
      ];
      
      // Save sample habits
      for (const habit of sampleHabits) {
        await kv.set(`habit:${user.id}:${habit.id}`, habit);
      }
      
      return c.json({ habits: sampleHabits });
    }
    
    return c.json({ habits: habitsArray });
  } catch (error) {
    console.log('❌ Error fetching habits:', error);
    return c.json({ error: 'Failed to fetch habits' }, 500);
  }
});

app.post('/make-server-22c67a59/habits', async (c) => {
  try {
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    
    const { name, category, description } = await c.req.json();
    const habitId = `${Date.now()}-${Math.random().toString(36).substring(7)}`;
    
    const habit = {
      id: habitId,
      userId: user.id,
      name,
      category,
      description,
      streak: 0,
      completedToday: false,
      weeklyProgress: 0,
      createdAt: new Date().toISOString(),
      lastCompletedAt: null,
      photos: [],
      dailyCompletions: {}
    };
    
    await kv.set(`habit:${user.id}:${habitId}`, habit);
    
    // Update user's total habits count
    const userProfile = await kv.get(`user:${user.id}`);
    if (userProfile) {
      userProfile.totalHabits += 1;
      await kv.set(`user:${user.id}`, userProfile);
    }
    
    return c.json({ habit });
  } catch (error) {
    console.log('Error creating habit:', error);
    return c.json({ error: 'Failed to create habit' }, 500);
  }
});

app.post('/make-server-22c67a59/habits/:habitId/complete', async (c) => {
  try {
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    
    const habitId = c.req.param('habitId');
    const { photoUrl } = await c.req.json();
    
    const habit = await kv.get(`habit:${user.id}:${habitId}`);
    if (!habit) return c.json({ error: 'Habit not found' }, 404);
    
    const today = new Date().toISOString().split('T')[0];
    const lastCompleted = habit.lastCompletedAt?.split('T')[0];
    
    // Update habit completion
    const isConsecutive = lastCompleted === new Date(Date.now() - 86400000).toISOString().split('T')[0];
    
    habit.streak = isConsecutive ? habit.streak + 1 : 1;
    habit.completedToday = true;
    habit.lastCompletedAt = new Date().toISOString();
    habit.weeklyProgress = Math.min(100, habit.weeklyProgress + 14.3);
    
    // Track daily completion for grid visualization
    if (!habit.dailyCompletions) habit.dailyCompletions = {};
    habit.dailyCompletions[today] = {
      completed: true,
      photoUrl,
      timestamp: new Date().toISOString()
    };
    
    if (photoUrl) {
      habit.photos.push({
        url: photoUrl,
        takenAt: new Date().toISOString()
      });
    }
    
    await kv.set(`habit:${user.id}:${habitId}`, habit);
    
    // Create social feed post
    const feedPost = {
      id: `${Date.now()}-${Math.random().toString(36).substring(7)}`,
      userId: user.id,
      habitId: habitId,
      habitName: habit.name,
      habitCategory: habit.category,
      habitStreak: habit.streak,
      photoUrl,
      createdAt: new Date().toISOString(),
      likes: [],
      comments: []
    };
    
    await kv.set(`post:${feedPost.id}`, feedPost);
    
    return c.json({ habit, post: feedPost });
  } catch (error) {
    console.log('Error completing habit:', error);
    return c.json({ error: 'Failed to complete habit' }, 500);
  }
});

// Photo Upload Route
app.post('/make-server-22c67a59/upload-photo', async (c) => {
  try {
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    
    const formData = await c.req.formData();
    const file = formData.get('photo') as File;
    
    if (!file) return c.json({ error: 'No photo provided' }, 400);
    
    const fileName = `${user.id}/${Date.now()}-${file.name}`;
    const bucketName = 'make-22c67a59-habit-photos';
    
    const { data, error } = await supabaseAdmin.storage
      .from(bucketName)
      .upload(fileName, file);
    
    if (error) {
      console.log('Photo upload error:', error);
      return c.json({ error: 'Failed to upload photo' }, 500);
    }
    
    // Get signed URL for the uploaded photo
    const { data: urlData } = await supabaseAdmin.storage
      .from(bucketName)
      .createSignedUrl(fileName, 60 * 60 * 24 * 30); // 30 days
    
    return c.json({ 
      photoUrl: urlData?.signedUrl,
      fileName: data.path 
    });
  } catch (error) {
    console.log('Photo upload processing error:', error);
    return c.json({ error: 'Failed to process photo upload' }, 500);
  }
});

// Social Feed Routes - Now should work!
app.get('/make-server-22c67a59/feed', async (c) => {
  try {
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    
    // Get all posts for now (in real app, would filter by following)
    const posts = await kv.getByPrefix('post:');
    
    // If no posts exist, create some sample posts
    if (!posts || posts.length === 0) {
      const samplePosts = [
        {
          id: 'sample-post-1',
          userId: user.id,
          habitId: 'sample-1',
          habitName: 'Morning Exercise',
          habitCategory: 'Fitness',
          habitStreak: 5,
          photoUrl: 'https://images.unsplash.com/photo-1518310383802-640c2de311b2?w=300&h=300&fit=crop',
          createdAt: new Date(Date.now() - 3600000).toISOString(), // 1 hour ago
          likes: [],
          comments: []
        },
        {
          id: 'sample-post-2',
          userId: user.id,
          habitId: 'sample-2',
          habitName: 'Read for 30 minutes',
          habitCategory: 'Learning',
          habitStreak: 12,
          photoUrl: null,
          createdAt: new Date(Date.now() - 7200000).toISOString(), // 2 hours ago
          likes: [],
          comments: []
        }
      ];
      
      // Save sample posts
      for (const post of samplePosts) {
        await kv.set(`post:${post.id}`, post);
      }
      
      // Return enriched sample posts
      const enrichedSamplePosts = samplePosts.map(post => ({
        ...post,
        user: {
          name: user.user_metadata?.name || user.email?.split('@')[0] || 'User',
          username: user.email?.split('@')[0] || 'user',
          avatar: `https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100&h=100&fit=crop&crop=face`
        }
      }));
      
      return c.json({ posts: enrichedSamplePosts });
    }
    
    // Enrich posts with user data
    const enrichedPosts = await Promise.all(
      posts.map(async (post) => {
        const postUser = await kv.get(`user:${post.userId}`);
        return {
          ...post,
          user: postUser ? {
            name: postUser.name,
            username: postUser.email.split('@')[0],
            avatar: `https://images.unsplash.com/photo-${Math.abs(postUser.id.hashCode() % 1000000000)}?w=100&h=100&fit=crop&crop=face`
          } : null
        };
      })
    );
    
    // Sort by creation date (newest first)
    enrichedPosts.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    
    return c.json({ posts: enrichedPosts });
  } catch (error) {
    console.log('Error fetching feed:', error);
    return c.json({ error: 'Failed to fetch feed' }, 500);
  }
});

app.post('/make-server-22c67a59/posts/:postId/like', async (c) => {
  try {
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    
    const postId = c.req.param('postId');
    const post = await kv.get(`post:${postId}`);
    
    if (!post) return c.json({ error: 'Post not found' }, 404);
    
    const likes = post.likes || [];
    const isLiked = likes.includes(user.id);
    
    if (isLiked) {
      post.likes = likes.filter(id => id !== user.id);
    } else {
      post.likes = [...likes, user.id];
    }
    
    await kv.set(`post:${postId}`, post);
    
    return c.json({ 
      liked: !isLiked, 
      likesCount: post.likes.length 
    });
  } catch (error) {
    console.log('Error toggling like:', error);
    return c.json({ error: 'Failed to toggle like' }, 500);
  }
});

// Discovery Routes - PUBLIC ENDPOINT (no auth required)
app.get('/make-server-22c67a59/discover/habits', async (c) => {
  try {
    console.log('🔍 Discovery: Fetching popular habits...');
    
    // Get all habits globally (not user-specific)
    const habits = await kv.getByPrefix('habit:');
    console.log('🔍 Discovery: Found habits in database:', habits?.length || 0);
    
    const habitStats = {};
    
    if (habits && habits.length > 0) {
      habits.forEach(habit => {
        const key = `${habit.name}|${habit.category}`;
        if (!habitStats[key]) {
          habitStats[key] = {
            name: habit.name,
            category: habit.category,
            participants: 0,
            totalStreak: 0,
            captures: []
          };
        }
        habitStats[key].participants += 1;
        habitStats[key].totalStreak += habit.streak;
        
        // Collect photo captures from this habit
        if (habit.photos && habit.photos.length > 0) {
          habitStats[key].captures.push(...habit.photos.map(photo => photo.url));
        }
      });
    }
    
    const popularHabits = Object.values(habitStats)
      .sort((a, b) => b.participants - a.participants)
      .slice(0, 10)
      .map(habit => ({
        ...habit,
        description: `Join ${habit.participants} others in this habit`,
        image: `https://images.unsplash.com/photo-${Math.abs(habit.name.hashCode() % 1000000000)}?w=300&h=200&fit=crop`,
        // Shuffle captures and limit to reasonable amount
        captures: habit.captures.sort(() => 0.5 - Math.random()).slice(0, 12)
      }));
    
    console.log('🔍 Discovery: Generated popular habits:', popularHabits.length);
    
    // Always return sample popular habits with test photo grids for testing
    // Later we can change this to: if (popularHabits.length === 0)
    if (true) {
      console.log('🔍 Discovery: Returning test data with photo grids...');
      
      // Calculate community stats from test data with more realistic capture numbers
      const testHabits = [
          {
            name: 'Morning Workout',
            category: 'Fitness',
            participants: 1250,
            totalStreak: 5000,
            description: 'Join 1250 others in this habit',
            image: 'https://images.unsplash.com/photo-1518310383802-640c2de311b2?w=300&h=200&fit=crop',
            captures: [
              'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1538805060514-97d9cc17730c?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1605296867304-46d5465a13f1?w=150&h=150&fit=crop'
            ],
            totalCaptureCount: 8742 // Representing thousands of workout photos
          },
          {
            name: 'Daily Reading',
            category: 'Learning',
            participants: 890,
            totalStreak: 3200,
            description: 'Join 890 others in this habit',
            image: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=200&fit=crop',
            captures: [
              'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1592496431122-2349e0fbc666?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1535905557558-afc4877cdf3f?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?w=150&h=150&fit=crop'
            ],
            totalCaptureCount: 6234
          },
          {
            name: 'Meditation',
            category: 'Wellness',
            participants: 765,
            totalStreak: 2800,
            description: 'Join 765 others in this habit',
            image: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300&h=200&fit=crop',
            captures: [
              'https://images.unsplash.com/photo-1545389336-cf090694435e?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1593811167562-9cef47bfc4d7?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1588286840104-8957b019727f?w=150&h=150&fit=crop'
            ],
            totalCaptureCount: 5123
          },
          {
            name: 'Healthy Cooking',
            category: 'Nutrition',
            participants: 654,
            totalStreak: 2100,
            description: 'Join 654 others in this habit',
            image: 'https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=300&h=200&fit=crop',
            captures: [
              'https://images.unsplash.com/photo-1547573854-74d2a71d0826?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=150&h=150&fit=crop'
            ],
            totalCaptureCount: 4890
          },
          {
            name: 'Daily Walk',
            category: 'Health',
            participants: 543,
            totalStreak: 1800,
            description: 'Join 543 others in this habit',
            image: 'https://images.unsplash.com/photo-1594736797933-d0a9ba3a5d7d?w=300&h=200&fit=crop',
            captures: [
              'https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1545558014-8692077e9b5c?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1544966503-7cc5ac882d5e?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=150&h=150&fit=crop'
            ],
            totalCaptureCount: 3567
          },
          {
            name: 'Journaling',
            category: 'Productivity',
            participants: 432,
            totalStreak: 1500,
            description: 'Join 432 others in this habit',
            image: 'https://images.unsplash.com/photo-1455390582262-044cdead277a?w=300&h=200&fit=crop',
            captures: [
              'https://images.unsplash.com/photo-1455390582262-044cdead277a?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1470324161839-ce2bb6fa6bc3?w=150&h=150&fit=crop',
              'https://images.unsplash.com/photo-1504805572947-34fad45aed93?w=150&h=150&fit=crop'
            ],
            totalCaptureCount: 2156
          },
          {
            name: 'Video Calls with Friends',
            category: 'Social',
            participants: 321,
            totalStreak: 1200,
            description: 'Join 321 others in this habit',
            image: 'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=300&h=200&fit=crop',
            captures: [
              'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?w=150&h=150&fit=crop'
            ],
            totalCaptureCount: 1834
          }
        ];
      
      // Calculate community stats - use realistic totals
      const totalActiveUsers = testHabits.reduce((sum, habit) => sum + habit.participants, 0);
      
      // For test data, simulate a much larger number of total habits tracked globally
      // This represents all habits created by all users, not just trending ones
      const totalHabitsTracked = 28749; // Realistic total habits across all users globally
      
      const totalCaptures = testHabits.reduce((sum, habit) => sum + (habit.totalCaptureCount || 0), 0);
      
      return c.json({
        habits: testHabits,
        communityStats: {
          activeUsers: totalActiveUsers,
          totalHabits: totalHabitsTracked, // Total habits tracked globally
          totalCaptures: totalCaptures
        }
      });
    }
    
    // Calculate community stats from real data
    const totalActiveUsers = popularHabits.reduce((sum, habit) => sum + habit.participants, 0);
    
    // For total habits, count ALL habits in the system, not just popular ones
    const allHabitsCount = habits.length; // This is the total habits tracked globally
    
    const totalCaptures = popularHabits.reduce((sum, habit) => sum + (habit.captures?.length || 0), 0);
    
    return c.json({ 
      habits: popularHabits,
      communityStats: {
        activeUsers: totalActiveUsers,
        totalHabits: allHabitsCount, // Total habits tracked across all users
        totalCaptures: totalCaptures
      }
    });
  } catch (error) {
    console.log('Error fetching popular habits:', error);
    return c.json({ error: 'Failed to fetch popular habits' }, 500);
  }
});

// Health Check Route (no auth required)
app.get('/make-server-22c67a59/health', async (c) => {
  return c.json({ 
    status: 'ok',
    timestamp: new Date().toISOString(),
    server: 'make-server-22c67a59'
  });
});

// Debug Route (no auth required)
app.get('/make-server-22c67a59/debug', async (c) => {
  try {
    const authHeader = c.req.header('Authorization');
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    
    return c.json({ 
      hasAuthHeader: !!authHeader,
      authHeaderPreview: authHeader?.substring(0, 50) + '...',
      authHeaderIsAnonKey: authHeader?.includes(anonKey || ''),
      serverTime: new Date().toISOString(),
      envVarsAvailable: {
        SUPABASE_URL: !!supabaseUrl,
        SUPABASE_ANON_KEY: !!anonKey,
        SUPABASE_SERVICE_ROLE_KEY: !!serviceKey
      },
      urlMatches: supabaseUrl?.includes('supabase.co'),
      keysAreDifferent: anonKey !== serviceKey
    });
  } catch (error) {
    console.log('Error in debug endpoint:', error);
    return c.json({ error: 'Debug failed' }, 500);
  }
});

// Simple Auth Test Route - FIXED
app.get('/make-server-22c67a59/auth-simple', async (c) => {
  try {
    console.log('=== SIMPLE AUTH TEST START ===');
    
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) {
      console.log('Auth failed in simple test');
      return c.json({ success: false, error: 'Unauthorized' }, 401);
    }
    
    console.log('✅ Auth successful for user:', user.id);
    console.log('=== SIMPLE AUTH TEST END ===');
    
    return c.json({ 
      success: true, 
      userId: user.id,
      email: user.email 
    });
    
  } catch (error) {
    console.log('Auth test exception:', error);
    return c.json({ success: false, error: 'Exception occurred' }, 500);
  }
});

// Test Auth Route - FIXED
app.get('/make-server-22c67a59/test-auth', async (c) => {
  try {
    console.log('Testing authentication...');
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) {
      console.log('Auth test failed - no user');
      return c.json({ error: 'Unauthorized', authenticated: false }, 401);
    }
    
    console.log('Auth test passed for user:', user.id);
    return c.json({ 
      authenticated: true, 
      user: { 
        id: user.id, 
        email: user.email 
      } 
    });
  } catch (error) {
    console.log('Error in auth test:', error);
    return c.json({ error: 'Auth test failed', authenticated: false }, 500);
  }
});

// User Profile Routes
app.get('/make-server-22c67a59/profile', async (c) => {
  try {
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    
    let profile = await kv.get(`user:${user.id}`);
    
    // Create profile if it doesn't exist
    if (!profile) {
      profile = {
        id: user.id,
        email: user.email,
        name: user.user_metadata?.name || user.email?.split('@')[0] || 'User',
        createdAt: new Date().toISOString(),
        totalHabits: 0,
        totalStreak: 0,
        followers: [],
        following: []
      };
      await kv.set(`user:${user.id}`, profile);
    }
    
    return c.json({ profile });
  } catch (error) {
    console.log('Error fetching profile:', error);
    return c.json({ error: 'Failed to fetch profile' }, 500);
  }
});

app.put('/make-server-22c67a59/profile', async (c) => {
  try {
    const user = await getAuthorizedUser(c.req.raw);
    if (!user) return c.json({ error: 'Unauthorized' }, 401);
    
    const { name, bio } = await c.req.json();
    
    let profile = await kv.get(`user:${user.id}`);
    
    if (!profile) {
      profile = {
        id: user.id,
        email: user.email,
        name: user.user_metadata?.name || user.email?.split('@')[0] || 'User',
        createdAt: new Date().toISOString(),
        totalHabits: 0,
        totalStreak: 0,
        followers: [],
        following: []
      };
    }
    
    // Update profile fields
    profile.name = name || profile.name;
    if (bio !== undefined) profile.bio = bio;
    profile.updatedAt = new Date().toISOString();
    
    await kv.set(`user:${user.id}`, profile);
    
    return c.json({ profile });
  } catch (error) {
    console.log('Error updating profile:', error);
    return c.json({ error: 'Failed to update profile' }, 500);
  }
});

// Add hashCode method to String prototype for consistent hashing
if (!String.prototype.hashCode) {
  String.prototype.hashCode = function() {
    let hash = 0;
    for (let i = 0; i < this.length; i++) {
      const char = this.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash;
  };
}

// Log startup info
console.log('🚀 Server starting up...');
console.log('Environment check:');
const supabaseUrl = Deno.env.get('SUPABASE_URL');
const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

console.log('SUPABASE_URL:', !!supabaseUrl);
console.log('SUPABASE_ANON_KEY:', !!anonKey);
console.log('SUPABASE_SERVICE_ROLE_KEY:', !!serviceKey);
console.log('Keys are different:', anonKey !== serviceKey);

// Test Supabase client initialization
try {
  console.log('🔧 Testing Supabase client...');
  const testResult = await supabase.auth.getSession();
  console.log('✅ Supabase client initialized successfully');
} catch (initError) {
  console.error('❌ Supabase client initialization error:', initError);
}

// Initialize storage on startup
initializeStorage();

console.log('✅ Server ready to handle requests');
Deno.serve(app.fetch);