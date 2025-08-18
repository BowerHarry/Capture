import { projectId, publicAnonKey } from './supabase/info';

const API_BASE_URL = `https://${projectId}.supabase.co/functions/v1/make-server-22c67a59`;

class ApiClient {
  private accessToken: string | null = null;

  setAccessToken(token: string | null) {
    console.log('🔑 API: Setting access token:', token ? `${token.substring(0, 20)}...` : 'null');
    this.accessToken = token;
    
    // Immediate validation
    if (token) {
      console.log('🔍 Token validation:');
      console.log('  - Length:', token.length);
      console.log('  - Format check:', token.split('.').length === 3 ? '✅ Valid JWT' : '❌ Invalid JWT');
      console.log('  - Is anon key:', token === publicAnonKey ? '❌ YES (BAD)' : '✅ No (Good)');
    }
  }

  getAccessToken() {
    return this.accessToken;
  }

  hasValidToken() {
    if (!this.accessToken || this.accessToken.length < 20) {
      console.log('❌ No valid token: too short or missing');
      return false;
    }
    
    // Check if it looks like a JWT (has 3 parts separated by dots)
    const parts = this.accessToken.split('.');
    if (parts.length !== 3) {
      console.warn('❌ Token does not have JWT format (3 parts):', parts.length);
      return false;
    }
    
    // Check if it's not the anon key (that would be wrong)
    if (this.accessToken === publicAnonKey) {
      console.warn('❌ Token is the anon key - should be user token');
      return false;
    }
    
    console.log('✅ Token appears valid');
    return true;
  }

  private getHeaders(): HeadersInit {
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
    };

    if (this.accessToken) {
      headers.Authorization = `Bearer ${this.accessToken}`;
      console.log('🔐 Using user token for authorization');
    } else {
      headers.Authorization = `Bearer ${publicAnonKey}`;
      console.log('🔓 Using anon key for authorization (no user token)');
    }

