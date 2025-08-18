import { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import { getSupabaseClient } from '../utils/supabase/client';
import { api } from '../utils/api';

interface User {
  id: string;
  email: string;
  name: string;
}

interface AuthContextType {
  user: User | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  signup: (email: string, password: string, name: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}

interface AuthProviderProps {
  children: ReactNode;
}

export function AuthProvider({ children }: AuthProviderProps) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  const supabase = getSupabaseClient();

  useEffect(() => {
    let mounted = true;

    // Check for existing session
    const initAuth = async () => {
      try {
        const { data: { session }, error } = await supabase.auth.getSession();
        if (error) {
          console.error('Session check error:', error);
          if (mounted) setLoading(false);
          return;
        }
        
        console.log('Initial session check:', !!session?.access_token, !!session?.user);
        
        if (session?.access_token && session?.user && mounted) {
          console.log('Setting initial access token and user');
          console.log('Initial access token preview:', session.access_token.substring(0, 30) + '...');
          console.log('Initial access token length:', session.access_token.length);
          
          // Validate token format before setting
          const tokenParts = session.access_token.split('.');
          if (tokenParts.length !== 3) {
            console.error('Invalid JWT token format:', tokenParts.length, 'parts');
            return;
          }
          
          // Set token first, then user
          api.setAccessToken(session.access_token);
          
          // Verify token was set correctly
          setTimeout(() => {
            console.log('Token verification - API has valid token:', api.hasValidToken());
          }, 100);
          
          setUser({
            id: session.user.id,
            email: session.user.email!,
            name: session.user.user_metadata?.name || session.user.email?.split('@')[0] || 'User'
          });
        }
      } catch (error) {
        console.error('Session check error:', error);
      } finally {
        if (mounted) setLoading(false);
      }
    };

    initAuth();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (!mounted) return;
        
        console.log('Auth state changed:', event, session?.user?.id);
        console.log('Session access token available:', !!session?.access_token);
        console.log('Session access token length:', session?.access_token?.length || 0);
        
        if (session?.access_token && session?.user) {
          console.log('Setting access token and user from auth change');
          console.log('Access token preview:', session.access_token.substring(0, 30) + '...');
          
          // Validate token format before setting
          const tokenParts = session.access_token.split('.');
          if (tokenParts.length !== 3) {
            console.error('Invalid JWT token format in auth change:', tokenParts.length, 'parts');
            api.setAccessToken(null);
            setUser(null);
            return;
          }
          
          // Set token first, then user
          api.setAccessToken(session.access_token);
          
          // Verify token was set correctly
          setTimeout(() => {
            console.log('Auth change token verification - API has valid token:', api.hasValidToken());
          }, 100);
          
          setUser({
            id: session.user.id,
            email: session.user.email!,
            name: session.user.user_metadata?.name || session.user.email?.split('@')[0] || 'User'
          });
        } else {
          console.log('Clearing access token and user');
          api.setAccessToken(null);
          setUser(null);
        }
        
        setLoading(false);
      }
    );

    return () => {
      mounted = false;
      subscription.unsubscribe();
    };
  }, []);



  const login = async (email: string, password: string) => {
    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        console.error('Login error:', error);
        throw new Error(error.message);
      }

      console.log('Login successful, session data:', {
        hasSession: !!data.session,
        hasAccessToken: !!data.session?.access_token,
        hasUser: !!data.session?.user,
        tokenLength: data.session?.access_token?.length || 0
      });

      if (data.session?.access_token) {
        console.log('Setting access token from login:', data.session.access_token.substring(0, 30) + '...');
        api.setAccessToken(data.session.access_token);
      }
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  };

  const signup = async (email: string, password: string, name: string) => {
    try {
      // Try to create user via our API first
      try {
        await api.signup(email, password, name);
        // If successful, sign them in
        await login(email, password);
      } catch (apiError: any) {
        // If user already exists, just try to sign them in
        if (apiError.message?.includes('already been registered')) {
          await login(email, password);
        } else {
          throw apiError;
        }
      }
    } catch (error) {
      console.error('Signup error:', error);
      throw error;
    }
  };

  const logout = async () => {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) {
        console.error('Logout error:', error);
      }
      api.setAccessToken(null);
      setUser(null);
    } catch (error) {
      console.error('Logout error:', error);
      throw error;
    }
  };

  const value = {
    user,
    loading,
    login,
    signup,
    logout,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}