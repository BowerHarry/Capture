import React from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "../ui/dialog";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Label } from "../ui/label";
import { Card, CardContent } from "../ui/card";
import { Badge } from "../ui/badge";
import { EMOJI_OPTIONS, HABIT_CATEGORIES, COLOR_OPTIONS, TARGET_PERIODS } from "./constants";

interface NewHabit {
  name: string;
  category: string;
  description: string;
  targetNumber: number;
  targetPeriod: 'day' | 'week' | 'month';
  icon?: string;
  color?: string;
}

interface CustomizeHabitDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  presetHabit?: any;
  onCreateHabit: (e: React.FormEvent) => void;
  newHabit: NewHabit;
  setNewHabit: (habit: NewHabit) => void;
}

export function CustomizeHabitDialog({ 
  open, 
  onOpenChange, 
  presetHabit, 
  onCreateHabit, 
  newHabit, 
  setNewHabit 
}: CustomizeHabitDialogProps) {
  
  // Initialize form with preset data if provided
  React.useEffect(() => {
    if (presetHabit) {
      setNewHabit({
        name: presetHabit.name,
        category: presetHabit.category,
        description: presetHabit.description || '',
        targetNumber: presetHabit.targetNumber,
        targetPeriod: presetHabit.targetPeriod,
        icon: presetHabit.icon || presetHabit.emoji,
        color: presetHabit.color?.includes('bg-') ? presetHabit.color.split(' ')[0] : 'bg-blue-500'
      });
    }
  }, [presetHabit, setNewHabit]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newHabit.name.trim() || !newHabit.category) return;
    
    onCreateHabit(e);
    onOpenChange(false);
    
    // Reset form for next time
    setNewHabit({ 
      name: '', 
      category: '', 
      description: '', 
      targetNumber: 1, 
      targetPeriod: 'day',
      icon: '🎯',
      color: 'bg-blue-500'
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="text-2xl font-bold text-center">
            Customize Your Habit
          </DialogTitle>
          <DialogDescription className="text-center text-muted-foreground">
            Personalize your habit with an icon, category, color, and target
          </DialogDescription>
        </DialogHeader>
        
        <form onSubmit={handleSubmit} className="space-y-6 mt-6">
          {/* Habit Name */}
          <div className="space-y-2">
            <Label htmlFor="habitName">Habit Name</Label>
            <Input
              id="habitName"
              value={newHabit.name}
              onChange={(e) => setNewHabit({ ...newHabit, name: e.target.value })}
              placeholder="Enter habit name..."
              className="w-full"
            />
          </div>

          {/* Icon Selection (8x2 grid) */}
          <div className="space-y-3">
            <Label>Icon</Label>
            <div className="grid grid-cols-8 gap-2">
              {EMOJI_OPTIONS.map((emoji, index) => (
                <Button
                  key={index}
                  type="button"
                  variant="outline"
                  size="sm"
                  className={`h-10 p-0 ${newHabit.icon === emoji ? 'ring-2 ring-primary' : ''}`}
                  onClick={() => setNewHabit({ ...newHabit, icon: emoji })}
                >
                  <span className="text-lg">{emoji}</span>
                </Button>
              ))}
            </div>
          </div>

          {/* Category Selection (pill group) */}
          <div className="space-y-3">
            <Label>Category</Label>
            <div className="flex flex-wrap gap-2">
              {HABIT_CATEGORIES.map((category) => (
                <Button
                  key={category.name}
                  type="button"
                  variant="outline"
                  size="sm"
                  className={`rounded-full ${
                    newHabit.category === category.name 
                      ? `${category.color} border-2` 
                      : 'border border-border'
                  }`}
                  onClick={() => setNewHabit({ ...newHabit, category: category.name })}
                >
                  {category.name}
                </Button>
              ))}
            </div>
          </div>

          {/* Color Selection (8x1 grid) */}
          <div className="space-y-3">
            <Label>Color</Label>
            <div className="grid grid-cols-8 gap-2">
              {COLOR_OPTIONS.map((color, index) => (
                <Button
                  key={index}
                  type="button"
                  variant="outline"
                  size="sm"
                  className={`h-10 p-0 ${color} ${
                    newHabit.color === color ? 'ring-2 ring-offset-2 ring-primary' : ''
                  }`}
                  onClick={() => setNewHabit({ ...newHabit, color })}
                >
                  <span className="sr-only">Color option {index + 1}</span>
                </Button>
              ))}
            </div>
          </div>

          {/* Target */}
          <div className="space-y-3">
            <Label>Target</Label>
            <div className="flex items-center gap-3">
              <Input
                type="number"
                min="1"
                value={newHabit.targetNumber}
                onChange={(e) => setNewHabit({ ...newHabit, targetNumber: parseInt(e.target.value) || 1 })}
                className="w-20"
              />
              <div className="flex gap-1">
                {TARGET_PERIODS.map((period) => (
                  <Button
                    key={period.value}
                    type="button"
                    variant="outline"
                    size="sm"
                    className={`rounded-full ${
                      newHabit.targetPeriod === period.value 
                        ? 'bg-primary text-primary-foreground' 
                        : ''
                    }`}
                    onClick={() => setNewHabit({ ...newHabit, targetPeriod: period.value as 'day' | 'week' | 'month' })}
                  >
                    {period.label}
                  </Button>
                ))}
              </div>
            </div>
          </div>

          {/* Preview */}
          <div className="space-y-3">
            <Label>Preview</Label>
            <Card className="border-2 border-dashed">
              <CardContent className="p-4">
                <div className="flex items-center space-x-3">
                  <div className={`w-10 h-10 rounded-xl ${newHabit.color} flex items-center justify-center text-white`}>
                    <span className="text-lg">{newHabit.icon || '🎯'}</span>
                  </div>
                  <div className="flex-1">
                    <h3 className="font-semibold">{newHabit.name || 'Your Habit'}</h3>
                    <div className="flex items-center gap-2 mt-1">
                      {newHabit.category && (
                        <Badge variant="secondary" className="text-xs">
                          {newHabit.category}
                        </Badge>
                      )}
                      <span className="text-sm text-muted-foreground">
                        {newHabit.targetNumber} times/{newHabit.targetPeriod}
                      </span>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Create Button */}
          <Button 
            type="submit" 
            className="w-full h-12 bg-gradient-to-r from-primary to-primary/80 shadow-lg font-semibold"
            disabled={!newHabit.name.trim() || !newHabit.category}
          >
            Create Custom Habit
          </Button>
        </form>
      </DialogContent>
    </Dialog>
  );
}