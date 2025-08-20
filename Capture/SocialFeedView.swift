import SwiftUI

struct SocialFeedView: View {
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var habitManager: HabitManager
    @StateObject private var imagePreloader = ImagePreloader.shared
    @State private var selectedTab = 0
    @State private var showingCreatePost = false
    @State private var showingComments = false
    @State private var selectedPost: SocialPost?
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
                        
                        Button(action: { showingCreatePost = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Tab Picker
                    Picker("Feed Tab", selection: $selectedTab) {
                        Text("Following").tag(0)
                        Text("For You").tag(1)
                        Text("Trending").tag(2)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)
                .padding(.top)
                
                // Content
                TabView(selection: $selectedTab) {
                    FollowingFeedView()
                        .tag(0)
                    
                    ForYouFeedView()
                        .tag(1)
                    
                    TrendingFeedView()
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
            .task {
                await socialManager.loadPosts()
                // Preload social feed images after posts are loaded
                imagePreloader.preloadSocialFeedImages(for: socialManager.posts)
            }
            .refreshable {
                await refreshFeed()
            }
            .sheet(isPresented: $showingCreatePost) {
                CreatePostView()
            }
            .sheet(isPresented: $showingComments) {
                if let post = selectedPost {
                    CommentsView(post: post)
                }
            }
            .onTapGesture {
                self.hideKeyboard()
            }
        }
    }
    
    private func refreshFeed() async {
        refreshTrigger.toggle()
        await socialManager.loadPosts()
        // Preload social feed images after posts are loaded
        imagePreloader.preloadSocialFeedImages(for: socialManager.posts)
    }
}

// MARK: - Following Feed View

struct FollowingFeedView: View {
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if socialManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if socialManager.feedItems.isEmpty {
                    EmptyStateView(
                        icon: "person.2",
                        title: "No posts from people you follow",
                        subtitle: "Follow some people to see their habit journeys!"
                    )
                } else {
                    ForEach(socialManager.feedItems.filter { $0.isFollowing }) { item in
                        SocialPostCard(item: item)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }
}

// MARK: - For You Feed View

struct ForYouFeedView: View {
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if socialManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if socialManager.feedItems.isEmpty {
                    EmptyStateView(
                        icon: "sparkles",
                        title: "No recommendations yet",
                        subtitle: "Start following people to get personalized recommendations!"
                    )
                } else {
                    ForEach(socialManager.feedItems) { item in
                        SocialPostCard(item: item)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
    }
}

// MARK: - Trending Feed View

struct TrendingFeedView: View {
    @EnvironmentObject var socialManager: SocialManager
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if socialManager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if socialManager.feedItems.isEmpty {
                    EmptyStateView(
                        icon: "flame",
                        title: "No trending posts",
                        subtitle: "Be the first to create a trending post!"
                    )
                } else {
                    ForEach(socialManager.feedItems.sorted { $0.post.likes > $1.post.likes }) { item in
                        SocialPostCard(item: item)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .task {
            await socialManager.getTrendingPosts()
        }
    }
}

// MARK: - Social Post Card

struct SocialPostCard: View {
    let item: SocialFeedItem
    @EnvironmentObject var socialManager: SocialManager
    @State private var showingComments = false
    @State private var showingShare = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User Header
            HStack {
                AsyncImage(url: URL(string: item.user.avatar ?? "")) { image in
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
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.user.username)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(timeAgoString(from: item.post.createdAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    if item.user.id == socialManager.currentUserId {
                        Button("Delete", role: .destructive) {
                            Task {
                                await socialManager.deletePost(item.post)
                            }
                        }
                    } else {
                        Button(item.isFollowing ? "Unfollow" : "Follow") {
                            Task {
                                await socialManager.toggleFollow(userId: item.user.id)
                            }
                        }
                    }
                    
                    Button("Report") {
                        // Report post
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            // Content
            Text(item.post.content)
                .font(.body)
                .multilineTextAlignment(.leading)
            
            // Habit/Capture Info
            if let habit = item.habit {
                HStack {
                    Text(habit.icon ?? "⭐️")
                        .font(.title2)
                        .frame(width: 32, height: 32)
                        .background(habitColor(for: habit.color))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(habit.category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(habit.currentStreak)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("day streak")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Image
            if let imageUrl = item.post.imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { image in
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
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Actions
            HStack(spacing: 20) {
                Button(action: {
                    Task {
                        await socialManager.toggleLike(postId: item.post.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: item.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(item.isLiked ? .red : .primary)
                        Text("\(item.post.likes)")
                            .font(.caption)
                    }
                }
                
                Button(action: { showingComments = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                        Text("\(item.post.comments)")
                            .font(.caption)
                    }
                }
                
                Button(action: { showingShare = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                            .font(.caption)
                    }
                }
                
                Spacer()
            }
            .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingComments) {
            CommentsView(post: item.post)
        }
        .sheet(isPresented: $showingShare) {
            ShareSheet(items: [item.post.content])
        }
    }
    
    private func habitColor(for colorName: String?) -> Color {
        switch colorName?.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "gray": return .gray
        default: return .blue
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Create Post View

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var socialManager: SocialManager
    @EnvironmentObject var habitManager: HabitManager
    @State private var content = ""
    @State private var selectedHabit: Habit?
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingHabitPicker = false
    @State private var isPosting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Content Input
                VStack(spacing: 16) {
                    TextField("What's on your mind?", text: $content, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .lineLimit(5...10)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onSubmit {
                            self.hideKeyboard()
                        }
                    
                    // Selected Habit
                    if let habit = selectedHabit {
                        HStack {
                            Text(habit.icon ?? "⭐️")
                                .font(.title2)
                                .frame(width: 32, height: 32)
                                .background(habitColor(for: habit.color))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(habit.category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button("Remove") {
                                selectedHabit = nil
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Selected Image
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                Button("Remove") {
                                    selectedImage = nil
                                }
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .padding(8),
                                alignment: .topTrailing
                            )
                    }
                    
                    Spacer()
                }
                .padding()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: { showingHabitPicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Add Habit")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    Button(action: { showingImagePicker = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "camera.aperture")
                            Text("Add Photo")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        Task {
                            await createPost()
                        }
                    }
                    .disabled(content.isEmpty || isPosting)
                }
            }
            .sheet(isPresented: $showingHabitPicker) {
                HabitPickerView(selectedHabit: $selectedHabit)
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePickerCropper(selectedImage: $selectedImage)
            }
        }
    }
    
    private func createPost() async {
        isPosting = true
        
        var imageUrl: String?
        if let image = selectedImage {
            // Upload image and get URL
            // imageUrl = await uploadImage(image)
        }
        
        await socialManager.createPost(
            content: content,
            habitId: selectedHabit?.id,
            imageUrl: imageUrl
        )
        
        isPosting = false
        dismiss()
    }
    
    private func habitColor(for colorName: String?) -> Color {
        switch colorName?.lowercased() {
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "gray": return .gray
        default: return .blue
        }
    }
}

// MARK: - Comments View

struct CommentsView: View {
    let post: SocialPost
    @EnvironmentObject var socialManager: SocialManager
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [Comment] = []
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
                            EmptyStateView(
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
        comments = await socialManager.loadComments(postId: post.id)
        isLoading = false
    }
    
    private func addComment() async {
        await socialManager.addComment(postId: post.id, content: newComment)
        newComment = ""
        await loadComments()
    }
}

// MARK: - Supporting Views

struct CommentCard: View {
    let comment: Comment
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}



// MARK: - Extensions

extension SocialManager {
    var currentUserId: UUID? {
        // Return current user ID from auth manager
        return nil
    }
}

// MARK: - Utility Functions

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
