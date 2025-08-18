import { useState, useEffect } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from "./ui/card";
import { Progress } from "./ui/progress";
import { Badge } from "./ui/badge";
import { Button } from "./ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "./ui/tabs";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "./ui/dialog";
import { Plus, Camera, Flame, Trophy, Target, Zap, TrendingUp, Calendar, Bug, Star, Award, Sparkles, Sun, Moon, Sunrise, Sunset, ChevronDown, ChevronUp } from 'lucide-react';
import { api } from '../utils/api';
import { useAuth } from './AuthContext';
import { toast } from 'sonner@2.0.3';
import { HabitGrid } from './HabitGrid';
import { ImageWithFallback } from './figma/ImageWithFallback';
import { PullToRefresh } from './PullToRefresh';
import { ChooseHabitDialog } from './habit-creation/ChooseHabitDialog';
import { CustomizeHabitDialog } from './habit-creation/CustomizeHabitDialog';
import { DASHBOARD_CATEGORIES } from './dashboard/constants';
import { Habit, getRandomMessage, calculateTargetProgress } from './dashboard/utils';

interface DashboardProps {
  onCaptureHabit: (habitId: string) => void;
}

// Motivational quotes (no emojis)
const MOTIVATIONAL_QUOTES = [
  "Small daily improvements lead to stunning results over time.",
  "You don't have to be perfect, just consistent.", 
  "Every expert was once a beginner. Keep going!",
  "The only impossible journey is the one you never begin.",
  "Success is the sum of small efforts repeated daily.",
  "Progress, not perfection. You've got this!",
  "Your only limit is your mind. Break through!",
  "Believe in yourself and all that you are."
];

// Achievement milestones
const STREAK_MILESTONES = [
  { streak: 3, title: "Getting Started!", emoji: "🌱", message: "3 days strong! You're building momentum!" },
  { streak: 7, title: "Week Warrior!", emoji: "🔥", message: "A whole week! You're on fire!" },
  { streak: 14, title: "Two Week Champion!", emoji: "⚡", message: "Two weeks of consistency! Incredible!" },
  { streak: 30, title: "Monthly Master!", emoji: "🏆", message: "30 days! You're a habit-building legend!" },
  { streak: 50, title: "Consistency King!", emoji: "👑", message: "50 days! You're absolutely unstoppable!" },
  { streak: 100, title: "Century Champion!", emoji: "🎯", message: "100 days! This is legendary territory!" }
];

