import Foundation
import Supabase

extension SupabaseManager {
    func getSocialFeedGroups(limit: Int = 10, offset: Int = 0) async throws -> [SocialFeedGroup] {
        #if DEBUG
        if DemoMode.isEnabled { return DemoData.socialFeedGroups }
        #endif
        
        // Temporarily use fallback function until optimized function parameter types are fixed
        let groups: [SocialFeedGroup] = try await client.rpc("get_social_feed_groups", params: [
            "limit_param": limit,
            "offset_param": offset
        ]).execute().value
        
        return groups
    }

    func toggleCaptureReaction(captureId: UUID) async throws -> (isLiked: Bool, reactionCount: Int) {
        // Direct table operations rather than an RPC
        do {
            let currentUserId = try await client.auth.session.user.id
            
            // First check if user already reacted
            let existingReactions: [CaptureReaction] = try await client
                .from("capture_reactions")
                .select()
                .eq("capture_id", value: captureId)
                .eq("user_id", value: currentUserId)
                .execute()
                .value
            
            let alreadyReacted = !existingReactions.isEmpty
            
            if alreadyReacted {
                // Remove existing reaction
                try await client
                    .from("capture_reactions")
                    .delete()
                    .eq("capture_id", value: captureId)
                    .eq("user_id", value: currentUserId)
                    .execute()
                
            } else {
                // Add new reaction
                try await client
                    .from("capture_reactions")
                    .insert([
                        "capture_id": captureId.uuidString,
                        "user_id": currentUserId.uuidString,
                        "reaction_type": "fire"
                    ])
                    .execute()
                
            }
            
            // Get updated reaction count
            let allReactions: [CaptureReaction] = try await client
                .from("capture_reactions")
                .select()
                .eq("capture_id", value: captureId)
                .execute()
                .value
            
            let reactionCount = allReactions.count
            let isLiked = !alreadyReacted // If we just added, then it's liked
            
            return (isLiked: isLiked, reactionCount: reactionCount)
            
        } catch {
            Log.error(String(format: "[SupabaseManager] toggleCaptureReaction: error %@", error.localizedDescription))
            throw error
        }
    }

    func getCaptureComments(captureId: UUID) async throws -> [CaptureComment] {
        #if DEBUG
        if DemoMode.isEnabled { return [] }
        #endif
        
        do {
            let comments: [CaptureComment] = try await client
                .from("capture_comments")
                .select()
                .eq("capture_id", value: captureId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return comments
        } catch {
            Log.error(String(format: "[SupabaseManager] getCaptureComments: error %@", error.localizedDescription))
            throw error
        }
    }

    func addCaptureComment(captureId: UUID, content: String) async throws -> CaptureComment {
        
        do {
            let comment: [CaptureComment] = try await client
                .from("capture_comments")
                .insert([
                    "capture_id": captureId.uuidString,
                    "content": content
                ])
                .select()
                .limit(1)
                .execute()
                .value
            
            if let newComment = comment.first {
                return newComment
            } else {
                throw NSError(domain: "APIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create comment"])
            }
        } catch {
            Log.error(String(format: "[SupabaseManager] addCaptureComment: error %@", error.localizedDescription))
            throw error
        }
    }
}
