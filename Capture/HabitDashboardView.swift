import SwiftUI

struct HabitDashboardView: View {
    @EnvironmentObject var habitManager: HabitManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var imagePreloader = ImagePreloader.shared
    @State private var showingHabitPicker = false
    @State private var tempSelectedHabit: Habit? = nil
    @State private var showDebug = false
    @State private var habitsCollapsed = false
    @State private var greetingCollapsed = false
    @State private var selectedTab: String = "overview"
    @State private var persistedQuote: String? = nil
    
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
    
    // Animated stats
    @State private var animatedTotalStreak: Int = 0
    @State private var animatedLongestStreak: Int = 0
    @State private var animatedTodayPercent: Int = 0
    
    let onNavigateToCamera: (UUID) -> Void
    
    // MARK: - Computed Views
    private var appHeader: some View {
        HStack {
            Text("Capture")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.top, -8)
    }
    
    private var greetingCard: some View {
        GreetingCard(
            userName: displayName,
            quote: persistedQuote ?? motivationalQuote,
            totalStreak: animatedTotalStreak,
            longestStreak: animatedLongestStreak,
            todayPercent: animatedTodayPercent,
            weeklyPercentage: weeklySummary.weeklyPercentage,
            weeklyCompletions: weeklySummary.totalCompletions,
            isCollapsed: greetingCollapsed,
            onToggleCollapse: { greetingCollapsed.toggle() }
        )
        .padding(.horizontal)
        .onAppear {
            if persistedQuote == nil { persistedQuote = motivationalQuote }
            animateStatsIfNeeded()
        }
    }
    
    private var mainContent: some View {
        Group {
            if habitManager.habits.isEmpty {
                EmptyHabitsView { showingHabitPicker = true }
            } else {
                VStack(spacing: 12) {
                    sectionHeader
                    tabPicker
                    tabContent
                }
            }
        }
    }
    