    return headers;
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${API_BASE_URL}${endpoint}`;
    const headers = this.getHeaders();
    
    console.log(`🌐 API Request: ${options.method || 'GET'} ${endpoint}`);
    console.log('📋 Request details:');
    console.log('  - Has access token:', !!this.accessToken);
    console.log('  - Token length:', this.accessToken?.length || 0);
    console.log('  - Auth type:', 
      headers.Authorization?.includes(publicAnonKey) ? 'ANON_KEY' : 'USER_TOKEN'
    );
    
    try {
      const response = await fetch(url, {
        ...options,
        headers: {
          ...headers,
          ...options.headers,
        },
      });

      console.log(`📡 Response: ${response.status} ${response.statusText}`);

      if (!response.ok) {
        let errorData;
        try {
          errorData = await response.json();
        } catch {
          errorData = { error: `HTTP ${response.status}: ${response.statusText}` };
        }
        
        console.error(`❌ API Error (${response.status}) for ${endpoint}:`, errorData);
        
        // Enhanced error logging for auth issues
        if (response.status === 401) {
          console.error('🚨 AUTHENTICATION FAILED:');
          console.error('  - Current token preview:', this.accessToken?.substring(0, 30) + '...');
          console.error('  - Token equals anon key:', this.accessToken === publicAnonKey);
          console.error('  - Token length:', this.accessToken?.length);
          console.error('  - Token format valid:', this.accessToken?.split('.').length === 3);
          
          // Try to decode JWT header for debugging
          if (this.accessToken) {
            try {
              const [header] = this.accessToken.split('.');
              const decodedHeader = JSON.parse(atob(header));
              console.error('  - JWT Header:', decodedHeader);
            } catch (jwtError) {
              console.error('  - JWT decode failed:', jwtError);
            }
          }
        }
        
        throw new Error(errorData.error || `HTTP ${response.status}`);
      }

      const data = await response.json();
      console.log(`✅ Success response for ${endpoint}:`, data);
      return data;
      
    } catch (fetchError) {
      console.error(`🔥 Network/Fetch error for ${endpoint}:`, fetchError);
      throw fetchError;
    }
  }

  // Enhanced debug method
  async debugAuthComprehensive() {
    console.log('🔍 Starting comprehensive auth debug...');
    try {
      const result = await this.request('/debug-auth-comprehensive');
      console.log('🎯 Comprehensive debug result:', result);
      return result;
    } catch (error) {
      console.error('❌ Comprehensive debug failed:', error);
      throw error;
    }
  }

  // Auth methods
  async signup(email: string, password: string, name: string) {
    return this.request('/auth/signup', {
      method: 'POST',
      body: JSON.stringify({ email, password, name }),
    });
  }

  // Habits methods
  async getHabits() {
    console.log('🎯 Getting habits...');
    
    // Pre-flight validation
    if (!this.hasValidToken()) {
      console.error('❌ Cannot get habits: invalid token');
      throw new Error('Invalid or missing authentication token');
    }
    
    return this.request('/habits');
  }

  async createHabit(name: string, category: string, description?: string) {
    if (!this.hasValidToken()) {
      throw new Error('Invalid or missing authentication token');
    }
    
    return this.request('/habits', {
      method: 'POST',
      body: JSON.stringify({ name, category, description }),
    });
  }

  async completeHabit(habitId: string, photoUrl?: string) {
    return this.request(`/habits/${habitId}/complete`, {
      method: 'POST',
      body: JSON.stringify({ photoUrl }),
    });
  }

  // Photo upload
  async uploadPhoto(file: File) {
    const formData = new FormData();
    formData.append('photo', file);

    const headers: HeadersInit = {};
    if (this.accessToken) {
      headers.Authorization = `Bearer ${this.accessToken}`;
    } else {
      headers.Authorization = `Bearer ${publicAnonKey}`;
    }

    const response = await fetch(`${API_BASE_URL}/upload-photo`, {
      method: 'POST',
      headers,
      body: formData,
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Network error' }));
      console.error(`Photo upload error (${response.status}):`, error);
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return response.json();
  }

  // Social feed methods
  async getFeed() {
    if (!this.hasValidToken()) {
      throw new Error('Invalid or missing authentication token');
    }
    
    return this.request('/feed');
  }

  async toggleLike(postId: string) {
    return this.request(`/posts/${postId}/like`, {
      method: 'POST',
    });
  }

  // Discovery methods - No auth required
  async getPopularHabits() {
    console.log('🔍 Getting popular habits (public endpoint)...');
    
    // Use a direct fetch without authentication headers for public discovery
    const url = `${API_BASE_URL}/discover/habits`;
    console.log(`🌐 Public API Request: GET /discover/habits`);
    
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          // Use anon key for public endpoints
          'Authorization': `Bearer ${publicAnonKey}`
        }
      });

      console.log(`📡 Discovery Response: ${response.status} ${response.statusText}`);

      if (!response.ok) {
        let errorData;
        try {
          errorData = await response.json();
        } catch {
          errorData = { error: `HTTP ${response.status}: ${response.statusText}` };
        }
        
        console.error(`❌ Discovery API Error (${response.status}):`, errorData);
        throw new Error(errorData.error || `HTTP ${response.status}`);
      }

      const data = await response.json();
      console.log(`✅ Discovery success response:`, data);
      return data;
      
    } catch (fetchError) {
      console.error(`🔥 Discovery Network/Fetch error:`, fetchError);
      throw fetchError;
    }
  }

  // Profile methods
  async getProfile() {
    if (!this.hasValidToken()) {
      throw new Error('Invalid or missing authentication token');
    }
    
    return this.request('/profile');
  }

  async updateProfile(name: string, bio?: string) {
    if (!this.hasValidToken()) {
      throw new Error('Invalid or missing authentication token');
    }
    
    return this.request('/profile', {
      method: 'PUT',
      body: JSON.stringify({ name, bio }),
    });
  }

  // Test auth - simplified
  async testAuth() {
    return this.request('/test-auth');
  }

  // Health check (no auth required)
  async health() {
    const response = await fetch(`${API_BASE_URL}/health`);
    return response.json();
  }

  // Debug endpoint (no auth required)
  async debug() {
    return this.request('/debug');
  }

  // Simple auth test
  async authSimple() {
    console.log('🧪 Running simple auth test...');
    if (!this.hasValidToken()) {
      console.error('❌ Cannot run auth test: invalid token');
      throw new Error('Invalid token for auth test');
    }
    
    return this.request('/auth-simple');
  }
}

export const api = new ApiClient();