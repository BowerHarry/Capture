import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    private let supabaseURL = "https://your-project-ref.supabase.co"
    private let supabaseAnonKey = "YOUR-ANON-KEY"
    private let serverURL = "https://your-project-ref.supabase.co/functions/v1/make-server-b26ffe3e"
    
    lazy var client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: URL(string: supabaseURL)!,
            supabaseKey: supabaseAnonKey
        )
    }()
    
    var currentUser: User? {
        get async {
            do {
                return try await getCurrentUser()
            } catch {
                return nil
            }
        }
    }
    
    private init() {}
    
    // MARK: - Authentication
    func signUp(email: String, password: String, username: String) async throws -> User {
        // Create auth user in Supabase and attach username metadata for profile trigger
        let metadata: [String: AnyJSON] = ["username": .string(username)]
        _ = try await client.auth.signUp(email: email, password: password, data: metadata)
        // After sign up, sign in (if not already) to establish a session
        let user = try await signIn(email: email, password: password)
        return user
    }
    
    func signIn(email: String, password: String) async throws -> User {
        do {
            let _ = try await client.auth.signIn(email: email, password: password)
            return try await fetchCurrentProfile()
        } catch {
            throw error
        }
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    func getCurrentUser() async throws -> User? {
        do {
            let _ = try await client.auth.session
            return try await fetchCurrentProfile()
        } catch {
            return nil
        }
    }
    
    func updateProfile(userId: String, username: String?, bio: String?, avatar: String?) async throws -> User {
        let payload = UpdateProfilePayload(display_name: username, bio: bio, avatar_url: avatar)
        _ = try await client.database
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .execute()
        return try await fetchCurrentProfile()
    }
    
    func uploadAvatar(userId: String, imageData: Data) async throws -> String {
        let fileName = "\(userId)_avatar.jpg"
        let filePath = "avatars/\(fileName)"
        
        // Try to delete existing avatar first
        do {
            try await client.storage
                .from("avatars")
                .remove(paths: [filePath])
        } catch {
            // File doesn't exist, which is fine
            print("No existing avatar to delete: \(error)")
        }
        
        // Upload to Supabase storage
        let _ = try await client.storage
            .from("avatars")
            .upload(
                path: filePath,
                file: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        // Get public URL
        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        
        return publicURL.absoluteString
    }
    
    // MARK: - Helpers (Profiles)
    private func fetchCurrentProfile() async throws -> User {
        let session = try await client.auth.session
        let rows: [ProfileRow] = try await client.database
            .from("profiles")
            .select()
            .eq("id", value: session.user.id)
            .limit(1)
            .execute()
            .value
        if let row = rows.first {
            return mapProfileRowToUser(row)
        }
        // Profile missing (likely created before trigger). Create it now under RLS as the current user.
        let metadata = session.user.userMetadata ?? [:]
        let usernameMeta: String? = {
            if let any = metadata["username"], case let .string(val) = any { return val }
            return nil
        }()
        let avatarMeta: String? = {
            if let any = metadata["avatar_url"], case let .string(val) = any { return val }
            return nil
        }()
        let insertPayload = NewProfilePayload(
            id: session.user.id,
            email: session.user.email,
            display_name: usernameMeta,
            avatar_url: avatarMeta,
            bio: nil
        )
        _ = try await client.database
            .from("profiles")
            .insert(insertPayload)
            .execute()
        let created: [ProfileRow] = try await client.database
            .from("profiles")
            .select()
            .eq("id", value: session.user.id)
            .limit(1)
            .execute()
            .value
        guard let createdRow = created.first else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create profile"])
        }
        return mapProfileRowToUser(createdRow)
    }
    
    private func mapProfileRowToUser(_ p: ProfileRow) -> User {
        return User(
            id: p.id,
            email: p.email ?? "",
            username: p.display_name ?? "",
            avatar: p.avatar_url,
            bio: p.bio,
            createdAt: p.created_at,
            updatedAt: p.updated_at
        )
    }

    private struct ProfileRow: Decodable {
        let id: UUID
        let email: String?
        let display_name: String?
        let avatar_url: String?
        let bio: String?
        let created_at: Date
        let updated_at: Date
    }

    private struct UpdateProfilePayload: Encodable {
        let display_name: String?
        let bio: String?
        let avatar_url: String?
    }
    
    private struct NewProfilePayload: Encodable {
        let id: UUID
        let email: String?
        let display_name: String?
        let avatar_url: String?
        let bio: String?
    }
    
    // MARK: - Habits (production)
    func getHabits() async throws -> [Habit] {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        NSLog("[SupabaseManager] getHabits: fetching habits for user %@", currentUser.id.uuidString)
        
        do {
            NSLog("[SupabaseManager] getHabits: starting to fetch user habits...")
            
            // Get user habits using the new decoupled schema
            let userHabits: [UserHabit] = try await client.database
                .from("user_habits")
                .select()
                .eq("user_id", value: currentUser.id)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            NSLog("[SupabaseManager] getHabits: successfully fetched %d user habits", userHabits.count)
            
            // Convert to legacy Habit format for backward compatibility
            var habits: [Habit] = []
            
            for (index, userHabit) in userHabits.enumerated() {
                NSLog("[SupabaseManager] getHabits: processing user habit %d/%d: %@", index + 1, userHabits.count, userHabit.id.uuidString)
                
                do {
                    NSLog("[SupabaseManager] getHabits: fetching template for habit %@", userHabit.habitTemplateId.uuidString)
                    
                    let templateRows: [HabitTemplate] = try await client.database
                        .from("habit_templates")
                        .select()
                        .eq("id", value: userHabit.habitTemplateId)
                        .limit(1)
                        .execute()
                        .value
                    
                    NSLog("[SupabaseManager] getHabits: found %d templates for habit %@", templateRows.count, userHabit.id.uuidString)
                    
                    guard let template = templateRows.first else {
                        NSLog("[SupabaseManager] getHabits: template not found for habit %@", userHabit.id.uuidString)
                        continue
                    }
                    
                    NSLog("[SupabaseManager] getHabits: creating Habit object for %@ with template %@", userHabit.id.uuidString, template.name)
                    
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
                    
                    NSLog("[SupabaseManager] getHabits: successfully created Habit object: %@", habit.name)
                    habits.append(habit)
                    
                } catch {
                    NSLog("[SupabaseManager] getHabits: error fetching template for habit %@: %@", userHabit.id.uuidString, error.localizedDescription)
                    
                    // Add detailed error logging
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            NSLog("[SupabaseManager] getHabits: missing key '%@' at path %@", key.stringValue, context.codingPath.map { $0.stringValue }.joined(separator: "."))
                        case .typeMismatch(let type, let context):
                            NSLog("[SupabaseManager] getHabits: type mismatch for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                        case .valueNotFound(let type, let context):
                            NSLog("[SupabaseManager] getHabits: value not found for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                        case .dataCorrupted(let context):
                            NSLog("[SupabaseManager] getHabits: data corrupted at path %@: %@", context.codingPath.map { $0.stringValue }.joined(separator: "."), context.debugDescription)
                        @unknown default:
                            NSLog("[SupabaseManager] getHabits: unknown decoding error")
                        }
                    }
                    continue
                }
            }
            
            NSLog("[SupabaseManager] getHabits: successfully fetched %d habits", habits.count)
            return habits
        } catch {
            NSLog("[SupabaseManager] getHabits: error %@", error.localizedDescription)
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    NSLog("[SupabaseManager] getHabits: missing key '%@' at path %@", key.stringValue, context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .typeMismatch(let type, let context):
                    NSLog("[SupabaseManager] getHabits: type mismatch for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .valueNotFound(let type, let context):
                    NSLog("[SupabaseManager] getHabits: value not found for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .dataCorrupted(let context):
                    NSLog("[SupabaseManager] getHabits: data corrupted at path %@: %@", context.codingPath.map { $0.stringValue }.joined(separator: "."), context.debugDescription)
                @unknown default:
                    NSLog("[SupabaseManager] getHabits: unknown decoding error")
                }
            }
            
            // Try to get raw data for debugging
            do {
                let rawData = try await getHabitsRawData()
                NSLog("[SupabaseManager] getHabits: got raw data for debugging")
            } catch {
                NSLog("[SupabaseManager] getHabits: failed to get raw data: %@", error.localizedDescription)
            }
            
            throw error
        }
    }
    
    func getHabitsForUserID(userId: UUID) async throws -> [Habit] {
        
        NSLog("[SupabaseManager] getHabits: fetching habits for user %@", userId.uuidString)
        
        do {
            // Get user habits with their templates using the new decoupled schema
            let rows: [UserHabit] = try await client.database
                .from("user_habits")
                .select("""
                    id,
                    user_id,
                    habit_template_id,
                    current_streak,
                    is_active,
                    created_at,
                    updated_at,
                    habit_templates!inner(
                        id,
                        name,
                        description,
                        category,
                        target_frequency,
                        target_count,
                        is_active,
                        created_at,
                        updated_at
                    )
                """)
                .eq("user_id", value: userId)
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Convert to legacy Habit format for backward compatibility
            var habits: [Habit] = []
            
            for userHabit in rows {
                do {
                    let templateRows: [HabitTemplate] = try await client.database
                        .from("habit_templates")
                        .select()
                        .eq("id", value: userHabit.habitTemplateId)
                        .limit(1)
                        .execute()
                        .value
                    
                    guard let template = templateRows.first else {
                        NSLog("[SupabaseManager] getHabitsForUserID: template not found for habit %@", userHabit.id.uuidString)
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
                    NSLog("[SupabaseManager] getHabitsForUserID: error fetching template for habit %@: %@", userHabit.id.uuidString, error.localizedDescription)
                    continue
                }
            }
            
            NSLog("[SupabaseManager] getHabits: successfully fetched %d habits", habits.count)
            return habits
        } catch {
            NSLog("[SupabaseManager] getHabits: error %@", error.localizedDescription)
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    NSLog("[SupabaseManager] getHabits: missing key '%@' at path %@", key.stringValue, context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .typeMismatch(let type, let context):
                    NSLog("[SupabaseManager] getHabits: type mismatch for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .valueNotFound(let type, let context):
                    NSLog("[SupabaseManager] getHabits: value not found for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .dataCorrupted(let context):
                    NSLog("[SupabaseManager] getHabits: data corrupted at path %@: %@", context.codingPath.map { $0.stringValue }.joined(separator: "."), context.debugDescription)
                @unknown default:
                    NSLog("[SupabaseManager] getHabits: unknown decoding error")
                }
            }
            
            // Try to get raw data for debugging
            do {
                let rawData = try await getHabitsRawData()
                NSLog("[SupabaseManager] getHabits: got raw data for debugging")
            } catch {
                NSLog("[SupabaseManager] getHabits: failed to get raw data: %@", error.localizedDescription)
            }
            
            throw error
        }
    }
    
    private func makeISO8601Decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        if #available(iOS 11.0, *) {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let str = try container.decode(String.self)
                if let date = fmt.date(from: str) { return date }
                // Fallback without fractional seconds
                let fmt2 = ISO8601DateFormatter()
                fmt2.formatOptions = [.withInternetDateTime]
                if let date2 = fmt2.date(from: str) { return date2 }
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid ISO8601 date: \(str)"))
            }
        }
        return decoder
    }
    
    private func getHabitsRawREST(accessToken: String) async throws -> [Habit] {
        guard let url = URL(string: "\(supabaseURL)/rest/v1/habits?select=*&order=created_at.desc") else {
            NSLog("[Supabase] getHabitsRawREST: invalid URL")
            return []
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        NSLog("[Supabase] getHabitsRawREST: GET %@", url.absoluteString)
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse { NSLog("[Supabase] getHabitsRawREST: status %ld", http.statusCode) }
        let decoder = makeISO8601Decoder()
        do {
            let rows = try decoder.decode([Habit].self, from: data)
            return rows
        } catch {
            let body = String(data: data.prefix(500), encoding: .utf8) ?? "<non-utf8>"
            NSLog("[Supabase] getHabitsRawREST: decode error %@ body(sample)=%@", error.localizedDescription, body)
            throw error
        }
    }
    
    private func getHabitsRawData() async throws -> Data {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let response = try await client.database
            .from("habits")
            .select()
            .eq("user_id", value: currentUser.id)
            .order("created_at", ascending: false)
            .execute()
        
        // Get the raw data to inspect what's being returned
        let data = response.data
        let jsonString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        NSLog("[SupabaseManager] getHabitsRawData: raw JSON response: %@", jsonString)
        return data
    }
    
    func createHabit(userId: String, name: String, description: String?, category: String, targetFrequency: String) async throws -> Habit {
        let response = try await makeAPICall(
            endpoint: "/habits",
            method: "POST",
            body: CreateHabitRequest(name: name, description: description, category: category, targetFrequency: targetFrequency),
            authenticated: true
        )
        
        let apiResponse: APIResponse<Habit> = try JSONDecoder().decode(APIResponse<Habit>.self, from: response)
        
        if let habit = apiResponse.data {
            return habit
        } else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Create habit failed"])
        }
    }
    
    func deleteHabit(habitId: String) async throws {
        let response = try await makeAPICall(
            endpoint: "/habits/\(habitId)",
            method: "DELETE",
            authenticated: true
        )
        
        let apiResponse: APIResponse<Bool> = try JSONDecoder().decode(APIResponse<Bool>.self, from: response)
        
        if apiResponse.success != true {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Delete habit failed"])
        }
    }
    
    func getHabitStats(habitId: String) async throws -> [String: Any] {
        let response = try await makeAPICall(
            endpoint: "/habits/\(habitId)/stats",
            method: "GET",
            authenticated: true
        )
        
        let json = try JSONSerialization.jsonObject(with: response, options: []) as? [String: Any]
        return json?["data"] as? [String: Any] ?? [:]
    }
    
    // MARK: - Captures
    func getCaptures(userId: String) async throws -> [HabitCapture] {
        let response = try await makeAPICall(
            endpoint: "/captures/recent",
            method: "GET",
            authenticated: true
        )
        
        let apiResponse: APIResponse<[HabitCapture]> = try JSONDecoder().decode(APIResponse<[HabitCapture]>.self, from: response)
        return apiResponse.data ?? []
    }
    
    func createCapture(habitId: String, userId: String, caption: String?, isPublic: Bool, imageData: Data?) async throws -> HabitCapture {
        let response = try await makeAPICall(
            endpoint: "/captures",
            method: "POST",
            body: CreateCaptureRequest(habitId: habitId, caption: caption, isPublic: isPublic, imageData: imageData),
            authenticated: true
        )
        
        let apiResponse: APIResponse<HabitCapture> = try JSONDecoder().decode(APIResponse<HabitCapture>.self, from: response)
        
        if let capture = apiResponse.data {
            return capture
        } else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Create capture failed"])
        }
    }
    
    // MARK: - Captures fetch
    func getCapturesSince(since: Date) async throws -> [HabitCapture] {
        NSLog("[SupabaseManager] getCapturesSince: starting fetch for captures since %@", since.description)
        
        let session = try await client.auth.session
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceStr = iso.string(from: since)
        
        NSLog("[SupabaseManager] getCapturesSince: querying captures for user %@ since %@", session.user.id.uuidString, sinceStr)
        
        do {
            let rows: [HabitCapture] = try await client.database
                .from("captures")
                .select()
                .eq("user_id", value: session.user.id)
                .gte("created_at", value: sinceStr)
                .not("user_habit_id", operator: .is, value: "null")  // Filter out captures with null user_habit_id
                .order("created_at", ascending: true)
                .execute()
                .value
            
            NSLog("[SupabaseManager] getCapturesSince: successfully fetched %d captures", rows.count)
            
            // Filter out any captures with nil userHabitId (additional safety check)
            let filteredRows = rows.filter { $0.userHabitId != nil }
            NSLog("[SupabaseManager] getCapturesSince: filtered out %d captures with nil userHabitId", rows.count - filteredRows.count)
            return filteredRows
        } catch {
            NSLog("[SupabaseManager] getCapturesSince: error %@", error.localizedDescription)
            
            // Add detailed error logging
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    NSLog("[SupabaseManager] getCapturesSince: missing key '%@' at path %@", key.stringValue, context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .typeMismatch(let type, let context):
                    NSLog("[SupabaseManager] getCapturesSince: type mismatch for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .valueNotFound(let type, let context):
                    NSLog("[SupabaseManager] getCapturesSince: value not found for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .dataCorrupted(let context):
                    NSLog("[SupabaseManager] getCapturesSince: data corrupted at path %@: %@", context.codingPath.map { $0.stringValue }.joined(separator: "."), context.debugDescription)
                @unknown default:
                    NSLog("[SupabaseManager] getCapturesSince: unknown decoding error")
                }
            }
            
            throw error
        }
    }
    
    // MARK: - Social Features
    func getSocialFeed(userId: String) async throws -> [HabitCapture] {
        let response = try await makeAPICall(
            endpoint: "/feed",
            method: "GET",
            authenticated: true
        )
        
        let apiResponse: APIResponse<[HabitCapture]> = try JSONDecoder().decode(APIResponse<[HabitCapture]>.self, from: response)
        return apiResponse.data ?? []
    }
    
    func getDiscoveryUsers(userId: String) async throws -> [User] {
        let response = try await makeAPICall(
            endpoint: "/discovery",
            method: "GET",
            authenticated: true
        )
        
        let apiResponse: APIResponse<[User]> = try JSONDecoder().decode(APIResponse<[User]>.self, from: response)
        return apiResponse.data ?? []
    }
    
    func searchUsers(query: String) async throws -> [User] {
        let response = try await makeAPICall(
            endpoint: "/search/users?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
            method: "GET",
            authenticated: true
        )
        
        let apiResponse: APIResponse<[User]> = try JSONDecoder().decode(APIResponse<[User]>.self, from: response)
        return apiResponse.data ?? []
    }
    
    func followUser(followerId: String, followingId: String) async throws {
        let response = try await makeAPICall(
            endpoint: "/social/follow",
            method: "POST",
            body: ["user_id": followingId],
            authenticated: true
        )
        
        let apiResponse: APIResponse<Bool> = try JSONDecoder().decode(APIResponse<Bool>.self, from: response)
        
        if apiResponse.success != true {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Follow failed"])
        }
    }
    
    func unfollowUser(followerId: String, followingId: String) async throws {
        let response = try await makeAPICall(
            endpoint: "/social/unfollow",
            method: "POST",
            body: ["user_id": followingId],
            authenticated: true
        )
        
        let apiResponse: APIResponse<Bool> = try JSONDecoder().decode(APIResponse<Bool>.self, from: response)
        
        if apiResponse.success != true {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Unfollow failed"])
        }
    }
    
    func getFollowing(userId: String) async throws -> [User] {
        let response = try await makeAPICall(
            endpoint: "/users/\(userId)/following",
            method: "GET",
            authenticated: true
        )
        
        let apiResponse: APIResponse<[User]> = try JSONDecoder().decode(APIResponse<[User]>.self, from: response)
        return apiResponse.data ?? []
    }
    
    func getFollowers(userId: String) async throws -> [User] {
        let response = try await makeAPICall(
            endpoint: "/users/\(userId)/followers",
            method: "GET",
            authenticated: true
        )
        
        let apiResponse: APIResponse<[User]> = try JSONDecoder().decode(APIResponse<[User]>.self, from: response)
        return apiResponse.data ?? []
    }
    
    func likeCapture(captureId: String, userId: String) async throws {
        let response = try await makeAPICall(
            endpoint: "/social/like",
            method: "POST",
            body: ["capture_id": captureId],
            authenticated: true
        )
        
        let apiResponse: APIResponse<Bool> = try JSONDecoder().decode(APIResponse<Bool>.self, from: response)
        
        if apiResponse.success != true {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Like failed"])
        }
    }
    
    func unlikeCapture(captureId: String, userId: String) async throws {
        let response = try await makeAPICall(
            endpoint: "/social/unlike",
            method: "POST",
            body: ["capture_id": captureId],
            authenticated: true
        )
        
        let apiResponse: APIResponse<Bool> = try JSONDecoder().decode(APIResponse<Bool>.self, from: response)
        
        if apiResponse.success != true {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: apiResponse.error ?? "Unlike failed"])
        }
    }
    
    // MARK: - Available Habits (Suggestions)
    func getAvailableHabits() async throws -> [AvailableHabit] {
        let rows: [AvailableHabit] = try await client.database
            .from("available_habits")
            .select()
            .order("is_default", ascending: false)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows
    }
    
    // MARK: - Discovery Methods
    func getTrendingHabits() async throws -> [TrendingHabit] {
        NSLog("[SupabaseManager] getTrendingHabits: fetching trending habits from trending_habits_view")
        
        do {
            let rows: [TrendingHabit] = try await client.database
                .from("trending_habits_view")
                .select()
                .execute()
                .value
            
            NSLog("[SupabaseManager] getTrendingHabits: successfully fetched %d trending habits", rows.count)
            return rows
        } catch {
            NSLog("[SupabaseManager] getTrendingHabits: error %@, falling back to available habits", error.localizedDescription)
            
            // Fallback: Use available_habits as trending habits if view doesn't exist yet
            let availableHabits: [AvailableHabit] = try await client.database
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
            
            NSLog("[SupabaseManager] getTrendingHabits: using fallback data with %d habits", trendingHabits.count)
            return trendingHabits
        }
    }
    
    func getTrendingHabitsByCategory(_ category: String) async throws -> [TrendingHabit] {
        NSLog("[SupabaseManager] getTrendingHabitsByCategory: fetching trending habits for category '%@'", category)
        
        // Map UI category names to database category names
        let mappedCategory = mapUICategoryToDatabaseCategory(category)
        NSLog("[SupabaseManager] getTrendingHabitsByCategory: mapped '%@' to '%@'", category, mappedCategory)
        
        do {
            // First try to filter by category in the database
            let rows: [TrendingHabit] = try await client.database
                .from("trending_habits_view")
                .select()
                .eq("category", value: mappedCategory)
                .order("participants", ascending: false)
                .order("total_captures", ascending: false)
                .limit(5)
                .execute()
                .value
            
            NSLog("[SupabaseManager] getTrendingHabitsByCategory: successfully fetched %d trending habits for category '%@' (mapped from '%@')", rows.count, mappedCategory, category)
            
            // If we got results, return them
            if !rows.isEmpty {
                return rows
            }
            
            // If no results, try fetching all trending habits and filtering by category on client side
            NSLog("[SupabaseManager] getTrendingHabitsByCategory: no results for category '%@', trying client-side filtering", category)
            
            let allRows: [TrendingHabit] = try await client.database
                .from("trending_habits_view")
                .select()
                .order("participants", ascending: false)
                .order("total_captures", ascending: false)
                .limit(20) // Get more habits to filter from
                .execute()
                .value
            
            // Filter by category using flexible matching
            let filteredRows = allRows.filter { habit in
                matchesCategory(habit: habit, targetCategory: category)
            }
            
            NSLog("[SupabaseManager] getTrendingHabitsByCategory: client-side filtering found %d habits for category '%@'", filteredRows.count, category)
            
            return Array(filteredRows.prefix(5)) // Return top 5
            
        } catch {
            NSLog("[SupabaseManager] getTrendingHabitsByCategory: error %@, falling back to available habits for category '%@'", error.localizedDescription, category)
            
            // Fallback: Use available_habits filtered by category
            let availableHabits: [AvailableHabit] = try await client.database
                .from("available_habits")
                .select()
                .eq("category", value: mappedCategory)
                .order("is_default", ascending: false)
                .limit(5)
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
            
            NSLog("[SupabaseManager] getTrendingHabitsByCategory: using fallback data with %d habits for category '%@'", trendingHabits.count, category)
            return trendingHabits
        }
    }
    
    // Helper function to check if a habit matches a target category
    private func matchesCategory(habit: TrendingHabit, targetCategory: String) -> Bool {
        let lowercasedTarget = targetCategory.lowercased()
        let lowercasedHabitCategory = habit.category.lowercased()
        let lowercasedHabitName = habit.name.lowercased()
        
        // First check if the habit category matches
        if lowercasedHabitCategory == lowercasedTarget {
            return true
        }
        
        // Then check if the habit name suggests the target category
        switch lowercasedTarget {
        case "fitness":
            return lowercasedHabitName.contains("steps") || lowercasedHabitName.contains("workout") ||
                   lowercasedHabitName.contains("exercise") || lowercasedHabitName.contains("run") ||
                   lowercasedHabitName.contains("gym") || lowercasedHabitName.contains("fitness")
        case "learning":
            return lowercasedHabitName.contains("read") || lowercasedHabitName.contains("learn") ||
                   lowercasedHabitName.contains("study") || lowercasedHabitName.contains("language") ||
                   lowercasedHabitName.contains("book") || lowercasedHabitName.contains("course")
        case "health":
            return lowercasedHabitName.contains("water") || lowercasedHabitName.contains("meal") ||
                   lowercasedHabitName.contains("diet") || lowercasedHabitName.contains("nutrition") ||
                   lowercasedHabitName.contains("vitamin") || lowercasedHabitName.contains("healthy")
        case "wellness":
            return lowercasedHabitName.contains("meditation") || lowercasedHabitName.contains("journal") ||
                   lowercasedHabitName.contains("sleep") || lowercasedHabitName.contains("mindfulness") ||
                   lowercasedHabitName.contains("breathing") || lowercasedHabitName.contains("yoga")
        case "productivity":
            return lowercasedHabitName.contains("work") || lowercasedHabitName.contains("productivity") ||
                   lowercasedHabitName.contains("focus") || lowercasedHabitName.contains("task") ||
                   lowercasedHabitName.contains("goal") || lowercasedHabitName.contains("plan")
        case "social":
            return lowercasedHabitName.contains("social") || lowercasedHabitName.contains("friend") ||
                   lowercasedHabitName.contains("family") || lowercasedHabitName.contains("call") ||
                   lowercasedHabitName.contains("meet") || lowercasedHabitName.contains("connect")
        case "nutrition":
            return lowercasedHabitName.contains("water") || lowercasedHabitName.contains("meal") ||
                   lowercasedHabitName.contains("diet") || lowercasedHabitName.contains("nutrition") ||
                   lowercasedHabitName.contains("vitamin") || lowercasedHabitName.contains("healthy")
        default:
            return false
        }
    }
    
    // Helper function to map UI category names to database category names
    private func mapUICategoryToDatabaseCategory(_ uiCategory: String) -> String {
        switch uiCategory.lowercased() {
        case "fitness":
            return "Fitness"
        case "wellness":
            return "Wellness"
        case "learning":
            return "Learning"
        case "nutrition":
            return "Nutrition"
        case "productivity":
            return "Productivity"
        case "health":
            return "Health"
        case "social":
            return "Social"
        default:
            // If no mapping found, try the original category name
            return uiCategory
        }
    }
    
    // MARK: - Trending Captures
    func getTrendingCapturesForHabits() async throws -> [TrendingCapture] {
        NSLog("[SupabaseManager] getTrendingCapturesForHabits: fetching trending captures from RPC function")
        
        do {
            NSLog("[SupabaseManager] getTrendingCapturesForHabits: calling RPC function...")
            
            let captures: [TrendingCapture] = try await client.database
                .rpc("get_trending_captures_for_habits")
                .execute()
                .value
            
            NSLog("[SupabaseManager] getTrendingCapturesForHabits: successfully fetched %d trending captures", captures.count)
            
            // Log first capture details for debugging
            if let firstCapture = captures.first {
                NSLog("[SupabaseManager] getTrendingCapturesForHabits: first capture - id: %@, habitName: %@, likeCount: %d", 
                      firstCapture.id.uuidString, firstCapture.habitName, firstCapture.likeCount)
            }
            
            return captures
        } catch {
            NSLog("[SupabaseManager] getTrendingCapturesForHabits: error %@, falling back to recent captures", error.localizedDescription)
            
            // Add detailed error logging
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    NSLog("[SupabaseManager] getTrendingCapturesForHabits: missing key '%@' at path %@", 
                          key.stringValue, context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .typeMismatch(let type, let context):
                    NSLog("[SupabaseManager] getTrendingCapturesForHabits: type mismatch for %@ at path %@", 
                          String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .valueNotFound(let type, let context):
                    NSLog("[SupabaseManager] getTrendingCapturesForHabits: value not found for %@ at path %@", 
                          String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .dataCorrupted(let context):
                    NSLog("[SupabaseManager] getTrendingCapturesForHabits: data corrupted at path %@: %@", 
                          context.codingPath.map { $0.stringValue }.joined(separator: "."), context.debugDescription)
                @unknown default:
                    NSLog("[SupabaseManager] getTrendingCapturesForHabits: unknown decoding error")
                }
            }
            
            NSLog("[SupabaseManager] getTrendingCapturesForHabits: trying fallback to recent captures...")
            
            // Fallback: Get recent public captures from the captures table
            let captures: [HabitCapture] = try await client.database
                .from("captures")
                .select()
                .eq("is_public", value: true)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            
            NSLog("[SupabaseManager] getTrendingCapturesForHabits: fallback fetched %d captures", captures.count)
            
            // Convert HabitCapture to TrendingCapture
            let trendingCaptures: [TrendingCapture] = captures.compactMap { capture in
                // Skip captures without habitTemplateId
                guard let habitTemplateId = capture.habitTemplateId else {
                    NSLog("[SupabaseManager] getTrendingCapturesForHabits: skipping capture %@ with nil habitTemplateId", capture.id.uuidString)
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
            
            NSLog("[SupabaseManager] getTrendingCapturesForHabits: using fallback data with %d captures", trendingCaptures.count)
            return trendingCaptures
        }
    }
    
    // MARK: - Capture Likes
    func toggleCaptureLike(captureId: UUID) async throws -> Bool {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        NSLog("[SupabaseManager] toggleCaptureLike: toggling like for capture %@", captureId.uuidString)
        
        do {
            let result: [String: Bool] = try await client.database
                .rpc("toggle_capture_like", params: [
                    "capture_uuid": captureId.uuidString,
                    "user_uuid": currentUser.id.uuidString
                ])
                .execute()
                .value
            
            let wasLiked = result["toggle_capture_like"] ?? false
            NSLog("[SupabaseManager] toggleCaptureLike: like %@", wasLiked ? "added" : "removed")
            return wasLiked
        } catch {
            NSLog("[SupabaseManager] toggleCaptureLike: error %@", error.localizedDescription)
            throw error
        }
    }
    
    func isCaptureLikedByUser(captureId: UUID) async throws -> Bool {
        guard let currentUser = try await getCurrentUser() else {
            return false
        }
        
        do {
            let result: [String: Bool] = try await client.database
                .rpc("is_capture_liked_by_user", params: [
                    "capture_uuid": captureId.uuidString,
                    "user_uuid": currentUser.id.uuidString
                ])
                .execute()
                .value
            
            return result["is_capture_liked_by_user"] ?? false
        } catch {
            NSLog("[SupabaseManager] isCaptureLikedByUser: error %@", error.localizedDescription)
            return false
        }
    }
    
    func getSocialFeedWithLikes() async throws -> [SocialFeedPost] {
        guard let currentUser = try await getCurrentUser() else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        NSLog("[SupabaseManager] getSocialFeedWithLikes: fetching social feed")
        
        do {
            let posts: [SocialFeedPost] = try await client.database
                .from("social_feed_with_likes")
                .select()
                .order("capture_created_at", ascending: false)
                .limit(50)
                .execute()
                .value
            
            // Update isLikedByCurrentUser for each post
            var updatedPosts: [SocialFeedPost] = []
            for var post in posts {
                let isLiked = try await isCaptureLikedByUser(captureId: post.captureId)
                // Create a new post with updated like status
                let updatedPost = SocialFeedPost(
                    captureId: post.captureId,
                    habitId: post.habitId,
                    habitTemplateId: post.habitTemplateId,
                    captureUserId: post.captureUserId,
                    imageUrl: post.imageUrl,
                    caption: post.caption,
                    isPublic: post.isPublic,
                    captureCreatedAt: post.captureCreatedAt,
                    habitName: post.habitName,
                    habitCategory: post.habitCategory,
                    userDisplayName: post.userDisplayName,
                    userAvatarUrl: post.userAvatarUrl,
                    likeCount: post.likeCount,
                    likedByUserIds: post.likedByUserIds,
                    isLikedByCurrentUser: isLiked
                )
                updatedPosts.append(updatedPost)
            }
            
            NSLog("[SupabaseManager] getSocialFeedWithLikes: successfully fetched %d posts", updatedPosts.count)
            return updatedPosts
        } catch {
            NSLog("[SupabaseManager] getSocialFeedWithLikes: error %@", error.localizedDescription)
            throw error
        }
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
        let rows: [AvailableHabit] = try await client.database
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
    
    // MARK: - Direct Habit creation via PostgREST (New Decoupled Schema with Uniqueness Check)
    func createHabitDirect(name: String, description: String?, category: String, targetFrequency: String, targetCount: Int? = nil) async throws -> Habit {
        let session = try await client.auth.session
        
        // First, try to find an existing habit template with the same name and category
        let existingTemplates: [HabitTemplate] = try await client.database
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
            let existingUserHabits: [UserHabit] = try await client.database
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
                NSLog("[SupabaseManager] createHabitDirect: user already has habit %@ for template %@", existingUserHabit.id.uuidString, existingTemplate.id.uuidString)
                
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
        let templateTemplates: [HabitTemplate] = try await client.database
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
            NSLog("[SupabaseManager] createHabitDirect: reusing existing template %@ for habit '%@'", existingTemplate.id.uuidString, name)
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
            
            let templateRows: [HabitTemplate] = try await client.database
                .from("habit_templates")
                .insert(templatePayload)
                .select()
                .limit(1)
                .execute()
                .value
            
            guard let newTemplate = templateRows.first else {
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create habit template"])
            }
            
            NSLog("[SupabaseManager] createHabitDirect: created new template %@ for habit '%@'", newTemplate.id.uuidString, name)
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
        
        let userHabitRows: [UserHabit] = try await client.database
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
    
    // MARK: - Storage Upload
    func uploadCaptureImage(imageData: Data, userId: UUID) async throws -> String {
        let userFolder = userId.uuidString.lowercased()
        let fileName = "\(userFolder)/\(UUID().uuidString).jpg"
        NSLog("[Supabase] uploadCaptureImage: uploading to captures_public/%@ (bytes=%d)", fileName, imageData.count)
        
        // Add timeout handling
        let options = FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        
        do {
            _ = try await withTimeout(seconds: 60) {
                try await self.client.storage
                    .from("captures_public")
                    .upload(path: fileName, file: imageData, options: options)
            }
            NSLog("[Supabase] uploadCaptureImage: uploaded path %@", fileName)
            return fileName
        } catch {
            NSLog("[Supabase] uploadCaptureImage: upload failed - %@", error.localizedDescription)
            throw error
        }
    }
    
    // Helper function for timeout handling
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
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
    
    // Get a signed URL for a capture image (respects RLS policies)
    func getSignedURLForCapture(path: String, expiresIn: Int = 3600) async throws -> String {
        print("🔐 Creating signed URL for path: \(path)")
        let signedURL = try await client.storage
            .from("captures")
            .createSignedURL(path: path, expiresIn: expiresIn)
        print("🔐 Created signed URL: \(signedURL.absoluteString)")
        return signedURL.absoluteString
    }
    
    // Upload image to trending-images bucket (public access)
    func uploadTrendingImage(imageData: Data, userId: UUID) async throws -> String {
        let userFolder = userId.uuidString.lowercased()
        let fileName = "\(userFolder)/\(UUID().uuidString).jpg"
        NSLog("[Supabase] uploadTrendingImage: uploading to trending-images/%@ (bytes=%d)", fileName, imageData.count)
        let options = FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        _ = try await client.storage
            .from("trending-images")
            .upload(path: fileName, file: imageData, options: options)
        NSLog("[Supabase] uploadTrendingImage: uploaded path %@", fileName)
        return fileName
    }
    
    // Add a capture to trending images
    func addCaptureToTrending(captureId: UUID, userId: UUID) async throws -> String {
        let result: [String] = try await client.rpc("add_capture_to_trending", params: [
            "capture_uuid": captureId.uuidString,
            "user_uuid": userId.uuidString
        ]).execute().value
        return result.first ?? ""
    }
    
    // Remove a capture from trending images
    func removeCaptureFromTrending(captureId: UUID) async throws -> Bool {
        let result: [Bool] = try await client.rpc("remove_capture_from_trending", params: [
            "capture_uuid": captureId.uuidString
        ]).execute().value
        return result.first ?? false
    }
    
    // Copy image from captures bucket to trending-images bucket
    func copyImageToTrending(originalPath: String, trendingPath: String) async throws {
        // Download the image from captures bucket
        let imageData = try await client.storage
            .from("captures")
            .download(path: originalPath)
        
        // Upload to trending-images bucket
        let options = FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        _ = try await client.storage
            .from("trending-images")
            .upload(path: trendingPath, file: imageData, options: options)
        
        NSLog("[Supabase] Copied image from captures/%@ to trending-images/%@", originalPath, trendingPath)
    }
    
    // Populate trending images by copying files
    func populateTrendingImages() async throws {
        // Get all trending image entries that need files copied
        let result: [TrendingImageEntry] = try await client.database
            .from("trending_images")
            .select("habit_id, capture_id, user_id, image_path")
            .eq("is_active", value: true)
            .execute()
            .value
        
        for entry in result {
            // Get the original capture path
            let capture: [Capture] = try await client.database
                .from("captures")
                .select("image_url")
                .eq("id", value: entry.captureId.uuidString)
                .execute()
                .value
            
            if let capture = capture.first, let originalPath = extractPathFromURL(capture.imageUrl) {
                // Copy the image file
                try await copyImageToTrending(originalPath: originalPath, trendingPath: entry.imagePath)
            }
        }
    }
    
    // Helper function to extract path from full URL
    private func extractPathFromURL(_ url: String?) -> String? {
        guard let url = url else { return nil }
        // Extract path from URL like: https://.../storage/v1/object/public/captures/user-id/uuid.jpg
        if let range = url.range(of: "/captures/") {
            let pathStart = url.index(range.upperBound, offsetBy: 0)
            return String(url[pathStart...])
        }
        return url
    }
    
    // Struct for trending image entries
    private struct TrendingImageEntry: Codable {
        let habitId: UUID
        let captureId: UUID
        let userId: UUID
        let imagePath: String
        
        enum CodingKeys: String, CodingKey {
            case habitId = "habit_id"
            case captureId = "capture_id"
            case userId = "user_id"
            case imagePath = "image_path"
        }
    }
    
    // MARK: - Captures insert (New Decoupled Schema with Habit Templates)
    func insertCapture(habitId: String, userId: UUID, imageUrl: String, caption: String?, isPublic: Bool) async throws -> HabitCapture {
        NSLog("[SupabaseManager] insertCapture: starting with habitId=%@, userId=%@", habitId, userId.uuidString)
        
        // Validate habitId format
        guard let habitUUID = UUID(uuidString: habitId) else {
            NSLog("[SupabaseManager] insertCapture: ERROR - Invalid habitId format: %@", habitId)
            throw NSError(domain: "ValidationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid habit ID format"])
        }
        
        // Get habit template ID from user_habits
        NSLog("[SupabaseManager] insertCapture: querying user_habits for habitId=%@", habitUUID.uuidString)
        
        struct UserHabitTemplate: Codable {
            let habitTemplateId: UUID
            
            enum CodingKeys: String, CodingKey {
                case habitTemplateId = "habit_template_id"
            }
        }
        
        let userHabits: [UserHabitTemplate] = try await client.database
            .from("user_habits")
            .select("habit_template_id")
            .eq("id", value: habitUUID)
            .limit(1)
            .execute()
            .value
        
        NSLog("[SupabaseManager] insertCapture: user_habits query returned %d results", userHabits.count)
        
        guard let userHabit = userHabits.first else {
            NSLog("[SupabaseManager] insertCapture: ERROR - No user_habit found for habitId=%@", habitUUID.uuidString)
            throw NSError(domain: "ValidationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Habit not found"])
        }
        
        NSLog("[SupabaseManager] insertCapture: validated habitId=%@, found templateId=%@", habitUUID.uuidString, userHabit.habitTemplateId.uuidString)
        
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
        
        NSLog("[SupabaseManager] insertCapture: created payload successfully")
        
        NSLog("[SupabaseManager] insertCapture: created payload with habit_template_id=%@, user_habit_id=%@", payload.habit_template_id.uuidString, payload.user_habit_id.uuidString)
        
        do {
            NSLog("[SupabaseManager] insertCapture: attempting database insert with payload: %@", String(describing: payload))
            
            // First, try to insert without selecting to see if the insert works
            let _ = try await client.database
                .from("captures")
                .insert(payload)
                .execute()
            
            NSLog("[SupabaseManager] insertCapture: database insert completed successfully")
            
            // Now fetch the inserted record
            let rows: [HabitCapture] = try await client.database
                .from("captures")
                .select()
                .eq("user_habit_id", value: habitUUID)
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            NSLog("[SupabaseManager] insertCapture: fetch completed, returned %d rows", rows.count)
            
            guard let row = rows.first else {
                NSLog("[SupabaseManager] insertCapture: ERROR - No rows returned from fetch")
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch created capture"])
            }
            
            NSLog("[SupabaseManager] insertCapture: successfully inserted capture %@ with habitId=%@, habitTemplateId=%@", 
                  row.id.uuidString, 
                  row.habitId?.uuidString ?? "nil", 
                  row.habitTemplateId?.uuidString ?? "nil")
            
            return row
        } catch {
            NSLog("[SupabaseManager] insertCapture: ERROR during database operation: %@", error.localizedDescription)
            
            // Add more detailed error logging
            if let postgrestError = error as? PostgrestError {
                NSLog("[SupabaseManager] insertCapture: PostgrestError details: %@", postgrestError.localizedDescription)
            }
            
            // Log the specific decoding error if it's a decoding error
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    NSLog("[SupabaseManager] insertCapture: Missing key '%@' at path %@", key.stringValue, context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .typeMismatch(let type, let context):
                    NSLog("[SupabaseManager] insertCapture: Type mismatch for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .valueNotFound(let type, let context):
                    NSLog("[SupabaseManager] insertCapture: Value not found for %@ at path %@", String(describing: type), context.codingPath.map { $0.stringValue }.joined(separator: "."))
                case .dataCorrupted(let context):
                    NSLog("[SupabaseManager] insertCapture: Data corrupted at path %@: %@", context.codingPath.map { $0.stringValue }.joined(separator: "."), context.debugDescription)
                @unknown default:
                    NSLog("[SupabaseManager] insertCapture: Unknown decoding error")
                }
            }
            
            throw error
        }
    }
    
private func makeAPICall(
    endpoint: String,
    method: String,
    body: Encodable? = nil,
    authenticated: Bool = false
) async throws -> Data {
    guard let url = URL(string: serverURL + endpoint) else {
        throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    if authenticated {
        let session = try await client.auth.session
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
    } else {
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    }
    
    if let body = body {
        request.httpBody = try JSONEncoder().encode(AnyEncodable(body))
    }
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
    
    guard httpResponse.statusCode == 200 else {
        let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw NSError(domain: "APIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
    }
    
    return data
}
// Helper to encode Encodable to Data
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ encodable: Encodable) {
        self.encodeFunc = encodable.encode
    }
    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

    // MARK: - Habit Categories
    
    func getHabitCategories() async throws -> [DatabaseHabitCategory] {
        NSLog("[SupabaseManager] getHabitCategories: fetching habit categories from database")
        
        do {
            let categories: [DatabaseHabitCategory] = try await client.database
                .rpc("get_habit_categories")
                .execute()
                .value
            
            NSLog("[SupabaseManager] getHabitCategories: successfully fetched %d habit categories", categories.count)
            return categories
        } catch {
            NSLog("[SupabaseManager] getHabitCategories: error %@ - categories not available", error.localizedDescription)
            throw error
        }
    }
    
    func getTrendingHabitsByCategoryId(_ categoryId: UUID) async throws -> [TrendingHabit] {
        NSLog("[SupabaseManager] getTrendingHabitsByCategoryId: fetching trending habits for category ID '%@'", categoryId.uuidString)
        
        do {
            let rows: [TrendingHabit] = try await client.database
                .rpc("get_trending_habits_by_category", params: ["category_id_param": categoryId])
                .execute()
                .value
            
            NSLog("[SupabaseManager] getTrendingHabitsByCategoryId: successfully fetched %d trending habits for category ID '%@'", rows.count, categoryId.uuidString)
            return rows
        } catch {
            NSLog("[SupabaseManager] getTrendingHabitsByCategoryId: error %@", error.localizedDescription)
            throw error
        }
    }
    
    func getCommunityStats() async throws -> CommunityStats {
        NSLog("[SupabaseManager] getCommunityStats: fetching community stats from database")
        
        do {
            let stats: [CommunityStats] = try await client.database
                .rpc("get_community_stats")
                .execute()
                .value
            
            if let firstStat = stats.first {
                NSLog("[SupabaseManager] getCommunityStats: successfully fetched stats - activeUsers: %d, totalHabits: %d, totalCaptures: %d", firstStat.activeUsers, firstStat.totalHabits, firstStat.totalCaptures)
                return firstStat
            } else {
                NSLog("[SupabaseManager] getCommunityStats: no stats returned, using default values")
                return CommunityStats(activeUsers: 0, totalHabits: 0, totalCaptures: 0)
            }
        } catch {
            NSLog("[SupabaseManager] getCommunityStats: error %@ - using default values", error.localizedDescription)
            return CommunityStats(activeUsers: 0, totalHabits: 0, totalCaptures: 0)
        }
    }
}
