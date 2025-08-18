import SwiftUI

struct DiscoveryView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var habitManager: HabitManager
    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var showingSearch = false
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Discovery")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: { showingSearch = true }) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Tab Picker
                    Picker("Discovery Tab", selection: $selectedTab) {
                        Text("Trending").tag(0)
                        Text("People").tag(1)
                        Text("Habits").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Content
                TabView(selection: $selectedTab) {
                    TrendingView()
                        .tag(0)
                    
                    PeopleView()
                        .tag(1)
                    
                    HabitInspirationView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
            .task {
                await socialManager.loadPosts()
            }
            .sheet(isPresented: $showingSearch) {
                SearchView(searchText: $searchText, searchResults: $searchResults, isSearching: $isSearching)
            }
        }
    }
}

// MARK: - Trending View

struct TrendingView: View {
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if socialManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if socialManager.feedItems.isEmpty {
                    EmptyStateView(
                        icon: "flame",
                        title: "No trending posts yet",
                        subtitle: "Be the first to share your habit journey!"
                    )
                } else {
                    ForEach(socialManager.feedItems) { item in
                        DiscoverySocialPostCard(item: item)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .refreshable {
            await socialManager.getTrendingPosts()
        }
    }
}

// MARK: - People View

struct PeopleView: View {
    @EnvironmentObject var socialManager: SocialManager
    @State private var suggestedUsers: [User] = []
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if suggestedUsers.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No people to discover",
                        subtitle: "Check back later for new connections!"
                    )
                } else {
                    ForEach(suggestedUsers) { user in
                        UserCard(user: user)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .task {
            await loadSuggestedUsers()
        }
    }
    
    private func loadSuggestedUsers() async {
        isLoading = true
        // In a real app, this would load users based on mutual connections, interests, etc.
        suggestedUsers = []
        isLoading = false
    }
}

// MARK: - Habit Inspiration View

struct HabitInspirationView: View {
    @EnvironmentObject var habitManager: HabitManager
    @State private var selectedCategory: HabitCategory? = nil
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryChip(title: "All", isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        
                        ForEach(HabitCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                icon: category.icon,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Habit Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(filteredHabits) { habit in
                        HabitInspirationCard(habit: habit)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 16)
        }
    }
    
    private var filteredHabits: [AvailableHabit] {
        if let category = selectedCategory {
            return habitManager.availableHabits.filter { $0.category == category.rawValue }
        } else {
            return habitManager.availableHabits
        }
    }
}

// MARK: - Supporting Views

private struct DiscoverySocialPostCard: View {
    let item: SocialFeedItem
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Header
            HStack {
                AsyncImage(url: URL(string: item.user.avatar ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.user.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(timeAgoString(from: item.post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await socialManager.toggleFollow(userId: item.user.id)
                    }
                }) {
                    Text(item.isFollowing ? "Following" : "Follow")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(item.isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                        .foregroundColor(item.isFollowing ? .primary : .white)
                        .cornerRadius(16)
                }
            }
            
            // Content
            Text(item.post.content)
                .font(.body)
                .multilineTextAlignment(.leading)
            
            // Habit/Capture Info
            if let habit = item.habit {
                HStack {
                    Text(habit.icon ?? "⭐️")
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .background(habitColor(for: habit.color))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(habit.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Image
            if let imageUrl = item.post.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Actions
            HStack(spacing: 20) {
                Button(action: {
                    Task {
                        await socialManager.toggleLike(postId: item.post.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: item.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(item.isLiked ? .red : .primary)
                        Text("\(item.post.likes)")
                            .font(.caption)
                    }
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                        Text("\(item.post.comments)")
                            .font(.caption)
                    }
                }
                
                Spacer()
            }
            .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
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
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct UserCard: View {
    let user: User
    @EnvironmentObject var socialManager: SocialManager
    @State private var isFollowing = false
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.avatar ?? "")) { image in
                image.resizable()
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if let bio = user.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Button(action: {
                Task {
                    await socialManager.toggleFollow(userId: user.id)
                    isFollowing.toggle()
                }
            }) {
                Text(isFollowing ? "Following" : "Follow")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                    .foregroundColor(isFollowing ? .primary : .white)
                    .cornerRadius(20)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct HabitInspirationCard: View {
    let habit: AvailableHabit
    
    var body: some View {
        VStack(spacing: 12) {
            Text(habit.icon ?? "⭐️")
                .font(.system(size: 32))
                .frame(width: 60, height: 60)
                .background(habitColor(for: habit.color))
                .clipShape(Circle())
            
            VStack(spacing: 4) {
                Text(habit.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(habit.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let description = habit.description {
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
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

struct CategoryChip: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Text(icon)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
    }
}

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

struct SearchView: View {
    @Binding var searchText: String
    @Binding var searchResults: [User]
    @Binding var isSearching: Bool
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchText) { newValue in
                            Task {
                                await performSearch(query: newValue)
                            }
                        }
                    
                    if !searchText.isEmpty {
                        Button("Cancel") {
                            searchText = ""
                            searchResults = []
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)
                
                // Results
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "No users found",
                        subtitle: "Try searching with a different term"
                    )
                } else {
                    List(searchResults) { user in
                        UserCard(user: user)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchResults = await socialManager.searchUsers(query: query)
        isSearching = false
    }
}

#Preview {
    DiscoveryView()
        .environmentObject(SocialManager.shared)
        .environmentObject(HabitManager.shared)
}
