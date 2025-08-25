import SwiftUI
import Foundation

// MARK: - Image Preloader

class ImagePreloader: ObservableObject {
    static let shared = ImagePreloader()
    
    // MARK: - Properties
    
    internal let cache = NSCache<NSString, UIImage>()
    private var imageCache: [String: UIImage] = [:]
    private var avatarCache: [String: UIImage] = [:]
    private var loadingTasks: [String: Task<Void, Never>] = [:]
    private let lockQueue = DispatchQueue(label: "imagePreloader.lock", attributes: .concurrent)
    
    // MARK: - Trending Thumbnail Properties
    
    private var trendingThumbnailCache: [String: UIImage] = [:]
    private var trendingThumbnailLoadingTasks: [String: Task<Void, Never>] = [:]
    private var trendingThumbnailCompletions: [String: [(UIImage?) -> Void]] = [:]
    
    init() {
        // Configure cache
        cache.countLimit = 100 // Maximum number of images to cache
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB limit
    }
    
    // MARK: - Preload Images
    
    func preloadImages(for urls: [String]) {
        Task {
            for url in urls {
                _ = await preloadImage(url: url)
            }
        }
    }
    
    // Non-async version for backward compatibility
    func preloadImageSync(url: String) {
        Task {
            _ = await preloadImage(url: url)
        }
    }
    
    func preloadImage(url: String) async -> UIImage? {
        guard !url.isEmpty else { return nil }
        
        // Normalize URL - add scheme if missing
        let normalizedURL = normalizeURL(url)
        guard let imageURL = URL(string: normalizedURL) else {
            print("❌ Invalid URL format: \(url)")
            return nil
        }
        
        // Check if already cached
        if let cached = cache.object(forKey: normalizedURL as NSString) {
            print("🖼️ Image already cached: \(normalizedURL)")
            return cached
        }
        
        // Check if already loading
        if loadingTasks[normalizedURL] != nil {
            print("🖼️ Image already loading: \(normalizedURL)")
            // Don't wait, just return nil to avoid race conditions
            return nil
        }
        
        print("🖼️ Starting to preload image: \(normalizedURL)")
        
        // Start loading
        let task = Task {
            await loadImage(url: imageURL, key: normalizedURL)
        }
        loadingTasks[normalizedURL] = task
        
        // Don't wait for completion, just return nil
        // The image will be available in cache when it's ready
        return nil
    }
    
    private func normalizeURL(_ urlString: String) -> String {
        // If URL already has a scheme, return as is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        // If it looks like a Supabase storage URL (contains /storage/), add https://
        if urlString.contains("/storage/") {
            return "https://" + urlString
        }
        
        // If it looks like a relative path or filename, it might be a Supabase storage path
        // Add the Supabase storage base URL
        if !urlString.contains("://") && !urlString.hasPrefix("/") {
            // This looks like a relative path, add the Supabase storage base URL
            return "https://your-project-ref.supabase.co/storage/v1/object/public/captures/" + urlString
        }
        
        // Default to adding https://
        return "https://" + urlString
    }
    
