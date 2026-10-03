import Foundation
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseClient = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkExistingSession()
    }
    
    func checkExistingSession() {
        Task {
            isLoading = true
            do {
                if let user = try await supabaseClient.getCurrentUser() {
                    self.currentUser = user
                    self.isAuthenticated = true
                    // Load habits on session restore
                    await HabitManager.shared.loadHabits()
                }
            } catch {
                print("Session check failed: \(error)")
            }
            isLoading = false
        }
    }
    
    func signUp(email: String, password: String, username: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await supabaseClient.signUp(email: email, password: password, username: username)
            self.currentUser = user
            self.isAuthenticated = true
            // Load habits after signup
            await HabitManager.shared.loadHabits()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await supabaseClient.signIn(email: email, password: password)
            self.currentUser = user
            self.isAuthenticated = true
            // Load habits after signin
            await HabitManager.shared.loadHabits()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func signOut() async {
        do {
            try await supabaseClient.signOut()
            self.isAuthenticated = false
            self.currentUser = nil
        } catch {
            print("Sign out failed: \(error)")
        }
    }
    
    func updateProfile(username: String?, bio: String?, avatar: String?) async {
        guard let currentUser = currentUser else { return }
        
        isLoading = true
        
        do {
            let updatedUser = try await supabaseClient.updateProfile(
                userId: currentUser.id.uuidString,
                username: username,
                bio: bio,
                avatar: avatar
            )
            self.currentUser = updatedUser
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func updateCurrentUser(_ user: User) async {
        self.currentUser = user
    }
    
    func refreshFollowerCounts() async {
        #if DEBUG
        if DemoMode.isEnabled { return }
        #endif
        guard let currentUser = currentUser else { 
            print("❌ No current user to refresh follower counts")
            return 
        }
        
        print("🔄 Refreshing follower counts for user: \(currentUser.id)")
        
        do {
            // Get followers count
            let followersResponse: [Follow] = try await supabaseClient.client
                .from("user_follows")
                .select()
                .eq("following_id", value: currentUser.id)
                .execute()
                .value
            
            // Get following count
            let followingResponse: [Follow] = try await supabaseClient.client
                .from("user_follows")
                .select()
                .eq("follower_id", value: currentUser.id)
                .execute()
                .value
            
            print("📊 Found \(followersResponse.count) followers and \(followingResponse.count) following")
            
            // Update current user with new counts
            let updatedUser = User(
                id: currentUser.id,
                email: currentUser.email,
                username: currentUser.username,
                avatar: currentUser.avatar,
                bio: currentUser.bio,
                createdAt: currentUser.createdAt,
                updatedAt: currentUser.updatedAt,
                followersCount: followersResponse.count,
                followingCount: followingResponse.count,
                bestStreak: currentUser.bestStreak
            )
            
            print("✅ Updated user with \(updatedUser.followersCount ?? 0) followers and \(updatedUser.followingCount ?? 0) following")
            self.currentUser = updatedUser
        } catch {
            print("❌ Failed to refresh follower counts: \(error)")
        }
    }
    
    func refreshFollowerCountsForUser(userId: UUID) async {
        #if DEBUG
        if DemoMode.isEnabled { return }
        #endif
        print("🔄 Refreshing follower counts for specific user: \(userId)")
        
        do {
            // Get followers count for the specific user
            let followersResponse: [Follow] = try await supabaseClient.client
                .from("user_follows")
                .select()
                .eq("following_id", value: userId)
                .execute()
                .value
            
            // Get following count for the specific user
            let followingResponse: [Follow] = try await supabaseClient.client
                .from("user_follows")
                .select()
                .eq("follower_id", value: userId)
                .execute()
                .value
            
            print("📊 User \(userId) has \(followersResponse.count) followers and \(followingResponse.count) following")
            
            // If this is the current user, update the current user object
            if let currentUser = currentUser, currentUser.id == userId {
                let updatedUser = User(
                    id: currentUser.id,
                    email: currentUser.email,
                    username: currentUser.username,
                    avatar: currentUser.avatar,
                    bio: currentUser.bio,
                    createdAt: currentUser.createdAt,
                    updatedAt: currentUser.updatedAt,
                    followersCount: followersResponse.count,
                    followingCount: followingResponse.count,
                    bestStreak: currentUser.bestStreak
                )
                
                print("✅ Updated current user with new counts")
                self.currentUser = updatedUser
            }
        } catch {
            print("❌ Failed to refresh follower counts for user \(userId): \(error)")
        }
    }
}
