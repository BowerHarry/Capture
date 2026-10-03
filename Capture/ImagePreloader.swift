import SwiftUI
import Foundation

// MARK: - Image Preloader

class ImagePreloader: ObservableObject {
    static let shared = ImagePreloader()
    
    // MARK: - Properties
    
    internal let cache = NSCache<NSString, UIImage>()
    
    // Actor for thread-safe access to shared state
    private actor ImagePreloaderState {
        var loadingTasks: [String: Task<Void, Never>] = [:]
        var imageCache: [String: UIImage] = [:]
        var avatarCache: [String: UIImage] = [:]
        var trendingThumbnailCache: [String: UIImage] = [:]
        var trendingThumbnailLoadingTasks: [String: Task<Void, Never>] = [:]
        var trendingThumbnailCompletions: [String: [(UIImage?) -> Void]] = [:]
        
        // Methods for managing loading tasks
        func setLoadingTask(_ task: Task<Void, Never>, for key: String) {
            loadingTasks[key] = task
        }
        
        func removeLoadingTask(for key: String) {
            loadingTasks.removeValue(forKey: key)
        }
        
        func clearAllLoadingTasks() {
            loadingTasks.removeAll()
        }
        
        func getLoadingTask(for key: String) -> Task<Void, Never>? {
            return loadingTasks[key]
        }
        
        // Methods for managing trending thumbnail loading tasks
        func setTrendingThumbnailLoadingTask(_ task: Task<Void, Never>, for key: String) {
            trendingThumbnailLoadingTasks[key] = task
        }
        
        func removeTrendingThumbnailLoadingTask(for key: String) {
            trendingThumbnailLoadingTasks.removeValue(forKey: key)
        }
        
        func clearAllTrendingThumbnailLoadingTasks() {
            trendingThumbnailLoadingTasks.removeAll()
        }
        
        func getTrendingThumbnailLoadingTask(for key: String) -> Task<Void, Never>? {
            return trendingThumbnailLoadingTasks[key]
        }
        
        // Methods for managing trending thumbnail completions
        func addTrendingThumbnailCompletion(_ completion: @escaping (UIImage?) -> Void, for key: String) {
            if trendingThumbnailCompletions[key] == nil {
                trendingThumbnailCompletions[key] = []
            }
            trendingThumbnailCompletions[key]?.append(completion)
        }
        
        func getTrendingThumbnailCompletions(for key: String) -> [(UIImage?) -> Void] {
            return trendingThumbnailCompletions[key] ?? []
        }
        
        func clearTrendingThumbnailCompletions(for key: String) {
            trendingThumbnailCompletions[key] = []
        }
        
        func clearAllTrendingThumbnailCompletions() {
            trendingThumbnailCompletions.removeAll()
        }
        
        // Methods for managing caches
        func setImageCache(_ image: UIImage, for key: String) {
            imageCache[key] = image
        }
        
        func setAvatarCache(_ image: UIImage, for key: String) {
            avatarCache[key] = image
        }
        
        func setTrendingThumbnailCache(_ image: UIImage, for key: String) {
            trendingThumbnailCache[key] = image
        }
        
        func getTrendingThumbnailCache(for key: String) -> UIImage? {
            return trendingThumbnailCache[key]
        }
        
        func clearAllCaches() {
            imageCache.removeAll()
            avatarCache.removeAll()
            trendingThumbnailCache.removeAll()
        }
    }
    
    private let state = ImagePreloaderState()
    
    // MARK: - Performance Properties
    
    private var preloadQueue = DispatchQueue(label: "imagePreloader.preload", qos: .utility, attributes: .concurrent)
    private var highPriorityQueue = DispatchQueue(label: "imagePreloader.highPriority", qos: .userInitiated)
    private var backgroundQueue = DispatchQueue(label: "imagePreloader.background", qos: .background)
    
    // MARK: - Cache Statistics
    
