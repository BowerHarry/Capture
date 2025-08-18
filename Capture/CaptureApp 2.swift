import SwiftUI

@main
struct CaptureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthManager.shared)
                .environmentObject(HabitManager.shared)
                .environmentObject(SocialManager.shared)
        }
    }
}