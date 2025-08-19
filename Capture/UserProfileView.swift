import SwiftUI

struct UserProfileView: View {
    let user: User
    @EnvironmentObject var habitManager: HabitManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = "overview"
    @State private var isLoading = false
    @State private var userHabits: [Habit] = []
    @State private var userCaptures: [Capture] = []
    @State private var isFollowing = false
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    UserProfileHeaderView(
                        user: user,
                        userHabits: userHabits,
                        userCaptures: userCaptures,
                        isFollowing: isFollowing,
                        onFollowToggle: {
                            Task {
                                await toggleFollow()
                            }
                        }
                    )
                    
                    // Profile Tabs
                    UserProfileTabsView(
                        selectedTab: $selectedTab,
                        user: user,
                        userHabits: userHabits,
                        userCaptures: userCaptures
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100) // Space for floating tab bar
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(.systemBackground),
                        Color(.systemBackground),
                        CaptureTheme.Palette.accent.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            .sheet(isPresented: $showingFollowers) {
                FollowersListView(userId: user.id)
            }
                    .sheet(isPresented: $showingFollowing) {
            FollowingListView(userId: user.id)
        }
        .onAppear {
            Task {
                await loadUserData()
            }
        }
        }
    }
    
    private func loadUserData() async {
        isLoading = true
        
        // Load user's captures first, then habits (so we can calculate streaks)
        await loadUserCaptures()
        await loadUserHabits()
        
        // Check if current user is following this user
        isFollowing = await socialManager.isFollowing(userId: user.id)
        
        isLoading = false
    }
    
    private func loadUserHabits() async {
        do {
            let habits: [Habit] = try await SupabaseManager.shared.client
                .from("habits")
                .select()
                .eq("user_id", value: user.id)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            userHabits = habits
        } catch {
            print("❌ Failed to load user habits: \(error)")
            userHabits = []
        }
    }
    
    private func loadUserCaptures() async {
        do {
            let captures: [Capture] = try await SupabaseManager.shared.client
                .from("captures")
                .select()
                .eq("user_id", value: user.id)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            userCaptures = captures
        } catch {
            print("❌ Failed to load user captures: \(error)")
            userCaptures = []
        }
    }
    

    
    private func toggleFollow() async {
        await socialManager.toggleFollow(userId: user.id)
        isFollowing = await socialManager.isFollowing(userId: user.id)
    }
    

}

// MARK: - User Profile Header

struct UserProfileHeaderView: View {
    let user: User
    let userHabits: [Habit]
    let userCaptures: [Capture]
    let isFollowing: Bool
    let onFollowToggle: () -> Void
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var habitManager: HabitManager
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    
    private var totalHabits: Int {
        userHabits.count
    }
    
    private var totalCaptures: Int {
        userCaptures.count
    }
    
    private var followers: Int {
        followersCount
    }
    
    private var following: Int {
        followingCount
    }
    
    private func extractUsername(from email: String?) -> String {
        guard let email = email else { return "user" }
        return email.split(separator: "@").first?.description ?? "user"
    }
    