export function Dashboard({ onCaptureHabit }: DashboardProps) {
  const [habits, setHabits] = useState<Habit[]>([]);
  const [loading, setLoading] = useState(true);
  const [showAddDialog, setShowAddDialog] = useState(false);
  const [showChooseHabit, setShowChooseHabit] = useState(false);
  const [showCustomizeHabit, setShowCustomizeHabit] = useState(false);
  const [selectedPresetHabit, setSelectedPresetHabit] = useState<any>(null);
  const [showDebug, setShowDebug] = useState(false);
  const [debugInfo, setDebugInfo] = useState<any>(null);
  const [showAchievement, setShowAchievement] = useState(false);
  const [currentAchievement, setCurrentAchievement] = useState<any>(null);
  const [animatedStats, setAnimatedStats] = useState({ totalStreak: 0, longestStreak: 0, todayPercent: 0 });
  const [newHabit, setNewHabit] = useState({
    name: '',
    category: '',
    description: '',
    targetNumber: 1,
    targetPeriod: 'day' as 'day' | 'week' | 'month'
  });
  
  // State for collapsible habits section
  const [habitsCollapsed, setHabitsCollapsed] = useState(() => {
    const stored = localStorage.getItem('habits-collapsed');
    return stored ? JSON.parse(stored) : false;
  });

  const { user } = useAuth();

  // Get time-based greeting with black outline icons (no emojis)
  const getTimeBasedGreeting = () => {
    const hour = new Date().getHours();
    if (hour < 6) return { text: "Burning the midnight oil", icon: Moon };
    if (hour < 12) return { text: "Good morning", icon: Sunrise };
    if (hour < 17) return { text: "Good afternoon", icon: Sun };
    if (hour < 20) return { text: "Good evening", icon: Sunset };
    return { text: "Good evening", icon: Moon };
  };

  // Get random motivational quote
  const getMotivationalQuote = () => {
    return MOTIVATIONAL_QUOTES[Math.floor(Math.random() * MOTIVATIONAL_QUOTES.length)];
  };

  // Check for achievements
  const checkForAchievements = (updatedHabits: Habit[]) => {
    const maxStreak = Math.max(...updatedHabits.map(h => h.streak), 0);
    const milestone = STREAK_MILESTONES.find(m => 
      m.streak === maxStreak && 
      !localStorage.getItem(`achievement_${m.streak}_shown`)
    );
    
    if (milestone) {
      setCurrentAchievement(milestone);
      setShowAchievement(true);
      localStorage.setItem(`achievement_${milestone.streak}_shown`, 'true');
    }
  };

  // Animate stats counters
  useEffect(() => {
    if (habits.length > 0) {
      const totalStreak = habits.reduce((sum, h) => sum + h.streak, 0);
      const longestStreak = Math.max(...habits.map(h => h.streak), 0);
      const dailyHabits = habits.filter(h => h.targetPeriod === 'day');
      const completedDaily = dailyHabits.filter(h => h.completedToday);
      const todayPercent = dailyHabits.length > 0 ? Math.round((completedDaily.length / dailyHabits.length) * 100) : 0;

      // Animate counters
      const duration = 1500;
      const steps = 30;
      const stepDuration = duration / steps;

      let step = 0;
      const interval = setInterval(() => {
        step++;
        const progress = step / steps;
        const easeOut = 1 - Math.pow(1 - progress, 3);

        setAnimatedStats({
          totalStreak: Math.round(totalStreak * easeOut),
          longestStreak: Math.round(longestStreak * easeOut),
          todayPercent: Math.round(todayPercent * easeOut)
        });

        if (step >= steps) {
          clearInterval(interval);
        }
      }, stepDuration);

      return () => clearInterval(interval);
    }
  }, [habits]);

  useEffect(() => {
    if (user) {
      console.log('🎯 Dashboard: User is authenticated, loading habits immediately');
      loadHabits(false);
    }
  }, [user]);

  useEffect(() => {
    const handleFocus = () => {
      if (user && !loading) {
        console.log('🎯 Dashboard: App gained focus, refreshing data');
        loadHabits(false);
      }
    };

    window.addEventListener('focus', handleFocus);
    return () => window.removeEventListener('focus', handleFocus);
  }, [user, loading]);

  const handleRefresh = async () => {
    console.log('🔄 Pull to refresh triggered');
    await loadHabits(false);
  };

  const runDebugTests = async () => {
    console.log('🐛 Running comprehensive debug tests...');
    setDebugInfo({ testing: true });
    
    try {
      const results: any = {
        timestamp: new Date().toISOString(),
        userInfo: {
          exists: !!user,
          id: user?.id,
          email: user?.email
        },
        apiInfo: {
          hasToken: !!api.getAccessToken(),
          tokenLength: api.getAccessToken()?.length || 0,
          tokenValid: api.hasValidToken()
        }
      };

      try {
        console.log('🔐 Testing simple auth...');
        const authResult = await api.authSimple();
        results.simpleAuth = { success: true, data: authResult };
      } catch (error: any) {
        results.simpleAuth = { success: false, error: error.message };
      }

      try {
        console.log('🔬 Testing comprehensive auth debug...');
        const compAuthResult = await api.debugAuthComprehensive();
        results.comprehensiveAuth = { success: true, data: compAuthResult };
      } catch (error: any) {
        results.comprehensiveAuth = { success: false, error: error.message };
      }

      try {
        console.log('🎯 Testing habits endpoint...');
        const habitsResult = await api.getHabits();
        results.habitsEndpoint = { success: true, data: habitsResult, habitsCount: habitsResult.habits?.length || 0 };
      } catch (error: any) {
        results.habitsEndpoint = { success: false, error: error.message };
      }

      console.log('✅ Debug tests completed:', results);
      setDebugInfo(results);
      
      if (results.habitsEndpoint?.success) {
        const habitsWithTargets = results.habitsEndpoint.data.habits.map((habit: Habit) => ({
          ...habit,
          targetNumber: habit.targetNumber || 1,
          targetPeriod: habit.targetPeriod || 'day'
        }));
        setHabits(habitsWithTargets);
        toast.success('Debug test passed! Habits loaded successfully. 🎉');
      }
      
    } catch (error: any) {
      console.error('❌ Debug test error:', error);
      setDebugInfo({ error: error.message });
    }
  };

  const loadHabits = async (showToast = true) => {
    try {
      setLoading(true);
      console.log('🎯 Loading habits for user:', user?.id);

      if (!api.hasValidToken()) {
        console.error('❌ Cannot load habits: invalid or missing token');
        if (showToast) toast.error('Authentication error. Please sign out and back in.');
        return;
      }

      console.log('📡 Making habits API request...');
      const response = await api.getHabits();
      console.log('✅ Habits loaded successfully:', response);
      
      const habitsWithTargets = (response.habits || []).map((habit: Habit) => ({
        ...habit,
        targetNumber: habit.targetNumber || 1,
        targetPeriod: habit.targetPeriod || 'day'
      }));
      
      setHabits(habitsWithTargets);
      checkForAchievements(habitsWithTargets);
      if (showToast) toast.success(`Loaded ${habitsWithTargets.length} habits! 🎯`);
      
    } catch (error: any) {
      console.error('❌ Error loading habits:', error);
      
      if (error.message.includes('Unauthorized')) {
        console.log('🚨 Unauthorized error - this should be fixed now!');
        if (showToast) toast.error('Authentication failed. Click "Run Tests" in debug panel to troubleshoot.');
      } else {
        if (showToast) toast.error('Failed to load habits. Please try refreshing.');
      }
      
      setHabits([]);
    } finally {
      setLoading(false);
    }
  };

  const handleAddHabit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newHabit.name.trim() || !newHabit.category) return;

    try {
      console.log('➕ Creating habit:', newHabit);
      
      const response = await api.createHabit(
        newHabit.name,
        newHabit.category,
        newHabit.description,
        {
          targetNumber: newHabit.targetNumber,
          targetPeriod: newHabit.targetPeriod
        }
      );
      
      console.log('✅ Habit created:', response);
      const habitWithDefaults = {
        ...response.habit,
        targetNumber: newHabit.targetNumber,
        targetPeriod: newHabit.targetPeriod
      };
      
      const updatedHabits = [...habits, habitWithDefaults];
      setHabits(updatedHabits);
      setNewHabit({ name: '', category: '', description: '', targetNumber: 1, targetPeriod: 'day' });
      setShowCustomizeHabit(false);
      
      // Celebrate habit creation
      toast.success('🎉 Awesome! Your new habit is ready to track!', {
        description: 'Time to build that streak! 💪'
      });
    } catch (error: any) {
      console.error('❌ Error creating habit:', error);
      toast.error('Failed to create habit: ' + error.message);
    }
  };

  // Toggle habits collapsed state
  const toggleHabitsCollapsed = () => {
    const newState = !habitsCollapsed;
    setHabitsCollapsed(newState);
    localStorage.setItem('habits-collapsed', JSON.stringify(newState));
  };

  // Get category color for collapsed view
  const getCategoryColor = (category: string) => {
    const categoryData = DASHBOARD_CATEGORIES.find(c => c.name === category);
    return categoryData?.color || 'bg-gray-100 text-gray-700';
  };

  // Format target text for collapsed view
  const getTargetText = (habit: Habit) => {
    const number = habit.targetNumber || 1;
    const period = habit.targetPeriod || 'day';
    
    if (number === 1) {
      return `once per ${period}`;
    } else {
      return `${number} times per ${period}`;
    }
  };

  // Get weekly summary
  const getWeeklySummary = () => {
    const today = new Date();
    const startOfWeek = new Date(today);
    startOfWeek.setDate(today.getDate() - today.getDay());
    
    let totalCompletions = 0;
    let possibleCompletions = 0;
    
    habits.forEach(habit => {
      // Simplified: assume 1 completion per day for weekly calculation
      possibleCompletions += 7;
      totalCompletions += habit.streak > 7 ? 7 : habit.streak;
    });
    
    const weeklyPercentage = possibleCompletions > 0 ? Math.round((totalCompletions / possibleCompletions) * 100) : 0;
    return { weeklyPercentage, totalCompletions, possibleCompletions };
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-background via-background to-accent/10">
        <div className="p-4 pb-20 space-y-6">
          <div className="animate-pulse space-y-4">
            <div className="h-8 bg-gray-200 rounded w-1/2"></div>
            <div className="h-4 bg-gray-200 rounded w-3/4"></div>
            <div className="h-32 bg-gray-200 rounded"></div>
            <div className="space-y-3">
              {[...Array(3)].map((_, i) => (
                <div key={i} className="h-24 bg-gray-200 rounded"></div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  const completedToday = habits.filter(h => h.completedToday).length;
  const totalStreak = habits.reduce((sum, h) => sum + h.streak, 0);
  const longestStreak = Math.max(...habits.map(h => h.streak), 0);
  const greeting = getTimeBasedGreeting();
  const weeklySummary = getWeeklySummary();

  return (
    <PullToRefresh onRefresh={handleRefresh} className="min-h-screen bg-gradient-to-br from-background via-background to-accent/10 hide-scrollbar">
      {/* App Header with Centered Title */}
      <div className="flex items-center justify-between p-4 pb-2">
        <div className="w-10"></div>
        
        <h1 className="text-xl font-bold bg-gradient-to-r from-primary to-primary/70 bg-clip-text text-transparent">
          Capture
        </h1>
        
        <div className="flex items-center space-x-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setShowDebug(!showDebug)}
            className="text-muted-foreground"
          >
            <Bug size={16} />
          </Button>
        </div>
      </div>
      
      <div className="px-4 space-y-6">
        {/* Enhanced Header with Time-based Greeting */}
        <div className="relative">
          <div className="absolute inset-0 bg-gradient-to-br from-card via-card to-accent/30 rounded-2xl border border-border/50 shadow-sm -z-10"></div>
          <div className="p-6 space-y-4">
            <div className="flex items-center justify-between">
              <div className="space-y-2">
                <div className="flex items-center space-x-2">
                  <greeting.icon className="w-6 h-6 text-primary stroke-2" />
                  <h1 className="text-2xl font-bold bg-gradient-to-r from-primary to-primary/70 bg-clip-text text-transparent">
                    {greeting.text}, {user?.name?.split(' ')[0] || user?.email?.split('@')[0] || 'there'}!
                  </h1>
                </div>
                <p className="text-muted-foreground">
                  {habits.length === 0 
                    ? "Ready to start your journey?"
                    : getMotivationalQuote()
                  }
                </p>
              </div>
            </div>

            {/* Enhanced Stats Cards with Subtle Gradients */}
            {habits.length > 0 && (
              <div className="grid grid-cols-3 gap-3">
                {/* Total Streaks - Orange to Red gradient */}
                <Card className="bg-gradient-to-br from-orange-50 via-red-50 to-orange-100 dark:from-orange-950/20 dark:via-red-950/20 dark:to-orange-950/30 border-orange-200/60 shadow-sm backdrop-blur-sm animate-bounce-in">
                  <CardContent className="p-4 text-center">
                    <div className="flex items-center justify-center space-x-2 mb-1">
                      <div className="p-1 rounded-full bg-gradient-to-br from-orange-500/10 to-red-500/10">
                        <Flame className="w-4 h-4 text-orange-600" />
                      </div>
                      <span className="text-2xl font-bold text-orange-700 tabular-nums">
                        {animatedStats.totalStreak}
                      </span>
                    </div>
                    <p className="text-xs text-orange-700/80 font-medium">Total Streaks</p>
                  </CardContent>
                </Card>
                
                {/* Best Streak - Yellow to Amber gradient */}
                <Card className="bg-gradient-to-br from-yellow-50 via-amber-50 to-yellow-100 dark:from-yellow-950/20 dark:via-amber-950/20 dark:to-yellow-950/30 border-yellow-200/60 shadow-sm backdrop-blur-sm animate-bounce-in" style={{ animationDelay: '0.1s' }}>
                  <CardContent className="p-4 text-center">
                    <div className="flex items-center justify-center space-x-2 mb-1">
                      <div className="p-1 rounded-full bg-gradient-to-br from-yellow-500/10 to-amber-500/10">
                        <Trophy className="w-4 h-4 text-yellow-600" />
                      </div>
                      <span className="text-2xl font-bold text-yellow-700 tabular-nums">
                        {animatedStats.longestStreak}
                      </span>
                    </div>
                    <p className="text-xs text-yellow-700/80 font-medium">Best Streak</p>
                  </CardContent>
                </Card>
                
                {/* Today Progress - Green to Emerald gradient */}
                <Card className="bg-gradient-to-br from-green-50 via-emerald-50 to-green-100 dark:from-green-950/20 dark:via-emerald-950/20 dark:to-green-950/30 border-green-200/60 shadow-sm backdrop-blur-sm animate-bounce-in" style={{ animationDelay: '0.2s' }}>
                  <CardContent className="p-4 text-center">
                    <div className="flex items-center justify-center space-x-2 mb-1">
                      <div className="relative w-6 h-6">
                        <div className="absolute inset-0 rounded-full bg-gradient-to-br from-green-500/10 to-emerald-500/10"></div>
                        <svg className="w-6 h-6 transform -rotate-90 relative z-10" viewBox="0 0 24 24">
                          <circle
                            cx="12"
                            cy="12"
                            r="9"
                            stroke="currentColor"
                            strokeWidth="1.5"
                            fill="none"
                            className="text-green-200"
                          />
                          <circle
                            cx="12"
                            cy="12"
                            r="9"
                            stroke="currentColor"
                            strokeWidth="1.5"
                            fill="none"
                            strokeLinecap="round"
                            className="text-green-600"
                            strokeDasharray={`${2 * Math.PI * 9}`}
                            strokeDashoffset={`${2 * Math.PI * 9 * (1 - animatedStats.todayPercent / 100)}`}
                            style={{
                              transition: 'stroke-dashoffset 0.5s ease-in-out'
                            }}
                          />
                        </svg>
                      </div>
                      <span className="text-2xl font-bold text-green-700 tabular-nums">
                        {animatedStats.todayPercent}%
                      </span>
                    </div>
                    <p className="text-xs text-green-700/80 font-medium">Today</p>
                  </CardContent>
                </Card>
              </div>
            )}

            {/* Enhanced Weekly Summary Card */}
            {habits.length > 0 && (
              <Card className="bg-gradient-to-br from-purple-50 via-blue-50 to-indigo-100 dark:from-purple-950/20 dark:via-blue-950/20 dark:to-indigo-950/30 border-purple-200/60 shadow-sm backdrop-blur-sm">
                <CardContent className="p-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center space-x-3">
                      <div className="p-1.5 rounded-full bg-gradient-to-br from-purple-500/10 to-blue-500/10">
                        <Sparkles className="w-4 h-4 text-purple-600" />
                      </div>
                      <span className="font-medium text-purple-800">This Week</span>
                    </div>
                    <div className="text-right">
                      <div className="text-2xl font-bold text-purple-700">
                        {weeklySummary.weeklyPercentage}%
                      </div>
                      <div className="text-xs text-purple-700/80 font-medium">
                        {weeklySummary.totalCompletions} completions
                      </div>
                    </div>
                  </div>
                  <Progress 
                    value={weeklySummary.weeklyPercentage} 
                    className="h-2 mt-3 bg-purple-100/60 [&>div]:bg-gradient-to-r [&>div]:from-purple-500 [&>div]:via-blue-500 [&>div]:to-indigo-500 [&>div]:shadow-sm" 
                  />
                </CardContent>
              </Card>
            )}
          </div>
        </div>

        {/* Achievement Modal */}
        <Dialog open={showAchievement} onOpenChange={setShowAchievement}>
          <DialogContent className="bg-gradient-to-br from-yellow-50 to-orange-50 border-yellow-300">
            <DialogHeader>
              <DialogTitle className="text-center space-y-2">
                <div className="text-6xl animate-bounce">{currentAchievement?.emoji}</div>
                <div className="text-2xl font-bold text-yellow-700">
                  {currentAchievement?.title}
                </div>
              </DialogTitle>
            </DialogHeader>
            <div className="text-center space-y-4">
              <p className="text-lg text-yellow-600">
                {currentAchievement?.message}
              </p>
              <div className="flex items-center justify-center space-x-2">
                <Award className="w-6 h-6 text-yellow-500" />
                <span className="font-medium">Achievement Unlocked!</span>
                <Award className="w-6 h-6 text-yellow-500" />
              </div>
              <Button 
                onClick={() => setShowAchievement(false)}
                className="bg-gradient-to-r from-yellow-500 to-orange-500 hover:from-yellow-600 hover:to-orange-600 text-white"
              >
                <Star className="w-4 h-4 mr-2" />
                Awesome!
              </Button>
            </div>
          </DialogContent>
        </Dialog>

        {/* Debug Panel */}
        {showDebug && (
          <Card className="border-yellow-300 bg-yellow-50 dark:bg-yellow-950/20">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm flex items-center space-x-2">
                <Bug className="w-4 h-4" />
                <span>Debug Information</span>
                <Button size="sm" variant="outline" onClick={runDebugTests}>
                  Run Tests
                </Button>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2">
              <div className="text-xs space-y-1">
                <div>User: {user?.id ? `✅ ${user.id}` : '❌ No user'}</div>
                <div>Token: {api.hasValidToken() ? '✅ Valid' : '❌ Invalid'}</div>
                <div>Token Length: {api.getAccessToken()?.length || 0}</div>
                <div>Habits: {habits.length} loaded</div>
              </div>
              
              {debugInfo && (
                <div className="mt-3 p-2 bg-gray-100 dark:bg-gray-800 rounded text-xs">
                  <pre className="overflow-auto max-h-32 text-xs whitespace-pre-wrap">
                    {JSON.stringify(debugInfo, null, 2)}
                  </pre>
                </div>
              )}
            </CardContent>
          </Card>
        )}

        {/* Main Content Area */}
        {habits.length === 0 && !loading ? (
          <Card className="bg-gradient-to-br from-accent/20 to-background">
            <CardContent className="pt-8 pb-8 text-center space-y-6">
              <div className="relative">
                <ImageWithFallback 
                  src="https://images.unsplash.com/photo-1611262588024-d12430b98920?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxzb2NpYWwlMjBtZWRpYSUyMGJyaWdodHxlbnwxfHx8fDE3NTUxMTg3ODJ8MA&ixlib=rb-4.1.0&q=80&w=1080&utm_source=figma&utm_medium=referral"
                  alt="Fun social media"
                  className="w-24 h-24 rounded-full mx-auto object-cover shadow-lg animate-bounce-in"
                />
                <div className="absolute -top-2 -right-2 bg-primary text-primary-foreground rounded-full w-8 h-8 flex items-center justify-center text-lg animate-glow">
                  🎯
                </div>
              </div>
              <div className="space-y-2">
                <h3 className="text-xl font-semibold">Ready to start your journey?</h3>
                <p className="text-muted-foreground max-w-md mx-auto">
                  Create your first habit and join the community! Track your progress, share photos, and build consistency together.
                </p>
              </div>
              <div className="flex flex-col space-y-3 max-w-xs mx-auto">
                <Button 
                  className="bg-gradient-to-r from-primary to-primary/80 shadow-lg hover:shadow-xl transform hover:scale-105 transition-all"
                  onClick={() => setShowChooseHabit(true)}
                >
                  <Plus size={16} className="mr-2" />
                  Create Your First Habit
                </Button>
                <div className="text-sm text-muted-foreground">
                  Popular: 💪 Workout • 📚 Reading • 🧘 Meditation
                </div>
              </div>
            </CardContent>
          </Card>
        ) : habits.length > 0 ? (
          <div className="space-y-4">
            {/* Your Habits Section Header */}
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-2">
                <h2 className="text-lg font-semibold flex items-center space-x-2">
                  <Zap className="w-5 h-5 text-yellow-500" />
                  <span>Your Habits</span>
                </h2>
                
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={toggleHabitsCollapsed}
                  className="p-1 h-auto"
                >
                  {habitsCollapsed ? (
                    <ChevronDown size={16} className="text-muted-foreground" />
                  ) : (
                    <ChevronUp size={16} className="text-muted-foreground" />
                  )}
                </Button>
              </div>
              
              <Button 
                size="sm" 
                className="rounded-full bg-primary hover:bg-primary/90 shadow-lg hover:shadow-xl transform hover:scale-105 transition-all"
                onClick={() => setShowChooseHabit(true)}
              >
                <Plus size={16} />
              </Button>
            </div>

            {/* Tabs for Overview and Progress Grid */}
            <Tabs defaultValue="overview" className="space-y-4 overflow-hidden">
              <TabsList className="grid w-full grid-cols-2">
                <TabsTrigger value="overview" className="flex items-center space-x-2">
                  <TrendingUp size={16} />
                  <span>Overview</span>
                </TabsTrigger>
                <TabsTrigger value="grid" className="flex items-center space-x-2">
                  <Calendar size={16} />
                  <span>Progress Grid</span>
                </TabsTrigger>
              </TabsList>

              <TabsContent value="overview" className="space-y-4">
                {habitsCollapsed ? (
                  // Collapsed view - thin habit bars
                  <div className="space-y-2">
                    {habits
                      .sort((a, b) => {
                        // Sort so uncompleted habits come first, completed habits go to bottom
                        if (a.completedToday === b.completedToday) {
                          return 0;
                        }
                        return a.completedToday ? 1 : -1;
                      })
                      .map((habit) => {
                        const categoryData = DASHBOARD_CATEGORIES.find(c => c.name === habit.category);
                        
                        return (
                          <div 
                            key={habit.id} 
                            className={`flex items-center justify-between p-3 rounded-lg border transition-all duration-200 hover:shadow-md ${
                              habit.completedToday 
                                ? 'bg-completed-stripes border-green-200' 
                                : 'bg-card border-border hover:shadow-sm'
                            }`}
                          >
                            {/* Left side: Color indicator + Habit name + Target */}
                            <div className="flex items-center space-x-3">
                              <div 
                                className={`w-3 h-8 rounded-full`}
                                style={{
                                  backgroundColor: categoryData?.name === 'Fitness' ? 'var(--habit-fitness)' :
                                                categoryData?.name === 'Wellness' ? 'var(--habit-wellness)' :
                                                categoryData?.name === 'Learning' ? 'var(--habit-learning)' :
                                                categoryData?.name === 'Nutrition' ? 'var(--habit-nutrition)' :
                                                categoryData?.name === 'Productivity' ? 'var(--habit-productivity)' :
                                                categoryData?.name === 'Health' ? 'var(--habit-health)' :
                                                categoryData?.name === 'Social' ? 'var(--habit-social)' :
                                                '#6B7280'
                                }}
                              ></div>
                              <div className="flex flex-col">
                                <span className="font-medium">{habit.name}</span>
                                <span className="text-xs text-muted-foreground/70">{getTargetText(habit)}</span>
                              </div>
                            </div>
                            
                            {/* Right side: Streak and Camera */}
                            <div className="flex items-center space-x-3">
                              <div className="flex items-center space-x-1 text-orange-500 bg-orange-50 dark:bg-orange-950/20 px-2 py-1 rounded-full">
                                <Flame size={12} />
                                <span className="font-bold text-sm">{habit.streak}</span>
                              </div>
                              
                              {!habit.completedToday ? (
                                <Button 
                                  variant="ghost"
                                  size="sm" 
                                  onClick={() => onCaptureHabit(habit.id)}
                                  className="w-8 h-8 rounded-lg p-0 hover:bg-accent"
                                >
                                  <Camera size={16} />
                                </Button>
                              ) : (
                                <div className="w-8 h-8 rounded-lg bg-green-100 dark:bg-green-950/20 flex items-center justify-center">
                                  <Target className="w-4 h-4 text-green-600" />
                                </div>
                              )}
                            </div>
                          </div>
                        );
                      })}
                  </div>
                ) : (
                  // Expanded view - full habit cards
                  habits
                    .sort((a, b) => {
                      // Sort so uncompleted habits come first, completed habits go to bottom
                      if (a.completedToday === b.completedToday) {
                        return 0; // Keep original order if both have same completion status
                      }
                      return a.completedToday ? 1 : -1; // Uncompleted (false) comes first (-1), completed (true) comes last (1)
                    })
                    .map((habit) => {
                    const categoryData = DASHBOARD_CATEGORIES.find(c => c.name === habit.category);
                    const progress = calculateTargetProgress(habit);
                    
                    return (
                      <Card key={habit.id} className={`transition-all duration-300 hover:shadow-lg ${
                        habit.completedToday 
                          ? 'bg-completed-stripes border-green-200 animate-bounce-in' 
                          : 'hover:scale-[1.02] hover:shadow-xl'
                      }`}>
                        <CardContent className="p-5">
                          <div className="space-y-3">
                            {/* Top row: Photo + Habit Name + Camera Button */}
                            <div className="flex items-center justify-between">
                              <div className="flex items-center space-x-3">
                                {habit.photos && habit.photos.length > 0 && (
                                  <div className="w-12 h-12 rounded-xl overflow-hidden bg-muted shadow-sm animate-bounce-in">
                                    <ImageWithFallback 
                                      src={habit.photos[habit.photos.length - 1].url} 
                                      alt="Last photo"
                                      className="w-full h-full object-cover"
                                    />
                                  </div>
                                )}
                                <h3 className="font-semibold text-lg">{habit.name}</h3>
                              </div>
                              
                              {!habit.completedToday && (
                                <Button 
                                  variant="ghost"
                                  size="lg" 
                                  onClick={() => onCaptureHabit(habit.id)}
                                  className="w-12 h-12 rounded-xl p-0 hover:bg-accent transform hover:scale-110 transition-all"
                                >
                                  <Camera size={20} />
                                </Button>
                              )}
                              
                              {habit.completedToday && (
                                <div className="w-12 h-12 rounded-xl bg-green-100 dark:bg-green-950/20 flex items-center justify-center animate-bounce-in">
                                  <Target className="w-5 h-5 text-green-600" />
                                </div>
                              )}
                            </div>

                            {/* Bottom row: Category + Streak + Target Text */}
                            <div className="flex items-center justify-between">
                              <div className="flex items-center space-x-2">
                                <Badge variant="secondary" className={`${categoryData?.color} border-0 text-sm`}>
                                  {categoryData?.emoji} {habit.category}
                                </Badge>
                                <div className="flex items-center space-x-1 text-orange-500 bg-orange-50 dark:bg-orange-950/20 px-2 py-0.5 rounded-full">
                                  <Flame size={14} />
                                  <span className="font-bold text-sm">{habit.streak}</span>
                                </div>
                              </div>
                              <span className="font-medium text-sm text-muted-foreground">{progress.text}</span>
                            </div>
                          </div>
                          
                          <div className="space-y-3 mt-4">
                            <Progress 
                              value={progress.percentage} 
                              className={`h-2 bg-gray-100 ${
                                progress.current >= progress.target 
                                  ? '[&>div]:bg-gradient-to-r [&>div]:from-green-500 [&>div]:to-emerald-500' 
                                  : '[&>div]:bg-gradient-to-r [&>div]:from-primary [&>div]:to-primary/80'
                              }`}
                            />
                            {progress.current >= progress.target && (
                              <div className="flex items-center space-x-1 text-green-600 text-sm animate-bounce-in">
                                <Target size={14} />
                                <span>Target achieved! 🎉</span>
                              </div>
                            )}
                          </div>
                        </CardContent>
                      </Card>
                    );
                  })
                )}
              </TabsContent>

              <TabsContent value="grid" className="space-y-4 overflow-y-auto hide-scrollbar">
                {habits.map((habit) => (
                  <HabitGrid 
                    key={habit.id} 
                    habit={habit}
                    onDateClick={(date) => {
                      console.log('Clicked date:', date, 'for habit:', habit.name);
                    }}
                  />
                ))}
              </TabsContent>
            </Tabs>
          </div>
        ) : null}

        {/* Choose Habit Dialog */}
        <ChooseHabitDialog 
          open={showChooseHabit}
          onOpenChange={setShowChooseHabit}
          onSelectPreset={(preset) => {
            setSelectedPresetHabit(preset);
            setShowChooseHabit(false);
            setShowCustomizeHabit(true);
          }}
          onCreateCustom={() => {
            setSelectedPresetHabit(null);
            setShowChooseHabit(false);
            setShowCustomizeHabit(true);
          }}
        />

        {/* Customize Habit Dialog */}
        <CustomizeHabitDialog 
          open={showCustomizeHabit}
          onOpenChange={setShowCustomizeHabit}
          presetHabit={selectedPresetHabit}
          onCreateHabit={handleAddHabit}
          newHabit={newHabit}
          setNewHabit={setNewHabit}
        />
      </div>
    </PullToRefresh>
  );
}