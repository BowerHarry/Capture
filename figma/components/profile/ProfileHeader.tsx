import { useState } from 'react';
import { Card, CardContent } from "../ui/card";
import { Badge } from "../ui/badge";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Label } from "../ui/label";
import { Textarea } from "../ui/textarea";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogTrigger } from "../ui/dialog";
import { Avatar, AvatarFallback, AvatarImage } from "../ui/avatar";
import { Edit3, Camera, Calendar, Upload, LogOut, Target, Users } from "lucide-react";
import { toast } from 'sonner@2.0.3';
import { api } from '../../utils/api';
import { useAuth } from '../AuthContext';

interface ProfileData {
  id: string;
  email: string;
  name: string;
  bio?: string;
  avatar?: string;
  createdAt: string;
  totalHabits: number;
  totalCaptures: number;
  followers: string[];
}

interface ProfileHeaderProps {
  profile: ProfileData;
  onProfileUpdate: (updatedProfile: ProfileData) => void;
}

export function ProfileHeader({ profile, onProfileUpdate }: ProfileHeaderProps) {
  const [showEditDialog, setShowEditDialog] = useState(false);
  const [showAvatarDialog, setShowAvatarDialog] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [editForm, setEditForm] = useState({
    name: profile.name || '',
    bio: profile.bio || ''
  });

  const { logout } = useAuth();

  // Extract username from email (part before @)
  const username = profile.email.split('@')[0];

  const handleEditProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const response = await api.updateProfile(editForm.name, editForm.bio);
      onProfileUpdate(response.profile);
      setShowEditDialog(false);
      toast.success('Profile updated successfully! ✨');
    } catch (error: any) {
      console.error('Error updating profile:', error);
      toast.error('Failed to update profile: ' + error.message);
    }
  };

  const handleAvatarUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      setUploading(true);
      const uploadResponse = await api.uploadPhoto(file);
      const updatedProfile = { ...profile, avatar: uploadResponse.photoUrl };
      onProfileUpdate(updatedProfile);
      setShowAvatarDialog(false);
      toast.success('Profile picture updated! 📸');
    } catch (error: any) {
      console.error('Error uploading avatar:', error);
      toast.error('Failed to upload profile picture');
    } finally {
      setUploading(false);
    }
  };

  return (
    <Card className="relative overflow-hidden">
      <div className="absolute inset-0 bg-gradient-to-br from-primary/5 via-accent/10 to-secondary/5"></div>
      <CardContent className="relative p-6">
        <div className="flex items-start justify-between mb-6">
          <div className="flex items-center space-x-4">
            <div className="relative">
              <Avatar className="w-20 h-20 ring-4 ring-primary/10">
                <AvatarImage 
                  src={profile.avatar} 
                  alt={profile.name}
                  className="object-cover"
                />
                <AvatarFallback className="bg-gradient-to-br from-primary to-primary/80 text-primary-foreground text-xl">
                  {profile.name.charAt(0).toUpperCase()}
                </AvatarFallback>
              </Avatar>
              <Dialog open={showAvatarDialog} onOpenChange={setShowAvatarDialog}>
                <DialogTrigger asChild>
                  <Button 
                    size="sm" 
                    variant="secondary"
                    className="absolute -bottom-1 -right-1 rounded-full w-8 h-8 p-0 shadow-lg"
                  >
                    <Camera size={14} />
                  </Button>
                </DialogTrigger>
                <DialogContent className="max-w-sm">
                  <DialogHeader>
                    <DialogTitle>Update Profile Picture</DialogTitle>
                    <DialogDescription>
                      Choose a new profile picture to represent you in the community.
                    </DialogDescription>
                  </DialogHeader>
                  <div className="space-y-4">
                    <div className="text-center">
                      <Avatar className="w-24 h-24 mx-auto mb-4">
                        <AvatarImage src={profile.avatar} alt={profile.name} />
                        <AvatarFallback className="bg-gradient-to-br from-primary to-primary/80 text-primary-foreground text-2xl">
                          {profile.name.charAt(0).toUpperCase()}
                        </AvatarFallback>
                      </Avatar>
                    </div>
                    <Label htmlFor="avatar-upload" className="cursor-pointer">
                      <div className="flex items-center justify-center p-4 border-2 border-dashed border-muted-foreground/30 rounded-lg hover:border-primary/50 transition-colors">
                        <div className="text-center space-y-2">
                          <Upload className="w-8 h-8 mx-auto text-muted-foreground" />
                          <p className="text-sm text-muted-foreground">
                            {uploading ? 'Uploading...' : 'Click to upload photo'}
                          </p>
                        </div>
                      </div>
                      <Input
                        id="avatar-upload"
                        type="file"
                        accept="image/*"
                        className="hidden"
                        onChange={handleAvatarUpload}
                        disabled={uploading}
                      />
                    </Label>
                  </div>
                </DialogContent>
              </Dialog>
            </div>
            
            <div className="space-y-1">
              <h1 className="text-2xl font-bold">{profile.name}</h1>
              <p className="text-muted-foreground">@{username}</p>
              {profile.bio && (
                <p className="text-sm text-muted-foreground mt-2 max-w-md">
                  {profile.bio}
                </p>
              )}
              <div className="flex items-center space-x-2 mt-2">
                <Badge variant="secondary" className="text-xs">
                  <Calendar size={12} className="mr-1" />
                  Joined {new Date(profile.createdAt).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}
                </Badge>
              </div>
            </div>
          </div>
          
          <div className="flex items-center space-x-2">
            <Button variant="ghost" size="sm" onClick={logout} className="text-muted-foreground hover:text-foreground">
              <LogOut size={16} />
            </Button>
            <Dialog open={showEditDialog} onOpenChange={setShowEditDialog}>
              <DialogTrigger asChild>
                <Button variant="outline" size="sm">
                  <Edit3 size={16} className="mr-2" />
                  Edit
                </Button>
              </DialogTrigger>
              <DialogContent className="max-w-md">
                <DialogHeader>
                  <DialogTitle>Edit Profile</DialogTitle>
                  <DialogDescription>
                    Update your profile information to share more about yourself.
                  </DialogDescription>
                </DialogHeader>
                <form onSubmit={handleEditProfile} className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="edit-name">Name</Label>
                    <Input
                      id="edit-name"
                      value={editForm.name}
                      onChange={(e) => setEditForm(prev => ({ ...prev, name: e.target.value }))}
                      placeholder="Your display name"
                      required
                    />
                  </div>
                  
                  <div className="space-y-2">
                    <Label htmlFor="edit-bio">Bio (Optional)</Label>
                    <Textarea
                      id="edit-bio"
                      value={editForm.bio}
                      onChange={(e) => setEditForm(prev => ({ ...prev, bio: e.target.value }))}
                      placeholder="Tell others about yourself and your goals..."
                      rows={3}
                      maxLength={150}
                    />
                    <p className="text-xs text-muted-foreground">
                      {editForm.bio.length}/150 characters
                    </p>
                  </div>

                  <div className="flex justify-end space-x-2">
                    <Button type="button" variant="outline" onClick={() => setShowEditDialog(false)}>
                      Cancel
                    </Button>
                    <Button type="submit">
                      Save Changes
                    </Button>
                  </div>
                </form>
              </DialogContent>
            </Dialog>
          </div>
        </div>

        {/* Enhanced Stats Grid */}
        <div className="grid grid-cols-3 gap-3">
          {/* Habits */}
          <div className="text-center p-3 bg-gradient-to-br from-orange-50 to-red-50 dark:from-orange-950/20 dark:to-red-950/20 rounded-xl border border-orange-200/60 shadow-sm backdrop-blur-sm">
            <div className="flex items-center justify-center space-x-2 mb-1">
              <div className="p-1 rounded-full bg-gradient-to-br from-orange-500/10 to-red-500/10">
                <Target className="w-4 h-4 text-orange-600" />
              </div>
              <span className="text-xl font-bold text-orange-700 tabular-nums">{profile.totalHabits}</span>
            </div>
            <p className="text-xs text-orange-700/80 font-medium">Habits</p>
          </div>
          
          {/* Captures */}
          <div className="text-center p-3 bg-gradient-to-br from-blue-50 to-indigo-50 dark:from-blue-950/20 dark:to-indigo-950/20 rounded-xl border border-blue-200/60 shadow-sm backdrop-blur-sm">
            <div className="flex items-center justify-center space-x-2 mb-1">
              <div className="p-1 rounded-full bg-gradient-to-br from-blue-500/10 to-indigo-500/10">
                <Camera className="w-4 h-4 text-blue-600" />
              </div>
              <span className="text-xl font-bold text-blue-700 tabular-nums">{profile.totalCaptures}</span>
            </div>
            <p className="text-xs text-blue-700/80 font-medium">Captures</p>
          </div>
          
          {/* Followers */}
          <div className="text-center p-3 bg-gradient-to-br from-purple-50 to-pink-50 dark:from-purple-950/20 dark:to-pink-950/20 rounded-xl border border-purple-200/60 shadow-sm backdrop-blur-sm">
            <div className="flex items-center justify-center space-x-2 mb-1">
              <div className="p-1 rounded-full bg-gradient-to-br from-purple-500/10 to-pink-500/10">
                <Users className="w-4 h-4 text-purple-600" />
              </div>
              <span className="text-xl font-bold text-purple-700 tabular-nums">{profile.followers.length}</span>
            </div>
            <p className="text-xs text-purple-700/80 font-medium">Followers</p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}