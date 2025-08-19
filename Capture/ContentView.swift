import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var habitManager: HabitManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .onAppear {
            if authManager.isAuthenticated {
                Task { await habitManager.loadHabits() }
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthed in
            if isAuthed {
                Task { await habitManager.loadHabits() }
            }
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var selectedHabitId: UUID?
    @State private var showingDebugPanel = false
    @State private var isKeyboardVisible = false
    
    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 0) {
                // Content area
                ZStack {
                    switch selectedTab {
                    case 0:
                        HabitDashboardView(onNavigateToCamera: { habitId in
                            selectedHabitId = habitId
                            selectedTab = 2
                        })
                    case 1:
                        SocialFeedView()
                    case 2:
                        CameraCaptureView(
                            preselectedHabitId: selectedHabitId?.uuidString,
                            onBack: {
                                selectedHabitId = nil
                                selectedTab = 0
                            }
                        )
                    case 3:
                        DiscoveryView()
                            .environmentObject(AuthManager.shared)
                    case 4:
                        ProfileView()
                    default:
                        HabitDashboardView(onNavigateToCamera: { habitId in
                            selectedHabitId = habitId
                            selectedTab = 2
                        })
                    }
                }
            }
            
            // Custom floating tab bar
            if !isKeyboardVisible {
                VStack {
                    Spacer()
                    CustomTabBar(selectedTab: $selectedTab)
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.5)
                        .padding(.bottom, 10)
                }
                .allowsHitTesting(true)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isKeyboardVisible = false
            }
        }
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    private let tabs = [
        TabItem(icon: "house", title: "Home", tag: 0, gradient: [Color.blue, Color.purple], isSpecial: false),
        TabItem(icon: "person.2", title: "Feed", tag: 1, gradient: [Color.pink, Color.red], isSpecial: false),
        TabItem(icon: "camera.aperture", title: "Capture", tag: 2, gradient: [Color.orange, Color.red], isSpecial: true),
        TabItem(icon: "magnifyingglass", title: "Discover", tag: 3, gradient: [Color.green, Color.mint], isSpecial: false),
        TabItem(icon: "person", title: "Profile", tag: 4, gradient: [Color.orange, Color.yellow], isSpecial: false)
    ]
    

    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.tag) { tab in
                TabButtonView(
                    tab: tab,
                    isSelected: selectedTab == tab.tag,
                    onTap: { selectedTab = tab.tag }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
        )
    }
}

struct TabItem {
    let icon: String
    let title: String
    let tag: Int
    let gradient: [Color]
    let isSpecial: Bool
}

struct TabButtonView: View {
    let tab: TabItem
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding(8)
            .background(
                isSelected ?
                AnyShapeStyle(
                    LinearGradient(
                        colors: tab.gradient,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                ) : AnyShapeStyle(Color.clear)
            )
            .cornerRadius(12)
            .scaleEffect(isSelected ? 1.0 : 0.9)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(minWidth: 0, maxWidth: .infinity)
    }
}



#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
        .environmentObject(HabitManager.shared)
        .environmentObject(SocialManager.shared)
}