    private var sectionHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Text("Your Habits").font(.headline)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                habitsCollapsed.toggle()
            }
            Button(action: { habitsCollapsed.toggle() }) {
                Image(systemName: habitsCollapsed ? "chevron.down" : "chevron.up")
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { showingHabitPicker = true }) {
                Image(systemName: "plus").font(.system(size: 14)).foregroundColor(.white)
                    .padding(8)
                    .background(Color.black)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
    }
    
    private var tabPicker: some View {
        Picker("View", selection: $selectedTab) {
            Text("Overview").tag("overview")
            Text("Progress Grid").tag("grid")
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    
    private var tabContent: some View {
        VStack(spacing: 12) {
            if selectedTab == "overview" {
                if habitsCollapsed {
                    CollapsedHabitsList(onCapture: onNavigateToCamera)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                } else {
                    expandedHabitsList
                }
            } else {
                ProgressGridList()
                    .padding(.horizontal)
                    .padding(.bottom, 40)
            }
        }
    }
    
    private var expandedHabitsList: some View {
        ForEach(sortedHabits) { habit in
            HabitCardView(habit: habit, onCapture: onNavigateToCamera)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    appHeader
                    greetingCard
                    mainContent
                }
                .padding(.vertical)
            }
            .onAppear {
                if let stored = UserDefaults.standard.value(forKey: "habitsCollapsed") as? Bool {
                    habitsCollapsed = stored
                }
                if let stored = UserDefaults.standard.value(forKey: "greetingCollapsed") as? Bool {
                    greetingCollapsed = stored
                }
            }
            .onChange(of: habitsCollapsed) { newValue in
                UserDefaults.standard.set(newValue, forKey: "habitsCollapsed")
            }
            .onChange(of: greetingCollapsed) { newValue in
                UserDefaults.standard.set(newValue, forKey: "greetingCollapsed")
            }
            .task { 
                await loadHabitsWithCache()
                await loadHabitCategoriesWithCache()
                // Preload habit capture images after habits are loaded
                imagePreloader.preloadHabitCaptures(habitManager.captures)
            }
            .onChange(of: authManager.isAuthenticated) { isAuthed in
                if isAuthed { 
                    Task { 
                        await loadHabitsWithCache()
                        await loadHabitCategoriesWithCache()
                        // Preload habit capture images after habits are loaded
                        imagePreloader.preloadHabitCaptures(habitManager.captures)
                    } 
                }
            }
            .refreshable { 
                await loadHabitsWithCache()
                await loadHabitCategoriesWithCache()
                // Preload habit capture images after habits are loaded
                imagePreloader.preloadHabitCaptures(habitManager.captures)
            }
            .sheet(isPresented: $showingHabitPicker) { HabitPickerView(selectedHabit: $tempSelectedHabit) }
            .onChange(of: habitManager.habits) { _ in
                // Update stats when habits change
                let (totalStreak, longestStreak, todayPercent) = computeStats()
                animatedTotalStreak = totalStreak
                animatedLongestStreak = longestStreak
                animatedTodayPercent = todayPercent
                
                // Preload habit capture images when habits change
                imagePreloader.preloadHabitCaptures(habitManager.captures)
            }
            .onChange(of: habitManager.totalStreakSum) { _ in
                // Update stats when computed stats change
                let (totalStreak, longestStreak, todayPercent) = computeStats()
                animatedTotalStreak = totalStreak
                animatedLongestStreak = longestStreak
                animatedTodayPercent = todayPercent
            }
            .onChange(of: habitManager.longestStreakValue) { _ in
                // Update stats when computed stats change
                let (totalStreak, longestStreak, todayPercent) = computeStats()
                animatedTotalStreak = totalStreak
                animatedLongestStreak = longestStreak
                animatedTodayPercent = todayPercent
            }
            .onChange(of: habitManager.todayPercentValue) { _ in
                // Update stats when computed stats change
                let (totalStreak, longestStreak, todayPercent) = computeStats()
                animatedTotalStreak = totalStreak
                animatedLongestStreak = longestStreak
                animatedTodayPercent = todayPercent
            }
            .onChange(of: selectedTab) { newTab in
                // Use ultra-optimized loading for progress grid tab
                if newTab == "grid" {
                    Task {
                        await habitManager.loadProgressGridDataOptimized()
                        // Preload habit capture images after ultra-optimized data load
                        imagePreloader.preloadHabitCaptures(habitManager.captures)
                    }
                }
            }
        }
    }
    
    private var displayName: String {
                    if let name = authManager.currentUser?.username {
            let components = name.split(separator: " ")
            if let firstName = components.first {
                return String(firstName)
            }
        }
        if let email = authManager.currentUser?.email {
            let components = email.split(separator: "@")
            if let username = components.first {
                return String(username)
            }
        }
        return "there"
    }
    
    private var motivationalQuote: String {
        let quotes = [
            "Small daily improvements lead to stunning results over time.",
            "You don't have to be perfect, just consistent.",
            "Every expert was once a beginner. Keep going!",
            "The only impossible journey is the one you never begin.",
            "Success is the sum of small efforts repeated daily.",
            "Progress, not perfection. You've got this!",
            "Your only limit is your mind. Break through!",
            "Believe in yourself and all that you are."
        ]
        return quotes.randomElement() ?? "Keep going!"
    }
    
    // Utility function for consistent category colors
    private func categoryColor(_ category: String) -> Color {
        // Try to find the category in the database first
        if let habitCategory = habitManager.habitCategories.first(where: { $0.name.lowercased() == category.lowercased() }) {
            return CaptureTheme.categoryColor(from: habitCategory.color)
        }
        
        // Default to gray if category not found
        return .gray
    }
    
    private func animateStatsIfNeeded() {
        guard !habitManager.habits.isEmpty else { return }
        let duration: Double = 1.2
        let steps: Int = 30
        let stepDuration = duration / Double(steps)
        var step = 0
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
            // Read the stats on every tick: they may finish computing after the animation starts
            let (totalStreak, longestStreak, todayPercent) = computeStats()
            step += 1
            let progress = Double(step) / Double(steps)
            let easeOut = 1 - pow(1 - progress, 3)
            animatedTotalStreak = Int(Double(totalStreak) * easeOut)
            animatedLongestStreak = Int(Double(longestStreak) * easeOut)
            animatedTodayPercent = Int(Double(todayPercent) * easeOut)
            if step >= steps { timer.invalidate() }
        }
    }
    
    private func computeStats() -> (Int, Int, Int) {
        // Use actual computed stats from HabitManager
        let total = habitManager.totalStreakSum
        let longest = habitManager.longestStreakValue
        let todayPercent = habitManager.todayPercentValue
        return (total, longest, todayPercent)
    }
    
    private var weeklySummary: (weeklyPercentage: Int, totalCompletions: Int) {
        // Use actual weekly stats from HabitManager
        let weeklyPercentage = habitManager.weeklyPercentageValue
        let totalCompletions = habitManager.weeklyCompletionsValue
        return (weeklyPercentage, totalCompletions)
    }
}

