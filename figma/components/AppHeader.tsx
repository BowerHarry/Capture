import { Camera } from 'lucide-react';

interface AppHeaderProps {
  className?: string;
  showOnlyText?: boolean;
}

export function AppHeader({ className = '', showOnlyText = false }: AppHeaderProps) {
  return (
    <div className={`flex items-center justify-between p-4 pb-2 ${className}`}>
      <div className="flex items-center space-x-2">
        {!showOnlyText && (
          <div className="relative">
            <div className="w-8 h-8 bg-gradient-to-br from-primary to-primary/80 rounded-xl flex items-center justify-center shadow-sm">
              <Camera size={16} className="text-primary-foreground" />
            </div>
            <div className="absolute -top-0.5 -right-0.5 w-2 h-2 bg-orange-500 rounded-full animate-pulse"></div>
          </div>
        )}
        <h1 className="text-xl font-bold bg-gradient-to-r from-primary to-primary/70 bg-clip-text text-transparent">
          Capture
        </h1>
      </div>
      
      {/* Optional right side content can be added here */}
      <div className="flex items-center space-x-2">
        {/* Space for future header actions */}
      </div>
    </div>
  );
}