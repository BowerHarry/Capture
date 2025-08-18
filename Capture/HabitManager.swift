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
}
