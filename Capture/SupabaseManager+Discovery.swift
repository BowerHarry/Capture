import Foundation
import Supabase

extension SupabaseManager {
    func getTrendingHabits() async throws -> [TrendingHabit] {
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.trendingHabits }
        #endif
        
        do {
            let rows: [TrendingHabit] = try await client
                .from("trending_habits_view")
                .select()
                .execute()
                .value
            
            return rows
        } catch {
            Log.error(String(format: "[SupabaseManager] getTrendingHabits: error %@, falling back to available habits", error.localizedDescription))
            
            // Fallback: Use available_habits as trending habits if view doesn't exist yet
            let availableHabits: [AvailableHabit] = try await client
                .from("available_habits")
                .select()
                .order("is_default", ascending: false)
                .limit(10)
                .execute()
                .value
            
            // Convert AvailableHabit to TrendingHabit
            let trendingHabits = availableHabits.map { habit in
                TrendingHabit(
                    id: habit.id,
                    name: habit.name,
                    category: habit.category,
                    participants: Int.random(in: 50...500), // Mock data for now
                    avgStreak: Double.random(in: 3.0...15.0), // Mock data for now
                    description: habit.description ?? "A popular habit that many people are trying to build.",
                    captures: [], // Will be populated by trending captures
                    totalCaptures: Int.random(in: 100...1000) // Mock data for now
                )
            }
            
            return trendingHabits
        }
    }

    func getTrendingCapturesForHabits() async throws -> [TrendingCapture] {
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.trendingCaptures }
        #endif
        
        do {
            
            let captures: [TrendingCapture] = try await client
                .rpc("get_trending_captures_for_habits")
                .execute()
                .value
            
            
            return captures
        } catch {
            Log.error(String(format: "[SupabaseManager] getTrendingCapturesForHabits: error %@, falling back to recent captures", error.localizedDescription))
            
            
            // Fallback: Get recent public captures from the captures table
            let captures: [HabitCapture] = try await client
                .from("captures")
                .select()
                .eq("is_public", value: true)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            
            // Convert HabitCapture to TrendingCapture
            let trendingCaptures: [TrendingCapture] = captures.compactMap { capture in
                // Skip captures without habitTemplateId
                guard let habitTemplateId = capture.habitTemplateId else {
                    return nil
                }
                
                return TrendingCapture(
                    id: capture.id,
                    captureId: capture.id,
                    habitTemplateId: habitTemplateId,
                    userId: capture.userId,
                    imageUrl: capture.imageUrl,
                    caption: capture.caption,
                    isPublic: capture.isPublic,
                    captureCreatedAt: capture.createdAt,
                    habitName: "Unknown Habit", // We'll need to join with habits table
                    habitCategory: "General",
                    habitCategoryId: nil, // Add the missing parameter
                    userDisplayName: nil,
                    userAvatarUrl: nil,
                    likeCount: 0,
                    totalCaptures: 1,
                    trendScore: 1.0
                )
            }
            
            return trendingCaptures
        }
    }

    func getTrendingHabitsByCategoryId(_ categoryId: UUID) async throws -> [TrendingHabit] {
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.trendingHabits(inCategory: categoryId) }
        #endif
        
        do {
            let rows: [TrendingHabit] = try await client
                .rpc("get_trending_habits_by_category", params: ["category_id_param": categoryId])
                .execute()
                .value
            
            return rows
        } catch {
            Log.error(String(format: "[SupabaseManager] getTrendingHabitsByCategoryId: error %@", error.localizedDescription))
            throw error
        }
    }

    func getCommunityStats() async throws -> CommunityStats {
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.communityStats }
        #endif
        
        do {
            let stats: [CommunityStats] = try await client
                .rpc("get_community_stats")
                .execute()
                .value
            
            if let firstStat = stats.first {
                return firstStat
            } else {
                return CommunityStats(activeUsers: 0, totalHabits: 0, totalCaptures: 0)
            }
        } catch {
            Log.error(String(format: "[SupabaseManager] getCommunityStats: error %@ - using default values", error.localizedDescription))
            return CommunityStats(activeUsers: 0, totalHabits: 0, totalCaptures: 0)
        }
    }
}
