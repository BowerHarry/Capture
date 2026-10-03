import Foundation
import Supabase

extension SupabaseManager {
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
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.currentUser }
        #endif
        do {
            let _ = try await client.auth.session
            return try await fetchCurrentProfile()
        } catch {
            return nil
        }
    }

    func updateProfile(userId: String, username: String?, bio: String?, avatar: String?) async throws -> User {
        let payload = UpdateProfilePayload(display_name: username, bio: bio, avatar_url: avatar)
        _ = try await client
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
            Log.error("No existing avatar to delete: \(error)")
        }
        
        // Upload to Supabase storage
        let _ = try await client.storage
            .from("avatars")
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg")
            )
        
        // Get public URL
        let publicURL = try client.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        
        return publicURL.absoluteString
    }

    func fetchCurrentProfile() async throws -> User {
        let session = try await client.auth.session
        let rows: [ProfileRow] = try await client
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
        let metadata = session.user.userMetadata
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
        _ = try await client
            .from("profiles")
            .insert(insertPayload)
            .execute()
        let created: [ProfileRow] = try await client
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

    func mapProfileRowToUser(_ p: ProfileRow) -> User {
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

    struct ProfileRow: Decodable {
        let id: UUID
        let email: String?
        let display_name: String?
        let avatar_url: String?
        let bio: String?
        let created_at: Date
        let updated_at: Date
    }

    struct UpdateProfilePayload: Encodable {
        let display_name: String?
        let bio: String?
        let avatar_url: String?
    }

    struct NewProfilePayload: Encodable {
        let id: UUID
        let email: String?
        let display_name: String?
        let avatar_url: String?
        let bio: String?
    }
}
