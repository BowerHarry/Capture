import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var habitManager: HabitManager
    @StateObject private var imagePreloader = ImagePreloader.shared
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .onAppear {
            if authManager.isAuthenticated {
                Task { 
                    await habitManager.loadAppData()
                    
                    // Start preloading trending thumbnails immediately after app data is loaded
                    let trendingURLs = habitManager.trendingCaptures.compactMap { $0.imageUrl }
                    if !trendingURLs.isEmpty {
                        imagePreloader.preloadTrendingThumbnails(for: trendingURLs, size: CGSize(width: 64, height: 64))
                    }
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthed in
            if isAuthed {
                Task { await habitManager.loadAppData() }
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var selectedHabitId: UUID?
    @State private var showingDebugPanel = false
    @State private var isKeyboardVisible = false
    @StateObject private var imagePreloader = ImagePreloader.shared
    @EnvironmentObject var habitManager: HabitManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var authManager: AuthManager
    
    // Private properties for preventing duplicate calls
    @State private var lastPreloadTime: Date = Date.distantPast
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Content area
                ZStack {
                    switch selectedTab {
                    case 0:
                        HabitDashboardView(onNavigateToCamera: { habitId in
                            selectedHabitId = habitId
                            selectedTab = 2
                        })
                    case 1:
                        SocialFeedView()
                    case 2:
                        CameraCaptureView(
                            preselectedHabitId: selectedHabitId?.uuidString,
                            onBack: {
                                selectedHabitId = nil
                                selectedTab = 0
                            }
                        )
                    case 3:
                        DiscoveryView()
                            .environmentObject(AuthManager.shared)
                    case 4:
                        ProfileView()
                    default:
                        HabitDashboardView(onNavigateToCamera: { habitId in
                            selectedHabitId = habitId
                            selectedTab = 2
                        })
                    }
                }
            }
            
            // Custom floating tab bar
            if !isKeyboardVisible {
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $selectedTab)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75)
                        .padding(.bottom, 10)
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    let threshold: CGFloat = 50
                                    if value.translation.width > threshold {
                                        // Swipe right - go to previous tab
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedTab = max(0, selectedTab - 1)
                                        }
                                    } else if value.translation.width < -threshold {
                                        // Swipe left - go to next tab
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedTab = min(4, selectedTab + 1)
                                        }
                                    }
                                }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isKeyboardVisible)
                }
                .allowsHitTesting(true)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Preload images for all tabs when the app loads
            Task {
                await preloadImagesForAllTabs()
            }
        }
        .onChange(of: selectedTab) { newTab in
            // Preload images for the tab that's about to be selected
            Task {
                await preloadImagesForTab(newTab)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = false
            }
        }
    }
    
    // MARK: - Image Preloading Functions
    
    private func preloadImagesForAllTabs() async {
        // Preload user avatar
        if let currentUser = authManager.currentUser, let avatar = currentUser.avatar {
            imagePreloader.preloadImageSync(url: avatar)
        }
        
        // Preload habit captures
        imagePreloader.preloadHabitCaptures(habitManager.captures)
        
        // Preload discovery images in background
        await preloadDiscoveryImages()
        
        // Preload social feed images (if available)
        // This will be called when social data is loaded
    }
    
    private func preloadImagesForTab(_ tab: Int) async {
        switch tab {
        case 0: // Dashboard
            // Preload habit captures and user avatars
            imagePreloader.preloadHabitCaptures(habitManager.captures)
            if let currentUser = authManager.currentUser, let avatar = currentUser.avatar {
                imagePreloader.preloadImageSync(url: avatar)
            }
            
        case 1: // Social Feed
            // Preload social feed images and user avatars
            // This will be called when social data is loaded
            break
            
        case 3: // Discovery
            // Preload popular habit images and user avatars
            await preloadDiscoveryImages()
            break
            
        case 4: // Profile
            // Preload user avatar and habit captures
            if let currentUser = authManager.currentUser, let avatar = currentUser.avatar {
                imagePreloader.preloadImageSync(url: avatar)
            }
            imagePreloader.preloadHabitCaptures(habitManager.captures)
            
        default:
            break
        }
    }
    
    private func preloadDiscoveryImages() async {
        // Only preload if we haven't already done so recently
        let now = Date()
        
        // Only preload if it's been more than 30 seconds since last preload
        guard now.timeIntervalSince(lastPreloadTime) > 30 else {
            print("🖼️ Skipping preload - too soon since last preload")
            return
        }
        
        lastPreloadTime = now
        
        // Load all discovery data if not already loaded
        if habitManager.trendingHabits.isEmpty {
            await habitManager.loadTrendingHabits()
        }
        if habitManager.popularHabits.isEmpty {
            await habitManager.loadPopularHabits()
        }
        
        // No longer preloading trending captures - they're loaded on-demand without caching
        
        // Preload popular habit capture images
        let popularCaptures = habitManager.popularHabits.compactMap { habit in
            habit.captures
        }.flatMap { $0 }
        imagePreloader.preloadImages(for: popularCaptures)
        
        // Load and preload user avatars
        let allUsers = await habitManager.getAllUsers()
        imagePreloader.preloadUserAvatars(for: allUsers)
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @StateObject private var imagePreloader = ImagePreloader.shared
    @EnvironmentObject var habitManager: HabitManager
    @EnvironmentObject var authManager: AuthManager
    
    private let tabs = [
        TabItem(icon: "house", title: "Home", tag: 0, gradient: [Color.blue, Color.purple], isSpecial: false),
        TabItem(icon: "person.2", title: "Feed", tag: 1, gradient: [Color.pink, Color.red], isSpecial: false),
        TabItem(icon: "camera.aperture", title: "Capture", tag: 2, gradient: [Color.orange, Color.red], isSpecial: true),
        TabItem(icon: "magnifyingglass", title: "Discover", tag: 3, gradient: [Color.green, Color.mint], isSpecial: false),
        TabItem(icon: "person", title: "Profile", tag: 4, gradient: [Color.orange, Color.yellow], isSpecial: false)
    ]
    

    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                TabButtonView(
                    tab: tab,
                    isSelected: selectedTab == tab.tag,
                    onTap: { selectedTab = tab.tag }
                )
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        )
    }
}

