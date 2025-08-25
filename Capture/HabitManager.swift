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
    private var isUpdatingBestStreak = false
    private var hasComputedProgress = false
    private var lastComputedDataHash = ""
    
    // Discovery properties
    @Published var popularHabits: [PopularHabit] = []
    @Published var trendingHabits: [TrendingHabit] = []
    @Published var trendingCaptures: [TrendingCapture] = []
    @Published var communityStats = CommunityStats()
    @Published var habitCategories: [DatabaseHabitCategory] = []
    @Published var categories: [DiscoveryHabitCategory] = [] // For backward compatibility

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
    
    // Private properties for preventing duplicate calls
    private var isLoadingTrending = false
    
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
        // Prevent duplicate calls
        if isUpdatingBestStreak {
            NSLog("[HabitManager] updateUserBestStreak: already updating, skipping")
            return
        }
        
        isUpdatingBestStreak = true
        defer { isUpdatingBestStreak = false }
        
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
    
    // Reset progress computation when data changes
    private func resetProgressComputation() {
        hasComputedProgress = false
        lastComputedDataHash = ""
        NSLog("[HabitManager] resetProgressComputation: progress computation reset")
    }
    
    // MARK: - Progress computation
    private func computeStreaksAndCompletion(habits: [Habit], captures: [HabitCapture]) {
        // Create a hash of the current data to detect changes
        let habitsHash = habits.map { "\($0.id)-\($0.longestStreak)" }.joined(separator: "|")
        let capturesHash = captures.map { "\($0.id)-\($0.createdAt)" }.joined(separator: "|")
        let currentDataHash = "\(habitsHash)|\(capturesHash)"
        
        // Prevent duplicate calculations if data hasn't changed
        if hasComputedProgress && lastComputedDataHash == currentDataHash {
            NSLog("[HabitManager] computeStreaksAndCompletion: data unchanged, skipping")
            return
        }
        
        hasComputedProgress = true
        lastComputedDataHash = currentDataHash
        NSLog("[HabitManager] computeStreaksAndCompletion: starting with \(habits.count) habits and \(captures.count) captures")
        
        // Build per-habit buckets
        var dayCounts: [UUID: [Date: Int]] = [:]
        var weekCounts: [UUID: [Date: Int]] = [:]
        var monthCounts: [UUID: [Date: Int]] = [:]
        let todayStart = startOfDay(Date())

        for cap in captures {
            let hId = cap.userHabitIdForStreak
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
        
        // Update user's best streak if needed (only once)
        if !isUpdatingBestStreak {
            Task {
                await updateUserBestStreak()
            }
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
        NSLog("[HabitManager] loadHabits: starting fetch")
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let fetchedHabits = try await supabaseClient.getHabits()
            NSLog("[HabitManager] loadHabits: successfully fetched %d habits", fetchedHabits.count)
            
            // Log each habit's details
            for (index, habit) in fetchedHabits.enumerated() {
                NSLog("[HabitManager] loadHabits: habit[%d] id=%@, name=%@, userId=%@", index, habit.id.uuidString, habit.name, habit.userId.uuidString)
            }
            
            self.habits = fetchedHabits
            
            // Load captures for these habits
            NSLog("[HabitManager] loadHabits: loading captures for habits")
            let captures = try await supabaseClient.getCapturesSince(since: sixMonthsAgo)
            NSLog("[HabitManager] loadHabits: successfully fetched %d captures", captures.count)
            
            // Log capture details
            for (index, capture) in captures.enumerated() {
                NSLog("[HabitManager] loadHabits: capture[%d] id=%@, habitId=%@, userHabitId=%@", index, capture.id.uuidString, capture.habitId?.uuidString ?? "nil", capture.userHabitId?.uuidString ?? "nil")
            }
            
            self.captures = captures
            
            // Compute streaks and completion
            NSLog("[HabitManager] loadHabits: computing streaks and completion")
            computeStreaksAndCompletion(habits: self.habits, captures: self.captures)
            
            NSLog("[HabitManager] loadHabits: completed successfully")
        } catch {
            NSLog("[HabitManager] loadHabits: error %@", error.localizedDescription)
            self.errorMessage = error.localizedDescription
        }
    }
    
    // Load all app data at startup
    func loadAppData() async {
        // Prevent duplicate calls
        if isLoading {
            NSLog("[HabitManager] loadAppData: already loading, skipping")
            return
        }
        
        NSLog("[HabitManager] loadAppData: starting app data load")
        
        // Load user habits and captures
        await loadHabits()
        
        // Load trending and popular data in parallel (without loading state checks)
        async let trendingTask = loadTrendingHabitsInternal()
        async let popularTask = loadPopularHabitsInternal()
        
        // Wait for both to complete
        await (trendingTask, popularTask)
        
        NSLog("[HabitManager] loadAppData: completed app data load")
    }

    func createHabit(name: String, description: String?, category: String, targetFrequency: String) async {
        // Implementation would go here
    }
    
    // MARK: - Habit Creation from Template
    
    func createHabitFromTemplate(templateId: UUID) async throws -> Habit {
        guard let currentUser = AuthManager.shared.currentUser else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Check if user already has this habit template
        let existingUserHabits: [UserHabit] = try await supabaseClient.client
            .from("user_habits")
            .select()
            .eq("user_id", value: currentUser.id)
            .eq("habit_template_id", value: templateId)
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        
        if let existingUserHabit = existingUserHabits.first {
            // User already has this habit, return existing one
            let template: [HabitTemplate] = try await supabaseClient.client
                .from("habit_templates")
                .select()
                .eq("id", value: templateId)
                .limit(1)
                .execute()
                .value
            
            guard let habitTemplate = template.first else {
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Habit template not found"])
            }
            
            return Habit(
                id: existingUserHabit.id,
                name: habitTemplate.name,
                icon: nil,
                color: nil,
                category: habitTemplate.category,
                target: habitTemplate.targetCount ?? 1,
                targetFrequency: habitTemplate.targetFrequency,
                targetCount: habitTemplate.targetCount,
                currentStreak: existingUserHabit.currentStreak,
                longestStreak: 0,
                isActive: existingUserHabit.isActive,
                createdAt: existingUserHabit.createdAt,
                updatedAt: existingUserHabit.updatedAt,
                userId: existingUserHabit.userId
            )
        }
        
        // Create new user habit from template
        struct CreateUserHabit: Encodable {
            let habit_template_id: UUID
            let user_id: UUID
            let current_streak: Int
            let is_active: Bool
        }
        
        let userHabitPayload = CreateUserHabit(
            habit_template_id: templateId,
            user_id: currentUser.id,
            current_streak: 0,
            is_active: true
        )
        
        let userHabitRows: [UserHabit] = try await supabaseClient.client
            .from("user_habits")
            .insert(userHabitPayload)
            .select()
            .limit(1)
            .execute()
            .value
        
        guard let userHabit = userHabitRows.first else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create user habit"])
        }
        
        // Get template details
        let template: [HabitTemplate] = try await supabaseClient.client
            .from("habit_templates")
            .select()
            .eq("id", value: templateId)
            .limit(1)
            .execute()
            .value
        
        guard let habitTemplate = template.first else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Habit template not found"])
        }
        
        let newHabit = Habit(
            id: userHabit.id,
            name: habitTemplate.name,
            icon: nil,
            color: nil,
            category: habitTemplate.category,
            target: habitTemplate.targetCount ?? 1,
            targetFrequency: habitTemplate.targetFrequency,
            targetCount: habitTemplate.targetCount,
            currentStreak: userHabit.currentStreak,
            longestStreak: 0,
            isActive: userHabit.isActive,
            createdAt: userHabit.createdAt,
            updatedAt: userHabit.updatedAt,
            userId: userHabit.userId
        )
        
        // Add to local habits array
        habits.append(newHabit)
        
        return newHabit
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
        guard let imageData = imageData else { 
            NSLog("[HabitManager] createCapture: ERROR - No image data provided")
            return 
        }
        
        NSLog("[HabitManager] createCapture: starting capture creation for habit %@", habitId.uuidString)
        NSLog("[HabitManager] createCapture: parameters - caption=%@, isPublic=%@, imageDataSize=%d", caption ?? "nil", String(isPublic), imageData.count)
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            guard let user = try await SupabaseManager.shared.getCurrentUser() else {
                NSLog("[HabitManager] createCapture: ERROR - No authenticated user")
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            }
            
            NSLog("[HabitManager] createCapture: authenticated user %@", user.id.uuidString)
            
            NSLog("[HabitManager] createCapture: uploading image to storage (bytes=%d)", imageData.count)
            let storagePath = try await SupabaseManager.shared.uploadCaptureImage(imageData: imageData, userId: user.id)
            NSLog("[HabitManager] createCapture: successfully uploaded to %@", storagePath)
            
            // Manually construct the public URL since we're uploading to captures_public bucket
            let publicURL = "https://your-project-ref.supabase.co/storage/v1/object/public/captures_public/\(storagePath)"
            NSLog("[HabitManager] createCapture: created public URL %@", publicURL)
            
            NSLog("[HabitManager] createCapture: calling insertCapture with habitId=%@", habitId.uuidString)
            do {
                let created = try await SupabaseManager.shared.insertCapture(habitId: habitId.uuidString, userId: user.id, imageUrl: publicURL, caption: caption, isPublic: isPublic)
                NSLog("[HabitManager] createCapture: successfully inserted capture %@ with habitId=%@, habitTemplateId=%@", 
                      created.id.uuidString, 
                      created.habitId?.uuidString ?? "nil",
                      created.habitTemplateId?.uuidString ?? "nil")
                
                // Verify the returned capture has the expected habitId
                if created.habitId != habitId {
                    NSLog("[HabitManager] createCapture: WARNING - habitId mismatch! Expected=%@, Got=%@", habitId.uuidString, created.habitId?.uuidString ?? "nil")
                } else {
                    NSLog("[HabitManager] createCapture: SUCCESS - habitId matches expected value")
                }
                
                self.captures.append(created)
                NSLog("[HabitManager] createCapture: added capture to local array, total captures=%d", self.captures.count)
                
                // Reset progress computation and recompute after new capture
                resetProgressComputation()
                computeStreaksAndCompletion(habits: self.habits, captures: self.captures)
                
                // Immediately update best streak after capture
                await updateUserBestStreak()
                
                NSLog("[HabitManager] createCapture: completed successfully")
            } catch {
                NSLog("[HabitManager] createCapture: ERROR during insertCapture: %@", error.localizedDescription)
                throw error
            }
        } catch {
            NSLog("[HabitManager] createCapture: ERROR %@", error.localizedDescription)
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
                    let todays = captures.filter { $0.userHabitId == habitId && calendar.startOfDay(for: $0.createdAt) == today }
        return todays.count >= max(1, targetCount)
    }
    
    func progress(for habitId: UUID) -> HabitProgressState? {
        return habitProgress[habitId]
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
    
    func loadHabitCategories() async {
        NSLog("[HabitManager] loadHabitCategories: loading habit categories from database")
        
        do {
            let categories = try await supabaseClient.getHabitCategories()
            NSLog("[HabitManager] loadHabitCategories: successfully fetched %d habit categories", categories.count)
            
            // Update both the new and legacy category arrays
            self.habitCategories = categories
            self.categories = categories.map { DiscoveryHabitCategory(from: $0) }
            
            NSLog("[HabitManager] loadHabitCategories: updated categories array with %d items", self.categories.count)
        } catch {
            NSLog("[HabitManager] loadHabitCategories: error %@ - habit categories not available", error.localizedDescription)
            // Don't update the arrays - keep them empty to indicate categories are not available
            self.habitCategories = []
            self.categories = []
        }
    }
    
    func loadTrendingHabits() async {
        // Prevent duplicate calls
        if isLoading {
            NSLog("[HabitManager] loadTrendingHabits: already loading, skipping")
            return
        }
        
        await loadTrendingHabitsInternal()
    }
    
    func loadTrendingHabitsByCategoryId(_ categoryId: UUID) async {
        NSLog("[HabitManager] loadTrendingHabitsByCategoryId: loading trending habits for category ID '%@'", categoryId.uuidString)
        isLoadingTrending = true
        defer { isLoadingTrending = false }
        
        do {
            let trendingHabits = try await supabaseClient.getTrendingHabitsByCategoryId(categoryId)
            NSLog("[HabitManager] loadTrendingHabitsByCategoryId: successfully fetched %d trending habits for category ID '%@'", trendingHabits.count, categoryId.uuidString)
            
            // Log each trending habit's details
            for (index, habit) in trendingHabits.enumerated() {
                NSLog("[HabitManager] loadTrendingHabitsByCategoryId: trending[%d] id=%@, name=%@, totalCaptures=%d, participants=%d", index, habit.id.uuidString, habit.name, habit.totalCaptures, habit.participants)
            }
            
            self.trendingHabits = trendingHabits
            
            // Load trending captures for these habits
            NSLog("[HabitManager] loadTrendingHabitsByCategoryId: loading trending captures")
            let trendingCaptures = try await supabaseClient.getTrendingCapturesForHabits()
            NSLog("[HabitManager] loadTrendingHabitsByCategoryId: successfully fetched %d trending captures", trendingCaptures.count)
            
            // Filter captures to only include those for the habits in this category
            let habitTemplateIds = Set(trendingHabits.map { $0.id })
            let filteredCaptures = trendingCaptures.filter { habitTemplateIds.contains($0.habitTemplateId) }
            NSLog("[HabitManager] loadTrendingHabitsByCategoryId: filtered to %d captures for category ID '%@'", filteredCaptures.count, categoryId.uuidString)
            
            self.trendingCaptures = filteredCaptures
            
            NSLog("[HabitManager] loadTrendingHabitsByCategoryId: completed successfully for category ID '%@'", categoryId.uuidString)
        } catch {
            NSLog("[HabitManager] loadTrendingHabitsByCategoryId: error %@", error.localizedDescription)
        }
    }
    
    private func loadTrendingHabitsInternal() async {
        NSLog("[HabitManager] loadTrendingHabitsInternal: starting")
        isLoadingTrending = true
        defer { isLoadingTrending = false }
        
        do {
            let trendingHabits = try await supabaseClient.getTrendingHabits()
            NSLog("[HabitManager] loadTrendingHabitsInternal: successfully fetched %d trending habits", trendingHabits.count)
            
            // Log each trending habit's details
            for (index, habit) in trendingHabits.enumerated() {
                NSLog("[HabitManager] loadTrendingHabitsInternal: trending[%d] id=%@, name=%@, totalCaptures=%d, participants=%d", index, habit.id.uuidString, habit.name, habit.totalCaptures, habit.participants)
            }
            
            self.trendingHabits = trendingHabits
            
            // Load trending captures for these habits
            NSLog("[HabitManager] loadTrendingHabitsInternal: loading trending captures")
            let trendingCaptures = try await supabaseClient.getTrendingCapturesForHabits()
            NSLog("[HabitManager] loadTrendingHabitsInternal: successfully fetched %d trending captures", trendingCaptures.count)
            
            // Log trending capture details
            for (index, capture) in trendingCaptures.enumerated() {
                NSLog("[HabitManager] loadTrendingHabitsInternal: trendingCapture[%d] id=%@, habitTemplateId=%@, likeCount=%d", index, capture.id.uuidString, capture.habitTemplateId.uuidString, capture.likeCount)
            }
            
            self.trendingCaptures = trendingCaptures
            
            NSLog("[HabitManager] loadTrendingHabitsInternal: completed successfully")
        } catch {
            NSLog("[HabitManager] loadTrendingHabitsInternal: error %@", error.localizedDescription)
        }
    }
    
    // Helper function to get trending captures for a specific habit template
    func getTrendingCaptures(for habitTemplateId: UUID) -> [TrendingCapture] {
        NSLog("[HabitManager] getTrendingCaptures: filtering for habitTemplateId %@", habitTemplateId.uuidString)
        NSLog("[HabitManager] getTrendingCaptures: total trendingCaptures count: %d", trendingCaptures.count)
        
        // Debug: log the types of objects in trendingCaptures and check for nil habitTemplateId
        for (index, item) in trendingCaptures.enumerated() {
            NSLog("[HabitManager] getTrendingCaptures: item %d type: %@", index, String(describing: type(of: item)))
            if let capture = item as? TrendingCapture {
                NSLog("[HabitManager] getTrendingCaptures: item %d is TrendingCapture with habitTemplateId: %@", index, capture.habitTemplateId.uuidString)
            } else {
                NSLog("[HabitManager] getTrendingCaptures: item %d is NOT TrendingCapture, value: %@", index, String(describing: item))
            }
        }
        
        let filtered = trendingCaptures.filter { $0.habitTemplateId == habitTemplateId }
        NSLog("[HabitManager] getTrendingCaptures: filtered count: %d", filtered.count)
        return filtered
    }
    
    // Helper function to get trending capture image URLs for a specific habit template
    func getTrendingCaptureUrls(for habitTemplateId: UUID) -> [String] {
        return getTrendingCaptures(for: habitTemplateId).compactMap { $0.imageUrl }
    }
    
    func loadPopularHabits() async {
        await loadPopularHabitsInternal()
    }
    
    private func loadPopularHabitsInternal() async {
        NSLog("[HabitManager] loadPopularHabitsInternal: starting")
        
        do {
            // Load real community stats
            let realCommunityStats = try await supabaseClient.getCommunityStats()
            NSLog("[HabitManager] loadPopularHabitsInternal: loaded real community stats - activeUsers: %d, totalHabits: %d, totalCaptures: %d", realCommunityStats.activeUsers, realCommunityStats.totalHabits, realCommunityStats.totalCaptures)
            
            // Load real popular habits from trending habits
            let trendingHabits = try await supabaseClient.getTrendingHabits()
            let popularHabits = trendingHabits.prefix(5).map { trendingHabit in
                PopularHabit(
                    name: trendingHabit.name,
                    category: trendingHabit.category,
                    participants: trendingHabit.participants,
                    totalStreak: trendingHabit.totalCaptures, // Using total captures as a proxy for total streak
                    description: trendingHabit.description ?? "",
                    image: nil,
                    captures: trendingHabit.captures ?? []
                )
            }
            
            self.popularHabits = Array(popularHabits)
            self.communityStats = realCommunityStats
            
            NSLog("[HabitManager] loadPopularHabitsInternal: completed successfully with %d real popular habits", popularHabits.count)
            
        } catch {
            NSLog("[HabitManager] loadPopularHabitsInternal: error %@", error.localizedDescription)
            self.errorMessage = error.localizedDescription
            self.popularHabits = []
            self.communityStats = CommunityStats()
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
    
    // MARK: - Helper Functions
    
    /// Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