// MARK: - Habit Card View
private struct HabitCardView: View {
    let habit: Habit
    let onCapture: (UUID) -> Void
    @EnvironmentObject var habitManager: HabitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(habit.name).font(.headline)
                Spacer()
                Button(action: { onCapture(habit.id) }) {
                    Image(systemName: "camera.aperture").font(.system(size: 18)).foregroundColor(.primary)
                }
            }
            
            // Category and streak display
            HStack {
                // Category display
                Text(habit.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(categoryColor(habit.category).opacity(0.2))
                    .foregroundColor(categoryColor(habit.category))
                    .cornerRadius(8)
                
                // Streak display adjacent to category
                let streakValue = habitManager.progress(for: habit.id)?.currentStreak ?? 0
                HStack(spacing: 6) {
                    Image(systemName: "flame").foregroundColor(.orange).font(.system(size: 14))
                    Text("\(streakValue)").font(.system(size: 14, weight: .bold)).foregroundColor(.orange)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
                
                Spacer()
            }
            
            HStack {
                let p = habitManager.progress(for: habit.id)
                Text(p?.period.capitalized ?? habit.targetFrequency.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(p?.completedCount ?? 0)/\(p?.target ?? max(1, habit.targetCount ?? 1))")
                    .font(.caption)
                    .foregroundColor(p?.isComplete == true ? .green : .secondary)
                
                // Target achieved indicator next to progress count
                if let p = habitManager.progress(for: habit.id), p.isComplete {
                    HStack(spacing: 4) {
                        Image(systemName: "target").foregroundColor(.green).font(.system(size: 10))
                        Text("Target achieved")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            GradientProgressBar(percentage: {
                let p = habitManager.progress(for: habit.id)
                let target = max(1, p?.target ?? max(1, habit.targetCount ?? 1))
                let current = Double(p?.completedCount ?? 0)
                return min(100, (current / Double(target)) * 100)
            }())
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CaptureTheme.Palette.border, lineWidth: 1))
        .padding(.horizontal)
    }
    
    private func categoryColor(_ category: String) -> Color {
        // Try to find the category in the database first
        if let habitCategory = habitManager.habitCategories.first(where: { $0.name.lowercased() == category.lowercased() }) {
            return CaptureTheme.categoryColor(from: habitCategory.color)
        }
        
        // Default to gray if category not found
        return .gray
    }
}

private struct GreetingCard: View {
    let userName: String
    let quote: String
    let totalStreak: Int
    let longestStreak: Int
    let todayPercent: Int
    let weeklyPercentage: Int
    let weeklyCompletions: Int
    let isCollapsed: Bool
    let onToggleCollapse: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Greeting row with more weight - entire row is clickable
            HStack(spacing: 10) {
                Image(systemName: timeIconName)
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(.primary)
                Text("\(timeGreeting), \(userName)!")
                    .font(.title3).fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle()) // Make entire row clickable
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onToggleCollapse()
                }
            }
            
            if !isCollapsed {
                Text(quote)
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(2)
                
                // Enhanced stat cards grid with better gradients
                HStack(spacing: 8) {
                    DashboardStatCard(
                        icon: "flame",
                        iconColor: .orange, 
                        valueText: "\(totalStreak)", 
                        label: "Total Streaks", 
                        gradient: [.orange.opacity(0.15), .red.opacity(0.08)]
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    
                    DashboardStatCard(
                        icon: "trophy",
                        iconColor: .yellow, 
                        valueText: "\(longestStreak)", 
                        label: "Best Streak", 
                        gradient: [.yellow.opacity(0.15), .orange.opacity(0.08)]
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    
                    // Today card with circular progress indicator
                    TodayProgressCard(percentage: todayPercent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                }
                
                // Enhanced weekly summary
                WeeklySummaryInnerCard(percentage: weeklyPercentage, totalCompletions: weeklyCompletions)
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [
                    CaptureTheme.Palette.card, 
                    CaptureTheme.Palette.accent.opacity(0.18),
                    CaptureTheme.Palette.accent.opacity(0.08)
                ], 
                startPoint: .topLeading, 
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(CaptureTheme.Palette.border.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)

    }
    
    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "Burning the midnight oil" }
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        if hour < 20 { return "Good evening" }
        return "Good evening"
    }
    
    private var timeIconName: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 { return "moon" }
        if hour < 12 { return "sunrise" }
        if hour < 17 { return "sun.max" }
        if hour < 20 { return "sunset" }
        return "moon"
    }
}

