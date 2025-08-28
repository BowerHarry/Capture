import Foundation
import SwiftUI

// MARK: - Core Models

struct Habit: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String?
    var color: String?
    var category: String
    var target: Int
    var targetFrequency: String
    var targetCount: Int?
    var currentStreak: Int
    var longestStreak: Int
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    var userId: UUID
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case color
        case category
        case targetFrequency = "target_frequency"
        case targetCount = "target_count"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case userId = "user_id"
    }
    
    init(id: UUID = UUID(), name: String, icon: String? = nil, color: String? = nil, category: String, target: Int = 1, targetFrequency: String = "daily", targetCount: Int? = nil, currentStreak: Int = 0, longestStreak: Int = 0, isActive: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date(), userId: UUID) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.category = category
        self.target = target
        self.targetFrequency = targetFrequency
        self.targetCount = targetCount
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userId = userId
    }
    
    // Custom decoding to handle missing 'target' field and string UUIDs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        category = try container.decode(String.self, forKey: .category)
        targetFrequency = try container.decode(String.self, forKey: .targetFrequency)
        targetCount = try container.decodeIfPresent(Int.self, forKey: .targetCount)
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        longestStreak = try container.decodeIfPresent(Int.self, forKey: .longestStreak) ?? 0
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        // Handle userId as string and convert to UUID
        let userIdString = try container.decode(String.self, forKey: .userId)
        guard let userIdUUID = UUID(uuidString: userIdString) else {
            throw DecodingError.dataCorruptedError(forKey: .userId, in: container, debugDescription: "Invalid UUID string: \(userIdString)")
        }
        userId = userIdUUID
        
        // Use targetCount if available, otherwise default to 1
        target = targetCount ?? 1
    }
}

// MARK: - Habit Template Model (NEW)
struct HabitTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String?
    let category: String
    let targetFrequency: String
    let targetCount: Int?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case targetFrequency = "target_frequency"
        case targetCount = "target_count"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), name: String, description: String? = nil, category: String, targetFrequency: String, targetCount: Int? = nil, isActive: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.targetFrequency = targetFrequency
        self.targetCount = targetCount
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct AvailableHabit: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String?
    let color: String?
    let category: String
    let description: String?
    
    init(id: UUID = UUID(), name: String, icon: String? = nil, color: String? = nil, category: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.category = category
        self.description = description
    }
}

struct Capture: Identifiable, Codable {
    let id: UUID
    let habitId: UUID
    let userId: UUID
    let imageUrl: String?
    let note: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case imageUrl = "image_url"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), habitId: UUID, userId: UUID, imageUrl: String? = nil, note: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.habitId = habitId
        self.userId = userId
        self.imageUrl = imageUrl
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Computed property for backward compatibility with decoupled schema
    var userHabitId: UUID {
        return habitId
    }
}

// MARK: - User Models

struct User: Identifiable, Codable {
    let id: UUID
    let email: String
    let username: String
    let avatar: String?
    let bio: String?
    let createdAt: Date
    let updatedAt: Date
    let followersCount: Int?
    let followingCount: Int?
    let bestStreak: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case avatar
        case bio
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case bestStreak = "best_streak"
    }
    
    init(id: UUID, email: String, username: String, avatar: String? = nil, bio: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date(), followersCount: Int? = nil, followingCount: Int? = nil, bestStreak: Int? = nil) {
        self.id = id
        self.email = email
        self.username = username
        self.avatar = avatar
        self.bio = bio
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.bestStreak = bestStreak
    }
}

struct UserProfile: Identifiable, Codable {
    let id: UUID
    let email: String
    let username: String?
    let displayName: String?
    let avatarUrl: String?
    let bio: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case bio
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), email: String, username: String? = nil, displayName: String? = nil, avatarUrl: String? = nil, bio: String? = nil, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.email = email
        self.username = username
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.bio = bio
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Social Models

