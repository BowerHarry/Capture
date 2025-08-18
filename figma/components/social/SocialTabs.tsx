import { useState } from 'react';
import { Card, CardContent } from "../ui/card";
import { Avatar, AvatarFallback, AvatarImage } from "../ui/avatar";
import { Button } from "../ui/button";
import { Badge } from "../ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../ui/tabs";
import { DropdownMenu, DropdownMenuContent, DropdownMenuItem, DropdownMenuTrigger } from "../ui/dropdown-menu";
import { Input } from "../ui/input";
import { 
  Users, 
  MessageCircle, 
  MoreHorizontal, 
  Flame,
  ArrowLeft,
  Plus,
  Copy,
  ExternalLink,
  Search
} from "lucide-react";
import { toast } from 'sonner@2.0.3';

interface Capture {
  id: string;
  photoUrl: string;
  createdAt: string;
  likes: string[];
  comments: any[];
}

interface FeedGroup {
  id: string;
  user: {
    name: string;
    username: string;
    avatar: string;
  };
  habitName: string;
  habitCategory: string;
  habitStreak: number;
  captures: Capture[];
  lastUpdated: string;
}

interface Friend {
  id: string;
  name: string;
  username: string;
  avatar: string;
}

interface HabitGroup {
  id: string;
  habitName: string;
  habitCategory: string;
  friends: Friend[];
  createdAt: string;
  lastActivity: string;
  totalStreaks: number;
  recentPosts: any[];
}

interface SocialTabsProps {
  posts: any[];
  onToggleLike: (captureId: string) => void;
  formatTimeAgo: (dateString: string) => string;
  groupLastOpened: Record<string, string>;
  onMarkGroupAsRead: (groupId: string) => void;
}

// Helper function to create timestamps for today at different times
const createTodayTimestamp = (hour: number, minute: number = 0) => {
  const today = new Date();
  today.setHours(hour, minute, 0, 0);
  return today.toISOString();
};

const createYesterdayTimestamp = (hour: number, minute: number = 0) => {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  yesterday.setHours(hour, minute, 0, 0);
  return yesterday.toISOString();
};

const createDaysAgoTimestamp = (daysAgo: number, hour: number, minute: number = 0) => {
  const date = new Date();
  date.setDate(date.getDate() - daysAgo);
  date.setHours(hour, minute, 0, 0);
  return date.toISOString();
};

