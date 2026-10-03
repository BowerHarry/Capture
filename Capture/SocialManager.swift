import Foundation
import SwiftUI
import Combine

@MainActor
class SocialManager: ObservableObject {
    static let shared = SocialManager(supabaseManager: SupabaseManager.shared)
    
    @Published var isLoading = false
    @Published var error: String?
    
    private let supabaseManager: SupabaseManager
    private let authManager = AuthManager.shared
    
    init(supabaseManager: SupabaseManager) {
        self.supabaseManager = supabaseManager
    }
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    
    
    
    
    
    
    
    // MARK: - Follow Functionality
    
    func toggleFollow(userId: UUID) async {
        guard let currentUser = authManager.currentUser else {
            error = "User not authenticated"
            return
        }
        
        
        do {
            // Check if already following
            let existingFollow: [Follow] = try await supabaseManager.client
                .from("user_follows")
                .select()
                .eq("follower_id", value: currentUser.id)
                .eq("following_id", value: userId)
                .execute()
                .value
            
            
            if existingFollow.isEmpty {
                // Follow user
                let newFollow = Follow(
                    followerId: currentUser.id,
                    followingId: userId
                )
                
                try await supabaseManager.client
                    .from("user_follows")
                    .insert(newFollow)
                    .execute()
                
                
                // Refresh follower counts for both users
                await authManager.refreshFollowerCounts()
                await authManager.refreshFollowerCountsForUser(userId: userId)
            } else {
                // Unfollow user
                
                try await supabaseManager.client
                    .from("user_follows")
                    .delete()
                    .eq("follower_id", value: currentUser.id)
                    .eq("following_id", value: userId)
                    .execute()
                
                
                // Refresh follower counts for both users
                await authManager.refreshFollowerCounts()
                await authManager.refreshFollowerCountsForUser(userId: userId)
            }
        } catch {
            Log.error("❌ Follow toggle error: \(error)")
            self.error = "Failed to toggle follow: \(error.localizedDescription)"
        }
    }
    
    func isFollowing(userId: UUID) async -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        
        do {
            let existingFollow: [Follow] = try await supabaseManager.client
                .from("user_follows")
                .select()
                .eq("follower_id", value: currentUser.id)
                .eq("following_id", value: userId)
                .execute()
                .value
            
            let isFollowing = !existingFollow.isEmpty
            return isFollowing
        } catch {
            Log.error("❌ Is following error: \(error)")
            return false
        }
    }
    
    func getFollowers(userId: UUID) async -> [User] {
        do {
            // First get all follows where this user is being followed
            let follows: [Follow] = try await supabaseManager.client
                .from("user_follows")
                .select()
                .eq("following_id", value: userId)
                .execute()
                .value
            
            
            // Then get the profile for each follower
            var followers: [User] = []
            for follow in follows {
                let profiles: [UserProfile] = try await supabaseManager.client
                    .from("profiles")
                    .select()
                    .eq("id", value: follow.followerId)
                    .execute()
                    .value
                
                if let profile = profiles.first {
                    let user = User(
                        id: profile.id,
                        email: profile.email,
                        username: profile.username ?? profile.displayName ?? "Unknown User",
                        avatar: profile.avatarUrl,
                        bio: profile.bio,
                        createdAt: profile.createdAt,
                        updatedAt: profile.updatedAt,
                        bestStreak: nil // We'll need to fetch this separately if needed
                    )
                    followers.append(user)
                }
            }
            
            return followers
        } catch {
            Log.error("❌ Get followers error: \(error)")
            self.error = "Failed to get followers: \(error.localizedDescription)"
            return []
        }
    }
    
    func getFollowing(userId: UUID) async -> [User] {
        do {
            // First get all follows where this user is following others
            let follows: [Follow] = try await supabaseManager.client
                .from("user_follows")
                .select()
                .eq("follower_id", value: userId)
                .execute()
                .value
            
            
            // Then get the profile for each user being followed
            var following: [User] = []
            for follow in follows {
                let profiles: [UserProfile] = try await supabaseManager.client
                    .from("profiles")
                    .select()
                    .eq("id", value: follow.followingId)
                    .execute()
                    .value
                
                if let profile = profiles.first {
                    let user = User(
                        id: profile.id,
                        email: profile.email,
                        username: profile.username ?? profile.displayName ?? "Unknown User",
                        avatar: profile.avatarUrl,
                        bio: profile.bio,
                        createdAt: profile.createdAt,
                        updatedAt: profile.updatedAt,
                        bestStreak: nil // We'll need to fetch this separately if needed
                    )
                    following.append(user)
                }
            }
            
            return following
        } catch {
            Log.error("❌ Get following error: \(error)")
            self.error = "Failed to get following: \(error.localizedDescription)"
            return []
        }
    }
}

// MARK: - Extensions

extension Date {
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
