import SwiftUI

struct SocialFeedView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var habitManager: HabitManager
    @StateObject private var imagePreloader = ImagePreloader.shared
    @State private var selectedTab = 0
    @State private var feedGroups: [SocialFeedGroup] = []
    @State private var isLoading = false
    @State private var selectedCaptures: [String: UUID] = [:] // groupId -> selected captureId
    @State private var showingComments = false
    @State private var selectedCaptureForComments: SocialFeedCapture?
    @State private var refreshTrigger = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Social Feed")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                    
                    // Tab Picker
                    Picker("Feed Tab", selection: $selectedTab) {
                        Text("Feed").tag(0)
                        Text("Groups").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Content
                TabView(selection: $selectedTab) {
                    SocialFeedTabView(
                        feedGroups: feedGroups,
                        isLoading: isLoading,
                        selectedCaptures: $selectedCaptures,
                        onReactionToggle: handleReactionToggle,
                        onCommentTap: handleCommentTap
                    )
                    .tag(0)
                    
                    SocialGroupsTabView()
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
            .task {
                await loadSocialFeed()
            }
            .refreshable {
                await refreshFeed()
            }
            .sheet(isPresented: $showingComments) {
                if let capture = selectedCaptureForComments {
                    CaptureCommentsView(capture: capture)
                }
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab == 0 {
                    Task {
                        await loadSocialFeed()
                    }
                }
            }
        }
    }
    
    private func loadSocialFeed() async {
        isLoading = true
        do {
            feedGroups = try await SupabaseManager.shared.getSocialFeedGroups()
            // Preload images for the feed groups
            await imagePreloader.preloadSocialFeedImages(for: feedGroups)
        } catch {
            print("Error loading social feed: \(error)")
        }
        isLoading = false
    }
    
    private func refreshFeed() async {
        refreshTrigger.toggle()
        await loadSocialFeed()
    }
    
    private func handleReactionToggle(for captureId: UUID) async {
        do {
            let result = try await SupabaseManager.shared.toggleCaptureReaction(captureId: captureId)
            print("Reaction toggle result: isLiked=\(result.isLiked), count=\(result.reactionCount)")
            
            // Update the local state - find the group that contains this capture
            for groupIndex in feedGroups.indices {
                if let captures = feedGroups[groupIndex].recentCaptures {
                    for captureIndex in captures.indices {
                        if captures[captureIndex].id == captureId {
                            feedGroups[groupIndex].recentCaptures?[captureIndex].isLikedByCurrentUser = result.isLiked
                            feedGroups[groupIndex].recentCaptures?[captureIndex].reactionCount = result.reactionCount
                            // Also update the group's overall reaction count
                            feedGroups[groupIndex].reactionCount = result.reactionCount
                            return
                        }
                    }
                }
            }
            
            // If not found in recent captures, update the group's main capture
            for groupIndex in feedGroups.indices {
                if feedGroups[groupIndex].lastCaptureId == captureId {
                    feedGroups[groupIndex].isLikedByCurrentUser = result.isLiked
                    feedGroups[groupIndex].reactionCount = result.reactionCount
                    return
                }
            }
        } catch {
            print("Error toggling reaction: \(error)")
        }
    }
    
    private func handleCommentTap(for capture: SocialFeedCapture) {
        selectedCaptureForComments = capture
        showingComments = true
    }
}

// MARK: - Social Feed Tab View