    private var cacheHits = 0
    private var cacheMisses = 0
    private var totalLoadTime: TimeInterval = 0
    private var loadCount = 0
    
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
            Log.error("❌ Invalid URL format: \(url)")
            return nil
        }
        
        // Check if already cached
        if let cached = cache.object(forKey: normalizedURL as NSString) {
            cacheHits += 1
            return cached
        }
        
        cacheMisses += 1
        
        // Check if already loading with proper synchronization
        let isAlreadyLoading = await state.getLoadingTask(for: normalizedURL) != nil
        
        if isAlreadyLoading {
            // Don't wait, just return nil to avoid race conditions
            return nil
        }
        
        
        // Start loading with appropriate priority
        let task = Task {
            await loadImage(url: imageURL, key: normalizedURL)
        }
        
        // Add task to loadingTasks with proper synchronization
        await state.setLoadingTask(task, for: normalizedURL)
        
        // Don't wait for completion, just return nil
        // The image will be available in cache when it's ready
        return nil
    }
    
    // MARK: - High Priority Image Loading
    
    func preloadImageHighPriority(url: String) async -> UIImage? {
        guard !url.isEmpty else { return nil }
        
        let normalizedURL = normalizeURL(url)
        
        guard let imageURL = URL(string: normalizedURL) else {
            Log.error("❌ Invalid URL format: \(url)")
            return nil
        }
        
        // Check cache first
        if let cached = cache.object(forKey: normalizedURL as NSString) {
            cacheHits += 1
            return cached
        }
        
        cacheMisses += 1
        
        // Load immediately for high priority
        return await loadImageSync(url: imageURL, key: normalizedURL)
    }
    
    // MARK: - Batch Preloading
    
    func preloadImagesBatch(urls: [String], priority: PreloadPriority = .normal) async {
        let batchSize = 5 // Process in batches to avoid overwhelming the network
        
        for batch in urls.chunked(into: batchSize) {
            await withTaskGroup(of: Void.self) { group in
                for url in batch {
                    group.addTask {
                        switch priority {
                        case .high:
                            _ = await self.preloadImageHighPriority(url: url)
                        case .normal:
                            _ = await self.preloadImage(url: url)
                        case .low:
                            await self.preloadImageBackground(url: url)
                        }
                    }
                }
            }
            
            // Small delay between batches
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
    }
    
    // MARK: - Background Preloading
    
    func preloadImageBackground(url: String) async {
        guard !url.isEmpty else { return }
        
        let normalizedURL = normalizeURL(url)
        guard let imageURL = URL(string: normalizedURL) else { return }
        
        // Only preload if not already cached or loading with proper synchronization
        let isNotCached = cache.object(forKey: normalizedURL as NSString) == nil
        let isNotLoading = await state.getLoadingTask(for: normalizedURL) == nil
        let shouldPreload = isNotCached && isNotLoading
        
        if shouldPreload {
            Task {
                await loadImage(url: imageURL, key: normalizedURL)
            }
        }
    }
    
    // MARK: - Preload Priority
    
    enum PreloadPriority {
        case high
        case normal
        case low
    }
    
    private func normalizeURL(_ urlString: String) -> String {
        SupabaseConfig.normalizedImageURL(urlString, bucket: "captures")
    }
    
    private func loadImage(url: URL, key: String) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.cache.setObject(image, forKey: key as NSString)
                }
                // Remove task from loadingTasks with proper synchronization
                await state.removeLoadingTask(for: key)
            } else {
                Log.error("❌ Failed to create UIImage from data: \(key)")
                // Remove task from loadingTasks with proper synchronization
                await state.removeLoadingTask(for: key)
            }
        } catch {
            Log.error("❌ Failed to load image: \(key) - \(error.localizedDescription)")
            // Remove task from loadingTasks with proper synchronization
            await state.removeLoadingTask(for: key)
        }
    }
    
    private func loadImageSync(url: URL, key: String) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    self.cache.setObject(image, forKey: key as NSString)
                }
                return image
            } else {
                Log.error("❌ Failed to create UIImage from data: \(key)")
                return nil
            }
        } catch {
            Log.error("❌ Failed to load image: \(key) - \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Get Cached Image
    
    func getCachedImage(for url: String) -> UIImage? {
        return cache.object(forKey: url as NSString)
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        cache.removeAllObjects()
        
        Task {
            // Cancel and clear loading tasks with proper synchronization
            await state.clearAllLoadingTasks()
            await state.clearAllCaches()
            await state.clearAllTrendingThumbnailLoadingTasks()
            await state.clearAllTrendingThumbnailCompletions()
        }
        
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
    
    
    func preloadHabitCaptures(_ captures: [HabitCapture]) {
        // Preload recent habit capture images
        let captureURLs = captures.compactMap { capture in
            capture.imageUrl
        }.filter { !$0.isEmpty }
        preloadImages(for: captureURLs)
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
            return cached
        }
        
        // Check if already loading - use actor to prevent race conditions
        if await state.getTrendingThumbnailLoadingTask(for: normalizedURL) != nil {
            // Return nil immediately - don't wait to prevent blocking
            return nil
        }
        
        
        // Start loading
        let task = Task {
            await loadTrendingThumbnail(url: normalizedURL, size: size)
        }
        await state.setTrendingThumbnailLoadingTask(task, for: normalizedURL)
        
        // Return nil immediately - the image will be cached when ready
        return nil
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
            completion(cached)
            return
        }
        
        // Use async task to handle actor access
        Task {
            // Check if already loading
            if await state.getTrendingThumbnailLoadingTask(for: normalizedURL) != nil {
                // Store completion callback to be called when loading finishes
                await state.addTrendingThumbnailCompletion(completion, for: normalizedURL)
                return
            }
            
            
            // Store completion callback
            await state.addTrendingThumbnailCompletion(completion, for: normalizedURL)
            
            // Start loading
            let task = Task {
                await loadTrendingThumbnail(url: normalizedURL, size: size)
            }
            await state.setTrendingThumbnailLoadingTask(task, for: normalizedURL)
        }
    }
    
    
    // Get cached trending thumbnail only (synchronous)
    func getCachedTrendingThumbnailOnly(for url: String) -> UIImage? {
        guard !url.isEmpty else { return nil }
        let normalizedURL = normalizeTrendingURL(url)
        return getCachedTrendingThumbnail(for: normalizedURL)
    }
    
    private func getCachedTrendingThumbnail(for url: String) -> UIImage? {
        // This needs to be async, but we can't make it async due to existing API
        // For now, we'll use a synchronous approach with a semaphore
        let semaphore = DispatchSemaphore(value: 0)
        var result: UIImage?
        
        Task {
            result = await state.getTrendingThumbnailCache(for: url)
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
    
    private func setCachedTrendingThumbnail(_ image: UIImage, for url: String) {
        Task {
            await state.setTrendingThumbnailCache(image, for: url)
        }
    }
    
    
    private func loadTrendingThumbnail(url: String, size: CGSize) async {
        guard let imageURL = URL(string: url) else {
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            
            guard let originalImage = UIImage(data: data) else {
                Log.error(String(format: "[ImagePreloader] loadTrendingThumbnail: failed to create image from data for %@", url))
                return
            }
            
            // Create thumbnail
            let thumbnail = await createThumbnail(from: originalImage, size: size)
            
            // Cache the thumbnail
            setCachedTrendingThumbnail(thumbnail, for: url)
            
            // Clean up loading task
            await state.removeTrendingThumbnailLoadingTask(for: url)
            
            // Call all completion callbacks
            let completions = await state.getTrendingThumbnailCompletions(for: url)
            await state.clearTrendingThumbnailCompletions(for: url) // Clear completions after calling
            completions.forEach { $0(thumbnail) }
            
            
        } catch {
            Log.error(String(format: "[ImagePreloader] loadTrendingThumbnail: error loading %@: %@", url, error.localizedDescription))
            
            // Clean up loading task
            await state.removeTrendingThumbnailLoadingTask(for: url)
            
            // Call all completion callbacks with nil
            let completions = await state.getTrendingThumbnailCompletions(for: url)
            await state.clearTrendingThumbnailCompletions(for: url) // Clear completions after calling
            completions.forEach { $0(nil) }
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
        SupabaseConfig.normalizedImageURL(urlString, bucket: "captures_public")
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
        SupabaseConfig.normalizedImageURL(urlString, bucket: "captures")
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


// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
