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
    let habitId: UUID
    let userId: UUID
    let imageUrl: String?
    let caption: String?
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case habitId = "habit_id"
        case userId = "user_id"
        case imageUrl = "image_url"
        case caption
        case isPublic = "is_public"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID = UUID(), habitId: UUID, userId: UUID, imageUrl: String? = nil, caption: String? = nil, isPublic: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.habitId = habitId
        self.userId = userId
        self.imageUrl = imageUrl
        self.caption = caption
        self.isPublic = isPublic
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

struct CommunityStats: Codable {
    let activeUsers: Int
    let totalHabits: Int
    let totalCaptures: Int
    
    init(activeUsers: Int = 0, totalHabits: Int = 0, totalCaptures: Int = 0) {
        self.activeUsers = activeUsers
        self.totalHabits = totalHabits
        self.totalCaptures = totalCaptures
    }
}

struct DiscoveryHabitCategory: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
    let color: String
    
    init(name: String, count: Int = 0, color: String) {
        self.name = name
        self.count = count
        self.color = color
    }
}