    private func formatJoinDate(_ date: Date?) -> String {
        guard let date = date else { return "recently" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content with gradient background
            VStack(spacing: 24) {
                // Profile info section
                HStack(alignment: .top, spacing: 8) {
                    // Avatar section
                    VStack(spacing: 0) {
                        AsyncImage(url: URL(string: user.avatar ?? "")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.title)
                                        .foregroundColor(.gray)
                                )
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                    }
                    
                    // User info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.username)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text("@\(extractUsername(from: user.email))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .padding(.top, 4)
                        }
                        
                        // Joined date badge
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text("\(formatJoinDate(user.createdAt))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    // Follow button
                    Button(action: onFollowToggle) {
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isFollowing ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                }
                
                // Stats section
                HStack(spacing: 12) {
                    // Captures
                    StatCard(
                        icon: "camera",
                        value: "\(totalCaptures)",
                        label: "Captures",
                        gradient: [Color.blue.opacity(0.1), Color.cyan.opacity(0.05)],
                        iconColor: .blue,
                        textColor: .blue
                    )
                    
                    // Followers
                    Button(action: { showingFollowers = true }) {
                        StatCard(
                            icon: "person.2",
                            value: "\(followers)",
                            label: "Followers",
                            gradient: [Color.purple.opacity(0.1), Color.pink.opacity(0.05)],
                            iconColor: .purple,
                            textColor: .purple
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Following
                    Button(action: { showingFollowing = true }) {
                        StatCard(
                            icon: "person.3",
                            value: "\(following)",
                            label: "Following",
                            gradient: [Color.green.opacity(0.1), Color.teal.opacity(0.05)],
                            iconColor: .green,
                            textColor: .green
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.05),
                    Color.accentColor.opacity(0.1),
                    Color.secondary.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .sheet(isPresented: $showingFollowers) {
            FollowersListView(userId: user.id)
        }
        .sheet(isPresented: $showingFollowing) {
            FollowingListView(userId: user.id)
        }
        .onAppear {
            Task {
                await loadFollowerCounts()
            }
        }
    }
    
    private func loadFollowerCounts() async {
        do {
            // Get followers count for this user
            let followersResponse: [Follow] = try await SupabaseManager.shared.client
                .from("user_follows")
                .select()
                .eq("following_id", value: user.id)
                .execute()
                .value
            
            // Get following count for this user
            let followingResponse: [Follow] = try await SupabaseManager.shared.client
                .from("user_follows")
                .select()
                .eq("follower_id", value: user.id)
                .execute()
                .value
            
            print("📊 User \(user.id) has \(followersResponse.count) followers and \(followingResponse.count) following")
            
            // Update the state variables
            await MainActor.run {
                followersCount = followersResponse.count
                followingCount = followingResponse.count
            }
        } catch {
            print("❌ Failed to load follower counts for user \(user.id): \(error)")
        }
    }
}

// MARK: - User Profile Tabs

struct UserProfileTabsView: View {
    @Binding var selectedTab: String
    let user: User
    let userHabits: [Habit]
    let userCaptures: [Capture]
    @EnvironmentObject var authManager: AuthManager
    
    private var totalStreak: Int {
        userHabits.reduce(0) { $0 + $1.currentStreak }
    }
    
    private var longestStreak: Int {
        userHabits.map { $0.longestStreak }.max() ?? 0
    }
    
    private var completionRate: Int {
        calculateCompletionRate()
    }
    
    private var isOwnProfile: Bool {
        user.id == authManager.currentUser?.id
    }
    
    private func calculateCompletionRate() -> Int {
        let completedToday = userHabits.filter { habit in
            // This would check actual progress in a real implementation
            false
        }.count
        
        if userHabits.isEmpty {
            return 0
        }
        
        let percentage = Double(completedToday) / Double(userHabits.count) * 100
        return Int(percentage)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Tab Picker
            Picker("View", selection: $selectedTab) {
                Text("Overview").tag("overview")
                Text("Achievements").tag("achievements")
                if isOwnProfile {
                    Text("Habits").tag("habits")
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: isOwnProfile) { newValue in
                // If viewing someone else's profile and habits tab is selected, switch to overview
                if !newValue && selectedTab == "habits" {
                    selectedTab = "overview"
                }
            }
            
            // Tab Content
            switch selectedTab {
            case "overview":
                UserOverviewTabView(
                    totalStreak: totalStreak,
                    longestStreak: longestStreak,
                    completionRate: completionRate,
                    userHabits: userHabits,
                    userCaptures: userCaptures,
                    user: user
                )
            case "achievements":
                AchievementsTabView()
            case "habits":
                UserHabitsTabView(userHabits: userHabits)
            default:
                UserOverviewTabView(
                    totalStreak: totalStreak,
                    longestStreak: longestStreak,
                    completionRate: completionRate,
                    userHabits: userHabits,
                    userCaptures: userCaptures,
                    user: user
                )
            }
        }
    }
}

// MARK: - User Overview Tab

struct UserOverviewTabView: View {
    let totalStreak: Int
    let longestStreak: Int
    let completionRate: Int
    let userHabits: [Habit]
    let userCaptures: [Capture]
    let user: User
    @EnvironmentObject var habitManager: HabitManager
    @EnvironmentObject var authManager: AuthManager
    
    private var totalHabits: Int {
        userHabits.count
    }
    
    private var totalCaptures: Int {
        userCaptures.count
    }
    
    private var totalGroupStreaks: Int {
        // Calculate current streaks from captures for all habits
        userHabits.reduce(0) { total, habit in
            total + calculateCurrentStreak(for: habit, captures: userCaptures)
        }
    }
    
    private var allTimeBestStreak: Int {
        // If this is the current user, use real-time calculation
        if user.id == authManager.currentUser?.id {
            return habitManager.getCurrentBestStreak()
        } else {
            // For other users, calculate from their current streaks and stored best streak
            let currentBestStreak = userHabits.map { calculateCurrentStreak(for: $0, captures: userCaptures) }.max() ?? 0
            let storedBestStreak = user.bestStreak ?? userHabits.map { $0.longestStreak }.max() ?? 0
            return max(currentBestStreak, storedBestStreak)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Stats Grid
            HStack(spacing: 12) {
                // Habits
                StatCard(
                    icon: "target",
                    value: "\(totalHabits)",
                    label: "Habits",
                    gradient: [Color.orange.opacity(0.1), Color.red.opacity(0.05)],
                    iconColor: .orange,
                    textColor: .orange
                )
                
                // Group Streaks
                StatCard(
                    icon: "flame",
                    value: "\(totalGroupStreaks)",
                    label: "Group Streaks",
                    gradient: [Color.orange.opacity(0.1), Color.red.opacity(0.05)],
                    iconColor: .orange,
                    textColor: .orange
                )
                
                // Best Streak
                StatCard(
                    icon: "trophy",
                    value: "\(allTimeBestStreak)",
                    label: "Best Streak",
                    gradient: [Color.yellow.opacity(0.1), Color.orange.opacity(0.05)],
                    iconColor: .yellow,
                    textColor: .yellow
                )
            }
            
            // Progress Grid for last 6 months
            UserProgressGrid(userCaptures: userCaptures)
        }
        .padding(20)
    }
    
    private func calculateCurrentStreak(for habit: Habit, captures: [Capture]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get captures for this specific habit
        let habitCaptures = captures.filter { $0.habitId == habit.id }
        
        // Sort captures by date (newest first)
        let sortedCaptures = habitCaptures.sorted { $0.createdAt > $1.createdAt }
        
        var currentStreak = 0
        var currentDate = today
        
        // Check if there's a capture today
        let hasCaptureToday = sortedCaptures.contains { capture in
            calendar.startOfDay(for: capture.createdAt) == today
        }
        
        if !hasCaptureToday {
            return 0 // No streak if no capture today
        }
        
        // Count consecutive days backwards from today
        for capture in sortedCaptures {
            let captureDate = calendar.startOfDay(for: capture.createdAt)
            
            // If this capture is for today or yesterday, continue the streak
            if calendar.isDate(captureDate, inSameDayAs: currentDate) {
                continue
            } else if calendar.isDate(captureDate, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate) {
                currentStreak += 1
                currentDate = captureDate
            } else {
                break // Streak broken
            }
        }
        
        return currentStreak + 1 // +1 for today
    }
}

// MARK: - User Habits Tab

struct UserHabitsTabView: View {
    let userHabits: [Habit]
    
    var body: some View {
        VStack(spacing: 16) {
            if userHabits.isEmpty {
                VStack(spacing: 16) {
                    Text("🎯")
                        .font(.system(size: 48))
                    Text("No Habits Yet")
                        .font(.headline)
                        .fontWeight(.medium)
                    Text("This user hasn't created any habits yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(userHabits) { habit in
                        UserHabitCard(habit: habit)
                    }
                }
            }
        }
        .padding(20)
    }
}

// MARK: - User Progress Grid

struct UserProgressGrid: View {
    let userCaptures: [Capture]
    let weeks: Int = 26 // ~6 months
    let spacing: CGFloat = 3
    
    private var dailyCompletionData: [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        let today = Date()
        
        // Get captures for the last 6 months
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        
        for capture in userCaptures {
            if capture.createdAt >= sixMonthsAgo {
                let dayStart = calendar.startOfDay(for: capture.createdAt)
                data[dayStart, default: 0] += 1
            }
        }
        
        return data
    }
    
    private var maxCompletionsPerDay: Int {
        dailyCompletionData.values.max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("6 Month Progress")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            ZStack(alignment: .topLeading) {
                GeometryReader { proxy in
                    let totalWidth = proxy.size.width
                    let cellSize = (totalWidth - CGFloat(weeks - 1) * spacing) / CGFloat(weeks)
                    let gridHeight = cellSize * 7 + spacing * 6
                    
                    UserGridContentView(
                        weeks: weeks,
                        spacing: spacing,
                        cellSize: cellSize,
                        dailyCompletionData: dailyCompletionData,
                        maxCompletionsPerDay: maxCompletionsPerDay
                    )
                    .frame(width: totalWidth, height: gridHeight, alignment: .topLeading)
                }
            }
            .frame(height: 80)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }
}

struct UserGridContentView: View {
    let weeks: Int
    let spacing: CGFloat
    let cellSize: CGFloat
    let dailyCompletionData: [Date: Int]
    let maxCompletionsPerDay: Int
    
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<7, id: \.self) { dayOfWeek in
                HStack(spacing: spacing) {
                    ForEach(0..<weeks, id: \.self) { week in
                        let date = getDate(for: week, dayOfWeek: dayOfWeek)
                        let completions = dailyCompletionData[date] ?? 0
                        let intensity = maxCompletionsPerDay > 0 ? Double(completions) / Double(maxCompletionsPerDay) : 0
                        
                        Rectangle()
                            .fill(getColorForIntensity(intensity))
                            .frame(width: cellSize, height: cellSize)
                            .cornerRadius(2)
                    }
                }
            }
        }
    }
    
    private func getDate(for week: Int, dayOfWeek: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        
        // Calculate the date for this grid position
        let daysFromToday = (week * 7 + dayOfWeek) - (weeks * 7 - 1)
        return calendar.date(byAdding: .day, value: daysFromToday, to: startOfToday) ?? today
    }
    
    private func getColorForIntensity(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color(.systemGray6)
        } else if intensity <= 0.25 {
            return Color.green.opacity(0.3)
        } else if intensity <= 0.5 {
            return Color.green.opacity(0.6)
        } else if intensity <= 0.75 {
            return Color.green.opacity(0.8)
        } else {
            return Color.green
        }
    }
}

// MARK: - User Habit Card

struct UserHabitCard: View {
    let habit: Habit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(habit.name)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(habit.currentStreak) day streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Show category and target info instead of description
            HStack {
                Text(habit.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                
                Spacer()
                
                Text("Target: \(habit.target) \(habit.targetFrequency)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Spacer()
                
                Text("Best: \(habit.longestStreak) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    UserProfileView(user: User(
        id: UUID(),
        email: "test@example.com",
        username: "TestUser",
        avatar: nil,
        bio: "This is a test user bio",
        createdAt: Date(),
        updatedAt: Date()
    ))
    .environmentObject(HabitManager.shared)
    .environmentObject(SocialManager.shared)
    .environmentObject(AuthManager.shared)
}
