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
            let rows: [Habit] = try await client.database
                .from("habits")
                .select()
                .eq("user_id", value: currentUser.id)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            NSLog("[SupabaseManager] getHabits: successfully fetched %d habits", rows.count)
            return rows
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
            let rows: [Habit] = try await client.database
                .from("habits")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            NSLog("[SupabaseManager] getHabits: successfully fetched %d habits", rows.count)
            return rows
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
        let session = try await client.auth.session
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let sinceStr = iso.string(from: since)
        let rows: [HabitCapture] = try await client.database
            .from("captures")
            .select()
            .eq("user_id", value: session.user.id)
            .gte("created_at", value: sinceStr)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows
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
    
    // MARK: - Direct Habit creation via PostgREST
    func createHabitDirect(name: String, description: String?, category: String, targetFrequency: String, targetCount: Int? = nil) async throws -> Habit {
        struct InsertHabit: Encodable {
            let user_id: UUID
            let name: String
            let description: String?
            let category: String
            let target_frequency: String
            let target_count: Int?
        }
        let session = try await client.auth.session
        let payload = InsertHabit(
            user_id: session.user.id,
            name: name,
            description: description,
            category: category,
            target_frequency: targetFrequency,
            target_count: targetCount
        )
        let rows: [Habit] = try await client.database
            .from("habits")
            .insert(payload)
            .select()
            .limit(1)
            .execute()
            .value
        guard let habit = rows.first else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create habit"])
        }
        return habit
    }
    
    // MARK: - Storage Upload
    func uploadCaptureImage(imageData: Data, userId: UUID) async throws -> String {
        let userFolder = userId.uuidString.lowercased()
        let fileName = "\(userFolder)/\(UUID().uuidString).jpg"
        NSLog("[Supabase] uploadCaptureImage: uploading to captures/%@ (bytes=%d)", fileName, imageData.count)
        let options = FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
        _ = try await client.storage
            .from("captures")
            .upload(path: fileName, file: imageData, options: options)
        NSLog("[Supabase] uploadCaptureImage: uploaded path %@", fileName)
        return fileName
    }
    
    // MARK: - Captures insert
    func insertCapture(habitId: String, userId: UUID, imageUrl: String, caption: String?, isPublic: Bool) async throws -> HabitCapture {
        struct InsertCapture: Encodable {
            let habit_id: UUID
            let user_id: UUID
            let image_url: String
            let caption: String?
            let is_public: Bool
        }
        let payload = InsertCapture(habit_id: UUID(uuidString: habitId)!, user_id: userId, image_url: imageUrl, caption: caption, is_public: isPublic)
        let rows: [HabitCapture] = try await client.database
            .from("captures")
            .insert(payload)
            .select()
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else {
            throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create capture"])
        }
        return row
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
}