struct SocialPost: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let habitId: UUID?
    let captureId: UUID?
    let content: String
    let imageUrl: String?
    let likes: Int
    let comments: Int
    let createdAt: Date
    let updatedAt: Date
    
    init(id: UUID = UUID(), userId: UUID, habitId: UUID? = nil, captureId: UUID? = nil, content: String, imageUrl: String? = nil, likes: Int = 0, comments: Int = 0, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.habitId = habitId
        self.captureId = captureId
        self.content = content
        self.imageUrl = imageUrl
        self.likes = likes
        self.comments = comments
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Comment: Identifiable, Codable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let content: String
    let createdAt: Date
    let updatedAt: Date
    
    init(id: UUID = UUID(), postId: UUID, userId: UUID, content: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct Like: Identifiable, Codable {
    let id: UUID
    let postId: UUID
    let userId: UUID
    let createdAt: Date
    
    init(id: UUID = UUID(), postId: UUID, userId: UUID, createdAt: Date = Date()) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.createdAt = createdAt
    }
}

// MARK: - Follow Models

struct Follow: Identifiable, Codable {
    let id: UUID
    let followerId: UUID
    let followingId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
    
    init(id: UUID = UUID(), followerId: UUID, followingId: UUID, createdAt: Date = Date()) {
        self.id = id
        self.followerId = followerId
        self.followingId = followingId
        self.createdAt = createdAt
    }
}

// MARK: - Enums

enum HabitCategory: String, CaseIterable, Codable {
    case health = "Health"
    case fitness = "Fitness"
    case productivity = "Productivity"
    case learning = "Learning"
    case mindfulness = "Mindfulness"
    case creativity = "Creativity"
    case social = "Social"
    case finance = "Finance"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .health: return "❤️"
        case .fitness: return "💪"
        case .productivity: return "⚡"
        case .learning: return "📚"
        case .mindfulness: return "🧘"
        case .creativity: return "🎨"
        case .social: return "👥"
        case .finance: return "💰"
        case .other: return "⭐"
        }
    }
}

enum HabitColor: String, CaseIterable, Codable {
    case red = "red"
    case orange = "orange"
    case blue = "blue"
    case green = "green"
    case purple = "purple"
    case pink = "pink"
    case cyan = "cyan"
    case gray = "gray"
    
    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .pink: return .pink
        case .cyan: return .cyan
        case .gray: return .gray
        }
    }
}

enum TargetFrequency: String, CaseIterable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

// MARK: - API Models

struct APIResponse<T: Codable>: Codable {
    let success: Bool?
    let data: T?
    let error: String?
}

struct CreateHabitRequest: Codable {
    let name: String
    let description: String?
    let category: String
    let targetFrequency: String
}

struct CreateCaptureRequest: Codable {
    let habitId: String
    let caption: String?
    let isPublic: Bool
    let imageData: Data?
}

// MARK: - Capture Models

struct HabitCapture: Identifiable, Codable {
    let id: UUID
    let habitId: UUID?           // Keep for backward compatibility
    let habitTemplateId: UUID?   // NEW: For trending and discovery
    let userHabitId: UUID?       // NEW: For user-specific operations (user_habits.id)
    let userId: UUID
    let imageUrl: String?
    let caption: String?
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case habitTemplateId = "habit_template_id"  // NEW
        case userHabitId = "user_habit_id"          // NEW
        case userId = "user_id"
        case imageUrl = "image_url"
        case caption
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), habitId: UUID?, habitTemplateId: UUID?, userHabitId: UUID?, userId: UUID, imageUrl: String? = nil, caption: String? = nil, isPublic: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.habitId = habitId
        self.habitTemplateId = habitTemplateId
        self.userHabitId = userHabitId
        self.userId = userId
        self.imageUrl = imageUrl
        self.caption = caption
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Custom decoding to handle missing fields gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        habitId = try container.decodeIfPresent(UUID.self, forKey: .habitId)
        habitTemplateId = try container.decodeIfPresent(UUID.self, forKey: .habitTemplateId)
        userHabitId = try container.decodeIfPresent(UUID.self, forKey: .userHabitId)
        userId = try container.decode(UUID.self, forKey: .userId)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
    
    // Computed property for backward compatibility with decoupled schema
    var userHabitIdForStreak: UUID {
        // In the new schema, we use user_habit_id instead of habit_id
        // For backward compatibility, we'll try userHabitId first, then habitId
        if let userHabitId = self.userHabitId {
            return userHabitId
        }
        if let habitId = habitId {
            return habitId
        }
        // If both are nil, we need to get it from user_habits table using habit_template_id
        // For now, return a default UUID to prevent crashes, but this indicates a data issue
        NSLog("[HabitCapture] userHabitIdForStreak: WARNING - both userHabitId and habitId are nil, this indicates a database migration issue")
        return UUID() // This will cause streak calculation to fail, but prevents crashes
    }
}