private struct WeeklySummaryInnerCard: View {
    let percentage: Int
    let totalCompletions: Int
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(.purple)
                    Text("This Week")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.purple)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(percentage)%")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.purple)
                    Text("\(totalCompletions) completions")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.purple.opacity(0.8))
                }
            }
            GradientProgressBar(percentage: Double(percentage))
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.12), Color.blue.opacity(0.08), Color.indigo.opacity(0.06)], 
                startPoint: .topLeading, 
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .frame(height: 80)
    }
}

private struct DashboardStatCard: View {
    let icon: String
    let iconColor: Color
    let valueText: String
    let label: String
    let gradient: [Color]
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(iconColor)
                Text(valueText)
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundColor(iconColor)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .background(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(iconColor.opacity(0.25), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

private struct TodayProgressCard: View {
    let percentage: Int
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color.green.opacity(0.2), lineWidth: 4)
                        .frame(width: 14, height: 14)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: CGFloat(percentage) / 100.0)
                        .stroke(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: percentage)
                }
                
                Text("\(percentage)%")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundColor(.green)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Text("Today")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.green.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [.green.opacity(0.15), .mint.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.green.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

private struct GradientProgressBar: View {
    let percentage: Double // 0..100
    
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.purple.opacity(0.15)).frame(height: 8)
            Capsule()
                .fill(LinearGradient(colors: [.purple, .blue, .indigo], startPoint: .leading, endPoint: .trailing))
                .frame(height: 8)
                .mask(
                    GeometryReader { proxy in
                        Rectangle().frame(width: max(0, min(percentage / 100.0, 1.0)) * proxy.size.width)
                    }
                )
        }
    }
}

private struct CollapsedHabitsList: View {
    @EnvironmentObject var habitManager: HabitManager
    let onCapture: (UUID) -> Void
    
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
    
    private func isHabitComplete(_ habit: Habit) -> Bool {
        return habitManager.progress(for: habit.id)?.isComplete == true
    }
    
    private func habitBackground(_ habit: Habit) -> AnyShapeStyle {
        if isHabitComplete(habit) {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.green.opacity(0.1), Color.green.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(Color(.systemBackground))
        }
    }
    
    private func habitBorderColor(_ habit: Habit) -> Color {
        return isHabitComplete(habit) ? Color.green.opacity(0.3) : CaptureTheme.Palette.border
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(sortedHabits) { habit in
                HStack {
                    // Color bar
                    Rectangle()
                        .fill(categoryColor(habit.category))
                        .frame(width: 9, height: 28)
                        .cornerRadius(4)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name).font(.subheadline).fontWeight(.medium)
                        Text(targetText(for: habit)).font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                                              HStack(spacing: 6) {
                              HStack(spacing: 4) {
                                  Image(systemName: "flame").foregroundColor(.orange).font(.system(size: 10))
                                  Text("\(habitManager.progress(for: habit.id)?.currentStreak ?? 0)").font(.system(size: 12, weight: .bold)).foregroundColor(.orange)
                              }
                              .padding(.horizontal, 6).padding(.vertical, 2)
                              .background(Color.orange.opacity(0.15))
                              .cornerRadius(6)
                              Button(action: { onCapture(habit.id) }) {
                                  Image(systemName: "camera.aperture").font(.system(size: 14)).foregroundColor(.primary)
                              }
                          }
                }
                .padding(10)
                .background(habitBackground(habit))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(habitBorderColor(habit), lineWidth: 1)
                )
            }
        }
    }
    
    private func categoryColor(_ category: String) -> Color {
        // Try to find the category in the database first
        if let habitCategory = habitManager.habitCategories.first(where: { $0.name.lowercased() == category.lowercased() }) {
            return CaptureTheme.categoryColor(from: habitCategory.color)
        }
        
        // Default to gray if category not found
        return .gray
    }
    
    private func singularPeriod(_ period: String) -> String {
        switch period.lowercased() {
        case "daily": return "day"
        case "weekly": return "week"
        case "monthly": return "month"
        default: return period
        }
    }
    
    private func targetText(for habit: Habit) -> String {
        let number = habit.targetCount ?? 1
        let period = singularPeriod(habit.targetFrequency)
        return number == 1 ? "once per \(period)" : "\(number) times per \(period)"
    }
}

