import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var habitManager: HabitManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var socialManager: SocialManager
    @State private var selectedTab = "overview"
    @State private var showingEditProfile = false
    @State private var showingAvatarPicker = false
    @State private var isLoading = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                ProfileHeaderView(
                    user: authManager.currentUser,
                    habitManager: habitManager,
                    onEditProfile: { showingEditProfile = true },
                    onAvatarPicker: { showingAvatarPicker = true }
                )
                
                // Profile Tabs
                ProfileTabsView(
                    selectedTab: $selectedTab,
                    habitManager: habitManager
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
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingAvatarPicker) {
            AvatarPickerView()
        }
        .onAppear {
            // Refresh follower counts when profile appears
            Task {
                await authManager.refreshFollowerCounts()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh follower counts when app comes to foreground
            Task {
                await authManager.refreshFollowerCounts()
            }
        }
    }
    

}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let user: User?
    let habitManager: HabitManager
    let onEditProfile: () -> Void
    let onAvatarPicker: () -> Void
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var authManager: AuthManager
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    
    private var totalHabits: Int {
        habitManager.habits.count
    }
    
    private var activeHabits: Int {
        habitManager.habits.filter { $0.currentStreak > 0 }.count
    }
    
    private var totalCaptures: Int {
        habitManager.captures.count
    }
    
    private var followers: Int {
        authManager.currentUser?.followersCount ?? 0
    }
    
    private var following: Int {
        authManager.currentUser?.followingCount ?? 0
    }
    
    private var totalGroupStreaks: Int {
        habitManager.habits.reduce(0) { $0 + $1.currentStreak }
    }
    
    private var allTimeBestStreak: Int {
        habitManager.habits.map { $0.longestStreak }.max() ?? 0
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
                        ZStack {
                            // Avatar
                            AvatarImageView(user: user)
                            
                            // Camera button
                            Button(action: onAvatarPicker) {
                                Image(systemName: "camera")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(width: 24, height: 24)
                                    .background(Color.secondary)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            .offset(x: 28, y: 28)
                        }
                    }
                    
                    // User info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user?.username ?? "User")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Text("@\(extractUsername(from: user?.email))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        if let bio = user?.bio, !bio.isEmpty {
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
                            Text("\(formatJoinDate(user?.createdAt))")
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
                    
                    // Action buttons
                    HStack(spacing: 8) {
                        EditProfileButton(onEditProfile: onEditProfile)
                        
                        LogoutButton()
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
            FollowersListView(userId: user?.id ?? UUID())
        }
        .sheet(isPresented: $showingFollowing) {
            FollowingListView(userId: user?.id ?? UUID())
        }
    }
}

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let gradient: [Color]
    let iconColor: Color
    let textColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(textColor)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(12)
        .background(
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(textColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Profile Tabs

struct ProfileTabsView: View {
    @Binding var selectedTab: String
    let habitManager: HabitManager
    
    private var totalStreak: Int {
        habitManager.habits.reduce(0) { $0 + $1.currentStreak }
    }
    
    private var longestStreak: Int {
        habitManager.habits.map { $0.longestStreak }.max() ?? 0
    }
    
    private var completionRate: Int {
        calculateCompletionRate()
    }
    
    private func calculateCompletionRate() -> Int {
        let completedToday = habitManager.habits.filter { habit in
            habitManager.progress(for: habit.id)?.isComplete == true
        }.count
        
        if habitManager.habits.isEmpty {
            return 0
        }
        
        let percentage = Double(completedToday) / Double(habitManager.habits.count) * 100
        return Int(percentage)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Tab Picker
                // Tabs (Overview/Grid)
                Picker("View", selection: $selectedTab) {
                    Text("Overview").tag("overview")
                    Text("Achievements").tag("achievements")
                    Text("My Habits").tag("habits")
                }
                .pickerStyle(.segmented)

            
            // Tab Content
            switch selectedTab {
            case "overview":
                OverviewTabView(
                    totalStreak: totalStreak,
                    longestStreak: longestStreak,
                    completionRate: completionRate,
                    habitManager: habitManager
                )
            case "achievements":
                AchievementsTabView()
            case "habits":
                MyHabitsTabView(habitManager: habitManager)
            default:
                OverviewTabView(
                    totalStreak: totalStreak,
                    longestStreak: longestStreak,
                    completionRate: completionRate,
                    habitManager: habitManager
                )
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                isSelected ?
                AnyShapeStyle(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ) : AnyShapeStyle(Color.clear)
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Overview Tab

struct OverviewTabView: View {
    let totalStreak: Int
    let longestStreak: Int
    let completionRate: Int
    let habitManager: HabitManager
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var authManager: AuthManager
    @State private var showingFollowers = false
    @State private var showingFollowing = false
    
    private var totalHabits: Int {
        habitManager.habits.count
    }
    
    private var totalCaptures: Int {
        habitManager.captures.count
    }
    
    private var followers: Int {
        authManager.currentUser?.followersCount ?? 0
    }
    
    private var following: Int {
        authManager.currentUser?.followingCount ?? 0
    }
    
    private var totalGroupStreaks: Int {
        habitManager.habits.reduce(0) { $0 + $1.currentStreak }
    }
    
    private var allTimeBestStreak: Int {
        habitManager.habits.map { $0.longestStreak }.max() ?? 0
    }
    
    private var completedTodayCount: Int {
        habitManager.habits.filter { habit in
            habitManager.progress(for: habit.id)?.isComplete == true
        }.count
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
                
                // Followers
                StatCard(
                    icon: "flame",
                    value: "\(totalGroupStreaks)",
                    label: "Group Streaks",
                    gradient: [Color.orange.opacity(0.1), Color.red.opacity(0.05)],
                    iconColor: .orange,
                    textColor: .orange
                )
                
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
            ProfileProgressGrid(habitManager: habitManager)
            
        }
        .padding(20)
        .sheet(isPresented: $showingFollowers) {
            FollowersListView(userId: authManager.currentUser?.id ?? UUID())
        }
        .sheet(isPresented: $showingFollowing) {
            FollowingListView(userId: authManager.currentUser?.id ?? UUID())
        }
    }
}

struct PerformanceCard: View {
    let icon: String
    let value: String
    let label: String
    let gradient: [Color]
    let iconColor: Color
    let textColor: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
                    .frame(width: 20, height: 20)
                    .background(iconColor.opacity(0.1))
                    .clipShape(Circle())
                
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(textColor)
            }
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(textColor.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(textColor.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Achievements Tab

struct AchievementsTabView: View {
    private let achievements = [
        "First Habit",
        "7 Day Streak",
        "Perfect Week",
        "Habit Master"
    ]
    
    private let achievementIcons = ["🎯", "🔥", "⭐", "🏆"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Achievements Grid
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(Array(achievements.enumerated()), id: \.offset) { index, achievement in
                        AchievementCard(
                            icon: achievementIcons[index],
                            title: achievement
                        )
                        .frame(width: 100, height: 120)
                    }
                }
                // Coming Soon Card
                VStack(spacing: 12) {
                    ZStack {
                        Image(systemName: "trophy")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.3))
                        
                        Text("✨")
                            .font(.system(size: 20))
                            .offset(x: 20, y: -20)
                    }
                    
                    VStack(spacing: 4) {
                        Text("More achievements coming soon!")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Keep completing habits to unlock new badges")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.1), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
            }
            .padding(24)
//            .background(
//                LinearGradient(
//                    colors: [Color.yellow.opacity(0.05), Color(.systemBackground)],
//                    startPoint: .topLeading,
//                    endPoint: .bottomTrailing
//                )
//            )
            .cornerRadius(20)
//            .overlay(
//                RoundedRectangle(cornerRadius: 20)
//                    .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
//            )
            
            
        }
    }
}

struct AchievementCard: View {
    let icon: String
    let title: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 32))
            
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 4) {
                Image(systemName: "star")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
                Text("Earned")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - My Habits Tab

struct MyHabitsTabView: View {
    let habitManager: HabitManager
    
    private var sortedHabits: [Habit] {
        habitManager.habits.sorted { habit1, habit2 in
            let habit1Completed = habitManager.progress(for: habit1.id)?.isComplete == true
            let habit2Completed = habitManager.progress(for: habit2.id)?.isComplete == true
            
            // Show incomplete habits first, then completed ones
            if habit1Completed != habit2Completed {
                return !habit1Completed
            }
            
            // If both have same completion status, sort by name
            return habit1.name < habit2.name
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            if habitManager.habits.isEmpty {
                // Empty State
                VStack(spacing: 16) {
                    ZStack {
                        Image(systemName: "target")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.2))
                        
                        Text("🎯")
                            .font(.system(size: 24))
                            .offset(x: 24, y: -24)
                    }
                    
                    VStack(spacing: 8) {
                        Text("No habits yet")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Start your journey by creating your first habit!")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Popular: 💪 Workout • 📚 Reading • 🧘 Meditation")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .padding(32)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.1), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: 2, dash: [5]))
                )
            } else {
                // Habits List
                VStack(spacing: 12) {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedHabits) { habit in
                            HabitCard(habit: habit, habitManager: habitManager)
                        }
                    }
                }
                .padding(24)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.05), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
            }
        }
    }
}