// MARK: - View Models

struct HabitStats {
    let totalHabits: Int
    let activeHabits: Int
    let totalCaptures: Int
    let currentStreak: Int
    let longestStreak: Int
    let completionRate: Double
    
    init(totalHabits: Int = 0, activeHabits: Int = 0, totalCaptures: Int = 0, currentStreak: Int = 0, longestStreak: Int = 0, completionRate: Double = 0.0) {
        self.totalHabits = totalHabits
        self.activeHabits = activeHabits
        self.totalCaptures = totalCaptures
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.completionRate = completionRate
    }
}

struct SocialFeedItem: Identifiable {
    let id: UUID
    let post: SocialPost
    let user: User
    let habit: Habit?
    let capture: Capture?
    let isLiked: Bool
    let isFollowing: Bool
    
    init(id: UUID = UUID(), post: SocialPost, user: User, habit: Habit? = nil, capture: Capture? = nil, isLiked: Bool = false, isFollowing: Bool = false) {
        self.id = id
        self.post = post
        self.user = user
        self.habit = habit
        self.capture = capture
        self.isLiked = isLiked
        self.isFollowing = isFollowing
    }
}

// MARK: - Discovery Models

struct PopularHabit: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: String
    let participants: Int
    let totalStreak: Int
    let description: String
    let image: String?
    let captures: [String]? // Array of photo URLs from users
    
    init(id: UUID = UUID(), name: String, category: String, participants: Int, totalStreak: Int, description: String, image: String? = nil, captures: [String]? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.participants = participants
        self.totalStreak = totalStreak
        self.description = description
        self.image = image
        self.captures = captures
    }
}

struct TrendingHabit: Identifiable, Codable {
    let id: UUID  // This is now the habit_template_id
    let name: String
    let category: String
    let categoryColor: String? // New field from the category system
    let participants: Int // Unique users who captured this habit in the past week
    let avgStreak: Double // Average current streak for participants
    let description: String // AI-generated description
    let captures: [String]? // Array of photo URLs from the past week
    let totalCaptures: Int // Total captures in the past week

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case categoryColor = "category_color"
        case participants
        case avgStreak = "avg_streak"
        case description
        case captures
        case totalCaptures = "total_captures"
    }
    
    init(id: UUID, name: String, category: String, categoryColor: String? = nil, participants: Int, avgStreak: Double, description: String, captures: [String]? = nil, totalCaptures: Int) {
        self.id = id
        self.name = name
        self.category = category
        self.categoryColor = categoryColor
        self.participants = participants
        self.avgStreak = avgStreak
        self.description = description
        self.captures = captures
        self.totalCaptures = totalCaptures
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        categoryColor = try container.decodeIfPresent(String.self, forKey: .categoryColor)
        participants = try container.decode(Int.self, forKey: .participants)
        avgStreak = try container.decode(Double.self, forKey: .avgStreak)
        description = try container.decode(String.self, forKey: .description)
        captures = try container.decodeIfPresent([String].self, forKey: .captures)
        totalCaptures = try container.decode(Int.self, forKey: .totalCaptures)
    }
}

struct CommunityStats: Codable {
    let activeUsers: Int
    let totalHabits: Int
    let totalCaptures: Int
    
