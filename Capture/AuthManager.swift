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
    
    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let user = try await supabaseClient.signUp(email: email, password: password, name: name)
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
    
    func updateProfile(name: String?, bio: String?, avatar: String?) async {
        guard let currentUser = currentUser else { return }
        
        isLoading = true
        
        do {
            let updatedUser = try await supabaseClient.updateProfile(
                userId: currentUser.id.uuidString,
                name: name,
                bio: bio,
                avatar: avatar
            )
            self.currentUser = updatedUser
        } catch {
            self.errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