    private func loadImage(url: URL, key: String) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.cache.setObject(image, forKey: key as NSString)
                    self.loadingTasks.removeValue(forKey: key)
                    print("✅ Successfully cached image: \(key)")
                }
            } else {
                print("❌ Failed to create UIImage from data: \(key)")
            }
        } catch {
            await MainActor.run {
                self.loadingTasks.removeValue(forKey: key)
                print("❌ Failed to load image: \(key) - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Get Cached Image
    
    func getCachedImage(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        cache.removeAllObjects()
        loadingTasks.values.forEach { $0.cancel() }
        loadingTasks.removeAll()
    }
    
    // MARK: - Preload Specific Image Types
    
    func preloadUserAvatars(for users: [User]) {
        let avatarURLs = users.compactMap { $0.avatar }.filter { !$0.isEmpty }
        preloadImages(for: avatarURLs)
    }
    
    func preloadHabitCaptures(for habits: [Habit]) {
        // This function is called with habits, but we need captures
        // The actual implementation should be called with captures from HabitManager
    }
    
    func preloadCaptures(_ captures: [Capture]) {
        // Preload recent capture images
        let captureURLs = captures.compactMap { capture in
            capture.imageUrl
        }.filter { !$0.isEmpty }
        preloadImages(for: captureURLs)
    }
    
    func preloadHabitCaptures(_ captures: [HabitCapture]) {
        // Preload recent habit capture images
        let captureURLs = captures.compactMap { capture in
            capture.imageUrl
        }.filter { !$0.isEmpty }
        preloadImages(for: captureURLs)
    }
    
    func preloadSocialFeedImages(for posts: [SocialPost]) {
        let imageURLs = posts.compactMap { $0.imageUrl }.filter { !$0.isEmpty }
        preloadImages(for: imageURLs)
    }
}

// MARK: - Trending Thumbnail Methods

extension ImagePreloader {
    
    // Preload trending thumbnails for a list of URLs
    func preloadTrendingThumbnails(for urls: [String], size: CGSize) {
        Task {
            for url in urls {
                _ = await getTrendingThumbnail(for: url, size: size)
            }
        }
    }
    
    // Get trending thumbnail with caching (non-blocking)
    func getTrendingThumbnail(for url: String, size: CGSize) async -> UIImage? {
        guard !url.isEmpty else { return nil }
        
        // Normalize URL
        let normalizedURL = normalizeTrendingURL(url)
        
        // Check cache first
        if let cached = getCachedTrendingThumbnail(for: normalizedURL) {
            NSLog("[ImagePreloader] getTrendingThumbnail: found cached thumbnail for %@", normalizedURL)
            return cached
        }
        
        // Check if already loading - use lock to prevent race conditions
        return await lockQueue.sync {
            if trendingThumbnailLoadingTasks[normalizedURL] != nil {
                NSLog("[ImagePreloader] getTrendingThumbnail: already loading thumbnail for %@", normalizedURL)
                // Return nil immediately - don't wait to prevent blocking
                return nil
            }
            
            NSLog("[ImagePreloader] getTrendingThumbnail: loading thumbnail for %@", normalizedURL)
            
            // Start loading
            let task = Task {
                await loadTrendingThumbnail(url: normalizedURL, size: size)
            }
            trendingThumbnailLoadingTasks[normalizedURL] = task
            
            // Return nil immediately - the image will be cached when ready
            return nil
        }
    }
    
    // Get trending thumbnail with completion callback
    func getTrendingThumbnail(for url: String, size: CGSize, completion: @escaping (UIImage?) -> Void) {
        guard !url.isEmpty else { 
            completion(nil)
            return 
        }
        
        // Normalize URL
        let normalizedURL = normalizeTrendingURL(url)
        
        // Check cache first
        if let cached = getCachedTrendingThumbnail(for: normalizedURL) {
            NSLog("[ImagePreloader] getTrendingThumbnail: found cached thumbnail for %@", normalizedURL)
            completion(cached)
            return
        }
        
        // Check if already loading
        lockQueue.sync {
            if trendingThumbnailLoadingTasks[normalizedURL] != nil {
                NSLog("[ImagePreloader] getTrendingThumbnail: already loading thumbnail for %@", normalizedURL)
                // Store completion callback to be called when loading finishes
                if trendingThumbnailCompletions[normalizedURL] == nil {
                    trendingThumbnailCompletions[normalizedURL] = []
                }
                trendingThumbnailCompletions[normalizedURL]?.append(completion)
                return
            }
            
            NSLog("[ImagePreloader] getTrendingThumbnail: loading thumbnail for %@", normalizedURL)
            
            // Store completion callback
            if trendingThumbnailCompletions[normalizedURL] == nil {
                trendingThumbnailCompletions[normalizedURL] = []
            }
            trendingThumbnailCompletions[normalizedURL]?.append(completion)
            
            // Start loading
            let task = Task {
                await loadTrendingThumbnail(url: normalizedURL, size: size)
            }
            trendingThumbnailLoadingTasks[normalizedURL] = task
        }
    }
    
    // Check if trending thumbnail is cached (synchronous)
    func isTrendingThumbnailCached(for url: String) -> Bool {
        guard !url.isEmpty else { return false }
        let normalizedURL = normalizeTrendingURL(url)
        return getCachedTrendingThumbnail(for: normalizedURL) != nil
    }
    
    // Get cached trending thumbnail only (synchronous)
    func getCachedTrendingThumbnailOnly(for url: String) -> UIImage? {
        guard !url.isEmpty else { return nil }
        let normalizedURL = normalizeTrendingURL(url)
        return getCachedTrendingThumbnail(for: normalizedURL)
    }
    
    private func getCachedTrendingThumbnail(for url: String) -> UIImage? {
        return lockQueue.sync {
            return trendingThumbnailCache[url]
        }
    }
    
    private func setCachedTrendingThumbnail(_ image: UIImage, for url: String) {
        lockQueue.sync {
            trendingThumbnailCache[url] = image
        }
    }
    
    private func waitForTrendingThumbnailLoad(_ url: String) async {
        // Poll for up to 5 seconds (100 attempts * 50ms)
        for _ in 0..<100 {
            if getCachedTrendingThumbnail(for: url) != nil {
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }
    
    private func loadTrendingThumbnail(url: String, size: CGSize) async {
        guard let imageURL = URL(string: url) else {
            NSLog("[ImagePreloader] loadTrendingThumbnail: invalid URL %@", url)
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: imageURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                NSLog("[ImagePreloader] loadTrendingThumbnail: HTTP %d for %@", httpResponse.statusCode, url)
            }
            
            guard let originalImage = UIImage(data: data) else {
                NSLog("[ImagePreloader] loadTrendingThumbnail: failed to create image from data for %@", url)
                return
            }
            
            // Create thumbnail
            let thumbnail = await createThumbnail(from: originalImage, size: size)
            
            // Cache the thumbnail
            setCachedTrendingThumbnail(thumbnail, for: url)
            
            // Clean up loading task
            lockQueue.sync {
                trendingThumbnailLoadingTasks.removeValue(forKey: url)
            }
            
            // Call all completion callbacks
            lockQueue.sync {
                trendingThumbnailCompletions[url]?.forEach { $0(thumbnail) }
                trendingThumbnailCompletions[url] = [] // Clear completions after calling
            }
            
            NSLog("[ImagePreloader] loadTrendingThumbnail: successfully cached thumbnail for %@", url)
            
        } catch {
            NSLog("[ImagePreloader] loadTrendingThumbnail: error loading %@: %@", url, error.localizedDescription)
            
            // Clean up loading task
            lockQueue.sync {
                trendingThumbnailLoadingTasks.removeValue(forKey: url)
            }
            
            // Call all completion callbacks with nil
            lockQueue.sync {
                trendingThumbnailCompletions[url]?.forEach { $0(nil) }
                trendingThumbnailCompletions[url] = [] // Clear completions after calling
            }
        }
    }
    
    private func createThumbnail(from image: UIImage, size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderer = UIGraphicsImageRenderer(size: size)
                let thumbnail = renderer.image { context in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                continuation.resume(returning: thumbnail)
            }
        }
    }
    
    private func normalizeTrendingURL(_ urlString: String) -> String {
        // If URL already has a scheme, return as is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        // If it looks like a Supabase storage URL (contains /storage/), add https://
        if urlString.contains("/storage/") {
            return "https://" + urlString
        }
        
        // If it looks like a relative path or filename, it might be a Supabase storage path
        // Add the Supabase storage base URL for captures_public bucket
        if !urlString.contains("://") && !urlString.hasPrefix("/") {
            // This looks like a relative path, add the Supabase storage base URL for captures_public
            return "https://your-project-ref.supabase.co/storage/v1/object/public/captures_public/" + urlString
        }
        
        // Default to adding https://
        return "https://" + urlString
    }
    
    // Clear trending thumbnail cache
    func clearTrendingThumbnailCache() {
        lockQueue.sync {
            trendingThumbnailCache.removeAll()
            trendingThumbnailLoadingTasks.removeAll()
            trendingThumbnailCompletions.removeAll()
        }
    }
}

// MARK: - Preloadable AsyncImage

struct PreloadableAsyncImage<Content: View, Placeholder: View>: View {
    let url: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @StateObject private var preloader = ImagePreloader.shared
    @State private var cachedImage: UIImage?
    
    init(
        url: String?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let cachedImage = cachedImage {
                content(Image(uiImage: cachedImage))
            } else if let url = url, !url.isEmpty {
                let normalizedURL = normalizeURL(url)
                AsyncImage(url: URL(string: normalizedURL)) { image in
                    content(image)
                } placeholder: {
                    placeholder()
                }
            } else {
                placeholder()
            }
        }
        .task {
            if let url = url, !url.isEmpty {
                let normalizedURL = normalizeURL(url)
                // Check cache first
                if let cached = preloader.getCachedImage(for: normalizedURL) {
                    await MainActor.run {
                        cachedImage = cached
                    }
                } else {
                    // Start preloading (don't wait for result)
                    _ = await preloader.preloadImage(url: url)
                    
                    // Poll for the cached image to appear
                    await pollForCachedImage(normalizedURL)
                }
            }
        }
    }
    

    
    private func normalizeURL(_ urlString: String) -> String {
        // If URL already has a scheme, return as is
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        // If it looks like a Supabase storage URL (contains /storage/), add https://
        if urlString.contains("/storage/") {
            return "https://" + urlString
        }
        
        // If it looks like a relative path or filename, it might be a Supabase storage path
        // Add the Supabase storage base URL
        if !urlString.contains("://") && !urlString.hasPrefix("/") {
            // This looks like a relative path, add the Supabase storage base URL
            return "https://your-project-ref.supabase.co/storage/v1/object/public/captures/" + urlString
        }
        
        // Default to adding https://
        return "https://" + urlString
    }
    
    private func pollForCachedImage(_ url: String) async {
        // Poll for up to 3 seconds (60 attempts * 50ms)
        for _ in 0..<60 {
            if let cached = preloader.getCachedImage(for: url) {
                await MainActor.run {
                    cachedImage = cached
                }
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
    }
}



// MARK: - Preloadable Avatar View

struct PreloadableAvatarView: View {
    let user: User?
    let size: CGFloat
    
    init(user: User?, size: CGFloat = 80) {
        self.user = user
        self.size = size
    }
    
    private var avatarURL: URL? {
        guard let avatarString = user?.avatar, !avatarString.isEmpty else { return nil }
        // Add cache-busting parameter to force refresh
        var urlString = avatarString
        let timestamp = Int(Date().timeIntervalSince1970)
        let userId = user?.id.uuidString ?? ""
        if !urlString.contains("?") {
            urlString += "?t=\(timestamp)&u=\(userId)"
        } else {
            urlString += "&t=\(timestamp)&u=\(userId)"
        }
        return URL(string: urlString)
    }
    
    private var userInitial: String {
        user?.username.prefix(1).uppercased() ?? "U"
    }
    
    var body: some View {
        PreloadableAsyncImage(url: user?.avatar) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(Circle())
        } placeholder: {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.primary, .primary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Text(userInitial)
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(.white)
                )
        }
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 4)
        )
    }
}

// MARK: - Preloadable Habit Capture View

struct PreloadableHabitCaptureView: View {
    let captureURL: String?
    let size: CGSize
    
    init(captureURL: String?, size: CGSize = CGSize(width: 64, height: 64)) {
        self.captureURL = captureURL
        self.size = size
    }
    
    var body: some View {
        PreloadableAsyncImage(url: captureURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } placeholder: {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: size.width, height: size.height)
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                )
        }
    }
}