    enum CodingKeys: String, CodingKey {
        case activeUsers = "active_users"
        case totalHabits = "total_habits"
        case totalCaptures = "total_captures"
    }
    
    init(activeUsers: Int = 0, totalHabits: Int = 0, totalCaptures: Int = 0) {
        self.activeUsers = activeUsers
        self.totalHabits = totalHabits
        self.totalCaptures = totalCaptures
    }
}

// MARK: - Database Habit Categories

struct DatabaseHabitCategory: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String?
    let color: String
    let icon: String?
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case color
        case icon
        case sortOrder = "sort_order"
    }
}

// MARK: - Discovery Habit Category (for backward compatibility)
struct DiscoveryHabitCategory: Identifiable, Codable {
    let id: UUID
    let name: String
    let color: String
    let description: String?
    let icon: String?
    let sortOrder: Int
    
    init(from habitCategory: DatabaseHabitCategory) {
        self.id = habitCategory.id
        self.name = habitCategory.name
        self.color = habitCategory.color
        self.description = habitCategory.description
        self.icon = habitCategory.icon
        self.sortOrder = habitCategory.sortOrder
    }
    
    init(id: UUID, name: String, color: String, description: String? = nil, icon: String? = nil, sortOrder: Int = 0) {
        self.id = id
        self.name = name
        self.color = color
        self.description = description
        self.icon = icon
        self.sortOrder = sortOrder
    }
}

struct CaptureLike: Identifiable, Codable {
    let id: UUID
    let captureId: UUID
    let userId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case captureId = "capture_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

struct CaptureLikeCount: Identifiable, Codable {
    let captureId: UUID
    let habitId: UUID
    let captureUserId: UUID
    let imageUrl: String?
    let caption: String?
    let captureCreatedAt: Date
    let likeCount: Int
    let likedByUserIds: [UUID]
    
    var id: UUID { captureId }
    
    enum CodingKeys: String, CodingKey {
        case captureId = "capture_id"
        case habitId = "habit_id"
        case captureUserId = "capture_user_id"
        case imageUrl = "image_url"
        case caption
        case captureCreatedAt = "capture_created_at"
        case likeCount
        case likedByUserIds
    }
}

struct SocialFeedPost: Identifiable, Codable {
    let captureId: UUID
    let habitId: UUID?           // Keep for backward compatibility
    let habitTemplateId: UUID?   // NEW: For trending and discovery
    let captureUserId: UUID
    let imageUrl: String?
    let caption: String?
    let isPublic: Bool
    let captureCreatedAt: Date
    let habitName: String
    let habitCategory: String
    let userDisplayName: String?
    let userAvatarUrl: String?
    let likeCount: Int
    let likedByUserIds: [UUID]
    let isLikedByCurrentUser: Bool
    
    var id: UUID { captureId }
    
