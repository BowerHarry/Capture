import SwiftUI

struct UserProfileView: View {
    let userId: String
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                Text("User Profile - Coming Soon")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("User Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UserProfileView(userId: "test", onDismiss: {})
}