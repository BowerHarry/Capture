import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var habitManager: HabitManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var socialManager: SocialManager
    @State private var selectedTab = "overview"
    @State private var showingEditProfile = false
    @State private var showingAvatarPicker = false
    @State private var isLoading = false
    @State private var avatarRefreshTrigger = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Profile Header
                ProfileHeaderView(
                    user: authManager.currentUser,
                    habitManager: habitManager,
                    onEditProfile: { showingEditProfile = true },
                    onAvatarPicker: { showingAvatarPicker = true },
                    avatarRefreshTrigger: avatarRefreshTrigger
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
            AvatarPickerView(onAvatarUpdated: {
                avatarRefreshTrigger += 1
            })
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
    let avatarRefreshTrigger: Int
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
                                .id(avatarRefreshTrigger) // Force refresh when trigger changes
                            
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
            ScrollView {
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
            .gesture(
                DragGesture()
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width > threshold {
                            // Swipe right - go to previous tab
                            switch selectedTab {
                            case "achievements":
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = "overview"
                                }
                            case "habits":
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = "achievements"
                                }
                            default:
                                break
                            }
                        } else if value.translation.width < -threshold {
                            // Swipe left - go to next tab
                            switch selectedTab {
                            case "overview":
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = "achievements"
                                }
                            case "achievements":
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = "habits"
                                }
                            default:
                                break
                            }
                        }
                    }
            )
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
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showingImageCropper = false
    @State private var isLoading = false
    @State private var showSuccessMessage = false
    
    let onAvatarUpdated: () -> Void
    
    // Generic avatars
    private let genericAvatars = [
        "👤", "👨‍💼", "👩‍💼", "👨‍🎨", "👩‍🎨", "👨‍🔬", "👩‍🔬",
        "👨‍⚕️", "👩‍⚕️", "👨‍🏫", "👩‍🏫", "👨‍💻", "👩‍💻", "👨‍🚀", "👩‍🚀"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Custom header with buttons
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("Choose Avatar")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Header description
                VStack(spacing: 8) {
                    Text("Select a generic avatar or upload your own photo")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Current avatar preview
                VStack(spacing: 12) {
                    Text("Current Avatar")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    AvatarImageView(user: authManager.currentUser)
                        .frame(width: 100, height: 100)
                }
                
                // Generic avatars section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Generic Avatars")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(genericAvatars, id: \.self) { avatar in
                            Button(action: {
                                Task {
                                    await selectGenericAvatar(avatar)
                                }
                            }) {
                                Text(avatar)
                                    .font(.system(size: 32))
                                    .frame(width: 60, height: 60)
                                    .background(Color(.systemGray6))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Upload photo section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Upload Photo")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.title2)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose from Photo Library")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Text("Select and crop your photo")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .onChange(of: selectedItem) { item in
                print("📸 Photo selected, loading image data...")
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        print("📸 Image data loaded, size: \(data.count) bytes")
                        if let image = UIImage(data: data) {
                            print("📸 UIImage created successfully, size: \(image.size)")
                            selectedImage = image
                            showingImageCropper = true
                        } else {
                            print("❌ Failed to create UIImage from data")
                        }
                    } else {
                        print("❌ Failed to load image data from PhotosPicker")
                    }
                }
            }
            .sheet(isPresented: $showingImageCropper) {
                if let image = selectedImage {
                    ImageCropperView(image: image) { croppedImage in
                        Task {
                            await uploadAvatar(croppedImage)
                        }
                    }
                }
            }
            .onChange(of: showingImageCropper) { showing in
                if showing, let image = selectedImage {
                    print("📱 Presenting ImageCropperView with image size: \(image.size)")
                } else if !showing {
                    print("📱 ImageCropperView dismissed")
                }
            }
            .overlay(
                ZStack {
                    if isLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Uploading avatar...")
                                .font(.subheadline)
                                .foregroundColor(.white)
                        }
                    }
                    
                    if showSuccessMessage {
                        VStack {
                            Spacer()
                            
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                
                                Text("Avatar updated successfully!")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                            
                            Spacer()
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: showSuccessMessage)
                    }
                }
            )
        }
    }
    
    private func selectGenericAvatar(_ avatar: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Convert emoji to image and upload
            if let image = emojiToImage(avatar) {
                await uploadAvatar(image)
            }
        } catch {
            print("Error selecting generic avatar: \(error)")
        }
    }
    
    private func emojiToImage(_ emoji: String) -> UIImage? {
        let size = CGSize(width: 200, height: 200)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let rect = CGRect(origin: .zero, size: size)
        let context = UIGraphicsGetCurrentContext()
        
        // Draw background
        context?.setFillColor(UIColor.systemGray6.cgColor)
        context?.fillEllipse(in: rect)
        
        // Draw emoji
        let fontSize = size.width * 0.6
        let font = UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        
        let emojiSize = emoji.size(withAttributes: attributes)
        let emojiRect = CGRect(
            x: (size.width - emojiSize.width) / 2,
            y: (size.height - emojiSize.height) / 2,
            width: emojiSize.width,
            height: emojiSize.height
        )
        
        emoji.draw(in: emojiRect, withAttributes: attributes)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    private func uploadAvatar(_ image: UIImage) async {
        print("📱 Starting avatar upload...")
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "AvatarError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
            }
            
            // Upload to Supabase storage
            let avatarURL = try await SupabaseManager.shared.uploadAvatar(
                userId: authManager.currentUser?.id.uuidString ?? "",
                imageData: imageData
            )
            
            // Update user profile
            let updatedUser = try await SupabaseManager.shared.updateProfile(
                userId: authManager.currentUser?.id.uuidString ?? "",
                username: authManager.currentUser?.username,
                bio: authManager.currentUser?.bio,
                avatar: avatarURL
            )
            
            // Update auth manager
            await authManager.updateCurrentUser(updatedUser)
            
            // Force a complete refresh of the user data
            await authManager.refreshFollowerCounts()
            
            // Trigger avatar refresh via callback
            onAvatarUpdated()
            
            // Show success message briefly, then dismiss
            showSuccessMessage = true
            
            // Dismiss after a short delay to show success message
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSuccessMessage = false
                dismiss()
            }
            
        } catch {
            print("Error uploading avatar: \(error)")
            // You might want to show an error alert here
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
        // Add cache-busting parameter to force refresh
        var urlString = avatarString
        let timestamp = Int(Date().timeIntervalSince1970)
        let userId = user?.id.uuidString ?? ""
        if !urlString.contains("?") {
            urlString += "?t=\(timestamp)&u=\(userId)"
        } else {
            urlString += "&t=\(timestamp)&u=\(userId)"
        }
        return URL(string: urlString)
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

// MARK: - Image Cropper View

struct ImageCropperView: View {
    let image: UIImage
    let onCrop: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero
    @State private var lastScale: CGFloat = 1.0
    @State private var viewSize: CGSize = .zero
    
    init(image: UIImage, onCrop: @escaping (UIImage) -> Void) {
        self.image = image
        self.onCrop = onCrop
        print("🖼️ ImageCropperView initialized with image size: \(image.size)")
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Cropper view
                    ZStack {
                        Color.black
                            .ignoresSafeArea()
                        
                        // Image with gesture
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(scale)
                            .offset(offset)
                            .onAppear {
                                viewSize = geometry.size
                                print("📐 View size: \(viewSize)")
                            }
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        
                                        // Constrain offset to keep crop circle within image bounds
                                        offset = constrainOffset(newOffset, scale: scale, imageSize: image.size, viewSize: viewSize, cropSize: 300)
                                        print("🖱️ Drag gesture: offset = \(offset), translation = \(value.translation)")
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                        print("🖱️ Drag ended: final offset = \(offset)")
                                    }
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale = min(max(scale * delta, 1.0), 3.0)
                                        print("🔍 Zoom gesture: scale = \(scale), delta = \(delta)")
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        print("🔍 Zoom ended: final scale = \(scale)")
                                    }
                            )
                        
                        // Crop overlay
                        CropOverlay()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        let croppedImage = cropImage()
                        onCrop(croppedImage)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func constrainOffset(_ newOffset: CGSize, scale: CGFloat, imageSize: CGSize, viewSize: CGSize, cropSize: CGFloat) -> CGSize {
        // Calculate the scaled image dimensions as they appear on screen
        let aspectRatio = imageSize.width / imageSize.height
        var displayWidth: CGFloat
        var displayHeight: CGFloat
        
        // Use actual view size to calculate display dimensions
        let containerSize = min(viewSize.width, viewSize.height)
        
        if aspectRatio > 1 {
            // Landscape
            displayWidth = containerSize
            displayHeight = containerSize / aspectRatio
        } else {
            // Portrait
            displayHeight = containerSize
            displayWidth = containerSize * aspectRatio
        }
        
        // Apply scale
        let scaledWidth = displayWidth * scale
        let scaledHeight = displayHeight * scale
        
        // Calculate maximum allowed offset to keep crop circle within image bounds
        let maxOffsetX = max(0, (scaledWidth - cropSize) / 2)
        let maxOffsetY = max(0, (scaledHeight - cropSize) / 2)
        
        // Constrain the offset
        let constrainedX = max(-maxOffsetX, min(maxOffsetX, newOffset.width))
        let constrainedY = max(-maxOffsetY, min(maxOffsetY, newOffset.height))
        
        return CGSize(width: constrainedX, height: constrainedY)
    }
    
    private func cropImage() -> UIImage {
        print("✂️ Starting crop process...")
        print("✂️ Original image size: \(image.size)")
        print("✂️ Current scale: \(scale)")
        print("✂️ Current offset: \(offset)")
        print("✂️ View size: \(viewSize)")
        
        let outputSize = CGSize(width: 400, height: 400)
        let cropRadius = outputSize.width / 2
        
        UIGraphicsBeginImageContextWithOptions(outputSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("❌ Failed to get graphics context")
            return image
        }
        
        // Create circular clipping path
        let rect = CGRect(origin: .zero, size: outputSize)
        context.addEllipse(in: rect)
        context.clip()
        
        // Calculate how the image is displayed in the view (aspect fit)
        let imageAspectRatio = image.size.width / image.size.height
        var imageDisplaySize: CGSize
        
        // Use actual view size to calculate display dimensions
        let containerSize = min(viewSize.width, viewSize.height)
        
        if imageAspectRatio > 1 {
            // Landscape
            imageDisplaySize = CGSize(width: containerSize, height: containerSize / imageAspectRatio)
        } else {
            // Portrait  
            imageDisplaySize = CGSize(width: containerSize * imageAspectRatio, height: containerSize)
        }
        
        // Apply scale to display size
        let scaledDisplaySize = CGSize(
            width: imageDisplaySize.width * scale,
            height: imageDisplaySize.height * scale
        )
        
        // Calculate the crop area in image coordinates - simple approach
        
        // The crop circle is always centered in the view
        let cropCenterInView = CGPoint(x: viewSize.width / 2, y: viewSize.height / 2)
        
        // Calculate where the image appears in the view (centered, then offset)
        let imageViewRect = CGRect(
            x: (viewSize.width - scaledDisplaySize.width) / 2 + offset.width,
            y: (viewSize.height - scaledDisplaySize.height) / 2 + offset.height,
            width: scaledDisplaySize.width,
            height: scaledDisplaySize.height
        )
        
        // Calculate the crop center relative to the image view
        let cropCenterRelativeToImageView = CGPoint(
            x: cropCenterInView.x - imageViewRect.origin.x,
            y: cropCenterInView.y - imageViewRect.origin.y
        )
        
        // Normalize to 0-1 range within the image view
        let normalizedCropCenter = CGPoint(
            x: cropCenterRelativeToImageView.x / imageViewRect.width,
            y: cropCenterRelativeToImageView.y / imageViewRect.height
        )
        
        // Convert to actual image coordinates
        let cropCenterInImage = CGPoint(
            x: normalizedCropCenter.x * image.size.width,
            y: normalizedCropCenter.y * image.size.height
        )
        
        // Calculate the crop radius in image coordinates
        let cropRadiusInImage = (cropRadius / imageViewRect.width) * image.size.width
        
        // Calculate the source rect in the original image
        var sourceRect = CGRect(
            x: cropCenterInImage.x - cropRadiusInImage,
            y: cropCenterInImage.y - cropRadiusInImage,
            width: cropRadiusInImage * 2,
            height: cropRadiusInImage * 2
        )
        
        // Clamp the source rect to be within the image bounds
        sourceRect = sourceRect.intersection(CGRect(origin: .zero, size: image.size))
        
        print("✂️ Image display size: \(imageDisplaySize)")
        print("✂️ Scaled display size: \(scaledDisplaySize)")
        print("✂️ Image view rect: \(imageViewRect)")
        print("✂️ Crop center in view: \(cropCenterInView)")
        print("✂️ Crop center relative to image view: \(cropCenterRelativeToImageView)")
        print("✂️ Normalized crop center: \(normalizedCropCenter)")
        print("✂️ Crop center in image: \(cropCenterInImage)")
        print("✂️ Crop radius in image: \(cropRadiusInImage)")
        print("✂️ Source rect (before clamp): \(CGRect(x: cropCenterInImage.x - cropRadiusInImage, y: cropCenterInImage.y - cropRadiusInImage, width: cropRadiusInImage * 2, height: cropRadiusInImage * 2))")
        print("✂️ Source rect (after clamp): \(sourceRect)")
        print("✂️ Image bounds: \(CGRect(origin: .zero, size: image.size))")
        
        // Create a cropped image first, then draw it
        if !sourceRect.isEmpty {
            let croppedSourceImage = image.cgImage?.cropping(to: sourceRect)
            if let croppedCGImage = croppedSourceImage {
                let croppedUIImage = UIImage(cgImage: croppedCGImage)
                croppedUIImage.draw(in: CGRect(origin: .zero, size: outputSize))
            } else {
                // Fallback: draw the full image
                image.draw(in: CGRect(origin: .zero, size: outputSize))
            }
        } else {
            // Source rect is empty, draw the full image
            image.draw(in: CGRect(origin: .zero, size: outputSize))
        }
        
        guard let croppedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("❌ Failed to get cropped image from context")
            return image
        }
        
        print("✅ Crop successful: \(croppedImage.size)")
        return croppedImage
    }
}

struct CropOverlay: View {
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .allowsHitTesting(false) // Don't block touch events
                .onAppear {
                    print("🎭 CropOverlay: Black overlay appeared")
                }
            
            // Circular crop area - clear circle showing the image
            Circle()
                .fill(Color.clear)
                .frame(width: 300, height: 300)
                .blendMode(.destinationOut)
                .allowsHitTesting(false) // Don't block touch events
                .onAppear {
                    print("🎭 CropOverlay: Clear circle appeared")
                }
            
            // White border around the crop area
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 300, height: 300)
                .allowsHitTesting(false) // Don't block touch events
                .onAppear {
                    print("🎭 CropOverlay: White border appeared")
                }
        }
        .compositingGroup()
        .allowsHitTesting(false) // Don't block touch events
        .onAppear {
            print("🎭 CropOverlay: Complete overlay appeared")
        }
    }
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
