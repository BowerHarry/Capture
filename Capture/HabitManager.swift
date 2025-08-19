import Foundation
import Combine

@MainActor
class HabitManager: ObservableObject {
    static let shared = HabitManager()
    
    @Published var habits: [Habit] = []
    @Published var captures: [HabitCapture] = []
    @Published var availableHabits: [AvailableHabit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Discovery properties
    @Published var popularHabits: [PopularHabit] = []
    @Published var communityStats = CommunityStats()
    @Published var categories: [DiscoveryHabitCategory] = []

    // Progress and streaks
    struct HabitProgressState {
        let habitId: UUID
        let period: String // daily | weekly | monthly
        let target: Int
        let completedCount: Int
        let isComplete: Bool
        let currentStreak: Int
        let isExpiring: Bool
    }
    @Published var habitProgress: [UUID: HabitProgressState] = [:]
    @Published var totalStreakSum: Int = 0
    @Published var longestStreakValue: Int = 0
    @Published var todayPercentValue: Int = 0
    @Published var weeklyPercentageValue: Int = 0
    @Published var weeklyCompletionsValue: Int = 0
    
    private let supabaseClient = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Date helpers
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }
    
    private func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }
    private func startOfCurrentWeek() -> Date {
        let today = Date()
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        return calendar.date(from: comps) ?? startOfDay(today)
    }
    private func startOfCurrentMonth() -> Date {
        let today = Date()
        let comps = calendar.dateComponents([.year, .month], from: today)
        return calendar.date(from: comps) ?? startOfDay(today)
    }
    private func weekKey(for date: Date) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? startOfDay(date)
    }
    private func monthKey(for date: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? startOfDay(date)
    }
    private func windowStart(for period: String) -> Date {
        switch period.lowercased() {
        case "weekly": return startOfCurrentWeek()
        case "monthly": return startOfCurrentMonth()
        default: return startOfDay(Date())
        }
    }
    private var sixMonthsAgo: Date {
        calendar.date(byAdding: .day, value: -180, to: startOfDay(Date())) ?? startOfDay(Date())
    }

    // MARK: - Best Streak Management
    
    func updateUserBestStreak() async {
        guard let currentUser = AuthManager.shared.currentUser else { return }
        
        // Calculate the current best streak from all habits
        let currentBestStreak = calculateCurrentBestStreak()
        
        print("📊 Current best streak calculation: \(currentBestStreak)")
        
        // Check if this is higher than the user's current best streak
        if let userBestStreak = currentUser.bestStreak, currentBestStreak <= userBestStreak {
            print("📊 No update needed - current best streak (\(currentBestStreak)) <= user best streak (\(userBestStreak))")
            return // No update needed
        }
        
        do {
            // Update the user's best streak in the database
            try await supabaseClient.client
                .from("profiles")
                .update(["best_streak": currentBestStreak])
                .eq("id", value: currentUser.id)
                .execute()
            
            print("✅ Updated user best streak to \(currentBestStreak)")
            
            // Update the current user object
            let updatedUser = User(
                id: currentUser.id,
                email: currentUser.email,
                username: currentUser.username,
                avatar: currentUser.avatar,
                bio: currentUser.bio,
                createdAt: currentUser.createdAt,
                updatedAt: currentUser.updatedAt,
                followersCount: currentUser.followersCount,
                followingCount: currentUser.followingCount,
                bestStreak: currentBestStreak
            )
            
            AuthManager.shared.currentUser = updatedUser
        } catch {
            print("❌ Failed to update user best streak: \(error)")
        }
    }
    
    func calculateCurrentBestStreak() -> Int {
        // Calculate the best streak from both habit data and current progress
        let habitBestStreak = habits.map { $0.longestStreak }.max() ?? 0
        let currentProgressBestStreak = habitProgress.values.map { $0.currentStreak }.max() ?? 0
        
        // Take the maximum of habit longest streak and current progress streak
        let calculatedBestStreak = max(habitBestStreak, currentProgressBestStreak)
        
        print("📊 Best streak calculation:")
        print("   - Habit longest streaks: \(habits.map { $0.longestStreak })")
        print("   - Current progress streaks: \(habitProgress.values.map { $0.currentStreak })")
        print("   - Habit best: \(habitBestStreak)")
        print("   - Progress best: \(currentProgressBestStreak)")
        print("   - Final best: \(calculatedBestStreak)")
        
        return calculatedBestStreak
    }
    
    func getCurrentBestStreak() -> Int {
        // For the current user, calculate the real-time best streak
        return calculateCurrentBestStreak()
    }
    
    func getCurrentBestStreakForUser(userId: UUID) -> Int {
        // For other users, we'll need to calculate based on their habits
        // This would need to be implemented based on how we fetch other users' data
        return 0 // Placeholder for now
    }
    
    func forceUpdateBestStreak() async {
        print("🔄 Force updating best streak...")
        await updateUserBestStreak()
    }
    
    // MARK: - Progress computation
    private func computeStreaksAndCompletion(habits: [Habit], captures: [HabitCapture]) {
        NSLog("[HabitManager] computeStreaksAndCompletion: starting with \(habits.count) habits and \(captures.count) captures")
        
        // Build per-habit buckets
        var dayCounts: [UUID: [Date: Int]] = [:]
        var weekCounts: [UUID: [Date: Int]] = [:]
        var monthCounts: [UUID: [Date: Int]] = [:]
        let todayStart = startOfDay(Date())

        for cap in captures {
            let hId = cap.habitId
            let dKey = startOfDay(cap.createdAt)
            let wKey = weekKey(for: cap.createdAt)
            let mKey = monthKey(for: cap.createdAt)
            dayCounts[hId, default: [:]][dKey, default: 0] += 1
            weekCounts[hId, default: [:]][wKey, default: 0] += 1
            monthCounts[hId, default: [:]][mKey, default: 0] += 1
        }

        var progress: [UUID: HabitProgressState] = [:]
        var totalStreak = 0
        var longestStreak = 0
        var dailyHabits = 0
        var dailyComplete = 0
        var weeklyHabits = 0
        var weeklyComplete = 0
        var weeklyTargetsSum = 0
        var weeklyCompletionsSum = 0
        var monthlyHabits = 0
        var monthlyComplete = 0

        for habit in habits {
            let period = habit.targetFrequency.lowercased()
            let target = max(1, habit.targetCount ?? 1)

            var periodCompletedCount = 0
            let isComplete: Bool
            let currentStreak: Int
            var isExpiring: Bool = false

            switch period {
            case "weekly":
                let counts = weekCounts[habit.id] ?? [:]
                let thisWeek = weekKey(for: Date())
                periodCompletedCount = counts[thisWeek] ?? 0
                isComplete = periodCompletedCount >= target
                currentStreak = computeWeeklyStreak(target: target, weekCounts: counts)
                weeklyHabits += 1
                weeklyTargetsSum += target
                weeklyCompletionsSum += periodCompletedCount
                if isComplete { weeklyComplete += 1 }
                // Expiring on last day of week (Sunday)
                let weekday = calendar.component(.weekday, from: Date())
                isExpiring = (weekday == 1) && !isComplete
            case "monthly":
                let counts = monthCounts[habit.id] ?? [:]
                let thisMonth = monthKey(for: Date())
                periodCompletedCount = counts[thisMonth] ?? 0
                isComplete = periodCompletedCount >= target
                currentStreak = computeMonthlyStreak(target: target, monthCounts: counts)
                monthlyHabits += 1
                if isComplete { monthlyComplete += 1 }
                // Expiring on last day of month
                let today = Date()
                let day = calendar.component(.day, from: today)
                let range = calendar.range(of: .day, in: .month, for: today)
                let lastDay = range?.count ?? day
                isExpiring = (day == lastDay) && !isComplete
            default: // daily
                let counts = dayCounts[habit.id] ?? [:]
                periodCompletedCount = counts[todayStart] ?? 0
                isComplete = periodCompletedCount >= target
                currentStreak = computeDailyStreak(target: target, dayCounts: counts)
                dailyHabits += 1
                if isComplete { dailyComplete += 1 }
                // Expiring after 6pm local time
                let hour = calendar.component(.hour, from: Date())
                isExpiring = (hour >= 18) && !isComplete
            }

            totalStreak += currentStreak
            if currentStreak > longestStreak { longestStreak = currentStreak }

            progress[habit.id] = HabitProgressState(
                habitId: habit.id,
                period: period,
                target: target,
                completedCount: periodCompletedCount,
                isComplete: isComplete,
                currentStreak: currentStreak,
                isExpiring: isExpiring
            )
        }

        self.habitProgress = progress
        self.totalStreakSum = totalStreak
        self.longestStreakValue = longestStreak
        
        // Update user's best streak if needed
        Task {
            await updateUserBestStreak()
        }
        
        NSLog("[HabitManager] computeStreaksAndCompletion: completed - totalStreak: \(totalStreak), longestStreak: \(longestStreak), progress entries: \(progress.count)")
        for (habitId, progressState) in progress {
            NSLog("[HabitManager] Habit \(habitId): streak=\(progressState.currentStreak), completed=\(progressState.completedCount)")
        }

        // Daily percentage logic:
        // - Normal days: only daily habits
        // - Sundays: include weekly habits
        // - Last day of month: include monthly habits
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) // 1=Sunday
        let day = calendar.component(.day, from: today)
        let monthRange = calendar.range(of: .day, in: .month, for: today)
        let lastDay = monthRange?.count ?? day
        let includeWeekly = (weekday == 1) // Sunday
        let includeMonthly = (day == lastDay)

        var consideredHabits = dailyHabits
        var consideredComplete = dailyComplete
        if includeWeekly {
            consideredHabits += weeklyHabits
            consideredComplete += weeklyComplete
        }
        if includeMonthly {
            consideredHabits += monthlyHabits
            consideredComplete += monthlyComplete
        }
        if consideredHabits > 0 {
            self.todayPercentValue = Int(round(min(1.0, Double(consideredComplete) / Double(consideredHabits)) * 100))
        } else {
            self.todayPercentValue = 0
        }

        // Weekly percentage and completions across weekly habits only
        if weeklyTargetsSum > 0 {
            self.weeklyPercentageValue = Int(round(min(1.0, Double(weeklyCompletionsSum) / Double(weeklyTargetsSum)) * 100))
        } else {
            self.weeklyPercentageValue = 0
        }
        self.weeklyCompletionsValue = weeklyCompletionsSum
    }

    private func computeDailyStreak(target: Int, dayCounts: [Date: Int]) -> Int {
        var streak = 0
        var day = startOfDay(Date())
        // If today not met, begin from yesterday
        var dayCount = dayCounts[day] ?? 0
        if dayCount < target { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        while day >= sixMonthsAgo {
            dayCount = dayCounts[day] ?? 0
            if dayCount >= target {
                streak += 1
                day = calendar.date(byAdding: .day, value: -1, to: day)!
            } else {
                break
            }
        }
        return streak
    }

    private func computeWeeklyStreak(target: Int, weekCounts: [Date: Int]) -> Int {
        var streak = 0
        var week = weekKey(for: Date())
        // If current week not met, start from previous week
        if (weekCounts[week] ?? 0) < target {
            week = calendar.date(byAdding: .weekOfYear, value: -1, to: week)!
        }
        while week >= sixMonthsAgo {
            if (weekCounts[week] ?? 0) >= target {
                streak += 1
                week = calendar.date(byAdding: .weekOfYear, value: -1, to: week)!
            } else {
                break
            }
        }
        return streak
    }

    private func computeMonthlyStreak(target: Int, monthCounts: [Date: Int]) -> Int {
        var streak = 0
        var month = monthKey(for: Date())
        if (monthCounts[month] ?? 0) < target {
            month = calendar.date(byAdding: .month, value: -1, to: month)!
        }
        while month >= sixMonthsAgo {
            if (monthCounts[month] ?? 0) >= target {
                streak += 1
                month = calendar.date(byAdding: .month, value: -1, to: month)!
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Public API
    func loadAvailableHabits() async {
        isLoading = true
        errorMessage = nil
        do {
            let suggestions = try await supabaseClient.getAvailableHabits()
            self.availableHabits = suggestions
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadHabits() async {
        isLoading = true
        errorMessage = nil
        NSLog("[HabitManager] loadHabits: starting fetch")
        defer { isLoading = false }
        do {
            let result = try await supabaseClient.getHabits()
            NSLog("[HabitManager] loadHabits: fetched %d habits", result.count)
            self.habits = result
            // Fetch enough captures for streaks (last 6 months)
            let recentCaptures = try await supabaseClient.getCapturesSince(since: sixMonthsAgo)
            self.captures = recentCaptures
            computeStreaksAndCompletion(habits: result, captures: recentCaptures)
        } catch {
            self.errorMessage = error.localizedDescription
            NSLog("[HabitManager] loadHabits: error %@", error.localizedDescription)
            self.habits = []
        }
    }

    func createHabit(name: String, description: String?, category: String, targetFrequency: String) async {
        // Implementation would go here
    }
    
    func createHabitFromSuggestion(_ suggestion: AvailableHabit, defaultFrequency: String = "daily") async -> Habit? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let habit = try await supabaseClient.createHabitDirect(
                name: suggestion.name,
                description: nil,
                category: suggestion.category,
                targetFrequency: defaultFrequency
            )
            self.habits.append(habit)
            await loadHabits()
            return habit
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func createCustomHabit(name: String, icon: String, color: String, category: String, targetNumber: Int, period: TargetFrequency) async -> Habit? {
        guard let _ = await createAvailableHabitTemplate(name: name, category: category, icon: icon, color: color) else { return nil }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let habit = try await supabaseClient.createHabitDirect(
                name: name,
                description: nil,
                category: category,
                targetFrequency: period.rawValue,
                targetCount: targetNumber
            )
            self.habits.append(habit)
            await loadHabits()
            return habit
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func createCapture(habitId: UUID, caption: String?, isPublic: Bool, imageData: Data?) async {
        guard let imageData = imageData else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            guard let user = try await SupabaseManager.shared.getCurrentUser() else {
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            }
            let storagePath = try await SupabaseManager.shared.uploadCaptureImage(imageData: imageData, userId: user.id)
            let created = try await SupabaseManager.shared.insertCapture(habitId: habitId.uuidString, userId: user.id, imageUrl: storagePath, caption: caption, isPublic: isPublic)
            self.captures.append(created)
            // Recompute progress after new capture
            computeStreaksAndCompletion(habits: self.habits, captures: self.captures)
            // Immediately update best streak after capture
            await updateUserBestStreak()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func loadCaptures() async {
        // Implementation would go here
    }
    
    func deleteHabit(habitId: UUID) async {
        // Implementation would go here
    }
    
    func getHabitStats(habitId: UUID) async -> [String: Any] {
        return [:]
    }

    func createAvailableHabitTemplate(name: String, category: String, icon: String?, color: String?) async -> AvailableHabit? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let row = try await supabaseClient.createAvailableHabit(name: name, category: category, icon: icon, color: color)
            await loadAvailableHabits()
            return row
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
    
    func isHabitCompleteToday(habitId: UUID, targetCount: Int) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let todays = captures.filter { $0.habitId == habitId && calendar.startOfDay(for: $0.createdAt) == today }
        return todays.count >= max(1, targetCount)
    }
    
    func progress(for habitId: UUID) -> HabitProgressState? {
        let progress = habitProgress[habitId]
        NSLog("[HabitManager] progress(for: \(habitId)): \(progress?.currentStreak ?? -1)")
        return progress
    }

    func createTrackedHabit(name: String, category: String, targetNumber: Int, period: TargetFrequency) async -> Habit? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let habit = try await supabaseClient.createHabitDirect(
                name: name,
                description: nil,
                category: category,
                targetFrequency: period.rawValue,
                targetCount: targetNumber
            )
            self.habits.append(habit)
            await loadHabits()
            return habit
        } catch {
            self.errorMessage = error.localizedDescription
            return nil
        }
    }
    
    // MARK: - Discovery Methods
    
    func loadPopularHabits() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // Initialize categories
            let initialCategories = [
                DiscoveryHabitCategory(name: "Fitness", color: "blue"),
                DiscoveryHabitCategory(name: "Wellness", color: "green"),
                DiscoveryHabitCategory(name: "Learning", color: "purple"),
                DiscoveryHabitCategory(name: "Nutrition", color: "orange"),
                DiscoveryHabitCategory(name: "Productivity", color: "red"),
                DiscoveryHabitCategory(name: "Health", color: "pink"),
                DiscoveryHabitCategory(name: "Social", color: "yellow")
            ]
            
            // For now, we'll create mock data since we don't have the API endpoint yet
            // In a real implementation, this would call the API
            let mockPopularHabits = [
                PopularHabit(
                    name: "Morning Workout",
                    category: "Fitness",
                    participants: 1250,
                    totalStreak: 8750,
                    description: "Start your day with energy and build strength",
                    image: nil,
                    captures: ["https://picsum.photos/200/200?random=1", "https://picsum.photos/200/200?random=2"]
                ),
                PopularHabit(
                    name: "Daily Meditation",
                    category: "Wellness",
                    participants: 890,
                    totalStreak: 6230,
                    description: "Find inner peace and reduce stress",
                    image: nil,
                    captures: ["https://picsum.photos/200/200?random=3"]
                ),
                PopularHabit(
                    name: "Read 30 Minutes",
                    category: "Learning",
                    participants: 2100,
                    totalStreak: 14700,
                    description: "Expand your knowledge and vocabulary",
                    image: nil,
                    captures: ["https://picsum.photos/200/200?random=4", "https://picsum.photos/200/200?random=5", "https://picsum.photos/200/200?random=6"]
                ),
                PopularHabit(
                    name: "Drink 8 Glasses of Water",
                    category: "Health",
                    participants: 3400,
                    totalStreak: 23800,
                    description: "Stay hydrated and maintain good health",
                    image: nil,
                    captures: ["https://picsum.photos/200/200?random=7", "https://picsum.photos/200/200?random=8"]
                ),
                PopularHabit(
                    name: "No Phone Before Bed",
                    category: "Wellness",
                    participants: 1560,
                    totalStreak: 10920,
                    description: "Improve sleep quality and reduce blue light exposure",
                    image: nil,
                    captures: ["https://picsum.photos/200/200?random=9"]
                )
            ]
            
            let mockCommunityStats = CommunityStats(
                activeUsers: 15420,
                totalHabits: 8920,
                totalCaptures: 45670
            )
            
            self.popularHabits = mockPopularHabits
            self.communityStats = mockCommunityStats
            
            // Update categories with counts
            let updatedCategories = initialCategories.map { category in
                let count = mockPopularHabits
                    .filter { $0.category == category.name }
                    .reduce(0) { $0 + $1.participants }
                return DiscoveryHabitCategory(name: category.name, count: count, color: category.color)
            }
            self.categories = updatedCategories
            
        } catch {
            self.errorMessage = error.localizedDescription
            self.popularHabits = []
            self.communityStats = CommunityStats()
            self.categories = []
        }
    }
    
    func createHabitFromDiscovery(name: String, category: String) async {
        do {
            let habit = try await supabaseClient.createHabitDirect(
                name: name,
                description: nil,
                category: category,
                targetFrequency: "daily",
                targetCount: 1
            )
            self.habits.append(habit)
            await loadHabits()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    func getAllHabits() async -> [AvailableHabit] {
        do {
            let response: [AvailableHabit] = try await supabaseClient.client
                .from("available_habits")
                .select()
                .order("name", ascending: true)
                .limit(1000)
                .execute()
                .value
            
            return response
        } catch {
            self.errorMessage = error.localizedDescription
            return []
        }
    }
    
    func getAllUsers() async -> [User] {
        do {
            let response: [UserProfile] = try await supabaseClient.client
                .from("profiles")
                .select()
                .order("display_name", ascending: true)
                .limit(1000)
                .execute()
                .value
            
            // Convert UserProfile to User
            return response.map { profile in
                User(
                    id: profile.id,
                    email: profile.email,
                    username: profile.username ?? profile.displayName ?? "Unknown User",
                    avatar: profile.avatarUrl,
                    bio: profile.bio,
                    createdAt: profile.createdAt,
                    updatedAt: profile.updatedAt
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
            return []
        }
    }
}
