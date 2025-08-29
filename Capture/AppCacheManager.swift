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
            print("❌ Failed to create cache directory: \(error)")
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
            print("✅ Cache is valid and ready")
        } else {
            cacheStatus = .stale
            print("⚠️ Cache is stale, will refresh on next load")
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
            print("💾 Cached \(habits.count) habits")
        } catch {
            print("❌ Failed to cache habits: \(error)")
        }
    }
    
    func getCachedHabits() -> [Habit]? {
        guard let data = userDefaults.data(forKey: CacheKeys.habits),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.habits)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.habits else {
            print("⚠️ Habits cache expired")
            return nil
        }
        
        do {
            let habits = try JSONDecoder().decode([Habit].self, from: data)
            print("📱 Retrieved \(habits.count) habits from cache")
            return habits
        } catch {
            print("❌ Failed to decode cached habits: \(error)")
            return nil
        }
    }
    
    // MARK: - Captures Cache
    func cacheCaptures(_ captures: [HabitCapture]) {
        do {
            let data = try JSONEncoder().encode(captures)
            userDefaults.set(data, forKey: CacheKeys.captures)
            userDefaults.set(Date(), forKey: "\(CacheKeys.captures)_timestamp")
            print("💾 Cached \(captures.count) captures")
        } catch {
            print("❌ Failed to cache captures: \(error)")
        }
    }
    
    func getCachedCaptures() -> [HabitCapture]? {
        guard let data = userDefaults.data(forKey: CacheKeys.captures),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.captures)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.captures else {
            print("⚠️ Captures cache expired")
            return nil
        }
        
        do {
            let captures = try JSONDecoder().decode([HabitCapture].self, from: data)
            print("📱 Retrieved \(captures.count) captures from cache")
            return captures
        } catch {
            print("❌ Failed to decode cached captures: \(error)")
            return nil
        }
    }
    
    // MARK: - Social Feed Cache
    func cacheSocialFeedGroups(_ groups: [SocialFeedGroup]) {
        do {
            let data = try JSONEncoder().encode(groups)
            userDefaults.set(data, forKey: CacheKeys.socialFeedGroups)
            userDefaults.set(Date(), forKey: "\(CacheKeys.socialFeedGroups)_timestamp")
            print("💾 Cached \(groups.count) social feed groups")
        } catch {
            print("❌ Failed to cache social feed groups: \(error)")
        }
    }
    
    func getCachedSocialFeedGroups() -> [SocialFeedGroup]? {
        guard let data = userDefaults.data(forKey: CacheKeys.socialFeedGroups),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.socialFeedGroups)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.socialFeedGroups else {
            print("⚠️ Social feed cache expired")
            return nil
        }
        
        do {
            let groups = try JSONDecoder().decode([SocialFeedGroup].self, from: data)
            print("📱 Retrieved \(groups.count) social feed groups from cache")
            return groups
        } catch {
            print("❌ Failed to decode cached social feed groups: \(error)")
            return nil
        }
    }
    
    // MARK: - Habit Categories Cache
    func cacheHabitCategories(_ categories: [DatabaseHabitCategory]) {
        do {
            let data = try JSONEncoder().encode(categories)
            userDefaults.set(data, forKey: CacheKeys.habitCategories)
            userDefaults.set(Date(), forKey: "\(CacheKeys.habitCategories)_timestamp")
            print("💾 Cached \(categories.count) habit categories")
        } catch {
            print("❌ Failed to cache habit categories: \(error)")
        }
    }
    
    func getCachedHabitCategories() -> [DatabaseHabitCategory]? {
        guard let data = userDefaults.data(forKey: CacheKeys.habitCategories),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.habitCategories)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.habitCategories else {
            print("⚠️ Habit categories cache expired")
            return nil
        }
        
        do {
            let categories = try JSONDecoder().decode([DatabaseHabitCategory].self, from: data)
            print("📱 Retrieved \(categories.count) habit categories from cache")
            return categories
        } catch {
            print("❌ Failed to decode cached habit categories: \(error)")
            return nil
        }
    }
    
    // MARK: - Trending Habits Cache
    func cacheTrendingHabits(_ habits: [TrendingHabit]) {
        do {
            let data = try JSONEncoder().encode(habits)
            userDefaults.set(data, forKey: CacheKeys.trendingHabits)
            userDefaults.set(Date(), forKey: "\(CacheKeys.trendingHabits)_timestamp")
            print("💾 Cached \(habits.count) trending habits")
        } catch {
            print("❌ Failed to cache trending habits: \(error)")
        }
    }
    
    func getCachedTrendingHabits() -> [TrendingHabit]? {
        guard let data = userDefaults.data(forKey: CacheKeys.trendingHabits),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.trendingHabits)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.trendingHabits else {
            print("⚠️ Trending habits cache expired")
            return nil
        }
        
        do {
            let habits = try JSONDecoder().decode([TrendingHabit].self, from: data)
            print("📱 Retrieved \(habits.count) trending habits from cache")
            return habits
        } catch {
            print("❌ Failed to decode cached trending habits: \(error)")
            return nil
        }
    }
    
    // MARK: - Community Stats Cache
    func cacheCommunityStats(_ stats: CommunityStats) {
        do {
            let data = try JSONEncoder().encode(stats)
            userDefaults.set(data, forKey: CacheKeys.communityStats)
            userDefaults.set(Date(), forKey: "\(CacheKeys.communityStats)_timestamp")
            print("💾 Cached community stats")
        } catch {
            print("❌ Failed to cache community stats: \(error)")
        }
    }
    
    func getCachedCommunityStats() -> CommunityStats? {
        guard let data = userDefaults.data(forKey: CacheKeys.communityStats),
              let timestamp = userDefaults.object(forKey: "\(CacheKeys.communityStats)_timestamp") as? Date else {
            return nil
        }
        
        let cacheAge = Date().timeIntervalSince(timestamp)
        guard cacheAge < CacheDurations.communityStats else {
            print("⚠️ Community stats cache expired")
            return nil
        }
        
        do {
            let stats = try JSONDecoder().decode(CommunityStats.self, from: data)
            print("📱 Retrieved community stats from cache")
            return stats
        } catch {
            print("❌ Failed to decode cached community stats: \(error)")
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
        
        print("🗑️ All caches cleared")
    }
    
    func clearExpiredCaches() {
        let cacheTypes = [
            (CacheKeys.habits, CacheDurations.habits),
            (CacheKeys.captures, CacheDurations.captures),
            (CacheKeys.habitCategories, CacheDurations.habitCategories),
            (CacheKeys.trendingHabits, CacheDurations.trendingHabits),
            (CacheKeys.communityStats, CacheDurations.communityStats),
            (CacheKeys.socialFeedGroups, CacheDurations.socialFeedGroups),
            (CacheKeys.userProfile, CacheDurations.userProfile)
        ]
        
        for (key, duration) in cacheTypes {
            if let timestamp = userDefaults.object(forKey: "\(key)_timestamp") as? Date {
                let cacheAge = Date().timeIntervalSince(timestamp)
                if cacheAge > duration {
                    userDefaults.removeObject(forKey: key)
                    userDefaults.removeObject(forKey: "\(key)_timestamp")
                    print("🗑️ Cleared expired cache: \(key)")
                }
            }
        }
    }
    
    // MARK: - Cache Statistics
    func getCacheStatistics() -> [String: Any] {
        var stats: [String: Any] = [:]
        
        let cacheTypes = [
            CacheKeys.habits,
            CacheKeys.captures,
            CacheKeys.habitCategories,
            CacheKeys.trendingHabits,
            CacheKeys.communityStats,
            CacheKeys.socialFeedGroups,
            CacheKeys.userProfile
        ]
        
        for key in cacheTypes {
            if let timestamp = userDefaults.object(forKey: "\(key)_timestamp") as? Date {
                let age = Date().timeIntervalSince(timestamp)
                stats[key] = [
                    "age_seconds": age,
                    "age_minutes": age / 60,
                    "exists": true
                ]
            } else {
                stats[key] = ["exists": false]
            }
        }
        
        return stats
    }
    
    // MARK: - Preloading Strategy
    func shouldPreloadData(for tab: Int) -> Bool {
        // Priority: Home (0) > Social (1) > Discovery (2)
        switch tab {
        case 0: // Home tab - highest priority
            return true
        case 1: // Social tab - medium priority
            return !isInitializing
        case 2: // Discovery tab - lowest priority
            return !isInitializing && cacheStatus == .ready
        default:
            return false
        }
    }
    
    // MARK: - Background Preloading
    func startBackgroundPreloading() {
        Task {
            // Preload data in background based on priority
            await preloadHighPriorityData()
            
            // Wait a bit, then preload medium priority
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            await preloadMediumPriorityData()
            
            // Wait more, then preload low priority
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            await preloadLowPriorityData()
        }
    }
    
    private func preloadHighPriorityData() async {
        // Preload habits and categories (essential for home tab)
        if getCachedHabits() == nil {
            print("🚀 Preloading high priority: habits")
            // This will be called by HabitManager
        }
    }
    
    private func preloadMediumPriorityData() async {
        // Preload social feed data
        if getCachedSocialFeedGroups() == nil {
            print("🚀 Preloading medium priority: social feed")
            // This will be called by SocialFeedView
        }
    }
    
    private func preloadLowPriorityData() async {
        // Preload discovery data
        if getCachedTrendingHabits() == nil {
            print("🚀 Preloading low priority: discovery data")
            // This will be called by DiscoveryView
        }
    }
}

// MARK: - Cache Helper Methods

extension AppCacheManager {
    // Helper method to check if habits should be loaded from cache
    func shouldLoadHabitsFromCache() -> Bool {
        return getCachedHabits() != nil
    }
    
    // Helper method to check if social feed should be loaded from cache
    func shouldLoadSocialFeedFromCache() -> Bool {
        return getCachedSocialFeedGroups() != nil
    }
    
    // Helper method to check if habit categories should be loaded from cache
    func shouldLoadHabitCategoriesFromCache() -> Bool {
        return getCachedHabitCategories() != nil
    }
}
