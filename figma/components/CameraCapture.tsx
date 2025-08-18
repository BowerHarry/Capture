import { useState, useRef, useCallback, useEffect } from 'react';
import { Button } from './ui/button';
import { Card, CardContent } from './ui/card';
import { Badge } from './ui/badge';
import { X, Camera, RotateCcw, Check, Sparkles, Target, Upload, AlertCircle } from 'lucide-react';
import { api } from '../utils/api';
import { toast } from 'sonner@2.0.3';

interface CameraCaptureProps {
  habitId?: string;
  onClose: () => void;
  onPhotoTaken: (photo: string, habitId?: string) => void;
}

export function CameraCapture({ habitId, onClose, onPhotoTaken }: CameraCaptureProps) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  
  const [stream, setStream] = useState<MediaStream | null>(null);
  const [capturedPhoto, setCapturedPhoto] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [countdown, setCountdown] = useState<number | null>(null);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [cameraPermission, setCameraPermission] = useState<'granted' | 'denied' | 'prompt' | 'checking'>('checking');

  // Check camera permissions
  const checkCameraPermission = async () => {
    try {
      if ('permissions' in navigator) {
        const result = await navigator.permissions.query({ name: 'camera' as PermissionName });
        setCameraPermission(result.state as 'granted' | 'denied' | 'prompt');
        
        result.onchange = () => {
          setCameraPermission(result.state as 'granted' | 'denied' | 'prompt');
        };
      } else {
        // Fallback for browsers without permissions API
        setCameraPermission('prompt');
      }
    } catch (error) {
      console.warn('Could not check camera permission:', error);
      setCameraPermission('prompt');
    }
  };

  const startCamera = useCallback(async () => {
    try {
      setCameraError(null);
      console.log('🎥 Requesting camera access...');
      
      const mediaStream = await navigator.mediaDevices.getUserMedia({
        video: { 
          facingMode: 'user',
          width: { ideal: 1280 },
          height: { ideal: 720 }
        }
      });
      
      console.log('✅ Camera access granted');
      
      if (videoRef.current) {
        videoRef.current.srcObject = mediaStream;
      }
      setStream(mediaStream);
      setCameraPermission('granted');
    } catch (error: any) {
      console.error('❌ Camera access error:', error);
      
      let errorMessage = 'Could not access camera.';
      
      if (error.name === 'NotAllowedError') {
        errorMessage = 'Camera permission denied. Please allow camera access and try again.';
        setCameraPermission('denied');
      } else if (error.name === 'NotFoundError') {
        errorMessage = 'No camera found on this device.';
      } else if (error.name === 'NotReadableError') {
        errorMessage = 'Camera is already in use by another application.';
      } else if (error.name === 'OverconstrainedError') {
        errorMessage = 'Camera does not support the requested settings.';
      }
      
      setCameraError(errorMessage);
      toast.error(errorMessage);
    }
  }, []);

  const stopCamera = useCallback(() => {
    if (stream) {
      stream.getTracks().forEach(track => {
        track.stop();
        console.log('🛑 Camera track stopped');
      });
      setStream(null);
    }
  }, [stream]);

  const startCountdown = () => {
    setCountdown(3);
    const interval = setInterval(() => {
      setCountdown(prev => {
        if (prev === 1) {
          clearInterval(interval);
          capturePhoto();
          return null;
        }
        return prev ? prev - 1 : null;
      });
    }, 1000);
  };

  const capturePhoto = useCallback(() => {
    if (!videoRef.current || !canvasRef.current) return;

    const canvas = canvasRef.current;
    const video = videoRef.current;
    const context = canvas.getContext('2d');

    if (!context) return;

    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;

    // Flip the image horizontally for front-facing camera
    context.scale(-1, 1);
    context.drawImage(video, -canvas.width, 0, canvas.width, canvas.height);
    context.scale(-1, 1);

    const photoDataUrl = canvas.toDataURL('image/jpeg', 0.8);
    setCapturedPhoto(photoDataUrl);
    stopCamera();
    
    // Vibrate if supported
    if ('vibrate' in navigator) {
      navigator.vibrate(100);
    }
  }, [stopCamera]);

  const retakePhoto = () => {
    setCapturedPhoto(null);
    startCamera();
  };

  const handleFileUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = (e) => {
        const result = e.target?.result as string;
        setCapturedPhoto(result);
      };
      reader.readAsDataURL(file);
    }
  };

  const uploadPhoto = async () => {
    if (!capturedPhoto) return;

    try {
      setUploading(true);
      console.log('📤 Starting photo upload...');
      
      // Convert data URL to blob
      const response = await fetch(capturedPhoto);
      const blob = await response.blob();
      const file = new File([blob], 'habit-photo.jpg', { type: 'image/jpeg' });

      console.log('🔧 Created file:', file.name, file.size, 'bytes');

      // Upload to server
      const uploadResponse = await api.uploadPhoto(file);
      const photoUrl = uploadResponse.photoUrl;
      
      console.log('✅ Photo uploaded successfully:', photoUrl);

      // Complete habit if habitId is provided
      if (habitId) {
        console.log('🎯 Completing habit:', habitId);
        await api.completeHabit(habitId, photoUrl);
        console.log('✅ Habit completed successfully');
      }

      toast.success('Photo uploaded successfully! 📸✨');
      onPhotoTaken(photoUrl, habitId);
    } catch (error) {
      console.error('❌ Error uploading photo:', error);
      toast.error('Failed to upload photo. Please try again.');
    } finally {
      setUploading(false);
    }
  };

  useEffect(() => {
    checkCameraPermission();
    
    if (!capturedPhoto) {
      startCamera();
    }
    
    return () => {
      stopCamera();
    };
  }, [capturedPhoto, startCamera, stopCamera]);

  // Render camera error state
  if (cameraError || cameraPermission === 'denied') {
    return (
      <div className="fixed inset-0 bg-black z-50 flex items-center justify-center">
        <div className="absolute inset-0 bg-gradient-to-br from-red-900/20 via-black to-orange-900/20"></div>
        
        <div className="relative w-full h-full max-w-md mx-auto flex flex-col">
          {/* Header */}
          <div className="p-4">
            <div className="flex items-center justify-between">
              <Button
                variant="ghost"
                size="sm"
                onClick={onClose}
                className="text-white hover:bg-white/20 rounded-full h-10 w-10 p-0"
              >
                <X size={20} />
              </Button>
              
              <Badge className="bg-red-500/20 text-red-300 border-red-500/30">
                <AlertCircle size={14} className="mr-1" />
                Camera Issue
              </Badge>
              
              <div className="w-10" />
            </div>
          </div>

          {/* Error message */}
          <div className="flex-1 flex items-center justify-center p-6">
            <Card className="bg-white/10 backdrop-blur-sm border-white/20 max-w-sm">
              <CardContent className="p-6 text-center space-y-4">
                <div className="text-6xl">📷</div>
                <div>
                  <h3 className="text-lg font-medium text-white mb-2">Camera Access Needed</h3>
                  <p className="text-white/70 text-sm mb-4">
                    {cameraError || 'We need camera permission to capture your habit photos.'}
                  </p>
                </div>
                
                <div className="space-y-3">
                  {cameraPermission === 'denied' ? (
                    <div className="text-xs text-white/50 space-y-2">
                      <p>To enable camera:</p>
                      <p>1. Click the camera icon in your address bar</p>
                      <p>2. Select "Allow" for camera permission</p>
                      <p>3. Refresh the page</p>
                    </div>
                  ) : (
                    <Button onClick={startCamera} className="w-full bg-white/20 hover:bg-white/30">
                      Try Again
                    </Button>
                  )}
                  
                  <div className="text-white/50 text-sm">or</div>
                  
                  <Button
                    onClick={() => fileInputRef.current?.click()}
                    variant="outline"
                    className="w-full bg-transparent border-white/30 text-white hover:bg-white/10"
                  >
                    <Upload size={16} className="mr-2" />
                    Upload from Gallery
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
          
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            onChange={handleFileUpload}
            className="hidden"
          />
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 bg-black z-50 flex items-center justify-center">
      {/* Background gradient */}
      <div className="absolute inset-0 bg-gradient-to-br from-purple-900/20 via-black to-blue-900/20"></div>
      
      <div className="relative w-full h-full max-w-md mx-auto">
        {/* Header */}
        <div className="absolute top-0 left-0 right-0 z-10 p-4">
          <div className="flex items-center justify-between">
            <Button
              variant="ghost"
              size="sm"
              onClick={onClose}
              className="text-white hover:bg-white/20 rounded-full h-10 w-10 p-0"
            >
              <X size={20} />
            </Button>
            
            <div className="text-center">
              <Badge className="bg-white/20 text-white border-white/30 backdrop-blur-sm">
                <Target size={14} className="mr-1" />
                Habit Photo
              </Badge>
            </div>
            
            <Button
              variant="ghost"
              size="sm"
              onClick={() => fileInputRef.current?.click()}
              className="text-white hover:bg-white/20 rounded-full h-10 w-10 p-0"
            >
              <Upload size={20} />
            </Button>
          </div>
        </div>

        {/* Main content */}
        <div className="h-full flex flex-col">
          {/* Camera/Photo area */}
          <div className="flex-1 relative overflow-hidden">
            {!capturedPhoto && stream ? (
              <>
                <video
                  ref={videoRef}
                  autoPlay
                  playsInline
                  muted
                  className="w-full h-full object-cover"
                  style={{ transform: 'scaleX(-1)' }}
                />
                
                {/* Camera overlay */}
                <div className="absolute inset-0 pointer-events-none">
                  {/* Corner frames */}
                  <div className="absolute top-20 left-4 w-8 h-8 border-l-2 border-t-2 border-white/50"></div>
                  <div className="absolute top-20 right-4 w-8 h-8 border-r-2 border-t-2 border-white/50"></div>
                  <div className="absolute bottom-32 left-4 w-8 h-8 border-l-2 border-b-2 border-white/50"></div>
                  <div className="absolute bottom-32 right-4 w-8 h-8 border-r-2 border-b-2 border-white/50"></div>
                  
                  {/* Center guide */}
                  <div className="absolute inset-0 flex items-center justify-center">
                    <div className="w-48 h-48 border-2 border-white/30 rounded-full"></div>
                  </div>
                  
                  {/* Motivational text */}
                  <div className="absolute top-32 left-0 right-0 text-center">
                    <div className="bg-black/50 backdrop-blur-sm rounded-full px-4 py-2 mx-8">
                      <p className="text-white text-sm font-medium flex items-center justify-center">
                        <Sparkles size={16} className="mr-2 text-yellow-400" />
                        Show your progress! 
                      </p>
                    </div>
                  </div>
                </div>
                
                {/* Countdown overlay */}
                {countdown && (
                  <div className="absolute inset-0 bg-black/50 flex items-center justify-center">
                    <div className="text-white text-6xl font-bold animate-bounce-in">
                      {countdown}
                    </div>
                  </div>
                )}
              </>
            ) : !capturedPhoto && !stream ? (
              // Loading camera
              <div className="h-full flex items-center justify-center bg-gray-900">
                <div className="text-center text-white space-y-4">
                  <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-white mx-auto"></div>
                  <p>Starting camera...</p>
                </div>
              </div>
            ) : capturedPhoto ? (
              <div className="relative h-full">
                <img
                  src={capturedPhoto}
                  alt="Captured habit photo"
                  className="w-full h-full object-cover"
                />
                
                {/* Success overlay */}
                <div className="absolute inset-0 bg-gradient-to-t from-green-500/20 to-transparent"></div>
                <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2">
                  <div className="bg-green-500 text-white rounded-full p-4 animate-bounce-in">
                    <Check size={32} />
                  </div>
                </div>
              </div>
            ) : null}
          </div>

          {/* Bottom controls */}
          <div className="p-6 bg-gradient-to-t from-black via-black/80 to-transparent">
            {!capturedPhoto && stream ? (
              <div className="flex items-center justify-center space-x-8">
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => fileInputRef.current?.click()}
                  className="text-white hover:bg-white/20 rounded-full h-12 w-12 p-0"
                >
                  <Upload size={20} />
                </Button>
                
                <Button
                  onClick={startCountdown}
                  className="w-20 h-20 rounded-full bg-white hover:bg-gray-100 shadow-lg relative"
                  disabled={!!countdown}
                >
                  <div className="absolute inset-2 bg-red-500 rounded-full flex items-center justify-center">
                    <Camera size={24} className="text-white" />
                  </div>
                </Button>
                
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-white hover:bg-white/20 rounded-full h-12 w-12 p-0"
                  onClick={() => {
                    toast.info('Camera switch not available yet');
                  }}
                >
                  <RotateCcw size={20} />
                </Button>
              </div>
            ) : capturedPhoto ? (
              <div className="flex space-x-3">
                <Button
                  variant="outline"
                  onClick={retakePhoto}
                  className="flex-1 bg-white/10 border-white/30 text-white hover:bg-white/20"
                  disabled={uploading}
                >
                  <RotateCcw size={16} className="mr-2" />
                  Retake
                </Button>
                
                <Button
                  onClick={uploadPhoto}
                  disabled={uploading}
                  className="flex-1 bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 shadow-lg"
                >
                  {uploading ? (
                    <div className="flex items-center">
                      <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2"></div>
                      Saving...
                    </div>
                  ) : (
                    <>
                      <Check size={16} className="mr-2" />
                      Complete Habit
                    </>
                  )}
                </Button>
              </div>
            ) : null}
          </div>
        </div>

        {/* Fun motivational messages */}
        {!capturedPhoto && !countdown && stream && (
          <div className="absolute bottom-24 left-0 right-0 text-center px-4">
            <Card className="bg-white/10 backdrop-blur-sm border-white/20">
              <CardContent className="p-3">
                <p className="text-white text-sm">
                  📸 Capture your habit moment! 
                  <br />
                  <span className="text-white/70">Show your progress and inspire others</span>
                </p>
              </CardContent>
            </Card>
          </div>
        )}
      </div>

      <canvas ref={canvasRef} className="hidden" />
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        onChange={handleFileUpload}
        className="hidden"
      />
    </div>
  );
}