import { useState, useEffect } from 'react';
import { Card, CardContent } from './ui/card';
import { Badge } from './ui/badge';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Avatar, AvatarFallback, AvatarImage } from './ui/avatar';
import { Search, TrendingUp, Users, Camera } from 'lucide-react';
import { api } from '../utils/api';
import { toast } from 'sonner@2.0.3';
import { PullToRefresh } from './PullToRefresh';
import { ImageWithFallback } from './figma/ImageWithFallback';

interface PopularHabit {
  name: string;
  category: string;
  participants: number;
  totalStreak: number;
  description: string;
  image: string;
  captures?: string[]; // Array of photo URLs from users
}

interface CommunityStats {
  activeUsers: number;
  totalHabits: number;
  totalCaptures: number;
}

interface HabitPhotoGridProps {
  captures: string[];
  habitName: string;
}

function HabitPhotoGrid({ captures, habitName }: HabitPhotoGridProps) {
  // Debug logging
  console.log(`📸 HabitPhotoGrid for "${habitName}":`, captures?.length || 0, 'captures');
  
  // Show up to 4 photos in a 2x2 grid, or 1 photo if less than 4
  const photosToShow = captures && captures.length >= 4 ? captures.slice(0, 4) : (captures || []).slice(0, 1);
  
  console.log(`📸 Photos to show for "${habitName}":`, photosToShow.length);
  
  if (!captures || captures.length === 0 || photosToShow.length === 0) {
    // Fallback placeholder
    console.log(`📸 Using placeholder for "${habitName}" (no captures)`);
    return (
      <div className="w-16 h-16 rounded-lg bg-gradient-to-br from-gray-100 to-gray-200 flex items-center justify-center">
        <div className="text-2xl">📸</div>
      </div>
    );
  }
  
  if (photosToShow.length === 1) {
    // Single large photo
    return (
      <div className="w-16 h-16 rounded-lg overflow-hidden bg-muted flex-shrink-0">
        <ImageWithFallback 
          src={photosToShow[0]}
          alt={`${habitName} capture`}
          className="w-full h-full object-cover"
        />
      </div>
    );
  }
  
  // 2x2 grid for 4 photos
  return (
    <div className="w-16 h-16 grid grid-cols-2 gap-0.5 rounded-lg overflow-hidden bg-muted flex-shrink-0">
      {photosToShow.map((photoUrl, index) => (
        <div key={index} className="w-full h-full">
          <ImageWithFallback 
            src={photoUrl}
            alt={`${habitName} capture ${index + 1}`}
            className="w-full h-full object-cover"
          />
        </div>
      ))}
    </div>
  );
}

