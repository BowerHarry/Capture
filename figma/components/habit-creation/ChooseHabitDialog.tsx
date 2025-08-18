import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "../ui/dialog";
import { Button } from "../ui/button";
import { Card, CardContent } from "../ui/card";
import { PRESET_HABITS } from "./constants";

interface PresetHabit {
  name: string;
  category: string;
  emoji: string;
  icon: string;
  description: string;
  targetNumber: number;
  targetPeriod: 'day' | 'week' | 'month';
  color: string;
}

interface ChooseHabitDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSelectPreset: (preset: PresetHabit) => void;
  onCreateCustom: () => void;
}

export function ChooseHabitDialog({ open, onOpenChange, onSelectPreset, onCreateCustom }: ChooseHabitDialogProps) {

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md max-h-[90vh] overflow-y-auto">
        <DialogHeader className="text-center space-y-3">
          <DialogTitle className="text-2xl font-bold">Choose a habit</DialogTitle>
          <DialogDescription className="text-muted-foreground">
            Start with a popular habit or create your own
          </DialogDescription>
        </DialogHeader>
        
        <div className="space-y-6 mt-6">
          {/* 2x4 Grid of Preset Habits */}
          <div className="grid grid-cols-2 gap-3">
            {PRESET_HABITS.map((habit, index) => (
              <Card 
                key={index}
                className={`${habit.color} border-2 cursor-pointer transition-all duration-200 hover:scale-105 hover:shadow-md active:scale-95`}
                onClick={() => onSelectPreset(habit)}
              >
                <CardContent className="p-4 text-center space-y-2">
                  <div className="text-2xl">{habit.icon}</div>
                  <div className="space-y-1">
                    <h3 className="font-semibold text-sm leading-tight">{habit.name}</h3>
                    <p className="text-xs opacity-80">{habit.category}</p>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
          
          {/* Create Custom Habit Button */}
          <Button 
            onClick={onCreateCustom}
            className="w-full h-12 bg-gradient-to-r from-primary to-primary/80 hover:from-primary/90 hover:to-primary/70 shadow-lg font-semibold"
            size="lg"
          >
            ✨ Create Custom Habit
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}