struct TabItem {
    let icon: String
    let title: String
    let tag: Int
    let gradient: [Color]
    let isSpecial: Bool
}

struct TabButtonView: View {
    let tab: TabItem
    let isSelected: Bool
    let onTap: () -> Void
    @StateObject private var imagePreloader = ImagePreloader.shared
    @EnvironmentObject var habitManager: HabitManager
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Button(action: {
            // Preload images for the tab being tapped
            Task {
                await preloadImagesForTab(tab.tag)
            }
            onTap()
        }) {
            VStack(spacing: 0) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(4)
            .background(
                isSelected ?
                AnyShapeStyle(
                    LinearGradient(
                        colors: tab.gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ) : AnyShapeStyle(Color.clear)
            )
            .cornerRadius(18)
            .scaleEffect(isSelected ? 1.05 : 0.95)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 0, maxWidth: .infinity)
    }
    
    private func preloadImagesForTab(_ tab: Int) async {
        switch tab {
        case 0: // Dashboard
            // Preload habit captures and user avatars
            imagePreloader.preloadHabitCaptures(habitManager.captures)
            if let currentUser = authManager.currentUser, let avatar = currentUser.avatar {
                imagePreloader.preloadImageSync(url: avatar)
            }
            
        case 1: // Social Feed
            // Preload social feed images and user avatars
            // This will be called when social data is loaded
            break
            
        case 3: // Discovery
            // Preload popular habit images and user avatars
            await preloadDiscoveryImages()
            break
            
        case 4: // Profile
            // Preload user avatar and habit captures
            if let currentUser = authManager.currentUser, let avatar = currentUser.avatar {
                imagePreloader.preloadImageSync(url: avatar)
            }
            imagePreloader.preloadHabitCaptures(habitManager.captures)
            
        default:
            break
        }
    }
    
    private func preloadDiscoveryImages() async {
        // Load all app data at startup if not already loaded
        if habitManager.habits.isEmpty {
            await habitManager.loadAppData()
        }
        
        // Preload trending thumbnails with caching
        let trendingURLs = habitManager.trendingCaptures.compactMap { $0.imageUrl }
        if !trendingURLs.isEmpty {
            imagePreloader.preloadTrendingThumbnails(for: trendingURLs, size: CGSize(width: 64, height: 64))
        }
        
        // Preload popular habit capture images (only if not already preloaded)
        let popularCaptures = habitManager.popularHabits.compactMap { habit in
            habit.captures
        }.flatMap { $0 }
        if !popularCaptures.isEmpty {
            imagePreloader.preloadImages(for: popularCaptures)
        }
        
        // Load and preload user avatars
        let allUsers = await habitManager.getAllUsers()
        imagePreloader.preloadUserAvatars(for: allUsers)
    }
}



#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(HabitManager.shared)
        .environmentObject(SocialManager.shared)
}
