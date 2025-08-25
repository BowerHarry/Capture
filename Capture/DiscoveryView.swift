import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject var habitManager: HabitManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var imagePreloader = ImagePreloader.shared
    @State private var searchQuery = ""
    @State private var isLoading = false
    @State private var selectedTab = 0 // 0: Trending, 1: Habits, 2: Users
    @State private var selectedCategoryId: UUID? = nil // Track selected category ID for trending
    @State private var allHabits: [AvailableHabit] = []
    @State private var allUsers: [User] = []
    @State private var filteredHabits: [AvailableHabit] = []
    @State private var filteredUsers: [User] = []
    let onSwitchToHomeTab: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar (visible on all tabs)
                SearchBar(text: $searchQuery)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .onChange(of: searchQuery) { newValue in
                        Task {
                            await performSearch(query: newValue)
                        }
                    }
                
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    Text("Trending").tag(0)
                    Text("Habits").tag(1)
                    Text("Users").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .onChange(of: selectedTab) { newValue in
                    searchQuery = ""
                    // Clear filtered users when switching to Users tab
                    if newValue == 2 {
                        filteredUsers = []
                    }
                    // Hide keyboard when switching tabs
                    hideKeyboard()
                }
                
                // Content with Swipe Navigation
                TabView(selection: $selectedTab) {
                    // Wrap in animation for smooth transitions
                    Group {
                    // Trending Tab
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            TrendingTabContent(
                                searchQuery: searchQuery,
                                onSearchQueryChange: { newQuery in
                                    searchQuery = newQuery
                                },
                                onSwitchToHomeTab: onSwitchToHomeTab,
                                selectedCategoryId: $selectedCategoryId
                            )
                            
                            // Bottom spacer for navigation bar
                            Spacer()
                                .frame(height: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    .onTapGesture {
                        hideKeyboard()
                    }
                    .tag(0)
                    
                    // Habits Tab
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            HabitsTabContent(habits: filteredHabits)
                            
                            // Bottom spacer for navigation bar
                            Spacer()
                                .frame(height: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    .onTapGesture {
                        hideKeyboard()
                    }
                    .tag(1)
                    
                    // Users Tab
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            UsersTabContent(users: filteredUsers, searchQuery: searchQuery)
                            
                            // Bottom spacer for navigation bar
                            Spacer()
                                .frame(height: 100)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                    .onTapGesture {
                        hideKeyboard()
                    }
                    .tag(2)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.8), value: selectedTab)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemBackground), Color.accentColor.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationBarHidden(true)
            .task {
                await loadDiscoveryData()
            }
            .onAppear {
                preloadDiscoveryImages()
            }
            .refreshable {
                await loadDiscoveryData()
            }
        }
    }
    
    private func loadDiscoveryData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Load categories first
        await habitManager.loadHabitCategories()
        
        // Load trending habits
        await habitManager.loadTrendingHabits()
        
        // Load other data
        await habitManager.loadPopularHabits()
        await loadAvailableHabits()
        await loadUsers()
    }
    
    private func loadAvailableHabits() async {
        // This will be implemented with Supabase query
        allHabits = await habitManager.getAllHabits()
        filteredHabits = allHabits
    }
    
    private func loadUsers() async {
        // This will be implemented with Supabase query
        allUsers = await habitManager.getAllUsers()
        // Don't populate filteredUsers initially - only show results when user searches
        filteredUsers = []
    }
    
        private func performSearch(query: String) async {
        if selectedTab == 0 {
            // Search trending habits - this is handled by the computed property
            // No additional filtering needed as it's done in the view
        } else if selectedTab == 1 {
            // Search habits
            if query.isEmpty {
                filteredHabits = allHabits
            } else {
                filteredHabits = allHabits.filter { habit in
                    habit.name.localizedCaseInsensitiveContains(query) ||
                    habit.category.localizedCaseInsensitiveContains(query) ||
                    (habit.description?.localizedCaseInsensitiveContains(query) ?? false)
                }
            }
        } else if selectedTab == 2 {
            // Search users - only show results if query has at least 3 characters
            if query.count < 3 {
                filteredUsers = []
            } else {
                // Filter out the current user from search results
                let currentUserId = authManager.currentUser?.id
                filteredUsers = allUsers.filter { user in
                    // Exclude current user
                    user.id != currentUserId &&
                    // Include users that match the search query
                    (user.username.localizedCaseInsensitiveContains(query) ||
                     (user.bio?.localizedCaseInsensitiveContains(query) ?? false))
                }
                
                // Preload avatars for filtered users
                imagePreloader.preloadUserAvatars(for: filteredUsers)
            }
        }
    }
    
    private var trendingFilteredHabits: [PopularHabit] {
        if searchQuery.isEmpty {
            return habitManager.popularHabits
        } else {
            return habitManager.popularHabits.filter { habit in
                habit.name.localizedCaseInsensitiveContains(searchQuery) ||
                habit.category.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func preloadDiscoveryImages() {
        // Preload trending thumbnails with caching
        let trendingCaptures = habitManager.trendingCaptures.compactMap { $0.imageUrl }
        if !trendingCaptures.isEmpty {
            imagePreloader.preloadTrendingThumbnails(for: trendingCaptures, size: CGSize(width: 64, height: 64))
        }
        
        // Preload popular habit capture images
        let popularCaptures = habitManager.popularHabits.compactMap { habit in
            habit.captures
        }.flatMap { $0 }
        imagePreloader.preloadImages(for: popularCaptures)
        
        // Preload user avatars
        imagePreloader.preloadUserAvatars(for: allUsers)
        
        // Preload filtered user avatars if they exist
        if !filteredUsers.isEmpty {
            imagePreloader.preloadUserAvatars(for: filteredUsers)
        }
    }
}

// MARK: - Tab Content Views

struct TrendingTabContent: View {
    @EnvironmentObject var habitManager: HabitManager
    @StateObject private var imagePreloader = ImagePreloader.shared
    let searchQuery: String
    let onSearchQueryChange: (String) -> Void
    let onSwitchToHomeTab: () -> Void
    @Binding var selectedCategoryId: UUID?
    
    var body: some View {
        LazyVStack(spacing: 24) {
            // Categories
            CategoriesSection(
                categories: habitManager.categories,
                searchQuery: .constant(searchQuery),
                onSearchQueryChange: onSearchQueryChange,
                selectedCategoryId: $selectedCategoryId
            )
            
            // Trending Habits
            TrendingHabitsSection(
                habits: filteredTrendingHabits,
                searchQuery: searchQuery,
                onCaptureHabit: { habit in
                    Task {
                        // Create habit from template
                        do {
                            _ = try await habitManager.createHabitFromTemplate(templateId: habit.id)
                            print("✅ Successfully added habit: \(habit.name)")
                            
                            // Switch to home tab
                            DispatchQueue.main.async {
                                onSwitchToHomeTab()
                            }
                        } catch {
                            print("❌ Error creating habit from template: \(error)")
                        }
                    }
                },
                habitManager: habitManager,
                selectedCategoryId: selectedCategoryId,
                onClearCategory: {
                    selectedCategoryId = nil
                }
            )
            
            // Community Stats
            if !habitManager.popularHabits.isEmpty {
                CommunityStatsCard(stats: habitManager.communityStats)
            }
        }
        .onAppear {
            // Preload images for trending habits immediately
            preloadTrendingImages()
        }
        .task {
            // Ensure images are preloaded when the view appears
            preloadTrendingImages()
        }
        .onChange(of: selectedCategoryId) { newCategoryId in
            // Load trending habits by category when category changes
            if let categoryId = newCategoryId {
                Task {
                    await habitManager.loadTrendingHabitsByCategoryId(categoryId)
                }
            } else {
                // Load all trending habits when no category is selected
                Task {
                    await habitManager.loadTrendingHabits()
                }
            }
        }
    }
    
    private var filteredTrendingHabits: [TrendingHabit] {
        if searchQuery.isEmpty {
            return habitManager.trendingHabits
        } else {
            return habitManager.trendingHabits.filter { habit in
                habit.name.localizedCaseInsensitiveContains(searchQuery) ||
                habit.category.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
    
    private func preloadTrendingImages() {
        // Preload trending thumbnails with caching
        let allCaptures = habitManager.trendingCaptures.compactMap { $0.imageUrl }
        if !allCaptures.isEmpty {
            // Preload all trending thumbnails in the background
            Task {
                for url in allCaptures {
                    _ = await imagePreloader.getTrendingThumbnail(for: url, size: CGSize(width: 64, height: 64))
                }
            }
        }
    }
}

struct HabitsTabContent: View {
    let habits: [AvailableHabit]
    
    var body: some View {
        LazyVStack(spacing: 16) {
            if habits.isEmpty {
                DiscoveryEmptyStateCard(searchQuery: "")
            } else {
                ForEach(habits) { habit in
                    HabitListItem(habit: habit)
                }
            }
        }
    }
}

struct UsersTabContent: View {
    let users: [User]
    let searchQuery: String
    
    var body: some View {
        VStack(spacing: 16) {
            if users.isEmpty {
                VStack(spacing: 16) {
                    Text("👥")
                        .font(.system(size: 48))
                    
                    VStack(spacing: 8) {
                        Text("Find Friends")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        if searchQuery.count < 3 {
                            Text("Type at least 3 characters to search for users")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("No users found matching your search")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                ForEach(users) { user in
                    UserListItem(user: user)
                }
            }
        }
    }
}

// MARK: - List Item Views

struct HabitListItem: View {
    let habit: AvailableHabit
    
    var body: some View {
        HStack(spacing: 16) {
            Text(habit.icon ?? "⭐️")
                .font(.title2)
                .frame(width: 48, height: 48)
                .background(habitColor(for: habit.color))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(habit.category)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let description = habit.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func habitColor(for colorName: String?) -> Color {
        switch colorName?.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "gray": return .gray
        default: return .blue
        }
    }
}

struct UserListItem: View {
    let user: User
    @EnvironmentObject var socialManager: SocialManager
    @State private var isFollowing = false
    @State private var isLoading = false
    @State private var showingUserProfile = false
    
    var body: some View {
        HStack(spacing: 16) {
            // User info section (clickable)
            Button(action: {
                showingUserProfile = true
            }) {
                HStack(spacing: 16) {
                    PreloadableAvatarView(user: user, size: 48)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.username)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if let bio = user.bio {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Follow button
            Button(action: {
                Task {
                    isLoading = true
                    await socialManager.toggleFollow(userId: user.id)
                    // Update the local state based on the actual database state
                    isFollowing = await socialManager.isFollowing(userId: user.id)
                    isLoading = false
                }
            }) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isFollowing ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(16)
            .disabled(isLoading)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .task {
            isFollowing = await socialManager.isFollowing(userId: user.id)
        }
        .onAppear {
            Task {
                isFollowing = await socialManager.isFollowing(userId: user.id)
            }
        }
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView(user: user)
                .environmentObject(HabitManager.shared)
                .environmentObject(SocialManager.shared)
                .environmentObject(AuthManager.shared)
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))
            
            TextField("Search...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
                .onSubmit {
                    isFocused = false
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Categories Section

struct CategoriesSection: View {
    let categories: [DiscoveryHabitCategory]
    @Binding var searchQuery: String
    let onSearchQueryChange: ((String) -> Void)?
    @Binding var selectedCategoryId: UUID?
    
    init(categories: [DiscoveryHabitCategory], searchQuery: Binding<String>, onSearchQueryChange: ((String) -> Void)? = nil, selectedCategoryId: Binding<UUID?>) {
        self.categories = categories
        self._searchQuery = searchQuery
        self.onSearchQueryChange = onSearchQueryChange
        self._selectedCategoryId = selectedCategoryId
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular Categories")
                .font(.title2)
                .fontWeight(.medium)
            
            CategoryFlowLayout(categories: categories) { category in
                CategoryBadge(
                    category: category,
                    isSelected: selectedCategoryId == category.id,
                    onTap: {
                        if selectedCategoryId == category.id {
                            // If already selected, unselect it
                            selectedCategoryId = nil
                            if let onSearchQueryChange = onSearchQueryChange {
                                onSearchQueryChange("")
                            } else {
                                searchQuery = ""
                            }
                        } else {
                            // Select the new category
                            selectedCategoryId = category.id
                            if let onSearchQueryChange = onSearchQueryChange {
                                onSearchQueryChange(category.name)
                            } else {
                                searchQuery = category.name
                            }
                        }
                    }
                )
            }
        }
    }
}

struct CategoryBadge: View {
    let category: DiscoveryHabitCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(category.name)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(height: 32)
                .background(isSelected ? CaptureTheme.categoryColor(from: category.color) : CaptureTheme.categoryColor(from: category.color).opacity(0.3))
                .foregroundColor(isSelected ? .white : CaptureTheme.categoryColor(from: category.color))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? CaptureTheme.categoryColor(from: category.color) : Color.clear, lineWidth: 2)
                )
                .cornerRadius(8)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Trending Habits Section

struct TrendingHabitsSection: View {
    let habits: [TrendingHabit]
    let searchQuery: String
    let onCaptureHabit: (TrendingHabit) -> Void
    @ObservedObject var habitManager: HabitManager
    let selectedCategoryId: UUID?
    let onClearCategory: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(sectionTitle)
                    .font(.title2)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let selectedCategoryId = selectedCategoryId {
                    Button("Clear") {
                        onClearCategory?()
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            if habits.isEmpty {
                DiscoveryEmptyStateCard(searchQuery: searchQuery)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(habits) { habit in
                        DiscoveryHabitCard(
                            habit: habit,
                            habitManager: habitManager,
                            onCaptureHabit: onCaptureHabit
                        )
                    }
                }
            }
        }
    }
    
    private var sectionTitle: String {
        if let selectedCategoryId = selectedCategoryId {
            // Find the selected category name
            let selectedCategory = habitManager.habitCategories.first { $0.id == selectedCategoryId }
            let categoryName = selectedCategory?.name ?? "Category"
            return "Top \(categoryName) Habits"
        } else {
            return "Trending Habits"
        }
    }
}

struct DiscoveryHabitCard: View {
    let habit: TrendingHabit
    @ObservedObject var habitManager: HabitManager
    let onCaptureHabit: (TrendingHabit) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Left side: Thumbnails (smaller)
            let trendingCaptures = habitManager.getTrendingCaptures(for: habit.id)
            let captureUrls = trendingCaptures.compactMap { $0.imageUrl }
            
            let _ = NSLog("[DiscoveryHabitCard] habit: %@, trendingCaptures count: %d, captureUrls count: %d", habit.name, trendingCaptures.count, captureUrls.count)
            
            HabitPhotoGrid(captures: captureUrls, habitName: habit.name)
                .frame(width: 48, height: 48)
                .clipped()
                .cornerRadius(8)
            
            // Center: Habit details
            VStack(alignment: .leading, spacing: 8) {
                // Habit name and category
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // Category tag
                        Text(habit.category)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(CaptureTheme.categoryColor(from: habit.categoryColor).opacity(0.2))
                            .foregroundColor(CaptureTheme.categoryColor(from: habit.categoryColor))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    // Right side: Capture button
                    Button(action: {
                        onCaptureHabit(habit)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.aperture")
                                .font(.caption)
                            Text("Capture")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.clear)
                        .foregroundColor(.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary, lineWidth: 1)
                        )
                    }
                }
                
                // Description (full width)
                Text(habit.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Metrics (simplified, no emojis/icons)
                HStack(spacing: 16) {
                    Text("\(habit.participants) participants")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(habit.avgStreak)) avg streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(habit.totalCaptures) captures")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var categoryColor: Color {
        // Use the category color from the database if available
        if let categoryColorString = habit.categoryColor {
            return CaptureTheme.categoryColor(from: categoryColorString)
        }
        
        // Fallback to inferring from habit name if no category color is available
        return inferCategoryColorFromHabitName(habit.name)
    }
    
    private func colorFromString(_ colorString: String) -> Color {
        switch colorString.lowercased() {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        case "yellow": return .yellow
        case "mint": return .mint
        case "indigo": return .indigo
        case "teal": return .teal
        default: return .gray
        }
    }
    
    private func inferCategoryColorFromHabitName(_ habitName: String) -> Color {
        let lowercasedName = habitName.lowercased()
        
        // Fitness/Health related
        if lowercasedName.contains("steps") || lowercasedName.contains("workout") || 
           lowercasedName.contains("exercise") || lowercasedName.contains("run") ||
           lowercasedName.contains("gym") || lowercasedName.contains("fitness") {
            return .green
        }
        
        // Learning/Education related
        if lowercasedName.contains("read") || lowercasedName.contains("learn") ||
           lowercasedName.contains("study") || lowercasedName.contains("language") ||
           lowercasedName.contains("book") || lowercasedName.contains("course") {
            return .orange
        }
        
        // Health/Nutrition related
        if lowercasedName.contains("water") || lowercasedName.contains("meal") ||
           lowercasedName.contains("diet") || lowercasedName.contains("nutrition") ||
           lowercasedName.contains("vitamin") || lowercasedName.contains("healthy") {
            return .mint
        }
        
        // Wellness/Mindfulness related
        if lowercasedName.contains("meditation") || lowercasedName.contains("journal") ||
           lowercasedName.contains("sleep") || lowercasedName.contains("mindfulness") ||
           lowercasedName.contains("breathing") || lowercasedName.contains("yoga") {
            return .purple
        }
        
        // Productivity related
        if lowercasedName.contains("work") || lowercasedName.contains("productivity") ||
           lowercasedName.contains("focus") || lowercasedName.contains("task") ||
           lowercasedName.contains("goal") || lowercasedName.contains("plan") {
            return .blue
        }
        
        // Social related
        if lowercasedName.contains("social") || lowercasedName.contains("friend") ||
           lowercasedName.contains("family") || lowercasedName.contains("call") ||
           lowercasedName.contains("meet") || lowercasedName.contains("connect") {
            return .pink
        }
        
        // Default
        return .gray
    }
}

struct HabitPhotoGrid: View {
    let captures: [String]
    let habitName: String
    
    var body: some View {
        Group {
            let validCaptures = captures.compactMap { item -> String? in
                if let string = item as? String {
                    return string
                } else {
                    NSLog("[HabitPhotoGrid] Warning: non-string item in captures array: %@", String(describing: item))
                    return nil
                }
            }
            
            let photosToShow = validCaptures.count >= 4 ? Array(validCaptures.prefix(4)) : validCaptures
            
            let _ = NSLog("[HabitPhotoGrid] habit: %@, original captures count: %d, valid captures count: %d, photosToShow count: %d", habitName, captures.count, validCaptures.count, photosToShow.count)
            
            if photosToShow.isEmpty {
                // Placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text("📸")
                            .font(.title2)
                    )
            } else if photosToShow.count == 1 {
                // Single photo - use trending thumbnail with caching
                TrendingThumbnailAsyncImage(imageUrl: photosToShow[0], size: CGSize(width: 64, height: 64)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                // 2x2 grid - use trending thumbnails with caching
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 1),
                    GridItem(.flexible(), spacing: 1)
                ], spacing: 1) {
                    ForEach(photosToShow, id: \.self) { photoUrl in
                        TrendingThumbnailAsyncImage(imageUrl: photoUrl, size: CGSize(width: 31, height: 31)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 31, height: 31)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(width: 64, height: 64)
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Thumbnail Async Image Component

struct ThumbnailAsyncImage<Content: View, Placeholder: View>: View {
    let url: String
    let size: CGSize
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var imagePreloader = ImagePreloader.shared
    @State private var image: UIImage?
    @State private var isLoading = true
    
    init(url: String, size: CGSize, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.size = size
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        Task {
            if let thumbnail = await imagePreloader.getTrendingThumbnail(for: url, size: size) {
                await MainActor.run {
                    self.image = thumbnail
                    self.isLoading = false
                }
            }
        }
    }
}

struct TrendingThumbnailAsyncImage<Content: View, Placeholder: View>: View {
    let imageUrl: String
    let size: CGSize
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var imagePreloader = ImagePreloader.shared
    @State private var image: UIImage?
    @State private var isLoading = true
    
    init(imageUrl: String, size: CGSize, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.imageUrl = imageUrl
        self.size = size
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: imageUrl) { _ in
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        // First check if image is already cached synchronously
        if let cachedImage = imagePreloader.getCachedTrendingThumbnailOnly(for: imageUrl) {
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        // If not cached, use the completion callback system
        imagePreloader.getTrendingThumbnail(for: imageUrl, size: size) { loadedImage in
            DispatchQueue.main.async {
                self.image = loadedImage
                self.isLoading = false
            }
        }
    }
}

struct DiscoveryEmptyStateCard: View {
    let searchQuery: String
    
    var body: some View {
        VStack(spacing: 16) {
            Text("🔍")
                .font(.system(size: 48))
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(emptyStateSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var emptyStateTitle: String {
        if searchQuery.isEmpty {
            return "No popular habits yet"
        } else {
            return "No habits found"
        }
    }
    
    private var emptyStateSubtitle: String {
        if searchQuery.isEmpty {
            return "Be the first to start tracking habits and inspire others!"
        } else {
            return "Try searching for something else or create a new habit!"
        }
    }
}

// MARK: - Community Stats Card

struct CommunityStatsCard: View {
    let stats: CommunityStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Community Stats")
                .font(.headline)
                .fontWeight(.medium)
            
            HStack(spacing: 0) {
                StatItem(
                    value: stats.activeUsers,
                    label: "Active Users"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    value: stats.totalHabits,
                    label: "Habits"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    value: stats.totalCaptures,
                    label: "Captures"
                )
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct StatItem: View {
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(value.formatted())")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DiscoveryView(onSwitchToHomeTab: {})
        .environmentObject(HabitManager.shared)
        .environmentObject(AuthManager.shared)
}

// MARK: - Shared Components

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

struct CategoryFlowLayout<Content: View>: View {
    let categories: [DiscoveryHabitCategory]
    let content: (DiscoveryHabitCategory) -> Content
    
    @State private var sizes: [UUID: CGSize] = [:]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let spacing: CGFloat = 8
            
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: spacing) {
                        ForEach(row, id: \.id) { category in
                            content(category)
                                .background(
                                    GeometryReader { itemGeometry in
                                        Color.clear
                                            .onAppear {
                                                sizes[category.id] = itemGeometry.size
                                            }
                                    }
                                )
                        }
                        Spacer()
                    }
                }
            }
        }
        .frame(height: totalHeight)
    }
    
    private var rows: [[DiscoveryHabitCategory]] {
        var result: [[DiscoveryHabitCategory]] = []
        var currentRow: [DiscoveryHabitCategory] = []
        var currentRowWidth: CGFloat = 0
        let maxWidth = UIScreen.main.bounds.width - 32 // Account for padding
        let spacing: CGFloat = 8
        
        for category in categories {
            let categoryWidth = sizes[category.id]?.width ?? 100 // Default width
            let totalWidth = currentRowWidth + categoryWidth + (currentRow.isEmpty ? 0 : spacing)
            
            if totalWidth <= maxWidth {
                currentRow.append(category)
                currentRowWidth = totalWidth
            } else {
                if !currentRow.isEmpty {
                    result.append(currentRow)
                }
                currentRow = [category]
                currentRowWidth = categoryWidth
            }
        }
        
        if !currentRow.isEmpty {
            result.append(currentRow)
        }
        
        return result
    }
    
    private var totalHeight: CGFloat {
        let rowHeight: CGFloat = 32 + 8 // Category height + spacing
        return CGFloat(rows.count) * rowHeight
    }
}

