private struct ExpandedHabitsList: View {
    @EnvironmentObject var habitManager: HabitManager
    let onCapture: (UUID) -> Void
    
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
            ForEach(sortedHabits) { habit in
                VStack(alignment: .leading, spacing: 12) {
                    // Header with habit name and camera button
                    HStack {
                        Text(habit.name).font(.headline)
                        Spacer()
                        Button(action: { onCapture(habit.id) }) {
                            Image(systemName: "camera.aperture").font(.system(size: 18)).foregroundColor(.primary)
                        }
                    }
                    
                    // Category display underneath habit name
                    Text("Category: \(habit.category)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(categoryColor(habit.category).opacity(0.2))
                        .foregroundColor(categoryColor(habit.category))
                        .cornerRadius(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onAppear {
                            print("[ExpandedHabitsList] Category for \(habit.name): \(habit.category)")
                        }
                    
                    // Streak info
                    HStack {
                        Spacer()
                        
                        // Streak display - more prominent
                        let streakValue = habitManager.progress(for: habit.id)?.currentStreak ?? 0
                                                  let progress = habitManager.progress(for: habit.id)
                          HStack(spacing: 6) {
                              Image(systemName: "flame").foregroundColor(.orange).font(.system(size: 14))
                              Text("\(streakValue)").font(.system(size: 14, weight: .bold)).foregroundColor(.orange)
                          }
                          .padding(.horizontal, 8).padding(.vertical, 4)
                          .background(Color.orange.opacity(0.15))
                          .cornerRadius(8)
                        .onAppear {
                            print("[ExpandedHabitsList] Habit: \(habit.name), Progress: \(progress?.currentStreak ?? -1), Streak: \(streakValue)")
                        }
                    }
                    
                    // Progress text
                    Text(progressText(for: habit)).font(.caption).foregroundColor(.secondary)
                    
                    // Progress bar
                    GradientProgressBar(percentage: progressPercent(for: habit))
                }
                .padding(14)
                .background(Color(.systemBackground))
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(CaptureTheme.Palette.border, lineWidth: 1))
                .onAppear {
                    print("[ExpandedHabitsList] Habit data: name=\(habit.name), category=\(habit.category), id=\(habit.id)")
                }
            }
        }
    }
    
    private func categoryColor(_ category: String) -> Color {
        // Try to find the category in the database first
        if let habitCategory = habitManager.habitCategories.first(where: { $0.name.lowercased() == category.lowercased() }) {
            return CaptureTheme.categoryColor(from: habitCategory.color)
        }
        
        // Default to gray if category not found
        return .gray
    }
    
    private func singularPeriod(_ period: String) -> String {
        switch period.lowercased() {
        case "daily": return "day"
        case "weekly": return "week"
        case "monthly": return "month"
        default: return period
        }
    }
    
    private func progressPercent(for habit: Habit) -> Double {
        let progress = habitManager.progress(for: habit.id)
        let current = Double(progress?.completedCount ?? 0)
        let target = Double(habit.targetCount ?? 1)
        return min(100, max(0, (current / max(target, 1)) * 100))
    }
    
    private func progressText(for habit: Habit) -> String {
        let number = habit.targetCount ?? 1
        let period = singularPeriod(habit.targetFrequency)
        if number <= 1 { return "once per \(period)" }
        return "\(number) times per \(period)"
    }
}

private struct ProgressGridList: View {
    @EnvironmentObject var habitManager: HabitManager
    @State private var cachedHabitData: [OptimizedHabitData] = []
    @State private var lastUpdateTime: Date = Date()
    @State private var isComputing: Bool = false
    let weeks: Int = 26 // ~6 months
    let spacing: CGFloat = 3
    
