import Foundation
import SwiftUI
import Combine

@MainActor
class SocialManager: ObservableObject {
    static let shared = SocialManager(supabaseManager: SupabaseManager.shared)
    
    @Published var posts: [SocialPost] = []
    @Published var feedItems: [SocialFeedItem] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseManager: SupabaseManager
    private let authManager = AuthManager.shared
    
    init(supabaseManager: SupabaseManager) {
        self.supabaseManager = supabaseManager
    }
    
    // MARK: - Posts
    
    func loadPosts() async {
        isLoading = true
        error = nil
        
        do {
            let response: [SocialPost] = try await supabaseManager.client
                .from("social_posts")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            posts = response
            await loadFeedItems()
        } catch {
            self.error = "Failed to load posts: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func createPost(content: String, habitId: UUID? = nil, captureId: UUID? = nil, imageUrl: String? = nil) async {
        guard let currentUser = authManager.currentUser else {
            error = "User not authenticated"
            return
        }
        
        do {
            let post = SocialPost(
                userId: currentUser.id,
                habitId: habitId,
                captureId: captureId,
                content: content,
                imageUrl: imageUrl
            )
            
            let response: SocialPost = try await supabaseManager.client
                .from("social_posts")
                .insert(post)
                .select()
                .single()
                .execute()
                .value
            
            posts.insert(response, at: 0)
            await loadFeedItems()
        } catch {
            self.error = "Failed to create post: \(error.localizedDescription)"
        }
    }
    
    func deletePost(_ post: SocialPost) async {
        do {
            try await supabaseManager.client
                .from("social_posts")
                .delete()
                .eq("id", value: post.id)
                .execute()
            
            posts.removeAll { $0.id == post.id }
            await loadFeedItems()
        } catch {
            self.error = "Failed to delete post: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Feed Items
    
    private func loadFeedItems() async {
        guard !posts.isEmpty else {
            feedItems = []
            return
        }
        
        do {
            var items: [SocialFeedItem] = []
            
            for post in posts {
                let user = try await loadUserProfile(userId: post.userId)
                let habit = post.habitId != nil ? try await loadHabit(habitId: post.habitId!) : nil
                let capture = post.captureId != nil ? try await loadCapture(captureId: post.captureId!) : nil
                let isLiked = await checkIfLiked(postId: post.id)
                let isFollowing = await checkIfFollowing(userId: post.userId)
                
                let item = SocialFeedItem(
                    post: post,
                    user: user,
                    habit: habit,
                    capture: capture,
                    isLiked: isLiked,
                    isFollowing: isFollowing
                )
                items.append(item)
            }
            
            feedItems = items
        } catch {
            self.error = "Failed to load feed items: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Likes
    
    func toggleLike(postId: UUID) async {
        guard let currentUser = authManager.currentUser else {
            error = "User not authenticated"
            return
        }
        
        do {
            let isLiked = await checkIfLiked(postId: postId)
            
            if isLiked {
                // Unlike
                try await supabaseManager.client
                    .from("likes")
                    .delete()
                    .eq("post_id", value: postId)
                    .eq("user_id", value: currentUser.id)
                    .execute()
                
                // Update post like count
                if let index = posts.firstIndex(where: { $0.id == postId }) {
                    posts[index] = SocialPost(
                        id: posts[index].id,
                        userId: posts[index].userId,
                        habitId: posts[index].habitId,
                        captureId: posts[index].captureId,
                        content: posts[index].content,
                        imageUrl: posts[index].imageUrl,
                        likes: max(0, posts[index].likes - 1),
                        comments: posts[index].comments,
                        createdAt: posts[index].createdAt,
                        updatedAt: posts[index].updatedAt
                    )
                }
            } else {
                // Like
                let like = Like(postId: postId, userId: currentUser.id)
                try await supabaseManager.client
                    .from("likes")
                    .insert(like)
                    .execute()
                
                // Update post like count
                if let index = posts.firstIndex(where: { $0.id == postId }) {
                    posts[index] = SocialPost(
                        id: posts[index].id,
                        userId: posts[index].userId,
                        habitId: posts[index].habitId,
                        captureId: posts[index].captureId,
                        content: posts[index].content,
                        imageUrl: posts[index].imageUrl,
                        likes: posts[index].likes + 1,
                        comments: posts[index].comments,
                        createdAt: posts[index].createdAt,
                        updatedAt: posts[index].updatedAt
                    )
                }
            }
            
            await loadFeedItems()
        } catch {
            self.error = "Failed to toggle like: \(error.localizedDescription)"
        }
    }
    
    private func checkIfLiked(postId: UUID) async -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        
        do {
            let response: [Like] = try await supabaseManager.client
                .from("likes")
                .select()
                .eq("post_id", value: postId)
                .eq("user_id", value: currentUser.id)
                .execute()
                .value
            
            return !response.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Comments
    
    func addComment(postId: UUID, content: String) async {
        guard let currentUser = authManager.currentUser else {
            error = "User not authenticated"
            return
        }
        
        do {
            let comment = Comment(postId: postId, userId: currentUser.id, content: content)
            try await supabaseManager.client
                .from("comments")
                .insert(comment)
                .execute()
            
            // Update post comment count
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index] = SocialPost(
                    id: posts[index].id,
                    userId: posts[index].userId,
                    habitId: posts[index].habitId,
                    captureId: posts[index].captureId,
                    content: posts[index].content,
                    imageUrl: posts[index].imageUrl,
                    likes: posts[index].likes,
                    comments: posts[index].comments + 1,
                    createdAt: posts[index].createdAt,
                    updatedAt: posts[index].updatedAt
                )
            }
            
            await loadFeedItems()
        } catch {
            self.error = "Failed to add comment: \(error.localizedDescription)"
        }
    }
    
    func loadComments(postId: UUID) async -> [Comment] {
        do {
            let response: [Comment] = try await supabaseManager.client
                .from("comments")
                .select()
                .eq("post_id", value: postId)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            return response
        } catch {
            self.error = "Failed to load comments: \(error.localizedDescription)"
            return []
        }
    }
    
    // MARK: - Following
    
    func toggleFollow(userId: UUID) async {
        guard let currentUser = authManager.currentUser else {
            error = "User not authenticated"
            return
        }
        
        do {
            let isFollowing = await checkIfFollowing(userId: userId)
            
            if isFollowing {
                // Unfollow
                try await supabaseManager.client
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: currentUser.id)
                    .eq("following_id", value: userId)
                    .execute()
            } else {
                // Follow
                let follow = Follow(followerId: currentUser.id, followingId: userId)
                try await supabaseManager.client
                    .from("follows")
                    .insert(follow)
                    .execute()
            }
            
            await loadFeedItems()
        } catch {
            self.error = "Failed to toggle follow: \(error.localizedDescription)"
        }
    }
    
    private func checkIfFollowing(userId: UUID) async -> Bool {
        guard let currentUser = authManager.currentUser else { return false }
        
        do {
            let response: [Follow] = try await supabaseManager.client
                .from("follows")
                .select()
                .eq("follower_id", value: currentUser.id)
                .eq("following_id", value: userId)
                .execute()
                .value
            
            return !response.isEmpty
        } catch {
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadUserProfile(userId: UUID) async throws -> User {
        let response: UserProfile = try await supabaseManager.client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        
        // Convert UserProfile to User
        return User(
            id: response.id,
            email: response.email,
            name: response.fullName ?? response.username ?? "Unknown User",
            avatar: response.avatarUrl,
            bio: response.bio,
            createdAt: response.createdAt,
            updatedAt: response.updatedAt
        )
    }
    
    private func loadHabit(habitId: UUID) async throws -> Habit {
        let response: Habit = try await supabaseManager.client
            .from("habits")
            .select()
            .eq("id", value: habitId)
            .single()
            .execute()
            .value
        
        return response
    }
    
    private func loadCapture(captureId: UUID) async throws -> Capture {
        let response: Capture = try await supabaseManager.client
            .from("captures")
            .select()
            .eq("id", value: captureId)
            .single()
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Search and Discovery
    
    func searchUsers(query: String) async -> [User] {
        guard !query.isEmpty else { return [] }
        
        do {
            let response: [UserProfile] = try await supabaseManager.client
                .from("profiles")
                .select()
                .or("username.ilike.%\(query)%,full_name.ilike.%\(query)%")
                .limit(20)
                .execute()
                .value
            
            // Convert UserProfile to User
            return response.map { profile in
                User(
                    id: profile.id,
                    email: profile.email,
                    name: profile.fullName ?? profile.username ?? "Unknown User",
                    avatar: profile.avatarUrl,
                    bio: profile.bio,
                    createdAt: profile.createdAt,
                    updatedAt: profile.updatedAt
                )
            }
        } catch {
            self.error = "Failed to search users: \(error.localizedDescription)"
            return []
        }
    }
    
    func getTrendingPosts() async {
        do {
            let response: [SocialPost] = try await supabaseManager.client
                .from("social_posts")
                .select()
                .gte("created_at", value: Calendar.current.date(byAdding: .day, value: -7, to: Date())?.iso8601 ?? "")
                .order("likes", ascending: false)
                .limit(10)
                .execute()
                .value
            
            posts = response
            await loadFeedItems()
        } catch {
            self.error = "Failed to load trending posts: \(error.localizedDescription)"
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