    enum CodingKeys: String, CodingKey {
        case captureId = "capture_id"
        case habitId = "habit_id"
        case habitTemplateId = "habit_template_id"  // NEW
        case captureUserId = "capture_user_id"
        case imageUrl = "image_url"
        case caption
        case isPublic = "is_public"
        case captureCreatedAt = "capture_created_at"
        case habitName = "habit_name"
        case habitCategory = "habit_category"
        case userDisplayName = "user_display_name"
        case userAvatarUrl = "user_avatar_url"
        case likeCount
        case likedByUserIds
        case isLikedByCurrentUser
    }
}

// MARK: - New Decoupled Schema Models

struct UserHabit: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let habitTemplateId: UUID
    let currentStreak: Int
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case habitTemplateId = "habit_template_id"
        case currentStreak = "current_streak"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), userId: UUID, habitTemplateId: UUID, currentStreak: Int = 0, isActive: Bool = true, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.habitTemplateId = habitTemplateId
        self.currentStreak = currentStreak
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct TrendingCapture: Identifiable, Codable {
    let id: UUID
    let captureId: UUID
    let habitTemplateId: UUID    // Changed from habitId
    let userId: UUID
    let imageUrl: String?
    let caption: String?
    let isPublic: Bool
    let captureCreatedAt: Date
    let habitName: String
    let habitCategory: String
    let habitCategoryId: UUID?   // New field from the category system
    let userDisplayName: String?
    let userAvatarUrl: String?
    let likeCount: Int
    let totalCaptures: Int
    let trendScore: Double

    enum CodingKeys: String, CodingKey {
        case id
        case captureId = "capture_id"
        case habitTemplateId = "habit_template_id"  // Changed
        case userId = "user_id"
        case imageUrl = "image_url"
        case caption
        case isPublic = "is_public"
        case captureCreatedAt = "capture_created_at"
        case habitName = "habit_name"
        case habitCategory = "habit_category"
        case habitCategoryId = "habit_category_id"  // New field
        case userDisplayName = "user_display_name"
        case userAvatarUrl = "user_avatar_url"
        case likeCount = "like_count"
        case totalCaptures = "total_captures"
        case trendScore = "trend_score"
    }
    
    init(id: UUID, captureId: UUID, habitTemplateId: UUID, userId: UUID, imageUrl: String?, caption: String?, isPublic: Bool, captureCreatedAt: Date, habitName: String, habitCategory: String, habitCategoryId: UUID?, userDisplayName: String?, userAvatarUrl: String?, likeCount: Int, totalCaptures: Int, trendScore: Double) {
        self.id = id
        self.captureId = captureId
        self.habitTemplateId = habitTemplateId
        self.userId = userId
        self.imageUrl = imageUrl
        self.caption = caption
        self.isPublic = isPublic
        self.captureCreatedAt = captureCreatedAt
        self.habitName = habitName
        self.habitCategory = habitCategory
        self.habitCategoryId = habitCategoryId
        self.userDisplayName = userDisplayName
        self.userAvatarUrl = userAvatarUrl
        self.likeCount = likeCount
        self.totalCaptures = totalCaptures
        self.trendScore = trendScore
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        captureId = try container.decode(UUID.self, forKey: .captureId)
        habitTemplateId = try container.decode(UUID.self, forKey: .habitTemplateId)
        userId = try container.decode(UUID.self, forKey: .userId)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        captureCreatedAt = try container.decode(Date.self, forKey: .captureCreatedAt)
        habitName = try container.decode(String.self, forKey: .habitName)
        habitCategory = try container.decode(String.self, forKey: .habitCategory)
        habitCategoryId = try container.decodeIfPresent(UUID.self, forKey: .habitCategoryId)
        userDisplayName = try container.decodeIfPresent(String.self, forKey: .userDisplayName)
        userAvatarUrl = try container.decodeIfPresent(String.self, forKey: .userAvatarUrl)
        likeCount = try container.decode(Int.self, forKey: .likeCount)
        totalCaptures = try container.decode(Int.self, forKey: .totalCaptures)
        trendScore = try container.decode(Double.self, forKey: .trendScore)
    }
}

// MARK: - Social Feed Models

struct CaptureReaction: Identifiable, Codable {
    let id: UUID
    let captureId: UUID
    let userId: UUID
    let reactionType: String // "fire", "heart", etc.
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case captureId = "capture_id"
        case userId = "user_id"
        case reactionType = "reaction_type"
        case createdAt = "created_at"
    }
    
    init(id: UUID = UUID(), captureId: UUID, userId: UUID, reactionType: String = "fire", createdAt: Date = Date()) {
        self.id = id
        self.captureId = captureId
        self.userId = userId
        self.reactionType = reactionType
        self.createdAt = createdAt
    }
}