struct SocialFeedTabView: View {
    let feedGroups: [SocialFeedGroup]
    let isLoading: Bool
    @Binding var selectedCaptures: [String: UUID]
    let onReactionToggle: (UUID) async -> Void
    let onCommentTap: (SocialFeedCapture) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if feedGroups.isEmpty {
                    SocialFeedEmptyStateView(
                        icon: "person.2",
                        title: "No posts yet",
                        subtitle: "Complete some habits or follow friends to see their progress here!"
                    )
                } else {
                    ForEach(feedGroups) { group in
                        SocialFeedGroupCard(
                            group: group,
                            selectedCaptureId: selectedCaptures[group.id],
                            onCaptureSelect: { captureId in
                                selectedCaptures[group.id] = captureId
                            },
                            onReactionToggle: onReactionToggle,
                            onCommentTap: onCommentTap
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }
}

// MARK: - Social Feed Group Card

struct SocialFeedGroupCard: View {
    let group: SocialFeedGroup
    let selectedCaptureId: UUID?
    let onCaptureSelect: (UUID) -> Void
    let onReactionToggle: (UUID) async -> Void
    let onCommentTap: (SocialFeedCapture) -> Void
    
    private var selectedCapture: SocialFeedCapture {
        if let selectedId = selectedCaptureId,
           let capture = group.recentCaptures?.first(where: { $0.id == selectedId }) {
            return capture
        }
        // If no recent captures or no selection, use the last capture data from the group
        let fallbackCapture = SocialFeedCapture(
            id: group.lastCaptureId,
            imageUrl: group.lastCaptureImageUrl,
            caption: nil,
            createdAt: group.lastCaptureCreatedAt,
            reactionCount: group.reactionCount,
            commentCount: group.commentCount,
            isLikedByCurrentUser: group.isLikedByCurrentUser,
            reactionUsers: []
        )
        

        
        return group.recentCaptures?.first ?? fallbackCapture
    }
    
    private var otherCaptures: [SocialFeedCapture] {
        group.recentCaptures?.filter { $0.id != selectedCapture.id } ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Capture Image with Overlaid Header - Phone camera aspect ratio (9:16)
            ZStack(alignment: .top) {
                // Main image
                AsyncImage(url: URL(string: selectedCapture.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                .frame(height: 400) // 9:16 aspect ratio
                .clipped()
                
                // Category Badge - Top Right
                VStack {
                    HStack {
                        Spacer()
                        SocialFeedCategoryBadge(category: group.habitCategory, color: group.habitCategoryColor)
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                    }
                    Spacer()
                }
                
                // Overlaid Header Information
                VStack {
                    // Top gradient overlay for readability
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.black.opacity(0.2), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    
                    Spacer()
                }
                
                // User info overlay
                VStack {
                    HStack {
                        // User avatar and info
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: group.userAvatarUrl ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.title3)
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(group.userDisplayName ?? "Anonymous")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                
                                HStack(spacing: 4) {
                                    Text("@\(group.userUsername ?? "user")")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text("•")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text(timeAgoString(from: selectedCapture.createdAt))
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Streak indicator
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            
                            Text("\(group.currentStreak)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    Spacer()
                }
                
                // Previous Captures Preview Overlay - Bottom
                if !otherCaptures.isEmpty {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            HStack(spacing: 4) {
                                ForEach(Array(otherCaptures.enumerated()), id: \.element.id) { index, capture in
                                    Button(action: {
                                        onCaptureSelect(capture.id)
                                    }) {
                                        AsyncImage(url: URL(string: capture.imageUrl ?? "")) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                        }
                                        .frame(width: thumbnailSize(for: index), height: thumbnailSize(for: index))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            
            // Habit Info - Below Image
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(group.habitName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if let captures = group.recentCaptures, captures.count > 1 {
                        Text("\(captures.count) captures")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Reaction Stats
                if selectedCapture.reactionCount > 0 {
                    HStack(spacing: 8) {
                        // Reaction avatars
                        HStack(spacing: -8) {
                            ForEach(Array(selectedCapture.reactionUsers.prefix(4).enumerated()), id: \.element.id) { index, user in
                                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        )
                                }
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                .zIndex(Double(4 - index))
                            }
                        }
                        
                        Text("\(selectedCapture.reactionCount) reacted")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                }
                
                // Action Buttons - centered with icons only
                HStack(spacing: 60) {
                    Button(action: {
                        Task {
                            await onReactionToggle(selectedCapture.id)
                        }
                    }) {
                        Image(systemName: selectedCapture.isLikedByCurrentUser ? "flame.fill" : "flame")
                            .font(.title2)
                            .foregroundColor(selectedCapture.isLikedByCurrentUser ? .orange : .primary)
                    }
                    
                    Button(action: {
                        onCommentTap(selectedCapture)
                    }) {
                        Image(systemName: "message")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func thumbnailSize(for index: Int) -> CGFloat {
        // Reverse sizing: oldest (rightmost) is smallest, newest (leftmost) is largest
        switch index {
        case 0: return 32 // Smallest - oldest remaining
        case 1: return 36 // Small
        case 2: return 40 // Medium
        case 3: return 44 // Large
        default: return 48 // Largest - newest remaining
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Social Feed Category Badge

struct SocialFeedCategoryBadge: View {
    let category: String
    let color: String?
    
    private var categoryData: (emoji: String, color: Color) {
        switch category.lowercased() {
        case "fitness":
            return ("💪", CaptureTheme.Palette.fitness)
        case "wellness":
            return ("🧘", CaptureTheme.Palette.wellness)
        case "learning":
            return ("📚", CaptureTheme.Palette.learning)
        case "nutrition":
            return ("🥗", CaptureTheme.Palette.nutrition)
        case "productivity":
            return ("⚡", CaptureTheme.Palette.productivity)
        case "health":
            return ("🏥", CaptureTheme.Palette.health)
        case "social":
            return ("🤝", CaptureTheme.Palette.social)
        default:
            return ("🎯", .gray)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(categoryData.emoji)
                .font(.caption)
            
            Text(category)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(categoryData.color.opacity(0.2))
        .foregroundColor(categoryData.color)
        .cornerRadius(8)
    }
}

// MARK: - Social Groups Tab View

struct SocialGroupsTabView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SocialFeedEmptyStateView(
                    icon: "person.3",
                    title: "Groups coming soon",
                    subtitle: "Track habits with friends in groups!"
                )
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }
}

// MARK: - Capture Comments View

struct CaptureCommentsView: View {
    let capture: SocialFeedCapture
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [CaptureComment] = []
    @State private var newComment = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Comments List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 100)
                                        } else if comments.isEmpty {
                    SocialFeedEmptyStateView(
                        icon: "message",
                        title: "No comments yet",
                        subtitle: "Be the first to comment!"
                    )
                        } else {
                            ForEach(comments) { comment in
                                CommentCard(comment: comment)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
                
                // Comment Input
                HStack(spacing: 12) {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            self.hideKeyboard()
                        }
                    
                    Button("Post") {
                        Task {
                            await addComment()
                        }
                    }
                    .disabled(newComment.isEmpty)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                }
                .padding()
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadComments()
            }
        }
    }
    
    private func loadComments() async {
        isLoading = true
        do {
            comments = try await SupabaseManager.shared.getCaptureComments(captureId: capture.id)
        } catch {
            print("Error loading comments: \(error)")
        }
        isLoading = false
    }
    
    private func addComment() async {
        do {
            _ = try await SupabaseManager.shared.addCaptureComment(captureId: capture.id, content: newComment)
            newComment = ""
            await loadComments()
        } catch {
            print("Error adding comment: \(error)")
        }
    }
}

// MARK: - Comment Card

struct CommentCard: View {
    let comment: CaptureComment
    @State private var user: User?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: URL(string: user?.avatar ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user?.username ?? "Unknown User")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(timeAgoString(from: comment.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(comment.content)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct SocialFeedEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Extensions

extension ImagePreloader {
    func preloadSocialFeedImages(for groups: [SocialFeedGroup]) async {
        for group in groups {
            // Preload main capture image
            if let imageUrl = group.lastCaptureImageUrl {
                _ = await preloadImage(url: imageUrl)
            }
            
            // Preload recent capture images
            if let recentCaptures = group.recentCaptures {
                for capture in recentCaptures {
                    if let imageUrl = capture.imageUrl {
                        _ = await preloadImage(url: imageUrl)
                    }
                }
            }
        }
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    SocialFeedView()
        .environmentObject(SocialManager.shared)
        .environmentObject(HabitManager.shared)
}