export function Discovery() {
  const [searchQuery, setSearchQuery] = useState('');
  const [popularHabits, setPopularHabits] = useState<PopularHabit[]>([]);
  const [communityStats, setCommunityStats] = useState<CommunityStats>({ activeUsers: 0, totalHabits: 0, totalCaptures: 0 });
  const [loading, setLoading] = useState(true);
  
  const categories = [
    { name: 'Fitness', count: 0, color: 'bg-blue-100 text-blue-800' },
    { name: 'Wellness', count: 0, color: 'bg-green-100 text-green-800' },
    { name: 'Learning', count: 0, color: 'bg-purple-100 text-purple-800' },
    { name: 'Nutrition', count: 0, color: 'bg-orange-100 text-orange-800' },
    { name: 'Productivity', count: 0, color: 'bg-red-100 text-red-800' },
    { name: 'Health', count: 0, color: 'bg-pink-100 text-pink-800' },
    { name: 'Social', count: 0, color: 'bg-yellow-100 text-yellow-800' }
  ];

  // Update categories based on popular habits
  const updateCategoryCounts = (habits: PopularHabit[]) => {
    return categories.map(category => ({
      ...category,
      count: habits.filter(habit => habit.category === category.name).reduce((sum, habit) => sum + habit.participants, 0)
    }));
  };

  const [categoriesWithCounts, setCategoriesWithCounts] = useState(categories);

  useEffect(() => {
    loadPopularHabits(false);
  }, []);

  // Auto refresh when component gains focus
  useEffect(() => {
    const handleFocus = () => {
      if (!loading) {
        console.log('🎯 Discovery: App gained focus, refreshing data');
        loadPopularHabits(false);
      }
    };

    window.addEventListener('focus', handleFocus);
    return () => window.removeEventListener('focus', handleFocus);
  }, [loading]);

  const loadPopularHabits = async (showToast = true) => {
    try {
      setLoading(true);
      console.log('🔍 Discovery: Starting to load popular habits...');
      
      const response = await api.getPopularHabits();
      console.log('🔍 Discovery: API response received:', response);
      
      const habitsData = response.habits || [];
      const statsData = response.communityStats || { activeUsers: 0, totalHabits: 0, totalCaptures: 0 };
      console.log('🔍 Discovery: Habits data:', habitsData.length, 'habits');
      console.log('🔍 Discovery: Community stats:', statsData);
      
      setPopularHabits(habitsData);
      setCommunityStats(statsData);
      setCategoriesWithCounts(updateCategoryCounts(habitsData));
      
      if (showToast) {
        toast.success(`✅ Loaded ${habitsData.length} trending habits! 🔥`);
      }
    } catch (error) {
      console.error('❌ Discovery: Error loading popular habits:', error);
      if (showToast) {
        toast.error('Failed to load trending habits. Please try again.');
      }
      // Set empty state
      setPopularHabits([]);
      setCommunityStats({ activeUsers: 0, totalHabits: 0, totalCaptures: 0 });
      setCategoriesWithCounts(categories);
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = async () => {
    console.log('🔄 Pull to refresh triggered on Discovery');
    await loadPopularHabits(false);
  };

  const handleCreateHabit = async (habitName: string, category: string) => {
    try {
      await api.createHabit(habitName, category);
      toast.success(`Started tracking "${habitName}"! 🎯`);
    } catch (error) {
      console.error('Error creating habit:', error);
      toast.error('Failed to start habit');
    }
  };

  const filteredHabits = popularHabits.filter(habit =>
    habit.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    habit.category.toLowerCase().includes(searchQuery.toLowerCase())
  );

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-background via-background to-accent/10">
        <div className="p-4 space-y-6">
          <div className="animate-pulse space-y-4">
            <div className="h-8 bg-gray-200 rounded w-1/2"></div>
            <div className="h-10 bg-gray-200 rounded"></div>
            <div className="flex flex-wrap gap-2">
              {[...Array(5)].map((_, i) => (
                <div key={i} className="h-8 bg-gray-200 rounded w-20"></div>
              ))}
            </div>
            <div className="space-y-3">
              {[...Array(4)].map((_, i) => (
                <div key={i} className="h-24 bg-gray-200 rounded"></div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <PullToRefresh onRefresh={handleRefresh} className="min-h-screen bg-gradient-to-br from-background via-background to-accent/10">
      <div className="px-4 pt-4 space-y-6">
        {/* Search */}
        <div className="relative">
          <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground" size={18} />
          <Input
            placeholder="Search habits, categories, or people..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-10"
          />
        </div>

        {/* Categories */}
        <div className="space-y-3">
          <h2 className="text-lg font-medium">Popular Categories</h2>
          <div className="flex flex-wrap gap-2">
            {categoriesWithCounts.map((category) => (
              <Badge 
                key={category.name}
                variant="secondary"
                className={`${category.color} px-3 py-2 cursor-pointer hover:opacity-80`}
                onClick={() => setSearchQuery(category.name.toLowerCase())}
              >
                {category.name} ({category.count})
              </Badge>
            ))}
          </div>
        </div>

        {/* Trending Habits */}
        <div className="space-y-3">
          <div className="flex items-center space-x-2">
            <TrendingUp size={20} className="text-orange-500" />
            <h2 className="text-lg font-medium">
              {searchQuery ? `Search Results for "${searchQuery}"` : 'Trending Habits'}
            </h2>
          </div>
          
          {filteredHabits.length === 0 ? (
            <Card>
              <CardContent className="pt-6 text-center space-y-4">
                <div className="text-6xl">🔍</div>
                <div>
                  <h3 className="text-lg font-medium">
                    {searchQuery ? 'No habits found' : 'No popular habits yet'}
                  </h3>
                  <p className="text-muted-foreground mt-1">
                    {searchQuery 
                      ? 'Try searching for something else or create a new habit!'
                      : 'Be the first to start tracking habits and inspire others!'
                    }
                  </p>
                </div>
              </CardContent>
            </Card>
          ) : (
            <div className="grid gap-4">
              {filteredHabits.map((habit, index) => (
                <Card key={`${habit.name}-${habit.category}-${index}`}>
                  <CardContent className="p-4">
                    <div className="flex space-x-4">
                      {/* Photo Grid */}
                      <HabitPhotoGrid 
                        captures={habit.captures || []}
                        habitName={habit.name}
                      />
                      
                      <div className="flex-1">
                        <div className="flex items-start justify-between">
                          <div>
                            <h3 className="font-medium">{habit.name}</h3>
                            <Badge variant="outline" className="text-xs mt-1">
                              {habit.category}
                            </Badge>
                          </div>
                          <Button
                            size="sm"
                            variant="outline"
                            onClick={() => handleCreateHabit(habit.name, habit.category)}
                            className="border-black text-black bg-transparent hover:bg-transparent hover:border-black hover:text-black"
                          >
                            <Camera size={14} className="mr-1" />
                            Capture
                          </Button>
                        </div>
                        
                        <p className="text-sm text-muted-foreground mt-2">
                          {habit.description}
                        </p>
                        
                        <div className="flex items-center space-x-4 mt-3 text-sm text-muted-foreground">
                          <div className="flex items-center">
                            <Users size={14} className="mr-1" />
                            {habit.participants} participant{habit.participants !== 1 ? 's' : ''}
                          </div>
                          {habit.totalStreak > 0 && (
                            <div className="flex items-center">
                              <TrendingUp size={14} className="mr-1" />
                              {Math.round(habit.totalStreak / habit.participants)} avg streak
                            </div>
                          )}
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </div>

        {/* Community Stats */}
        {popularHabits.length > 0 && (
          <Card>
            <CardContent className="pt-6">
              <h3 className="font-medium mb-3">Community Stats</h3>
              <div className="grid grid-cols-3 gap-4 text-center">
                <div>
                  <div className="text-2xl font-bold text-primary">
                    {communityStats.activeUsers.toLocaleString()}
                  </div>
                  <div className="text-sm text-muted-foreground">Active Users</div>
                </div>
                <div>
                  <div className="text-2xl font-bold text-primary">
                    {communityStats.totalHabits.toLocaleString()}
                  </div>
                  <div className="text-sm text-muted-foreground">Habits</div>
                </div>
                <div>
                  <div className="text-2xl font-bold text-primary">
                    {communityStats.totalCaptures.toLocaleString()}
                  </div>
                  <div className="text-sm text-muted-foreground">Captures</div>
                </div>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </PullToRefresh>
  );
}