import { Home, Users, Search, Camera, User } from 'lucide-react';
import { Button } from './ui/button';

interface BottomNavProps {
  activeTab: string;
  onTabChange: (tab: string) => void;
}

export function BottomNav({ activeTab, onTabChange }: BottomNavProps) {
  const tabs = [
    {
      id: 'dashboard',
      label: 'Home',
      icon: Home,
      gradient: 'from-blue-500 to-purple-600'
    },
    {
      id: 'social',
      label: 'Feed',
      icon: Users,
      gradient: 'from-pink-500 to-rose-600'
    },
    {
      id: 'capture',
      label: 'Capture',
      icon: Camera,
      gradient: 'from-orange-500 to-red-600',
      isSpecial: true
    },
    {
      id: 'discover',
      label: 'Discover',
      icon: Search,
      gradient: 'from-green-500 to-emerald-600'
    },
    {
      id: 'profile',
      label: 'Profile',
      icon: User,
      gradient: 'from-amber-500 to-yellow-600'
    }
  ];

  return (
    <div className="fixed bottom-6 left-1/2 transform -translate-x-1/2 z-50">
      <div className="bg-background/90 backdrop-blur-xl border border-border/50 rounded-2xl shadow-2xl px-3 py-2">
        <div className="flex items-center justify-center space-x-2">
          {tabs.map((tab) => {
          const isActive = activeTab === tab.id;
          const IconComponent = tab.icon;
          
          if (tab.isSpecial) {
            return (
              <Button
                key={tab.id}
                onClick={() => onTabChange(tab.id)}
                className="p-0 bg-transparent hover:bg-transparent focus:bg-transparent"
                size="sm"
                variant="ghost"
              >
                <div className={`
                  relative p-2 rounded-xl transition-all duration-200
                  ${isActive 
                    ? `bg-gradient-to-r ${tab.gradient} text-white shadow-lg hover:shadow-xl` 
                    : 'border-2 border-border/40 text-muted-foreground hover:text-foreground hover:bg-accent hover:border-border/70'
                  }
                  hover:scale-110 active:scale-95
                `}>
                  {isActive && (
                    <div className="absolute inset-0 bg-gradient-to-r from-white/20 to-transparent rounded-xl"></div>
                  )}
                  <IconComponent size={16} className={isActive ? "relative z-10" : ""} />
                </div>
              </Button>
            );
          }
          
          return (
            <Button
              key={tab.id}
              variant="ghost"
              onClick={() => onTabChange(tab.id)}
              className="p-0 hover:bg-transparent"
              size="sm"
            >
              <div className={`
                p-2 rounded-xl transition-all duration-200
                ${isActive 
                  ? `bg-gradient-to-r ${tab.gradient} text-white shadow-md hover:scale-105` 
                  : 'text-muted-foreground hover:text-foreground hover:bg-accent'
                }
              `}>
                <IconComponent size={16} />
              </div>
            </Button>
          );
        })}
        </div>
      </div>
    </div>
  );
}