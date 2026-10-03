import Foundation

/// Supabase connection settings.
///
/// Values are read from `Supabase.plist` in the app bundle, which is git-ignored.
/// Copy `Supabase.example.plist` to `Supabase.plist` and fill in your project's
/// URL and anon key. Without it the app still builds and demo mode still works,
/// but every network call fails.
enum SupabaseConfig {
    private static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Supabase", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            return [:]
        }
        return plist
    }()

    static let url = URL(string: values["SUPABASE_URL"] ?? "") ?? URL(string: "https://supabase.invalid")!
    static let anonKey = values["SUPABASE_ANON_KEY"] ?? ""

    /// Public URL for an object in a public storage bucket.
    static func publicStorageURL(bucket: String, path: String) -> String {
        url.appendingPathComponent("storage/v1/object/public/\(bucket)/\(path)").absoluteString
    }

    /// Turns a stored image reference into a loadable URL string. Full URLs are returned
    /// unchanged; bare paths are resolved against the given public bucket.
    static func normalizedImageURL(_ urlString: String, bucket: String) -> String {
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        if urlString.contains("/storage/") {
            return "https://" + urlString
        }
        if !urlString.contains("://") && !urlString.hasPrefix("/") {
            return publicStorageURL(bucket: bucket, path: urlString)
        }
        return "https://" + urlString
    }
}
