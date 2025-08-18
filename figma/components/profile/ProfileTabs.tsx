import { Card, CardContent, CardHeader, CardTitle } from "../ui/card";
import { Badge } from "../ui/badge";
import { Progress } from "../ui/progress";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../ui/tabs";
import { 
  Target, 
  Calendar,
  Flame,
  Star,
  TrendingUp,
  Award,
  Trophy,
  Zap
} from "lucide-react";
import { PROFILE_CATEGORIES, ACHIEVEMENT_ICONS, DEFAULT_ACHIEVEMENTS } from './constants';

interface Habit {
  id: string;
  name: string;
  category: string;
  streak: number;
  completedToday: boolean;
  weeklyProgress: number;
  photos?: { url: string; takenAt: string }[];
}

interface ProfileData {
  totalHabits: number;
  totalCaptures: number;
  followers: string[];
  achievements: string[];
  weeklyStats: {
    captures: number;
    completedHabits: number;
  };
}

interface ProfileTabsProps {
  profile: ProfileData;
  habits: Habit[];
}

export function ProfileTabs({ profile, habits }: ProfileTabsProps) {
  const totalStreak = habits.reduce((sum, habit) => sum + habit.streak, 0);
  const longestStreak = Math.max(...habits.map(h => h.streak), 0);
  const completionRate = habits.length > 0 
    ? Math.round((habits.filter(h => h.completedToday).length / habits.length) * 100)
    : 0;

  return (
    <Tabs defaultValue="overview" className="space-y-4">
      <TabsList className="grid w-full grid-cols-3">
        <TabsTrigger value="overview" className="flex items-center space-x-2">
          <TrendingUp size={16} />
          <span>Overview</span>
        </TabsTrigger>
        <TabsTrigger value="achievements" className="flex items-center space-x-2">
          <Trophy size={16} />
          <span>Achievements</span>
        </TabsTrigger>
        <TabsTrigger value="habits" className="flex items-center space-x-2">
          <Zap size={16} />
          <span>My Habits</span>
        </TabsTrigger>
      </TabsList>

      <TabsContent value="overview" className="space-y-4">
        {/* Enhanced Performance Cards Grid */}
        <div className="grid grid-cols-2 gap-3">
          {/* Total Streaks - Orange to Red gradient */}
          <Card className="bg-gradient-to-br from-orange-50 via-red-50 to-orange-100 dark:from-orange-950/20 dark:via-red-950/20 dark:to-orange-950/30 border-orange-200/60 shadow-sm backdrop-blur-sm">
            <CardContent className="p-4 text-center">
              <div className="flex items-center justify-center space-x-2 mb-1">
                <div className="p-1 rounded-full bg-gradient-to-br from-orange-500/10 to-red-500/10">
                  <Flame className="w-4 h-4 text-orange-600" />
                </div>
                <span className="text-2xl font-bold text-orange-700 tabular-nums">
                  {totalStreak}
                </span>
              </div>
              <p className="text-xs text-orange-700/80 font-medium">Total Streaks</p>
            </CardContent>
          </Card>
          
          {/* Best Streak - Yellow to Amber gradient */}
          <Card className="bg-gradient-to-br from-yellow-50 via-amber-50 to-yellow-100 dark:from-yellow-950/20 dark:via-amber-950/20 dark:to-yellow-950/30 border-yellow-200/60 shadow-sm backdrop-blur-sm">
            <CardContent className="p-4 text-center">
              <div className="flex items-center justify-center space-x-2 mb-1">
                <div className="p-1 rounded-full bg-gradient-to-br from-yellow-500/10 to-amber-500/10">
                  <Award className="w-4 h-4 text-yellow-600" />
                </div>
                <span className="text-2xl font-bold text-yellow-700 tabular-nums">
                  {longestStreak}
                </span>
              </div>
              <p className="text-xs text-yellow-700/80 font-medium">Best Streak</p>
            </CardContent>
          </Card>
        </div>

        {/* Today's Progress Card */}
        <Card className="bg-gradient-to-br from-green-50 via-emerald-50 to-green-100 dark:from-green-950/20 dark:via-emerald-950/20 dark:to-green-950/30 border-green-200/60 shadow-sm backdrop-blur-sm">
          <CardContent className="p-4">
            <div className="flex items-center justify-between">
              <div className="flex items-center space-x-3">
                <div className="p-1.5 rounded-full bg-gradient-to-br from-green-500/10 to-emerald-500/10">
                  <Target className="w-4 h-4 text-green-600" />
                </div>
                <span className="font-medium text-green-800">Today's Progress</span>
              </div>
              <div className="text-right">
                <div className="text-2xl font-bold text-green-700">
                  {completionRate}%
                </div>
                <div className="text-xs text-green-700/80 font-medium">
                  {habits.filter(h => h.completedToday).length} / {habits.length} habits
                </div>
              </div>
            </div>
            <Progress 
              value={completionRate} 
              className="h-2 mt-3 bg-green-100/60 [&>div]:bg-gradient-to-r [&>div]:from-green-500 [&>div]:via-emerald-500 [&>div]:to-green-600 [&>div]:shadow-sm" 
            />
          </CardContent>
        </Card>
      </TabsContent>

      <TabsContent value="achievements" className="space-y-4">
        <div className="grid grid-cols-2 gap-3">
          {profile.achievements.map((achievement, index) => (
            <Card key={achievement} className="bg-gradient-to-br from-yellow-50 via-amber-50 to-orange-50 dark:from-yellow-950/10 dark:via-amber-950/10 dark:to-orange-950/10 border-yellow-200/60 shadow-sm backdrop-blur-sm">
              <CardContent className="p-4 text-center">
                <div className="text-3xl mb-2 animate-bounce-in">
                  {ACHIEVEMENT_ICONS[index] || '🏆'}
                </div>
                <p className="font-medium text-sm text-yellow-800">{achievement}</p>
                <Badge variant="secondary" className="mt-2 text-xs bg-yellow-100 text-yellow-700 border-yellow-200">
                  <Star size={10} className="mr-1" />
                  Earned
                </Badge>
              </CardContent>
            </Card>
          ))}
        </div>
        
        <Card className="border-dashed border-2 border-muted-foreground/20 bg-gradient-to-br from-accent/10 to-background">
          <CardContent className="p-6 text-center text-muted-foreground">
            <div className="relative">
              <Trophy className="w-12 h-12 mx-auto mb-3 opacity-30" />
              <div className="absolute -top-1 -right-1 bg-primary/10 text-primary rounded-full w-6 h-6 flex items-center justify-center text-xs">
                ✨
              </div>
            </div>
            <div className="space-y-1">
              <p className="text-sm font-medium">More achievements coming soon!</p>
              <p className="text-xs text-muted-foreground/80">Keep completing habits to unlock new badges</p>
            </div>
          </CardContent>
        </Card>
      </TabsContent>

      <TabsContent value="habits" className="space-y-3">
        {habits.length > 0 ? (
          <div className="space-y-3">
            {habits.map((habit) => {
              const categoryData = PROFILE_CATEGORIES.find(c => c.name === habit.category);
              const isCompleted = habit.completedToday;
              
              return (
                <Card key={habit.id} className={
                  isCompleted 
                    ? 'bg-gradient-to-br from-green-50 via-emerald-50 to-green-100 dark:from-green-950/10 dark:via-emerald-950/10 dark:to-green-950/20 border-green-200/60 shadow-sm'
                    : 'bg-gradient-to-br from-card via-card to-accent/10 border-border/50 shadow-sm'
                }>
                  <CardContent className="p-4">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center space-x-3">
                        {/* Enhanced completion indicator */}
                        <div className={`w-4 h-4 rounded-full flex items-center justify-center ${
                          isCompleted 
                            ? 'bg-green-500 text-white shadow-sm' 
                            : 'bg-gray-200 dark:bg-gray-700'
                        }`}>
                          {isCompleted && <span className="text-xs">✓</span>}
                        </div>
                        
                        <div>
                          <p className={`font-medium ${isCompleted ? 'text-green-800' : ''}`}>
                            {habit.name}
                          </p>
                          <Badge 
                            variant="outline" 
                            className={`text-xs mt-1 ${categoryData?.color || 'bg-gray-100 text-gray-700'}`}
                          >
                            {habit.category}
                          </Badge>
                        </div>
                      </div>
                      
                      <div className="text-right">
                        <div className="flex items-center space-x-1 text-orange-500">
                          <Flame size={16} />
                          <span className="font-bold text-lg">{habit.streak}</span>
                        </div>
                        <p className="text-xs text-muted-foreground">
                          {Math.round(habit.weeklyProgress)}% this week
                        </p>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        ) : (
          <Card className="border-dashed border-2 border-muted-foreground/20 bg-gradient-to-br from-accent/10 to-background">
            <CardContent className="p-8 text-center text-muted-foreground">
              <div className="relative">
                <Target className="w-16 h-16 mx-auto mb-4 opacity-20" />
                <div className="absolute -top-2 -right-2 bg-primary/10 text-primary rounded-full w-8 h-8 flex items-center justify-center text-lg">
                  🎯
                </div>
              </div>
              <div className="space-y-2">
                <h3 className="text-lg font-medium text-foreground">No habits yet</h3>
                <p className="text-sm">Start your journey by creating your first habit!</p>
                <p className="text-xs text-muted-foreground/80">
                  Popular: 💪 Workout • 📚 Reading • 🧘 Meditation
                </p>
              </div>
            </CardContent>
          </Card>
        )}
      </TabsContent>
    </Tabs>
  );
}