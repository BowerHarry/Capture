import SwiftUI

// MARK: - Progress Grid Data Protocol
@MainActor
protocol ProgressGridDataSource {
    var title: String { get }
    var showStats: Bool { get }
    var dailyCompletionData: [Date: Int] { get }
    var maxCompletionsPerDay: Int { get }
    var streakValue: Int { get }
    var captureCount: Int { get }
    var habitColor: Color { get }
}

// MARK: - Reusable Progress Grid View
@MainActor
struct ProgressGridView: View {
    let dataSource: ProgressGridDataSource
    let weeks: Int = 26 // ~6 months
    let spacing: CGFloat = 3
    @EnvironmentObject var habitManager: HabitManager
    @State private var refreshTrigger = false
    
    private var categoriesLoaded: Bool {
        !habitManager.habitCategories.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dataSource.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            
            if dataSource.showStats {
                HStack(spacing: 4) {
                    Image(systemName: "flame").foregroundColor(.orange).font(.system(size: 10))
                    Text("\(dataSource.streakValue) day streak").font(.system(size: 12)).foregroundColor(.secondary)
                }
            }
            
            if categoriesLoaded {
                ZStack(alignment: .topLeading) {
                    GeometryReader { proxy in
                        let totalWidth = proxy.size.width
                        let cellSize = (totalWidth - CGFloat(weeks - 1) * spacing) / CGFloat(weeks)
                        let gridHeight = cellSize * 7 + spacing * 6
                        
                        ProgressGridContentView(
                            weeks: weeks,
                            spacing: spacing,
                            cellSize: cellSize,
                            dataSource: dataSource
                        )
                        .frame(width: totalWidth, height: gridHeight, alignment: .topLeading)
                    }
                }
                .frame(height: 80)
            } else {
                // Show loading state while categories are being loaded
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading progress grid...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity)
            }
            
            if dataSource.showStats {
                Text("\(dataSource.captureCount) captures in the last 6 months")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
        .onChange(of: habitManager.habitCategories.count) { _, _ in
            refreshTrigger.toggle()
        }
        .onAppear {
            if habitManager.habitCategories.isEmpty {
                Task {
                    await habitManager.loadHabitCategories()
                }
            }
        }
    }
}

// MARK: - Progress Grid Content View
@MainActor
struct ProgressGridContentView: View {
    let weeks: Int
    let spacing: CGFloat
    let cellSize: CGFloat
    let dataSource: ProgressGridDataSource
    
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<7, id: \.self) { dayOfWeek in
                HStack(spacing: spacing) {
                    ForEach(0..<weeks, id: \.self) { week in
                        let date = getDate(for: week, dayOfWeek: dayOfWeek)
                        let completions = dataSource.dailyCompletionData[date] ?? 0
                        let intensity = dataSource.maxCompletionsPerDay > 0 ? Double(completions) / Double(dataSource.maxCompletionsPerDay) : 0
                        let isToday = Calendar.current.isDateInToday(date)
                        let isFuture = date > Calendar.current.startOfDay(for: Date())
                        let hasCaptures = completions > 0
                        
                        if isFuture {
                            // Hide future days - show transparent rectangle
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: cellSize, height: cellSize)
                        } else {
                            Rectangle()
                                .fill(getColorForIntensity(intensity, hasCaptures: hasCaptures))
                                .frame(width: cellSize, height: cellSize)
                                .cornerRadius(2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(isToday ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private func getDate(for week: Int, dayOfWeek: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Find the Monday of the current week
        let weekday = calendar.component(.weekday, from: today) // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let daysToMonday = weekday == 1 ? 6 : weekday - 2 // Convert to days to Monday
        let mondayOfCurrentWeek = calendar.date(byAdding: .day, value: -daysToMonday, to: today) ?? today
        
        // Calculate start date: go back (weeks - 1) weeks from Monday of current week
        let startDate = calendar.date(byAdding: .day, value: -(weeks - 1) * 7, to: mondayOfCurrentWeek) ?? today
        
        // Calculate the date for this grid position
        // dayOfWeek: 0 = Monday, 1 = Tuesday, ..., 6 = Sunday
        let cellDate = calendar.date(byAdding: .day, value: week * 7 + dayOfWeek, to: startDate) ?? today
        return calendar.startOfDay(for: cellDate)
    }
    
    private func getColorForIntensity(_ intensity: Double, hasCaptures: Bool) -> Color {
        if !hasCaptures {
            return Color(.systemGray6)
        } else {
            // Use habit color with intensity-based opacity
            let baseColor = dataSource.habitColor
            if intensity <= 0.25 {
                return baseColor.opacity(0.3)
            } else if intensity <= 0.5 {
                return baseColor.opacity(0.6)
            } else if intensity <= 0.75 {
                return baseColor.opacity(0.8)
            } else {
                return baseColor
            }
        }
    }
}

// MARK: - Habit Progress Grid Data Source
@MainActor
struct HabitProgressGridDataSource: ProgressGridDataSource {
    let habit: Habit
    let habitManager: HabitManager
    
    var title: String {
        habit.name
    }
    
    var showStats: Bool {
        true
    }
    
    var dailyCompletionData: [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        let today = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        
        for capture in habitManager.captures {
            if capture.userHabitId == habit.id && capture.createdAt >= sixMonthsAgo {
                let dayStart = calendar.startOfDay(for: capture.createdAt)
                data[dayStart, default: 0] += 1
            }
        }
        
        return data
    }
    
    var maxCompletionsPerDay: Int {
        dailyCompletionData.values.max() ?? 1
    }
    
    var streakValue: Int {
        habitManager.progress(for: habit.id)?.currentStreak ?? 0
    }
    
    var captureCount: Int {
        habitManager.captures.filter { $0.userHabitId == habit.id }.count
    }
    
    var habitColor: Color {
        getHabitColor(habit)
    }
    
    private func getHabitColor(_ habit: Habit) -> Color {
        // Try to find the category in the database first
        if let habitCategory = habitManager.habitCategories.first(where: { $0.name.lowercased() == habit.category.lowercased() }) {
            return CaptureTheme.categoryColor(from: habitCategory.color)
        }
        
        // Default to gray if category not found
        return .gray
    }
}

// MARK: - User Progress Grid Data Source
@MainActor
struct UserProgressGridDataSource: ProgressGridDataSource {
    let userCaptures: [HabitCapture]
    
    var title: String {
        "6 Month Progress"
    }
    
    var showStats: Bool {
        false
    }
    
    var dailyCompletionData: [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current
        let today = Date()
        let sixMonthsAgo = calendar.date(byAdding: .month, value: -6, to: today) ?? today
        
        for capture in userCaptures {
            if capture.createdAt >= sixMonthsAgo {
                let dayStart = calendar.startOfDay(for: capture.createdAt)
                data[dayStart, default: 0] += 1
            }
        }
        
        return data
    }
    
    var maxCompletionsPerDay: Int {
        dailyCompletionData.values.max() ?? 1
    }
    
    var streakValue: Int {
        0 // Not applicable for user progress
    }
    
    var captureCount: Int {
        userCaptures.count
    }
    
    var habitColor: Color {
        .green
    }
}