struct HabitCard: View {
    let habit: Habit
    let habitManager: HabitManager
    
    private var isCompleted: Bool {
        habitManager.progress(for: habit.id)?.isComplete == true
    }
    
    private var weeklyProgress: Int {
        // Calculate actual weekly progress based on captures
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklyCaptures = habitManager.captures.filter { capture in
            capture.habitId == habit.id && capture.createdAt >= oneWeekAgo
        }.count
        
        // Assuming target is 1 per day for weekly calculation
        let weeklyTarget = 7
        return weeklyTarget > 0 ? Int((Double(weeklyCaptures) / Double(weeklyTarget)) * 100) : 0
    }
    
    private var habitBackground: AnyShapeStyle {
        if isCompleted {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.green.opacity(0.1), Color.mint.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.accentColor.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Completion indicator
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color(.systemGray4))
                    .frame(width: 16, height: 16)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Habit info
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isCompleted ? .green : .primary)
                
                Text(habit.category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            // Streak and progress
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("\(habitManager.progress(for: habit.id)?.currentStreak ?? 0)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.orange)
                }
                
                Text("\(weeklyProgress)% this week")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(habitBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isCompleted ? Color.green.opacity(0.2) : Color(.systemGray5), lineWidth: 1)
        )
    }
}

// MARK: - Supporting Views

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var name: String = ""
    @State private var bio: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Profile Information") {
                    TextField("Name", text: $name)
                        .onSubmit {
                            hideKeyboard()
                        }
                    TextField("Bio", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                        .onSubmit {
                            hideKeyboard()
                        }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        // Save profile changes
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = authManager.currentUser?.username ?? ""
                bio = authManager.currentUser?.bio ?? ""
            }
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Avatar Picker")
                    .font(.title)
                Text("This would allow users to select or upload a profile picture")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Profile Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Profile Progress Grid

