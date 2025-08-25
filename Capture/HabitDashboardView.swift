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
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                                        // App Header with centered title and collapse button
                    HStack {
//                        Spacer().frame(width: 40)
                        Text("Capture")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                    }
                    .padding(.top, -8)
                    
                    // Greeting card with stats and weekly summary inside
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
                    
                    // Main content area
                    if habitManager.habits.isEmpty {
                        EmptyHabitsView { showingHabitPicker = true }
                    } else {
                        // Section header
                        HStack {
                            HStack(spacing: 6) {
//                                Image(systemName: "bolt.fill").foregroundColor(.yellow)
                                Text("Your Habits").font(.headline)
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
                        
                        // Tabs (Overview/Grid)
                        Picker("View", selection: $selectedTab) {
                            Text("Overview").tag("overview")
                            Text("Progress Grid").tag("grid")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            if selectedTab == "overview" {
                                if habitsCollapsed {
                                    CollapsedHabitsList(onCapture: onNavigateToCamera)
                                        .padding(.horizontal)
                                } else {
                                    // Expanded cards
                                    ForEach(sortedHabits) { habit in
                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                Text(habit.name).font(.headline)
                                                Spacer()
                                                Button(action: { onNavigateToCamera(habit.id) }) {
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
                                }
                            } else {
                                ProgressGridList()
                                    .padding(.horizontal)
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    let verticalThreshold: CGFloat = 50
                                    let horizontalThreshold: CGFloat = 50
                                    
                                    // Check if the gesture is primarily vertical
                                    if abs(value.translation.height) > abs(value.translation.width) {
                                        // Vertical swipe - handle collapse/expand
                                        if value.translation.height < -verticalThreshold {
                                            // Swipe up - collapse habits
                                            if !habitsCollapsed {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    habitsCollapsed = true
                                                }
                                            }
                                        } else if value.translation.height > verticalThreshold {
                                            // Swipe down - expand habits
                                            if habitsCollapsed {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    habitsCollapsed = false
                                                }
                                            }
                                        }
                                    } else {
                                        // Horizontal swipe - handle tab switching
                                        if value.translation.width > horizontalThreshold {
                                            // Swipe right - go to previous tab
                                            if selectedTab == "grid" {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    selectedTab = "overview"
                                                }
                                            }
                                        } else if value.translation.width < -horizontalThreshold {
                                            // Swipe left - go to next tab
                                            if selectedTab == "overview" {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    selectedTab = "grid"
                                                }
                                            }
                                        }
                                    }
                                }
                        )
                    }
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
                await habitManager.loadHabits()
                // Preload habit capture images after habits are loaded
                imagePreloader.preloadHabitCaptures(habitManager.captures)
            }
            .onChange(of: authManager.isAuthenticated) { isAuthed in
                if isAuthed { 
                    Task { 
                        await habitManager.loadHabits()
                        // Preload habit capture images after habits are loaded
                        imagePreloader.preloadHabitCaptures(habitManager.captures)
                    } 
                }
            }
            .refreshable { 
                await habitManager.loadHabits()
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
        
        // Fallback to the existing mapping
        switch category {
        case "Fitness": return CaptureTheme.Palette.fitness
        case "Wellness": return CaptureTheme.Palette.wellness
        case "Learning": return CaptureTheme.Palette.learning
        case "Nutrition": return CaptureTheme.Palette.nutrition
        case "Productivity": return CaptureTheme.Palette.productivity
        case "Health": return CaptureTheme.Palette.health
        case "Social": return CaptureTheme.Palette.social
        default: return .gray
        }
    }
    
    private func animateStatsIfNeeded() {
        guard !habitManager.habits.isEmpty else { return }
        let (totalStreak, longestStreak, todayPercent) = computeStats()
        let duration: Double = 1.2
        let steps: Int = 30
        let stepDuration = duration / Double(steps)
        var step = 0
        Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { timer in
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
            // Greeting row with more weight
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
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        onToggleCollapse()
                    }
                }) {
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
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
        .gesture(
            DragGesture()
                .onEnded { value in
                    let threshold: CGFloat = 30
                    if value.translation.height < -threshold {
                        // Swipe up - collapse
                        if !isCollapsed {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onToggleCollapse()
                            }
                        }
                    } else if value.translation.height > threshold {
                        // Swipe down - expand
                        if isCollapsed {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                onToggleCollapse()
                            }
                        }
                    }
                }
        )
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
        
        // Fallback to the existing mapping
        switch category {
        case "Fitness": return CaptureTheme.Palette.fitness
        case "Wellness": return CaptureTheme.Palette.wellness
        case "Learning": return CaptureTheme.Palette.learning
        case "Nutrition": return CaptureTheme.Palette.nutrition
        case "Productivity": return CaptureTheme.Palette.productivity
        case "Health": return CaptureTheme.Palette.health
        case "Social": return CaptureTheme.Palette.social
        default: return .gray
        }
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
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
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
        
        // Fallback to the existing mapping
        switch category {
        case "Fitness": return CaptureTheme.Palette.fitness
        case "Wellness": return CaptureTheme.Palette.wellness
        case "Learning": return CaptureTheme.Palette.learning
        case "Nutrition": return CaptureTheme.Palette.nutrition
        case "Productivity": return CaptureTheme.Palette.productivity
        case "Health": return CaptureTheme.Palette.health
        case "Social": return CaptureTheme.Palette.social
        default: return .gray
        }
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
    @State private var gridHeights: [UUID: CGFloat] = [:]
    let weeks: Int = 26 // ~6 months
    let spacing: CGFloat = 3
    
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
        VStack(spacing: 16) {
            ForEach(sortedHabits) { habit in
                VStack(alignment: .leading, spacing: 6) {
                    // Header with habit name and streak
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name).font(.subheadline).fontWeight(.semibold)
                        
                        // Streak display with icon
                        let streakValue = habitManager.progress(for: habit.id)?.currentStreak ?? 0
                        HStack(spacing: 4) {
                            Image(systemName: "flame").foregroundColor(.orange).font(.system(size: 10))
                            Text("\(streakValue) day streak").font(.system(size: 12)).foregroundColor(.secondary)
                        }
                    }
                    
                    // Grid with measured height
                    ZStack(alignment: .topLeading) {
                        GeometryReader { proxy in
                            let totalWidth = proxy.size.width
                            let cellSize = (totalWidth - CGFloat(weeks - 1) * spacing) / CGFloat(weeks)
                            let gridHeight = cellSize * 7 + spacing * 6
                            
                            GridContentView(
                                weeks: weeks,
                                spacing: spacing,
                                cellSize: cellSize,
                                habit: habit
                            )
                            .frame(width: totalWidth, height: gridHeight, alignment: .topLeading)
                            .onAppear { gridHeights[habit.id] = gridHeight }
                        }
                    }
                    .frame(height: gridHeights[habit.id] ?? 0)
                    
                    // Footer total captures
                    let captureCount = habitManager.captures.filter { $0.habitId == habit.id }.count
                    Text("\(captureCount) captures in the last 6 months")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(CaptureTheme.Palette.border, lineWidth: 1))
            }
        }
    }
    
    private func habitColor(_ habit: Habit) -> Color {
        // Use habit's custom color if available, otherwise fall back to category color
        if let colorString = habit.color {
            return Color(hex: colorString)
        }
        return categoryColor(habit.category)
    }
    
    private func habitIcon(_ habit: Habit) -> String {
        // Use habit's custom icon if available, otherwise fall back to category symbol
        if let iconString = habit.icon {
            return iconString
        }
        return categorySymbol(habit.category)
    }
    
    private func categoryColor(_ category: String) -> Color {
        // Try to find the category in the database first
        if let habitCategory = habitManager.habitCategories.first(where: { $0.name.lowercased() == category.lowercased() }) {
            return CaptureTheme.categoryColor(from: habitCategory.color)
        }
        
        // Fallback to the existing mapping
        switch category {
        case "Fitness": return CaptureTheme.Palette.fitness
        case "Wellness": return CaptureTheme.Palette.wellness
        case "Learning": return CaptureTheme.Palette.learning
        case "Nutrition": return CaptureTheme.Palette.nutrition
        case "Productivity": return CaptureTheme.Palette.productivity
        case "Health": return CaptureTheme.Palette.health
        case "Social": return CaptureTheme.Palette.social
        default: return .gray
        }
    }
    
    private func categorySymbol(_ category: String) -> String {
        switch category {
        case "Fitness": return "figure.run"
        case "Wellness": return "leaf.fill"
        case "Learning": return "book.fill"
        case "Nutrition": return "fork.knife"
        case "Productivity": return "checkmark.square.fill"
        case "Health": return "heart.fill"
        case "Social": return "person.2.fill"
        default: return "star.fill"
        }
    }
    

}

