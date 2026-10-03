import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var habitManager: HabitManager
    @StateObject private var imagePreloader = ImagePreloader.shared
    @StateObject private var cacheManager = AppCacheManager.shared
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if cacheManager.isInitializing {
                    LoadingView()
                } else {
                    MainTabView()
                }
            } else {
                AuthView()
            }
        }
        .onAppear {
            if authManager.isAuthenticated {
                Task { 
                    // Load high priority data first (habits)
                    await loadHabitsWithCache()
                    await loadHabitCategoriesWithCache()
                    
                    // Preload images for current habits
                    imagePreloader.preloadHabitCaptures(habitManager.captures)
                }
            }
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthed in
            if isAuthed {
                Task { 
                    await loadHabitsWithCache()
                    await loadHabitCategoriesWithCache()
                }
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading your habits...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Cache Loading Helpers

extension ContentView {
    private func loadHabitsWithCache() async {
        // Try cache first
        if let cachedHabits = cacheManager.getCachedHabits() {
            habitManager.habits = cachedHabits
            
            // Load captures in background
            Task {
                await loadCapturesWithCache()
            }
            return
        }
        
        // Load from network if cache miss
        await habitManager.loadHabits()
        
        // Cache the result
        cacheManager.cacheHabits(habitManager.habits)
    }
    
    private func loadCapturesWithCache() async {
        if let cachedCaptures = cacheManager.getCachedCaptures() {
            habitManager.captures = cachedCaptures
            return
        }
        
        // Load from network
        do {
            let captures = try await SupabaseManager.shared.getCapturesSince(since: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date())
            habitManager.captures = captures
            cacheManager.cacheCaptures(captures)
        } catch {
            Log.error("❌ Failed to load captures: \(error)")
        }
    }
    
    private func loadHabitCategoriesWithCache() async {
        if let cachedCategories = cacheManager.getCachedHabitCategories() {
            habitManager.habitCategories = cachedCategories
            habitManager.categories = cachedCategories.map { DiscoveryHabitCategory(from: $0) }
            return
        }
        
        await habitManager.loadHabitCategories()
        cacheManager.cacheHabitCategories(habitManager.habitCategories)
    }
}

struct MainTabView: View {
    #if DEBUG
    @State private var selectedTab = DemoMode.initialTab
    #else
    @State private var selectedTab = 0
    #endif
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
                        DiscoveryView(onSwitchToHomeTab: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = 0
                            }
                        })
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
        .onChange(of: selectedTab) { _, newTab in
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
        await preloadImagesForTab(0)
        await preloadDiscoveryImages()
    }
    
    private func preloadImagesForTab(_ tab: Int) async {
        switch tab {
        case 0, 4: // Dashboard and Profile both show the user's avatar and captures
            imagePreloader.preloadHabitCaptures(habitManager.captures)
            if let avatar = authManager.currentUser?.avatar {
                imagePreloader.preloadImageSync(url: avatar)
            }
        case 3: // Discovery
            await preloadDiscoveryImages()
        default: // The feed preloads its own images once its data has loaded
            break
        }
    }
    
    private func preloadDiscoveryImages() async {
        // Only preload if we haven't already done so recently
        let now = Date()
        
        // Only preload if it's been more than 30 seconds since last preload
        guard now.timeIntervalSince(lastPreloadTime) > 30 else {
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
    
    var body: some View {
        // Image preloading for the new tab is handled by MainTabView when the selection changes
        Button(action: onTap) {
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
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(HabitManager.shared)
        .environmentObject(SocialManager.shared)
}