struct ProfileProgressGrid: View {
    let habitManager: HabitManager
    let weeks: Int = 26 // ~6 months
    let spacing: CGFloat = 3
    
    private var dailyCompletionData: [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        let today = Date()
        
        // Get captures for the last 6 months
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        
        for capture in habitManager.captures {
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
                    
                    ProfileGridContentView(
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

struct ProfileGridContentView: View {
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

// MARK: - Supporting Types

// HabitStats is already defined in Models.swift

// MARK: - Helper Views

struct LogoutButton: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Button(action: {
            Task {
                await authManager.signOut()
            }
        }) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }
}

struct EditProfileButton: View {
    let onEditProfile: () -> Void
    
    var body: some View {
        Button(action: onEditProfile) {
            HStack(spacing: 6) {
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                Text("Edit")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

struct AvatarImageView: View {
    let user: User?
    
    private var avatarURL: URL? {
        guard let avatarString = user?.avatar, !avatarString.isEmpty else { return nil }
        return URL(string: avatarString)
    }
    
    private var userInitial: String {
                        user?.username.prefix(1).uppercased() ?? "U"
    }
    
    var body: some View {
        AsyncImage(url: avatarURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(Circle())
        } placeholder: {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Text(userInitial)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                )
        }
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 4)
        )
    }
}

#Preview {
    ProfileView()
        .environmentObject(HabitManager.shared)
        .environmentObject(AuthManager.shared)
        .environmentObject(SocialManager.shared)
}

struct ProfileUserListItem: View {
    let user: User
    @State private var showingUserProfile = false
    
    var body: some View {
        Button(action: {
            showingUserProfile = true
        }) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: user.avatar ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                
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
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView(user: user)
        }
    }
}

// MARK: - Followers/Following Lists

struct FollowersListView: View {
    let userId: UUID
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.dismiss) private var dismiss
    @State private var followers: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if followers.isEmpty {
                    VStack(spacing: 16) {
                        Text("👥")
                            .font(.system(size: 48))
                        Text("No Followers Yet")
                            .font(.headline)
                            .fontWeight(.medium)
                        Text("When people follow you, they'll appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(followers) { user in
                        ProfileUserListItem(user: user)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            print("🔄 Loading followers for user: \(userId)")
            followers = await socialManager.getFollowers(userId: userId)
            print("📊 Loaded \(followers.count) followers")
            isLoading = false
        }
    }
}

struct FollowingListView: View {
    let userId: UUID
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.dismiss) private var dismiss
    @State private var following: [User] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if following.isEmpty {
                    VStack(spacing: 16) {
                        Text("👥")
                            .font(.system(size: 48))
                        Text("Not Following Anyone")
                            .font(.headline)
                            .fontWeight(.medium)
                        Text("When you follow people, they'll appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(following) { user in
                        ProfileUserListItem(user: user)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Following")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            print("🔄 Loading following for user: \(userId)")
            following = await socialManager.getFollowing(userId: userId)
            print("📊 Loaded \(following.count) following")
            isLoading = false
        }
    }
}
