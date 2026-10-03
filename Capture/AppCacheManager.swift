import Foundation
import SwiftUI

// MARK: - App Cache Manager

@MainActor
class AppCacheManager: ObservableObject {
    static let shared = AppCacheManager()
    
    // MARK: - Cache Keys
    private enum CacheKeys {
        static let habits = "cached_habits"
        static let captures = "cached_captures"
        static let habitCategories = "cached_habit_categories"
        static let trendingHabits = "cached_trending_habits"
        static let communityStats = "cached_community_stats"
        static let socialFeedGroups = "cached_social_feed_groups"
        static let userProfile = "cached_user_profile"
        static let lastCacheUpdate = "last_cache_update"
        static let cacheVersion = "cache_version"
    }
    
    // MARK: - Cache Durations
    private enum CacheDurations {
        static let habits: TimeInterval = 3600 // 1 hour
        static let captures: TimeInterval = 1800 // 30 minutes
        static let habitCategories: TimeInterval = 86400 // 24 hours
        static let trendingHabits: TimeInterval = 1800 // 30 minutes
        static let communityStats: TimeInterval = 3600 // 1 hour
        static let socialFeedGroups: TimeInterval = 300 // 5 minutes
        static let userProfile: TimeInterval = 3600 // 1 hour
    }
    
    // MARK: - Properties
    @Published var isInitializing = true
    @Published var cacheStatus: CacheStatus = .unknown
    
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // MARK: - Cache Status
    enum CacheStatus: Equatable {
        case unknown
        case loading
        case ready
        case stale
        case error(String)
        
        static func == (lhs: CacheStatus, rhs: CacheStatus) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown), (.loading, .loading), (.ready, .ready), (.stale, .stale):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    private init() {
        // Create cache directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("AppCache")
        
        do {
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            Log.error("❌ Failed to create cache directory: \(error)")
        }
        
        // Initialize cache
        Task {
            await initializeCache()
        }
    }
    
    // MARK: - Cache Initialization
    private func initializeCache() async {
        isInitializing = true
        cacheStatus = .loading
        
        // Check if cache is valid
        if await isCacheValid() {
            cacheStatus = .ready
        } else {
            cacheStatus = .stale
            Log.error("⚠️ Cache is stale, will refresh on next load")
        }
        
        isInitializing = false
    }
    
    // MARK: - Cache Validation
    private func isCacheValid() async -> Bool {
        guard let lastUpdate = userDefaults.object(forKey: CacheKeys.lastCacheUpdate) as? Date else {
            return false
        }
        
        let cacheAge = Date().timeIntervalSince(lastUpdate)
        let maxAge: TimeInterval = 3600 // 1 hour max cache age
        
        return cacheAge < maxAge
    }
    
    // MARK: - Habits Cache
    func cacheHabits(_ habits: [Habit]) {
        do {
            let data = try JSONEncoder().encode(habits)
            userDefaults.set(data, forKey: CacheKeys.habits)
            userDefaults.set(Date(), forKey: "\(CacheKeys.habits)_timestamp")
        } catch {
            Log.error("❌ Failed to cache habits: \(error)")
        }
    }
    
    func getCachedHabits() -> [Habit]? {
        guard let data = userDefaults.data(forKey: CacheKeys.habits),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.habits)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.habits else {
            Log.error("⚠️ Habits cache expired")
            return nil
        }
        
        do {
            let habits = try JSONDecoder().decode([Habit].self, from: data)
            return habits
        } catch {
            Log.error("❌ Failed to decode cached habits: \(error)")
            return nil
        }
    }
    
    // MARK: - Captures Cache
    func cacheCaptures(_ captures: [HabitCapture]) {
        do {
            let data = try JSONEncoder().encode(captures)
            userDefaults.set(data, forKey: CacheKeys.captures)
            userDefaults.set(Date(), forKey: "\(CacheKeys.captures)_timestamp")
        } catch {
            Log.error("❌ Failed to cache captures: \(error)")
        }
    }
    
    func getCachedCaptures() -> [HabitCapture]? {
        guard let data = userDefaults.data(forKey: CacheKeys.captures),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.captures)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.captures else {
            Log.error("⚠️ Captures cache expired")
            return nil
        }
        
        do {
            let captures = try JSONDecoder().decode([HabitCapture].self, from: data)
            return captures
        } catch {
            Log.error("❌ Failed to decode cached captures: \(error)")
            return nil
        }
    }
    
    // MARK: - Social Feed Cache
    func cacheSocialFeedGroups(_ groups: [SocialFeedGroup]) {
        do {
            let data = try JSONEncoder().encode(groups)
            userDefaults.set(data, forKey: CacheKeys.socialFeedGroups)
            userDefaults.set(Date(), forKey: "\(CacheKeys.socialFeedGroups)_timestamp")
        } catch {
            Log.error("❌ Failed to cache social feed groups: \(error)")
        }
    }
    
    func getCachedSocialFeedGroups() -> [SocialFeedGroup]? {
        guard let data = userDefaults.data(forKey: CacheKeys.socialFeedGroups),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.socialFeedGroups)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.socialFeedGroups else {
            Log.error("⚠️ Social feed cache expired")
            return nil
        }
        
        do {
            let groups = try JSONDecoder().decode([SocialFeedGroup].self, from: data)
            return groups
        } catch {
            Log.error("❌ Failed to decode cached social feed groups: \(error)")
            return nil
        }
    }
    
    // MARK: - Habit Categories Cache
    func cacheHabitCategories(_ categories: [DatabaseHabitCategory]) {
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: CacheKeys.habitCategories)
            userDefaults.set(Date(), forKey: "\(CacheKeys.habitCategories)_timestamp")
        } catch {
            Log.error("❌ Failed to cache habit categories: \(error)")
        }
    }
    
    func getCachedHabitCategories() -> [DatabaseHabitCategory]? {
        guard let data = userDefaults.data(forKey: CacheKeys.habitCategories),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.habitCategories)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.habitCategories else {
            Log.error("⚠️ Habit categories cache expired")
            return nil
        }
        
        do {
            let categories = try JSONDecoder().decode([DatabaseHabitCategory].self, from: data)
            return categories
        } catch {
            Log.error("❌ Failed to decode cached habit categories: \(error)")
            return nil
        }
    }
    
    // MARK: - Trending Habits Cache
    
    func getCachedTrendingHabits() -> [TrendingHabit]? {
        guard let data = userDefaults.data(forKey: CacheKeys.trendingHabits),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.trendingHabits)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.trendingHabits else {
            Log.error("⚠️ Trending habits cache expired")
            return nil
        }
        
        do {
            let habits = try JSONDecoder().decode([TrendingHabit].self, from: data)
            return habits
        } catch {
            Log.error("❌ Failed to decode cached trending habits: \(error)")
            return nil
        }
    }
    
    
    
    // MARK: - Cache Management
    func clearAllCaches() {
        let keys = [
            CacheKeys.habits,
            CacheKeys.captures,
            CacheKeys.habitCategories,
            CacheKeys.trendingHabits,
            CacheKeys.communityStats,
            CacheKeys.socialFeedGroups,
            CacheKeys.userProfile,
            CacheKeys.lastCacheUpdate
        ]
        
        for key in keys {
            userDefaults.removeObject(forKey: key)
            userDefaults.removeObject(forKey: "\(key)_timestamp")
        }
        
        // Clear image cache
        ImagePreloader.shared.clearCache()
        
    }
}