// Mock users who reacted (for demo purposes)
const mockUsers = [
  { id: '1', name: 'Emma Watson', username: 'emma_w', avatar: 'https://images.unsplash.com/photo-1494790108755-2616b23ecfc1?w=40&h=40&fit=crop&crop=face' },
  { id: '2', name: 'Marcus Chen', username: 'marcus_c', avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=40&h=40&fit=crop&crop=face' },
  { id: '3', name: 'Sophie Miller', username: 'sophie_m', avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=40&h=40&fit=crop&crop=face' },
  { id: '4', name: 'Alex Thompson', username: 'alex_t', avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=40&h=40&fit=crop&crop=face' },
  { id: '5', name: 'Luna Rodriguez', username: 'luna_r', avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=40&h=40&fit=crop&crop=face' },
  { id: '6', name: 'James Wilson', username: 'james_w', avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop&crop=face' },
];

// Mock feed groups with multiple captures per user+habit
const mockFeedGroups: FeedGroup[] = [
  {
    id: 'bower-morning-workout',
    user: { name: 'Bower Harry', username: 'bowerharry', avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=40&h=40&fit=crop&crop=face' },
    habitName: 'Morning Workout',
    habitCategory: 'Fitness',
    habitStreak: 23,
    lastUpdated: createTodayTimestamp(8, 15),
    captures: [
      {
        id: 'c1',
        photoUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=300&h=533&fit=crop',
        createdAt: createTodayTimestamp(8, 15),
        likes: ['1', '2', '3', '4', '5', '6', 'current-user'],
        comments: []
      },
      {
        id: 'c2',
        photoUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=300&h=533&fit=crop',
        createdAt: createYesterdayTimestamp(8, 0),
        likes: ['2', '3', 'current-user'],
        comments: []
      },
      {
        id: 'c3',
        photoUrl: 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=300&h=533&fit=crop',
        createdAt: createDaysAgoTimestamp(2, 7, 45),
        likes: ['1', '4'],
        comments: []
      },
      {
        id: 'c4',
        photoUrl: 'https://images.unsplash.com/photo-1583500178690-1ca0d4de0b3d?w=300&h=533&fit=crop',
        createdAt: createDaysAgoTimestamp(3, 8, 30),
        likes: ['2', '5', '6'],
        comments: []
      },
      {
        id: 'c5',
        photoUrl: 'https://images.unsplash.com/photo-1526506118085-60ce8714f8c5?w=300&h=533&fit=crop',
        createdAt: createDaysAgoTimestamp(4, 7, 15),
        likes: ['1', '3', '4', 'current-user'],
        comments: []
      }
    ]
  },
  {
    id: 'emma-meditation',
    user: { name: 'Emma Watson', username: 'emma_w', avatar: 'https://images.unsplash.com/photo-1494790108755-2616b23ecfc1?w=40&h=40&fit=crop&crop=face' },
    habitName: 'Evening Meditation',
    habitCategory: 'Wellness',
    habitStreak: 15,
    lastUpdated: createTodayTimestamp(19, 30),
    captures: [
      {
        id: 'c6',
        photoUrl: 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=300&h=533&fit=crop',
        createdAt: createTodayTimestamp(19, 30),
        likes: ['2', '4', 'current-user'],
        comments: []
      },
      {
        id: 'c7',
        photoUrl: 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=300&h=533&fit=crop',
        createdAt: createYesterdayTimestamp(19, 15),
        likes: ['1', '3'],
        comments: []
      },
      {
        id: 'c8',
        photoUrl: 'https://images.unsplash.com/photo-1618004912476-29818d81ae2e?w=300&h=533&fit=crop',
        createdAt: createDaysAgoTimestamp(2, 20, 0),
        likes: ['5'],
        comments: []
      }
    ]
  },
  {
    id: 'marcus-reading',
    user: { name: 'Marcus Chen', username: 'marcus_c', avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=40&h=40&fit=crop&crop=face' },
    habitName: 'Daily Reading',
    habitCategory: 'Learning',
    habitStreak: 8,
    lastUpdated: createTodayTimestamp(21, 15),
    captures: [
      {
        id: 'c9',
        photoUrl: 'https://images.unsplash.com/photo-1481627834876-b7833e8f5570?w=300&h=533&fit=crop',
        createdAt: createTodayTimestamp(21, 15),
        likes: ['1', '4', '6'],
        comments: []
      },
      {
        id: 'c10',
        photoUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300&h=533&fit=crop',
        createdAt: createYesterdayTimestamp(20, 45),
        likes: ['2', 'current-user'],
        comments: []
      },
      {
        id: 'c11',
        photoUrl: 'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=300&h=533&fit=crop',
        createdAt: createDaysAgoTimestamp(2, 21, 30),
        likes: ['3', '5'],
        comments: []
      },
      {
        id: 'c12',
        photoUrl: 'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=300&h=533&fit=crop',
        createdAt: createDaysAgoTimestamp(3, 22, 0),
        likes: ['1', '2', '4'],
        comments: []
      }
    ]
  },
  {
    id: 'sophie-cooking',
    user: { name: 'Sophie Miller', username: 'sophie_m', avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=40&h=40&fit=crop&crop=face' },
    habitName: 'Healthy Cooking',
    habitCategory: 'Nutrition',
    habitStreak: 12,
    lastUpdated: createTodayTimestamp(18, 45),
    captures: [
      {
        id: 'c13',
        photoUrl: 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=300&h=533&fit=crop',
        createdAt: createTodayTimestamp(18, 45),
        likes: ['1', '2', '5', 'current-user'],
        comments: []
      },
      {
        id: 'c14',
        photoUrl: 'https://images.unsplash.com/photo-1540189549336-e6e99c3679fe?w=300&h=533&fit=crop',
        createdAt: createYesterdayTimestamp(19, 0),
        likes: ['3', '4'],
        comments: []
      },
      {
        id: 'c15',
        photoUrl: 'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=300&h=533&fit=crop',
        createdAt: createDaysAgoTimestamp(2, 18, 30),
        likes: ['1', '6'],
        comments: []
      }
    ]
  }
];

// Mock friend groups tracking habits together
const mockHabitGroups: HabitGroup[] = [
  {
    id: '1',
    habitName: 'Morning Run',
    habitCategory: 'Fitness',
    friends: [
      { id: '1', name: 'Emma Watson', username: 'emma_w', avatar: 'https://images.unsplash.com/photo-1494790108755-2616b23ecfc1?w=40&h=40&fit=crop&crop=face' },
      { id: '2', name: 'Marcus Chen', username: 'marcus_c', avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=40&h=40&fit=crop&crop=face' },
      { id: '3', name: 'Sophie Miller', username: 'sophie_m', avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=40&h=40&fit=crop&crop=face' },
      { id: '4', name: 'Bower Harry', username: 'bowerharry', avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=40&h=40&fit=crop&crop=face' }
    ],
    createdAt: '2024-01-15T08:00:00Z',
    lastActivity: createTodayTimestamp(7, 30),
    totalStreaks: 47,
    recentPosts: []
  },
  {
    id: '2',
    habitName: 'Book Club',
    habitCategory: 'Learning',
    friends: [
      { id: '2', name: 'Marcus Chen', username: 'marcus_c', avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=40&h=40&fit=crop&crop=face' },
      { id: '3', name: 'Sophie Miller', username: 'sophie_m', avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=40&h=40&fit=crop&crop=face' },
      { id: '5', name: 'Luna Rodriguez', username: 'luna_r', avatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=40&h=40&fit=crop&crop=face' }
    ],
    createdAt: '2024-01-20T10:00:00Z',
    lastActivity: createYesterdayTimestamp(20, 15),
    totalStreaks: 28,
    recentPosts: []
  },
  {
    id: '3',
    habitName: 'Healthy Eating',
    habitCategory: 'Nutrition',
    friends: [
      { id: '1', name: 'Emma Watson', username: 'emma_w', avatar: 'https://images.unsplash.com/photo-1494790108755-2616b23ecfc1?w=40&h=40&fit=crop&crop=face' },
      { id: '3', name: 'Sophie Miller', username: 'sophie_m', avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=40&h=40&fit=crop&crop=face' },
      { id: '4', name: 'Bower Harry', username: 'bowerharry', avatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=40&h=40&fit=crop&crop=face' },
      { id: '6', name: 'James Wilson', username: 'james_w', avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop&crop=face' }
    ],
    createdAt: '2024-01-25T14:00:00Z',
    lastActivity: createTodayTimestamp(12, 30),
    totalStreaks: 35,
    recentPosts: []
  }
];

export function SocialTabs({ posts, onToggleLike, formatTimeAgo, groupLastOpened, onMarkGroupAsRead }: SocialTabsProps) {
  const [habitGroups, setHabitGroups] = useState<HabitGroup[]>(mockHabitGroups);
  const [selectedGroup, setSelectedGroup] = useState<HabitGroup | null>(null);
  const [selectedCaptures, setSelectedCaptures] = useState<Record<string, string>>({});
  const [searchQuery, setSearchQuery] = useState('');

  // Use mock feed groups as display data
  const displayFeedGroups = mockFeedGroups;

  // Filter groups based on search query
  const filteredGroups = habitGroups.filter(group => {
    const query = searchQuery.toLowerCase();
    const matchesHabitName = group.habitName.toLowerCase().includes(query);
    const matchesCategory = group.habitCategory.toLowerCase().includes(query);
    const matchesUsernames = group.friends.some(friend => 
      friend.name.toLowerCase().includes(query) || 
      friend.username.toLowerCase().includes(query)
    );
    
    return matchesHabitName || matchesCategory || matchesUsernames;
  });

  // Use the same category styling as Dashboard for consistency
  const getCategoryData = (category: string) => {
    const categories = {
      'Fitness': { emoji: '💪', color: 'bg-red-100 text-red-700' },
      'Wellness': { emoji: '🧘', color: 'bg-green-100 text-green-700' },
      'Learning': { emoji: '📚', color: 'bg-blue-100 text-blue-700' },
      'Nutrition': { emoji: '🥗', color: 'bg-orange-100 text-orange-700' },
      'Productivity': { emoji: '⚡', color: 'bg-purple-100 text-purple-700' },
      'Health': { emoji: '🏥', color: 'bg-pink-100 text-pink-700' },
      'Social': { emoji: '🤝', color: 'bg-yellow-100 text-yellow-700' }
    };
    return categories[category as keyof typeof categories] || { emoji: '🎯', color: 'bg-gray-100 text-gray-700' };
  };

  const handleGroupClick = (group: HabitGroup) => {
    setSelectedGroup(group);
    onMarkGroupAsRead(group.id);
  };

  const handleBackToGroups = () => {
    setSelectedGroup(null);
  };

  const handleShare = (captureId: string, type: 'copy' | 'external') => {
    if (type === 'copy') {
      navigator.clipboard.writeText(`Check out this habit capture: ${window.location.origin}/capture/${captureId}`);
      toast.success('Link copied to clipboard!');
    } else {
      toast.success('Share feature coming soon!');
    }
  };

  const handleCreateGroup = () => {
    toast.success('Create group feature coming soon!');
  };

  // Get user avatars who reacted to a capture
  const getReactionAvatars = (likes: string[]) => {
    return likes.slice(0, 4).map(userId => {
      if (userId === 'current-user') {
        return {
          id: 'current-user',
          name: 'You',
          avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop&crop=face'
        };
      }
      return mockUsers.find(user => user.id === userId) || {
        id: userId,
        name: 'User',
        avatar: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=40&h=40&fit=crop&crop=face'
      };
    });
  };

  // Check if current user has reacted
  const hasUserReacted = (likes: string[]) => {
    return likes.includes('current-user');
  };

  // Get selected capture for a group
  const getSelectedCapture = (groupId: string, captures: Capture[]) => {
    const selectedId = selectedCaptures[groupId];
    if (selectedId) {
      return captures.find(c => c.id === selectedId) || captures[0];
    }
    return captures[0]; // Default to most recent
  };

  // Handle capture selection from preview row
  const handleCaptureSelect = (groupId: string, captureId: string) => {
    setSelectedCaptures(prev => ({
      ...prev,
      [groupId]: captureId
    }));
  };

  // Get other captures excluding the current selection
  // Sort oldest to newest so timeline flows left-to-right chronologically
  const getOtherCaptures = (group: FeedGroup, selectedCapture: Capture) => {
    return group.captures
      .filter(capture => capture.id !== selectedCapture.id)
      .sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
    // Array[0] = oldest remaining = rightmost position = SMALLEST size (newest previews are largest)
  };

  // Render reaction stats component
  const ReactionStats = ({ captureId, likes }: { captureId: string; likes: string[] }) => {
    if (likes.length === 0) return null;

    const reactionAvatars = getReactionAvatars(likes);
    const totalReactions = likes.length;

    return (
      <div className="flex items-center space-x-2">
        <div className="flex -space-x-1">
          {reactionAvatars.map((user, index) => (
            <Avatar key={user.id} className="w-6 h-6 border-2 border-background">
              <AvatarImage src={user.avatar} />
              <AvatarFallback className="text-xs">{user.name.charAt(0)}</AvatarFallback>
            </Avatar>
          ))}
        </div>
        <span className="text-sm text-muted-foreground">
          {totalReactions} reacted
        </span>
      </div>
    );
  };

  // Render action buttons
  const ActionButtons = ({ captureId, likes }: { captureId: string; likes: string[] }) => {
    const userHasReacted = hasUserReacted(likes);

    const handleReact = () => {
      onToggleLike(captureId);
      toast.success(userHasReacted ? 'Reaction removed! 🔥' : 'Reacted with fire! 🔥');
    };

    return (
      <div className="flex items-center justify-center space-x-4">
        {/* Fire React Button */}
        <Button 
          variant="ghost" 
          size="sm" 
          onClick={handleReact}
          className={`p-2 hover:bg-orange-50 hover:text-orange-600 transition-colors ${
            userHasReacted ? 'text-orange-600 bg-orange-50' : 'text-muted-foreground'
          }`}
        >
          <Flame 
            size={20} 
            className={userHasReacted ? 'fill-current' : 'stroke-current fill-none'} 
          />
        </Button>

        {/* Comment Button */}
        <Button 
          variant="ghost" 
          size="sm" 
          className="p-2 text-muted-foreground hover:bg-accent hover:text-accent-foreground transition-colors"
        >
          <MessageCircle size={20} />
        </Button>
      </div>
    );
  };

  // Render individual group feed
  if (selectedGroup) {
    return (
      <div className="space-y-4">
        {/* Group Header */}
        <div className="flex items-center space-x-3">
          <Button
            variant="ghost"
            size="sm"
            onClick={handleBackToGroups}
            className="p-2"
          >
            <ArrowLeft size={16} />
          </Button>
          <div className="flex-1">
            <div className="flex items-center space-x-2">
              <h2 className="font-semibold">{selectedGroup.habitName}</h2>
              <Badge className={`${getCategoryData(selectedGroup.habitCategory).color} px-2 py-1 text-xs border-0`}>
                {getCategoryData(selectedGroup.habitCategory).emoji} {selectedGroup.habitCategory}
              </Badge>
            </div>
            <div className="flex items-center space-x-2 text-sm text-muted-foreground">
              <div className="flex -space-x-1">
                {selectedGroup.friends.slice(0, 3).map((friend) => (
                  <Avatar key={friend.id} className="w-5 h-5 border border-background">
                    <AvatarImage src={friend.avatar} />
                    <AvatarFallback className="text-xs">{friend.name.charAt(0)}</AvatarFallback>
                  </Avatar>
                ))}
              </div>
              <span>{selectedGroup.friends.length} friends</span>
              <span>•</span>
              <span className="flex items-center space-x-1 text-orange-500">
                <Flame size={12} />
                <span>{selectedGroup.totalStreaks} total streaks</span>
              </span>
            </div>
          </div>
        </div>

        {/* Group Feed */}
        <div className="space-y-6">
          <Card>
            <CardContent className="pt-6 text-center space-y-4">
              <div className="text-4xl">{getCategoryData(selectedGroup.habitCategory).emoji}</div>
              <div>
                <h3 className="font-medium">Group feed coming soon!</h3>
                <p className="text-muted-foreground mt-1 text-sm">
                  Check out the main feed to see individual captures
                </p>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    );
  }

  return (
    <div>
      <Tabs defaultValue="feed" className="space-y-4">
        <TabsList className="grid w-full grid-cols-2">
          <TabsTrigger value="feed" className="flex items-center space-x-2">
            <span>🎯</span>
            <span>Feed</span>
          </TabsTrigger>
          <TabsTrigger value="groups" className="flex items-center space-x-2">
            <Users size={16} />
            <span>Groups</span>
          </TabsTrigger>
        </TabsList>

        <TabsContent value="feed" className="space-y-4">
          {displayFeedGroups.length === 0 ? (
            <Card>
              <CardContent className="pt-6 text-center space-y-4">
                <div className="text-6xl">👥</div>
                <div>
                  <h3 className="text-lg font-medium">No posts yet</h3>
                  <p className="text-muted-foreground mt-1">
                    Complete some habits or follow friends to see their progress here!
                  </p>
                </div>
              </CardContent>
            </Card>
          ) : (
            <div className="space-y-6">
              {displayFeedGroups.map((group) => {
                const selectedCapture = getSelectedCapture(group.id, group.captures);
                const otherCaptures = getOtherCaptures(group, selectedCapture);
                
                return (
                  <Card key={group.id} className="overflow-hidden">
                    {/* Main Capture Image with Overlaid Header - Phone camera aspect ratio (9:16) */}
                    <div className="relative overflow-hidden" style={{ aspectRatio: '9/16' }}>
                      <img 
                        src={selectedCapture.photoUrl} 
                        alt="Habit capture"
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          (e.target as HTMLImageElement).src = 'https://images.unsplash.com/photo-1516637090014-890d46927ba4?w=300&h=533&fit=crop';
                        }}
                      />
                      
                      {/* Category Badge - Bookmark Style in Top Right with Bottom Margin */}
                      <div className="absolute top-0 right-3 z-20 mb-4">
                        <Badge className={`${getCategoryData(group.habitCategory).color} px-3 py-1.5 text-xs border-0 shadow-lg rounded-b-md rounded-t-none`}>
                          {getCategoryData(group.habitCategory).emoji} {group.habitCategory}
                        </Badge>
                      </div>
                      
                      {/* Overlaid Header Information */}
                      <div className="absolute top-0 left-0 right-0">
                        {/* Top gradient overlay for readability */}
                        <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-black/20 to-transparent pointer-events-none" />
                        
                        <div className="relative p-4 pb-6 pt-12">
                          <div className="flex items-center justify-between">
                            <div className="flex items-center space-x-3">
                              <Avatar className="w-10 h-10 ring-2 ring-white/20">
                                <AvatarImage src={group.user?.avatar} />
                                <AvatarFallback className="bg-white/10 text-white backdrop-blur-sm">
                                  {group.user?.name?.charAt(0) || '?'}
                                </AvatarFallback>
                              </Avatar>
                              <div>
                                <p className="font-medium text-white drop-shadow-md">{group.user?.name || 'Anonymous'}</p>
                                <div className="flex items-center space-x-2 text-sm text-white/80">
                                  <span>@{group.user?.username || 'user'}</span>
                                  <span>•</span>
                                  <span>{formatTimeAgo(selectedCapture.createdAt)}</span>
                                </div>
                              </div>
                            </div>
                            <div className="flex items-center space-x-2">
                              <div className="flex items-center text-orange-400 bg-black/20 backdrop-blur-sm rounded-full px-2 py-1">
                                <Flame size={14} />
                                <span className="text-sm font-medium ml-1">{group.habitStreak}</span>
                              </div>
                              <DropdownMenu>
                                <DropdownMenuTrigger asChild>
                                  <Button variant="ghost" size="sm" className="p-2 text-white/80 hover:text-white hover:bg-white/10 backdrop-blur-sm">
                                    <MoreHorizontal size={16} />
                                  </Button>
                                </DropdownMenuTrigger>
                                <DropdownMenuContent align="end">
                                  <DropdownMenuItem onClick={() => handleShare(selectedCapture.id, 'copy')}>
                                    <Copy size={16} className="mr-2" />
                                    Copy link
                                  </DropdownMenuItem>
                                  <DropdownMenuItem onClick={() => handleShare(selectedCapture.id, 'external')}>
                                    <ExternalLink size={16} className="mr-2" />
                                    Share externally
                                  </DropdownMenuItem>
                                </DropdownMenuContent>
                              </DropdownMenu>
                            </div>
                          </div>
                        </div>
                      </div>
                      
                      {/* Previous Captures Preview Overlay */}
                      {otherCaptures.length > 0 && (
                        <div className="absolute bottom-0 left-0 right-0 p-3">
                          <div className="flex justify-end items-end space-x-2 overflow-x-auto no-scrollbar">
                            {otherCaptures.map((capture, index) => {
                              // REVERSED SIZING: rightmost (oldest) is smallest, leftmost (newest) is largest
                              const getSizeForIndex = (idx: number) => {
                                if (idx === 0) return '26px'; // Smallest - oldest remaining (rightmost, furthest back)
                                if (idx === 1) return '32px'; // Small - second oldest
                                if (idx === 2) return '38px'; // Medium - third oldest  
                                if (idx === 3) return '46px'; // Large - fourth oldest
                                return '56px'; // 🔥 LARGEST - newest remaining (leftmost, most recent)
                              };
                              
                              const width = getSizeForIndex(index);
                              
                              return (
                                <button
                                  key={capture.id}
                                  onClick={() => handleCaptureSelect(group.id, capture.id)}
                                  className="flex-shrink-0 relative rounded-md overflow-hidden transition-all hover:scale-110 hover:shadow-lg bg-white/90 backdrop-blur-sm border border-white/50"
                                  style={{ aspectRatio: '9/16', width }}
                                >
                                  <img 
                                    src={capture.photoUrl} 
                                    alt="Previous capture"
                                    className="w-full h-full object-cover"
                                  />
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      )}
                    </div>

                    {/* Habit Info - Below Image (Compact) */}
                    <div className="px-4 pt-2 pb-1">
                      <div className="flex items-center justify-between">
                        <span className="text-sm font-medium">{group.habitName}</span>
                        {group.captures.length > 1 && (
                          <span className="text-xs text-muted-foreground">
                            {group.captures.length} captures
                          </span>
                        )}
                      </div>
                    </div>

                    {/* Capture Reactions and Actions (Compact) */}
                    <div className="px-4 pb-3">
                      <div className="space-y-1.5">
                        {/* Reaction Stats */}
                        <ReactionStats captureId={selectedCapture.id} likes={selectedCapture.likes} />
                        
                        {/* Action Buttons */}
                        <ActionButtons captureId={selectedCapture.id} likes={selectedCapture.likes} />
                      </div>
                    </div>
                  </Card>
                );
              })}
            </div>
          )}
        </TabsContent>

        <TabsContent value="groups" className="space-y-4">
          {/* Search and Add Bar */}
          <div className="flex items-center space-x-3 w-full">
            <div className="flex-1 relative">
              <Search size={16} className="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground" />
              <Input
                placeholder="Search groups by habit, category, or friends..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-10 bg-input-background border-0 h-10"
              />
            </div>
            <Button 
              onClick={handleCreateGroup}
              size="sm"
              className="h-10 w-10 bg-primary hover:bg-primary/90 text-primary-foreground flex items-center justify-center"
            >
              <Plus size={16} />
            </Button>
          </div>

          {/* Groups List */}
          <div className="space-y-4">
            {filteredGroups.length === 0 ? (
              <Card>
                <CardContent className="pt-6 text-center space-y-4">
                  <div className="text-4xl">🔍</div>
                  <div>
                    <h3 className="font-medium">
                      {searchQuery ? 'No groups found' : 'No groups yet'}
                    </h3>
                    <p className="text-muted-foreground mt-1 text-sm">
                      {searchQuery 
                        ? `No groups match "${searchQuery}". Try a different search term.`
                        : 'Create your first group to start tracking habits with friends!'
                      }
                    </p>
                  </div>
                </CardContent>
              </Card>
            ) : (
              filteredGroups.map((group) => (
                <Card 
                  key={group.id} 
                  className="hover:shadow-md transition-all cursor-pointer hover:bg-accent/5"
                  onClick={() => handleGroupClick(group)}
                >
                  <CardContent className="p-4">
                    <div className="space-y-3">
                      {/* Group Name and Friend Icons - Same Line */}
                      <div className="flex items-center justify-between">
                        <h3 className="font-semibold text-lg">{group.habitName}</h3>
                        
                        {/* Friend Icons - Right Aligned */}
                        <div className="flex items-center space-x-1">
                          {group.friends.slice(0, 4).map((friend) => (
                            <div key={friend.id} className="relative">
                              <Avatar className="w-8 h-8">
                                <AvatarImage src={friend.avatar} />
                                <AvatarFallback className="text-xs">{friend.name.charAt(0)}</AvatarFallback>
                              </Avatar>
                            </div>
                          ))}
                          {group.friends.length > 4 && (
                            <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center text-xs text-muted-foreground">
                              +{group.friends.length - 4}
                            </div>
                          )}
                        </div>
                      </div>

                      <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-2">
                          <Badge className={`${getCategoryData(group.habitCategory).color} px-2 py-1 text-xs border-0`}>
                            {getCategoryData(group.habitCategory).emoji} {group.habitCategory}
                          </Badge>
                          <span className="text-sm text-muted-foreground">
                            Last active {formatTimeAgo(group.lastActivity)}
                          </span>
                        </div>
                        
                        <div className="text-right">
                          <div className="flex items-center space-x-1 text-orange-500">
                            <Flame size={12} />
                            <span className="text-xs font-medium">{group.totalStreaks}</span>
                          </div>
                          <span className="text-xs text-muted-foreground">total streaks</span>
                        </div>
                      </div>
                    </div>
                  </CardContent>
                </Card>
              ))
            )}
          </div>
        </TabsContent>
      </Tabs>
    </div>
  );
}