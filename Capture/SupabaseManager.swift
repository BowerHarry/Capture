import Foundation
import Supabase

/// Single entry point for backend access. The calls themselves live in the
/// `SupabaseManager+*.swift` extensions, grouped by domain.
class SupabaseManager {
    static let shared = SupabaseManager()

    lazy var client: SupabaseClient = {
        SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }()

    private init() {}
}
