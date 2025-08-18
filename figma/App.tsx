import { useState, useEffect } from 'react';
import { AuthProvider, useAuth } from './components/AuthContext';
import { AuthScreen } from './components/AuthScreen';
import { BottomNav } from './components/BottomNav';
import { Dashboard } from './components/Dashboard';
import { CameraCapture } from './components/CameraCapture';
import { SocialFeed } from './components/SocialFeed';
import { Discovery } from './components/Discovery';
import { Profile } from './components/Profile';
import { Toaster } from './components/ui/sonner';
import { toast } from 'sonner@2.0.3';

function AppContent() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [showCamera, setShowCamera] = useState(false);
  const [captureHabitId, setCaptureHabitId] = useState<string | undefined>();
  
  // Track when specific groups were last opened (not just social tab)
  const [groupLastOpened, setGroupLastOpened] = useState<Record<string, string>>(() => {
    const stored = localStorage.getItem('group-last-opened');
    if (stored) {
      try {
        return JSON.parse(stored);
      } catch {
        return {};
      }
    }
    return {};
  });

  const { user, loading } = useAuth();

  const handleCaptureHabit = (habitId: string) => {
    setCaptureHabitId(habitId);
    setShowCamera(true);
  };

  const handlePhotoTaken = (photo: string, habitId?: string) => {
    toast.success('Great job! Your habit photo has been saved. 📸');
    setShowCamera(false);
    setCaptureHabitId(undefined);
    
    // Switch to social tab after capturing to show the social aspect
    setTimeout(() => {
      setActiveTab('social');
    }, 1000);
  };

  const handleTabChange = (tab: string) => {
    if (tab === 'capture') {
      setShowCamera(true);
    } else {
      setActiveTab(tab);
    }
  };

  // Function to mark a group as read when opened
  const markGroupAsRead = (groupId: string) => {
    const now = new Date().toISOString();
    const updatedGroupTimes = {
      ...groupLastOpened,
      [groupId]: now
    };
    setGroupLastOpened(updatedGroupTimes);
    localStorage.setItem('group-last-opened', JSON.stringify(updatedGroupTimes));
  };

  const renderActiveTab = () => {
    switch (activeTab) {
      case 'dashboard':
        return <Dashboard onCaptureHabit={handleCaptureHabit} />;
      case 'social':
        return <SocialFeed groupLastOpened={groupLastOpened} onMarkGroupAsRead={markGroupAsRead} />;
      case 'discover':
        return <Discovery />;
      case 'profile':
        return <Profile />;
      default:
        return <Dashboard onCaptureHabit={handleCaptureHabit} />;
    }
  };

  // Show loading screen while checking authentication
  if (loading) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="text-center space-y-4">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary mx-auto"></div>
          <p className="text-muted-foreground">Loading Capture...</p>
        </div>
      </div>
    );
  }

  // Show auth screen if user is not logged in
  if (!user) {
    return <AuthScreen />;
  }

  // Show main app if user is authenticated
  return (
    <div className="min-h-screen bg-background overflow-x-hidden pb-24">
      {/* Main Content */}
      {renderActiveTab()}
      
      {/* Floating Bottom Navigation */}
      <BottomNav activeTab={activeTab} onTabChange={handleTabChange} />
      
      {/* Camera Modal */}
      {showCamera && (
        <CameraCapture
          habitId={captureHabitId}
          onClose={() => {
            setShowCamera(false);
            setCaptureHabitId(undefined);
          }}
          onPhotoTaken={handlePhotoTaken}
        />
      )}
      
      {/* Toast Notifications */}
      <Toaster />
    </div>
  );
}

export default function App() {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  );
}