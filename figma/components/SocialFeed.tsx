import { useState, useEffect } from 'react';
import { api } from '../utils/api';
import { toast } from 'sonner@2.0.3';
import { PullToRefresh } from './PullToRefresh';
import { SocialTabs } from './social/SocialTabs';

interface FeedPost {
  id: string;
  user: {
    name: string;
    username: string;
    avatar: string;
  };
  habitName: string;
  habitCategory: string;
  habitStreak: number;
  photoUrl: string;
  createdAt: string;
  likes: string[];
  comments: any[];
}

interface SocialFeedProps {
  groupLastOpened: Record<string, string>;
  onMarkGroupAsRead: (groupId: string) => void;
}

export function SocialFeed({ groupLastOpened, onMarkGroupAsRead }: SocialFeedProps) {
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadFeed(false);
  }, []);

  // Auto refresh when component gains focus
  useEffect(() => {
    const handleFocus = () => {
      if (!loading) {
        console.log('🎯 SocialFeed: App gained focus, refreshing data');
        loadFeed(false);
      }
    };

    window.addEventListener('focus', handleFocus);
    return () => window.removeEventListener('focus', handleFocus);
  }, [loading]);

  const loadFeed = async (showToast = true) => {
    try {
      setLoading(true);
      const response = await api.getFeed();
      setPosts(response.posts || []);
      if (showToast) toast.success('Feed refreshed! 🔄');
    } catch (error) {
      console.error('Error loading feed:', error);
      if (showToast) toast.error('Failed to load social feed');
    } finally {
      setLoading(false);
    }
  };

  const handleRefresh = async () => {
    console.log('🔄 Pull to refresh triggered on SocialFeed');
    await loadFeed(false);
  };

  const toggleLike = async (postId: string) => {
    try {
      const response = await api.toggleLike(postId);
      
      setPosts(prevPosts => 
        prevPosts.map(post => {
          if (post.id === postId) {
            const updatedLikes = response.liked 
              ? [...(post.likes || []), 'current-user'] // Simplified - in real app would use actual user ID
              : (post.likes || []).filter(id => id !== 'current-user');
            
            return {
              ...post,
              likes: updatedLikes
            };
          }
          return post;
        })
      );
      
      if (response.liked) {
        toast.success('Liked! ❤️');
      }
    } catch (error) {
      console.error('Error toggling like:', error);
      toast.error('Failed to update like');
    }
  };

  const formatTimeAgo = (dateString: string) => {
    const now = new Date();
    const date = new Date(dateString);
    const diffInMinutes = Math.floor((now.getTime() - date.getTime()) / (1000 * 60));
    
    if (diffInMinutes < 60) {
      return `${diffInMinutes}m ago`;
    } else if (diffInMinutes < 1440) {
      return `${Math.floor(diffInMinutes / 60)}h ago`;
    } else {
      return `${Math.floor(diffInMinutes / 1440)}d ago`;
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-background via-background to-accent/10">
        <div className="p-4 space-y-4">
          <div className="animate-pulse space-y-6">
            <div className="h-8 bg-gray-200 rounded w-1/2"></div>
            {[...Array(3)].map((_, i) => (
              <div key={i} className="space-y-4">
                <div className="flex items-center space-x-3">
                  <div className="w-10 h-10 bg-gray-200 rounded-full"></div>
                  <div className="space-y-2 flex-1">
                    <div className="h-4 bg-gray-200 rounded w-1/3"></div>
                    <div className="h-3 bg-gray-200 rounded w-1/4"></div>
                  </div>
                </div>
                <div className="aspect-square bg-gray-200 rounded"></div>
                <div className="h-8 bg-gray-200 rounded w-1/4"></div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  return (
    <PullToRefresh onRefresh={handleRefresh} className="min-h-screen bg-gradient-to-br from-background via-background to-accent/10">
      <div className="px-4 pt-4 space-y-6">
        <SocialTabs 
          posts={posts}
          onToggleLike={toggleLike}
          formatTimeAgo={formatTimeAgo}
          groupLastOpened={groupLastOpened}
          onMarkGroupAsRead={onMarkGroupAsRead}
        />
      </div>
    </PullToRefresh>
  );
}