struct CaptureComment: Identifiable, Codable {
    let id: UUID
    let captureId: UUID
    let userId: UUID
    let content: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case captureId = "capture_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), captureId: UUID, userId: UUID, content: String, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.captureId = captureId
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct SocialFeedGroup: Identifiable, Codable {
    let id: String // Composite key: "user_id-habit_template_id"
    let userId: UUID
    let habitTemplateId: UUID
    let habitName: String
    let habitCategory: String
    let habitCategoryColor: String?
    let userDisplayName: String?
    let userAvatarUrl: String?
    let userUsername: String?
    let currentStreak: Int
    let lastCaptureId: UUID
    let lastCaptureImageUrl: String?
    let lastCaptureCreatedAt: Date
    let totalCaptures: Int
    var reactionCount: Int
    let commentCount: Int
    var isLikedByCurrentUser: Bool
    var recentCaptures: [SocialFeedCapture]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case habitTemplateId = "habit_template_id"
        case habitName = "habit_name"
        case habitCategory = "habit_category"
        case habitCategoryColor = "habit_category_color"
        case userDisplayName = "user_display_name"
        case userAvatarUrl = "user_avatar_url"
        case userUsername = "user_username"
        case currentStreak = "current_streak"
        case lastCaptureId = "last_capture_id"
        case lastCaptureImageUrl = "last_capture_image_url"
        case lastCaptureCreatedAt = "last_capture_created_at"
        case totalCaptures = "total_captures"
        case reactionCount = "reaction_count"
        case commentCount = "comment_count"
        case isLikedByCurrentUser = "is_liked_by_current_user"
        case recentCaptures = "recent_captures"
    }
    
    init(id: String, userId: UUID, habitTemplateId: UUID, habitName: String, habitCategory: String, habitCategoryColor: String?, userDisplayName: String?, userAvatarUrl: String?, userUsername: String?, currentStreak: Int, lastCaptureId: UUID, lastCaptureImageUrl: String?, lastCaptureCreatedAt: Date, totalCaptures: Int, reactionCount: Int, commentCount: Int, isLikedByCurrentUser: Bool, recentCaptures: [SocialFeedCapture]?) {
        self.id = id
        self.userId = userId
        self.habitTemplateId = habitTemplateId
        self.habitName = habitName
        self.habitCategory = habitCategory
        self.habitCategoryColor = habitCategoryColor
        self.userDisplayName = userDisplayName
        self.userAvatarUrl = userAvatarUrl
        self.userUsername = userUsername
        self.currentStreak = currentStreak
        self.lastCaptureId = lastCaptureId
        self.lastCaptureImageUrl = lastCaptureImageUrl
        self.lastCaptureCreatedAt = lastCaptureCreatedAt
        self.totalCaptures = totalCaptures
        self.reactionCount = reactionCount
        self.commentCount = commentCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.recentCaptures = recentCaptures
    }
}

struct SocialFeedCapture: Identifiable, Codable {
    let id: UUID
    let imageUrl: String?
    let caption: String?
    let createdAt: Date
    var reactionCount: Int
    let commentCount: Int
    var isLikedByCurrentUser: Bool
    let reactionUsers: [SocialFeedReactionUser]
    
    enum CodingKeys: String, CodingKey {
        case id
        case imageUrl = "image_url"
        case caption
        case createdAt = "created_at"
        case reactionCount = "reaction_count"
        case commentCount = "comment_count"
        case isLikedByCurrentUser = "is_liked_by_current_user"
        case reactionUsers = "reaction_users"
    }
    
    init(id: UUID, imageUrl: String?, caption: String?, createdAt: Date, reactionCount: Int, commentCount: Int, isLikedByCurrentUser: Bool, reactionUsers: [SocialFeedReactionUser]) {
        self.id = id
        self.imageUrl = imageUrl
        self.caption = caption
        self.createdAt = createdAt
        self.reactionCount = reactionCount
        self.commentCount = commentCount
        self.isLikedByCurrentUser = isLikedByCurrentUser
        self.reactionUsers = reactionUsers
    }
}

struct SocialFeedReactionUser: Identifiable, Codable {
    let id: UUID
    let displayName: String?
    let avatarUrl: String?
    let username: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case username
    }
    
    init(id: UUID, displayName: String?, avatarUrl: String?, username: String?) {
        self.id = id
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.username = username
    }
}
