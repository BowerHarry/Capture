import Foundation
import Supabase

extension SupabaseManager {
    func getHabits() async throws -> [Habit] {
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.habits }
        #endif
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Try optimized function first
        do {
            let habits = try await getHabitsOptimized(userId: currentUser.id)
            return habits
        } catch {
            Log.error(String(format: "[SupabaseManager] getHabits: optimized function failed, falling back to original: %@", error.localizedDescription))
            return try await getHabitsFromTables(currentUser: currentUser)
        }
    }

    func getHabitsOptimized(userId: UUID) async throws -> [Habit] {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceStr = iso.string(from: sixMonthsAgo)
        
        // Get habits with progress using optimized function
        let habitData: [HabitProgressData] = try await client.rpc("get_user_habits_with_progress", params: [
            "user_id_param": userId.uuidString,
            "since_date": sinceStr
        ]).execute().value
        
        // Convert to Habit objects
        var habits: [Habit] = []
        for habitInfo in habitData {
            let habit = Habit(
                id: habitInfo.habit_id,
                name: habitInfo.habit_name,
                icon: nil,
                color: nil,
                category: habitInfo.habit_category,
                target: habitInfo.target_count,
                targetFrequency: habitInfo.target_frequency,
                targetCount: habitInfo.target_count,
                currentStreak: habitInfo.current_streak,
                longestStreak: 0, // Will be computed later
                isActive: true,
                createdAt: Date(),
                updatedAt: Date(),
                userId: userId
            )
            habits.append(habit)
        }
        
        return habits
    }

    func getHabitsFromTables(currentUser: User) async throws -> [Habit] {
        

        
        do {

            
            // Get user habits using the new decoupled schema
            let userHabits: [UserHabit] = try await client
                .from("user_habits")
                .select()
                .eq("user_id", value: currentUser.id)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            

            
            // Convert to legacy Habit format for backward compatibility
            var habits: [Habit] = []
            
            for userHabit in userHabits {

                
                do {

                    
                    let templateRows: [HabitTemplate] = try await client
                        .from("habit_templates")
                        .select()
                        .eq("id", value: userHabit.habitTemplateId)
                        .limit(1)
                        .execute()
                        .value
                    

                    
                    guard let template = templateRows.first else {

                        continue
                    }
                    

                    
                    let habit = Habit(
                        id: userHabit.id,
                        name: template.name,
                        icon: nil, // HabitTemplate doesn't have icon
                        color: nil, // HabitTemplate doesn't have color
                        category: template.category,
                        target: template.targetCount ?? 1,
                        targetFrequency: template.targetFrequency,
                        targetCount: template.targetCount,
                        currentStreak: userHabit.currentStreak,
                        longestStreak: 0,
                        isActive: userHabit.isActive,
                        createdAt: userHabit.createdAt,
                        updatedAt: userHabit.updatedAt,
                        userId: userHabit.userId
                    )
                    

                    habits.append(habit)
                    
                } catch {
                    Log.error(String(format: "[SupabaseManager] getHabits: error fetching template for habit %@: %@", userHabit.id.uuidString, error.localizedDescription))
                    continue
                }
            }
            
            return habits
        } catch {
            Log.error(String(format: "[SupabaseManager] getHabits: error %@", error.localizedDescription))
            throw error
        }
    }

    func getAvailableHabits() async throws -> [AvailableHabit] {
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.availableHabits }
        #endif
        let rows: [AvailableHabit] = try await client
            .from("available_habits")
            .select()
            .order("is_default", ascending: false)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows
    }

    func createAvailableHabit(name: String, category: String, icon: String?, color: String?) async throws -> AvailableHabit {
        struct InsertAvailable: Encodable {
            let user_id: UUID
            let name: String
            let category: String
            let icon: String?
            let color: String?
            let is_default: Bool
        }
        let session = try await client.auth.session
        let payload = InsertAvailable(
            user_id: session.user.id,
            name: name,
            category: category,
            icon: icon,
            color: color,
            is_default: false
        )
        let rows: [AvailableHabit] = try await client
            .from("available_habits")
            .insert(payload)
            .select()
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create available habit"])
        }
        return row
    }

    func createHabitDirect(name: String, description: String?, category: String, targetFrequency: String, targetCount: Int? = nil) async throws -> Habit {
        let session = try await client.auth.session
        
        // First, try to find an existing habit template with the same name and category
        let existingTemplates: [HabitTemplate] = try await client
            .from("habit_templates")
            .select()
            .eq("name", value: name)
            .eq("category", value: category)
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        
        // If template exists, check if user already has this habit
        if let existingTemplate = existingTemplates.first {
            let existingUserHabits: [UserHabit] = try await client
                .from("user_habits")
                .select()
                .eq("user_id", value: session.user.id)
                .eq("habit_template_id", value: existingTemplate.id)
                .eq("is_active", value: true)
                .limit(1)
                .execute()
                .value
            
            if let existingUserHabit = existingUserHabits.first {
                // User already has this habit, return the existing one
                
                // Convert to legacy Habit format
                return Habit(
                    id: existingUserHabit.id,
                    name: existingTemplate.name,
                    icon: nil,
                    color: nil,
                    category: existingTemplate.category,
                    target: existingTemplate.targetCount ?? 1,
                    targetFrequency: existingTemplate.targetFrequency,
                    targetCount: existingTemplate.targetCount,
                    currentStreak: existingUserHabit.currentStreak,
                    longestStreak: 0,
                    isActive: existingUserHabit.isActive,
                    createdAt: existingUserHabit.createdAt,
                    updatedAt: existingUserHabit.updatedAt,
                    userId: existingUserHabit.userId
                )
            }
        }
        

        
        // Find or create the habit template
        let templateTemplates: [HabitTemplate] = try await client
            .from("habit_templates")
            .select()
            .eq("name", value: name)
            .eq("category", value: category)
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        
        let template: HabitTemplate
        
        if let existingTemplate = templateTemplates.first {
            // Reuse existing template
            template = existingTemplate
        } else {
            // Create new habit template
            struct CreateHabitTemplate: Encodable {
                let name: String
                let description: String?
                let category: String
                let target_frequency: String
                let target_count: Int?
                let is_active: Bool
            }
            
            let templatePayload = CreateHabitTemplate(
                name: name, 
                description: description, 
                category: category, 
                target_frequency: targetFrequency, 
                target_count: targetCount,
                is_active: true
            )
            
            let templateRows: [HabitTemplate] = try await client
                .from("habit_templates")
                .insert(templatePayload)
                .select()
                .limit(1)
                .execute()
                .value
            
            guard let newTemplate = templateRows.first else {
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create habit template"])
            }
            
            template = newTemplate
        }
        
        // Create the user habit instance
        struct CreateUserHabit: Encodable {
            let habit_template_id: UUID
            let user_id: UUID
            let current_streak: Int
            let is_active: Bool
        }
        
        let userHabitPayload = CreateUserHabit(
            habit_template_id: template.id,
            user_id: session.user.id,
            current_streak: 0,
            is_active: true
        )
        
        let userHabitRows: [UserHabit] = try await client
            .from("user_habits")
            .insert(userHabitPayload)
            .select()
            .limit(1)
            .execute()
            .value
        
        guard let userHabit = userHabitRows.first else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create user habit"])
        }
        
        // Convert to legacy Habit format for backward compatibility
        return Habit(
            id: userHabit.id,
            name: template.name,
            icon: nil, // HabitTemplate doesn't have icon
            color: nil, // HabitTemplate doesn't have color
            category: template.category,
            target: targetCount ?? 1,
            targetFrequency: template.targetFrequency,
            targetCount: template.targetCount,
            currentStreak: userHabit.currentStreak,
            longestStreak: 0,
            isActive: userHabit.isActive,
            createdAt: userHabit.createdAt,
            updatedAt: userHabit.updatedAt,
            userId: userHabit.userId
        )
    }

    func getHabitCategories() async throws -> [DatabaseHabitCategory] {
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.categories }
        #endif
        
        do {
            let categories: [DatabaseHabitCategory] = try await client
                .rpc("get_habit_categories")
                .execute()
                .value
            
            return categories
        } catch {
            Log.error(String(format: "[SupabaseManager] getHabitCategories: error %@ - categories not available", error.localizedDescription))
            throw error
        }
    }
}
