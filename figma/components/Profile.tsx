import { useState, useEffect } from 'react';
import { Card, CardContent } from './ui/card';
import { api } from '../utils/api';
import { useAuth } from './AuthContext';
import { toast } from 'sonner@2.0.3';
import { PullToRefresh } from './PullToRefresh';
import { ProfileHeader } from './profile/ProfileHeader';
import { ProfileTabs } from './profile/ProfileTabs';
import { DEFAULT_ACHIEVEMENTS } from './profile/constants';

interface ProfileData {
  id: string;
  email: string;
  name: string;
  bio?: string;
  avatar?: string;
  createdAt: string;
  totalHabits: number;
  totalStreak: number;
  totalCaptures: number;
  followers: string[];
  following: string[];
  achievements: string[];
  weeklyStats: {
    captures: number;
    completedHabits: number;
  };
}

interface Habit {
  id: string;
  name: string;
  category: string;
  streak: number;
  completedToday: boolean;
  weeklyProgress: number;
  photos?: { url: string; takenAt: string }[];
}

export function Profile() {
  const [profile, setProfile] = useState<ProfileData | null>(null);
  const [habits, setHabits] = useState<Habit[]>([]);
  const [loading, setLoading] = useState(true);

  const { user } = useAuth();

  useEffect(() => {
    if (user) {
      loadProfile();
      loadHabits();
    }
  }, [user]);

  // Auto refresh when component gains focus
  useEffect(() => {
    const handleFocus = () => {
      if (user && !loading) {
        console.log('🎯 Profile: App gained focus, refreshing data');
        loadProfile();
        loadHabits();
      }
    };

    window.addEventListener('focus', handleFocus);
    return () => window.removeEventListener('focus', handleFocus);
  }, [user, loading]);

  const handleRefresh = async () => {
    console.log('🔄 Pull to refresh triggered on Profile');
    await Promise.all([loadProfile(), loadHabits()]);
  };

  const loadProfile = async () => {
    try {
      setLoading(true);
      const response = await api.getProfile();
      
      // Calculate additional stats from habits
      const habitsResponse = await api.getHabits();
      const userHabits = habitsResponse.habits || [];
      
      const totalCaptures = userHabits.reduce((sum, habit: Habit) => 
        sum + (habit.photos?.length || 0), 0
      );
      
      const completedToday = userHabits.filter((habit: Habit) => habit.completedToday).length;
      
      const enrichedProfile = {
        ...response.profile,
        totalCaptures,
        weeklyStats: {
          captures: Math.floor(totalCaptures * 0.3), // Mock weekly captures
          completedHabits: completedToday
        },
        achievements: DEFAULT_ACHIEVEMENTS
      };
      
      setProfile(enrichedProfile);
      
    } catch (error: any) {
      console.error('Error loading profile:', error);
      toast.error('Failed to load profile');
    } finally {
      setLoading(false);
    }
  };

  const loadHabits = async () => {
    try {
      const response = await api.getHabits();
      setHabits(response.habits || []);
    } catch (error: any) {
      console.error('Error loading habits:', error);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-background via-background to-accent/10">
        {/* App Header */}
        <div className="flex items-center justify-center p-4 pb-2">
          <h1 className="text-xl font-bold bg-gradient-to-r from-primary to-primary/70 bg-clip-text text-transparent">
            Profile
          </h1>
        </div>
        
        <div className="p-4 space-y-6 pb-20">
          <div className="animate-pulse space-y-4">
            {/* Profile header skeleton */}
            <div className="p-6 bg-card rounded-2xl border border-border/50 space-y-4">
              <div className="flex items-center space-x-4">
                <div className="w-20 h-20 bg-gray-200 rounded-full"></div>
                <div className="space-y-2">
                  <div className="h-6 bg-gray-200 rounded w-32"></div>
                  <div className="h-4 bg-gray-200 rounded w-24"></div>
                </div>
              </div>
              <div className="grid grid-cols-3 gap-3">
                {[...Array(3)].map((_, i) => (
                  <div key={i} className="h-16 bg-gray-200 rounded-xl"></div>
                ))}
              </div>
            </div>
            
            {/* Tabs skeleton */}
            <div className="space-y-3">
              <div className="h-10 bg-gray-200 rounded-lg"></div>
              <div className="grid grid-cols-2 gap-3">
                <div className="h-20 bg-gray-200 rounded-lg"></div>
                <div className="h-20 bg-gray-200 rounded-lg"></div>
              </div>
              <div className="h-24 bg-gray-200 rounded-lg"></div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (!profile) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-background via-background to-accent/10">
        {/* App Header */}
        <div className="flex items-center justify-center p-4 pb-2">
          <h1 className="text-xl font-bold bg-gradient-to-r from-primary to-primary/70 bg-clip-text text-transparent">
            Profile
          </h1>
        </div>
        
        <div className="p-4 pb-20 text-center space-y-4">
          <Card className="p-8">
            <CardContent className="space-y-4">
              <div className="text-6xl">😔</div>
              <div>
                <h3 className="text-lg font-medium">Failed to load profile</h3>
                <p className="text-muted-foreground">Please try refreshing the page</p>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <PullToRefresh onRefresh={handleRefresh} className="min-h-screen bg-gradient-to-br from-background via-background to-accent/10">
      {/* App Header with Centered Title */}
      <div className="flex items-center justify-center p-4 pb-2">
        <h1 className="text-xl font-bold bg-gradient-to-r from-primary to-primary/70 bg-clip-text text-transparent">
          Profile
        </h1>
      </div>
      
      <div className="px-4 space-y-6 pb-20">
        <ProfileHeader 
          profile={profile} 
          onProfileUpdate={setProfile}
        />
        
        <ProfileTabs 
          profile={profile}
          habits={habits}
        />
      </div>
    </PullToRefresh>
  );
}