private struct GridContentView: View {
    let weeks: Int
    let spacing: CGFloat
    let cellSize: CGFloat
    let habit: Habit
    
    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<weeks, id: \.self) { week in
                VStack(spacing: spacing) {
                    ForEach(0..<7, id: \.self) { day in
                        GridCell(habit: habit, week: week, day: day, cellSize: cellSize)
                    }
                }
            }
        }
    }
}

private struct GridCell: View {
    @EnvironmentObject var habitManager: HabitManager
    let habit: Habit
    let week: Int
    let day: Int
    let cellSize: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(gridFill(for: habit, week: week, day: day))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(gridBorderColor(for: habit, week: week, day: day), lineWidth: 1)
            )
    }
    
    private func gridFill(for habit: Habit, week: Int, day: Int) -> Color {
        // Calculate the date for this cell (6 months ago + week * 7 + day)
        let calendar = Calendar.current
        let sixMonthsAgo = calendar.date(byAdding: .day, value: -180, to: Date()) ?? Date()
        let cellDate = calendar.date(byAdding: .day, value: week * 7 + day, to: sixMonthsAgo) ?? Date()
        
        // Check if there are captures for this habit on this date
        let hasCapture = habitManager.captures.contains { capture in
            capture.habitId == habit.id && 
            calendar.isDate(capture.createdAt, inSameDayAs: cellDate)
        }
        
        // Check if this is today
        let isToday = calendar.isDateInToday(cellDate)
        
        if hasCapture {
            // Completed habit - use habit color
            return habitColor(habit)
        } else if isToday {
            // Today but not completed - white background
            return Color.white
        } else {
            // Not completed and not today - white background
            return Color.white
        }
    }
    
    private func gridBorderColor(for habit: Habit, week: Int, day: Int) -> Color {
        // Calculate the date for this cell
        let calendar = Calendar.current
        let sixMonthsAgo = calendar.date(byAdding: .day, value: -180, to: Date()) ?? Date()
        let cellDate = calendar.date(byAdding: .day, value: week * 7 + day, to: sixMonthsAgo) ?? Date()
        
        // Check if this is today
        let isToday = calendar.isDateInToday(cellDate)
        
        if isToday {
            // Today - blue outline
            return Color.blue.opacity(0.6)
        } else {
            // Not today - grey outline
            return Color.gray.opacity(0.3)
        }
    }
    
    private func habitColor(_ habit: Habit) -> Color {
        // Use habit's custom color if available, otherwise fall back to category color
        if let colorString = habit.color {
            return Color(hex: colorString)
        }
        return categoryColor(habit.category)
    }
    
    private func categoryColor(_ category: String) -> Color {
        // Try to find the category in the database first
        if let habitCategory = habitManager.habitCategories.first(where: { $0.name.lowercased() == category.lowercased() }) {
            return CaptureTheme.categoryColor(from: habitCategory.color)
        }
        
        // Fallback to the existing mapping
        switch category {
        case "Fitness": return CaptureTheme.Palette.fitness
        case "Wellness": return CaptureTheme.Palette.wellness
        case "Learning": return CaptureTheme.Palette.learning
        case "Nutrition": return CaptureTheme.Palette.nutrition
        case "Productivity": return CaptureTheme.Palette.productivity
        case "Health": return CaptureTheme.Palette.health
        case "Social": return CaptureTheme.Palette.social
        default: return .gray
        }
    }
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