    // Pre-computed data for performance with caching
    private var optimizedHabitData: [OptimizedHabitData] {
        // Check if we need to update cache (every 5 minutes or when data changes)
        let shouldUpdate = Date().timeIntervalSince(lastUpdateTime) > 300 || cachedHabitData.isEmpty
        
        if !shouldUpdate {
            return cachedHabitData
        }
        
        // Prevent multiple simultaneous computations
        if isComputing {
            return cachedHabitData
        }
        
        isComputing = true
        
        let calendar = Calendar.current
        let sixMonthsAgo = calendar.date(byAdding: .day, value: -180, to: Date()) ?? Date()
        let today = Date()
        
        let sortedHabits = habitManager.habits.sorted { habit1, habit2 in
            let habit1Completed = habitManager.progress(for: habit1.id)?.isComplete == true
            let habit2Completed = habitManager.progress(for: habit2.id)?.isComplete == true
            
            if habit1Completed != habit2Completed {
                return !habit1Completed
            }
            return habit1.name < habit2.name
        }
        
        let result = sortedHabits.map { habit in
            let streakValue = habitManager.progress(for: habit.id)?.currentStreak ?? 0
            let captureCount = habitManager.captures.filter { $0.userHabitId == habit.id }.count
            let habitColor = getHabitColor(habit)
            
            // Pre-compute capture dates for this habit
            let captureDates = Set(habitManager.captures
                .filter { $0.userHabitId == habit.id }
                .map { calendar.startOfDay(for: $0.createdAt) })
            
            return OptimizedHabitData(
                habit: habit,
                streakValue: streakValue,
                captureCount: captureCount,
                habitColor: habitColor,
                captureDates: captureDates,
                sixMonthsAgo: sixMonthsAgo,
                today: today
            )
        }
        
        // Update cache
        DispatchQueue.main.async {
            self.cachedHabitData = result
            self.lastUpdateTime = Date()
            self.isComputing = false
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if optimizedHabitData.isEmpty {
                ProgressView("Loading progress grid...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    ForEach(optimizedHabitData) { data in
                        let dataSource = HabitProgressGridDataSource(habit: data.habit, habitManager: habitManager)
                        ProgressGridView(dataSource: dataSource)
                    }
                }
            }
        }
        .onChange(of: habitManager.habitCategories.count) { _ in
            // Clear cache when categories are loaded so colors are recomputed
            cachedHabitData = []
            lastUpdateTime = Date.distantPast
            print("🔄 ProgressGridList: Cleared cache due to category change")
        }
    }
    
    // Cached color lookup
    private func getHabitColor(_ habit: Habit) -> Color {
        if let colorString = habit.color {
            return Color(hex: colorString)
        }
        
        if let habitCategory = habitManager.habitCategories.first(where: { $0.name.lowercased() == habit.category.lowercased() }) {
            return CaptureTheme.categoryColor(from: habitCategory.color)
        }
        
        // Default to gray if category not found
        return .gray
    }
}

// Optimized data structure
private struct OptimizedHabitData: Identifiable {
    let habit: Habit
    let streakValue: Int
    let captureCount: Int
    let habitColor: Color
    let captureDates: Set<Date>
    let sixMonthsAgo: Date
    let today: Date
    
    var id: UUID { habit.id }
}


    

    





private struct EmptyStateCard: View {
    let onCreate: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(CaptureTheme.Palette.accent).frame(width: 96, height: 96)
                Text("🎯").font(.system(size: 34))
            }
            Text("Ready to start your journey?").font(.headline)
            Text("Create your first habit and join the community! Track your progress, share photos, and build consistency together.")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button(action: onCreate) {
                HStack {
                    Image(systemName: "plus").font(.system(size: 14))
                    Text("Create Your First Habit").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal, 24)
            Text("Popular: 💪 Workout • 📚 Reading • 🧘 Meditation")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
        .background(LinearGradient(colors: [CaptureTheme.Palette.accent.opacity(0.2), CaptureTheme.Palette.card], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(CaptureTheme.Palette.border, lineWidth: 1))
    }
}

struct EmptyHabitsView: View {
    let onCreateHabit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "target")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("No habits yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start by adding your first habit")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onCreateHabit) {
                Text("Add First Habit")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [CaptureTheme.Palette.accent.opacity(0.2), CaptureTheme.Palette.card], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(CaptureTheme.Palette.border, lineWidth: 1))
        .padding(.horizontal)
    }
}

// MARK: - Cache Loading Helpers

extension HabitDashboardView {
    private func loadHabitsWithCache() async {
        // Try cache first
        if let cachedHabits = AppCacheManager.shared.getCachedHabits() {
            habitManager.habits = cachedHabits
            print("📱 Loaded habits from cache")
            return
        }
        
        // Load from network if cache miss
        await habitManager.loadHabits()
        
        // Cache the result
        AppCacheManager.shared.cacheHabits(habitManager.habits)
    }
    
    private func loadHabitCategoriesWithCache() async {
        if let cachedCategories = AppCacheManager.shared.getCachedHabitCategories() {
            habitManager.habitCategories = cachedCategories
            habitManager.categories = cachedCategories.map { DiscoveryHabitCategory(from: $0) }
            print("📱 Loaded habit categories from cache")
            return
        }
        
        await habitManager.loadHabitCategories()
        AppCacheManager.shared.cacheHabitCategories(habitManager.habitCategories)
    }
}
