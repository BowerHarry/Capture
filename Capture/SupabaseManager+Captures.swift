import Foundation
import Supabase

extension SupabaseManager {
    func getCapturesSince(since: Date) async throws -> [HabitCapture] {
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.captures.filter { $0.createdAt >= since } }
        #endif
        let session = try await client.auth.session
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceStr = iso.string(from: since)
        
        do {
            let rows: [HabitCapture] = try await client
                .from("captures")
                .select()
                .eq("user_id", value: session.user.id)
                .gte("created_at", value: sinceStr)
                .not("user_habit_id", operator: .is, value: "null")  // Filter out captures with null user_habit_id
                .order("created_at", ascending: true)
                .execute()
                .value
            
            // Filter out any captures with nil userHabitId (additional safety check)
            let filteredRows = rows.filter { $0.userHabitId != nil }
            return filteredRows
        } catch {
            Log.error(String(format: "[SupabaseManager] getCapturesSince: error %@", error.localizedDescription))
            
            throw error
        }
    }

    func getProgressGridData(since: Date) async throws -> (habits: [Habit], captures: [HabitCapture]) {
        #if DEBUG
        if DemoMode.isEnabled { return (DemoData.habits, DemoData.captures.filter { $0.createdAt >= since }) }
        #endif
        
        let session = try await client.auth.session
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceStr = iso.string(from: since)
        
        
        do {
            // Fetch habits and captures sequentially for now (parallel execution has issues with Supabase client)
            let userHabits: [UserHabit] = try await client
                .from("user_habits")
                .select()
                .eq("user_id", value: session.user.id)
                .eq("is_active", value: true)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            let captures: [HabitCapture] = try await client
                .from("captures")
                .select()
                .eq("user_id", value: session.user.id)
                .gte("created_at", value: sinceStr)
                .not("user_habit_id", operator: .is, value: "null")
                .order("created_at", ascending: true)
                .execute()
                .value
            
            
            // Convert user habits to Habit objects with batch template fetching
            var habits: [Habit] = []
            
            // Get all unique template IDs
            let templateIds = Set(userHabits.map { $0.habitTemplateId })
            
            // Batch fetch all templates
            let allTemplates: [HabitTemplate] = try await client
                .from("habit_templates")
                .select()
                .in("id", values: Array(templateIds))
                .execute()
                .value
            
            // Create a dictionary for quick template lookup
            let templateDict = Dictionary(uniqueKeysWithValues: allTemplates.map { ($0.id, $0) })
            
            for userHabit in userHabits {
                guard let template = templateDict[userHabit.habitTemplateId] else {
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
            }
            
            return (habits: habits, captures: captures)
            
        } catch {
            Log.error(String(format: "[SupabaseManager] getProgressGridData: error %@", error.localizedDescription))
            
            throw error
        }
    }

    func getProgressGridDataOptimized(since: Date) async throws -> (habits: [Habit], captures: [HabitCapture]) {
        #if DEBUG
        if DemoMode.isEnabled { return (DemoData.habits, DemoData.captures.filter { $0.createdAt >= since }) }
        #endif
        let session = try await client.auth.session
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceStr = iso.string(from: since)
        
        do {
            // Use the optimized database function
            let response = try await client
                .rpc("get_user_progress_grid_data", params: [
                    "p_user_id": session.user.id.uuidString,
                    "p_since_date": sinceStr
                ])
                .execute()
            
            guard let rows = try JSONSerialization.jsonObject(with: response.data) as? [[String: Any]] else {
                Log.error("[SupabaseManager] getProgressGridDataOptimized: failed to cast response to expected type")
                throw NSError(domain: "DatabaseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response format from database function"])
            }
            
            // Process the results to separate habits and captures
            var habitsDict: [UUID: Habit] = [:]
            var captures: [HabitCapture] = []
            
            for row in rows {
                // Extract habit data
                if let userHabitIdString = row["user_habit_id"] as? String,
                   let userHabitId = UUID(uuidString: userHabitIdString),
                   habitsDict[userHabitId] == nil {
                    
                    let habit = Habit(
                        id: userHabitId,
                        name: row["habit_name"] as? String ?? "",
                        icon: nil, // HabitTemplate doesn't have icon
                        color: nil, // HabitTemplate doesn't have color
                        category: row["habit_category"] as? String ?? "",
                        target: row["target_count"] as? Int ?? 1,
                        targetFrequency: row["target_frequency"] as? String ?? "daily",
                        targetCount: row["target_count"] as? Int,
                        currentStreak: row["current_streak"] as? Int ?? 0,
                        longestStreak: 0, // Will be computed later
                        isActive: row["is_active"] as? Bool ?? true,
                        createdAt: parseDate(row["user_habit_created_at"]),
                        updatedAt: parseDate(row["user_habit_updated_at"]),
                        userId: UUID(uuidString: row["user_id"] as? String ?? "") ?? UUID()
                    )
                    habitsDict[userHabitId] = habit
                }
                
                // Extract capture data
                if let captureIdString = row["capture_id"] as? String,
                   let captureId = UUID(uuidString: captureIdString) {
                    
                    let capture = HabitCapture(
                        id: captureId,
                        habitId: nil, // Not used in this context
                        habitTemplateId: nil, // Not used in this context
                        userHabitId: UUID(uuidString: row["user_habit_id"] as? String ?? ""),
                        userId: UUID(uuidString: row["user_id"] as? String ?? "") ?? UUID(),
                        imageUrl: row["image_url"] as? String,
                        caption: row["caption"] as? String,
                        isPublic: row["is_public"] as? Bool ?? false,
                        createdAt: parseDate(row["capture_created_at"]),
                        updatedAt: parseDate(row["capture_updated_at"])
                    )
                    captures.append(capture)
                }
            }
            
            let habits = Array(habitsDict.values)
            return (habits: habits, captures: captures)
            
        } catch {
            Log.error(String(format: "[SupabaseManager] getProgressGridDataOptimized: error %@", error.localizedDescription))
            throw error
        }
    }

    // Helper function to parse dates from database
    func parseDate(_ value: Any?) -> Date {
        if let dateString = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.date(from: dateString) ?? Date()
        }
        return Date()
    }

    func uploadCaptureImage(imageData: Data, userId: UUID) async throws -> String {
        let userFolder = userId.uuidString.lowercased()
        let fileName = "\(userFolder)/\(UUID().uuidString).jpg"
        
        // Add timeout handling
        let options = FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        
        do {
            _ = try await withTimeout(seconds: 60) {
                try await self.client.storage
                    .from("captures_public")
                    .upload(fileName, data: imageData, options: options)
            }
            return fileName
        } catch {
            Log.error(String(format: "[Supabase] uploadCaptureImage: upload failed - %@", error.localizedDescription))
            throw error
        }
    }

    // Helper function for timeout handling
    func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func insertCapture(habitId: String, userId: UUID, imageUrl: String, caption: String?, isPublic: Bool) async throws -> HabitCapture {
        
        // Validate habitId format
        guard let habitUUID = UUID(uuidString: habitId) else {
            Log.error(String(format: "[SupabaseManager] insertCapture: ERROR - Invalid habitId format: %@", habitId))
            throw NSError(domain: "ValidationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid habit ID format"])
        }
        
        // Get habit template ID from user_habits
        
        struct UserHabitTemplate: Codable {
            let habitTemplateId: UUID
            
            enum CodingKeys: String, CodingKey {
                case habitTemplateId = "habit_template_id"
            }
        }
        
        let userHabits: [UserHabitTemplate] = try await client
            .from("user_habits")
            .select("habit_template_id")
            .eq("id", value: habitUUID)
            .limit(1)
            .execute()
            .value
        
        
        guard let userHabit = userHabits.first else {
            Log.error(String(format: "[SupabaseManager] insertCapture: ERROR - No user_habit found for habitId=%@", habitUUID.uuidString))
            throw NSError(domain: "ValidationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Habit not found"])
        }
        
        
        struct InsertCapture: Encodable {
            let habit_template_id: UUID
            let user_habit_id: UUID   // This is the user_habits.id for streak calculation
            let user_id: UUID
            let image_url: String
            let caption: String?
            let is_public: Bool
        }
        
        let payload = InsertCapture(
            habit_template_id: userHabit.habitTemplateId,
            user_habit_id: habitUUID, // This is the user_habits.id for streak calculation
            user_id: userId, 
            image_url: imageUrl, 
            caption: caption, 
            is_public: isPublic
        )
        
        
        
        do {
            
            // First, try to insert without selecting to see if the insert works
            let _ = try await client
                .from("captures")
                .insert(payload)
                .execute()
            
            
            // Now fetch the inserted record
            let rows: [HabitCapture] = try await client
                .from("captures")
                .select()
                .eq("user_habit_id", value: habitUUID)
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            
            guard let row = rows.first else {
                Log.error("[SupabaseManager] insertCapture: ERROR - No rows returned from fetch")
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch created capture"])
            }
            
            
            return row
        } catch {
            Log.error(String(format: "[SupabaseManager] insertCapture: ERROR during database operation: %@", error.localizedDescription))
            
            // Add more detailed error logging
            if let postgrestError = error as? PostgrestError {
                Log.error(String(format: "[SupabaseManager] insertCapture: PostgrestError details: %@", postgrestError.localizedDescription))
            }
            
            // Log the specific decoding error if it's a decoding error
            
            throw error
        }
    }
}
