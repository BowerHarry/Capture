import { useState, useRef, useEffect, ReactNode } from 'react';
import { RefreshCw } from 'lucide-react';

interface PullToRefreshProps {
  onRefresh: () => Promise<void>;
  children: ReactNode;
  className?: string;
}

export function PullToRefresh({ onRefresh, children, className = '' }: PullToRefreshProps) {
  const [isPulling, setIsPulling] = useState(false);
  const [pullDistance, setPullDistance] = useState(0);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const startY = useRef(0);
  const currentY = useRef(0);
  const pullThreshold = 80;
  const maxPull = 120;

  const handleTouchStart = (e: TouchEvent) => {
    if (window.scrollY === 0) {
      startY.current = e.touches[0].clientY;
      setIsPulling(true);
    }
  };

  const handleTouchMove = (e: TouchEvent) => {
    if (!isPulling || window.scrollY > 0) return;

    currentY.current = e.touches[0].clientY;
    const pullDist = Math.max(0, currentY.current - startY.current);
    const adjustedPullDist = Math.min(pullDist * 0.6, maxPull);
    
    setPullDistance(adjustedPullDist);

    if (adjustedPullDist > 0) {
      e.preventDefault();
    }
  };

  const handleTouchEnd = async () => {
    if (pullDistance > pullThreshold && !isRefreshing) {
      setIsRefreshing(true);
      try {
        await onRefresh();
      } catch (error) {
        console.error('Refresh failed:', error);
      } finally {
        setIsRefreshing(false);
      }
    }
    
    setIsPulling(false);
    setPullDistance(0);
  };

  useEffect(() => {
    const element = document.body;
    
    element.addEventListener('touchstart', handleTouchStart, { passive: true });
    element.addEventListener('touchmove', handleTouchMove, { passive: false });
    element.addEventListener('touchend', handleTouchEnd, { passive: true });

    return () => {
      element.removeEventListener('touchstart', handleTouchStart);
      element.removeEventListener('touchmove', handleTouchMove);
      element.removeEventListener('touchend', handleTouchEnd);
    };
  }, [isPulling, pullDistance, isRefreshing]);

  const shouldShowRefreshIndicator = pullDistance > 20 || isRefreshing;
  const refreshOpacity = Math.min(pullDistance / pullThreshold, 1);
  const refreshRotation = isRefreshing ? 'animate-spin' : '';

  return (
    <div className={`relative ${className}`}>
      {/* Pull to refresh indicator */}
      {shouldShowRefreshIndicator && (
        <div 
          className="absolute top-0 left-0 right-0 z-50 flex items-center justify-center bg-background/80 backdrop-blur-sm border-b border-border/30"
          style={{
            height: `${Math.max(40, pullDistance)}px`,
            opacity: refreshOpacity,
            transform: `translateY(${pullDistance - 40}px)`
          }}
        >
          <div className="flex items-center space-x-2 text-muted-foreground">
            <RefreshCw 
              size={16} 
              className={`${refreshRotation} ${pullDistance > pullThreshold ? 'text-primary' : ''}`}
            />
            <span className="text-sm">
              {isRefreshing ? 'Refreshing...' : pullDistance > pullThreshold ? 'Release to refresh' : 'Pull to refresh'}
            </span>
          </div>
        </div>
      )}
      
      {/* Content */}
      <div 
        style={{ 
          transform: `translateY(${pullDistance}px)`,
          transition: isPulling ? 'none' : 'transform 0.3s ease-out'
        }}
      >
        {children}
      </div>
    </div>
  );
}