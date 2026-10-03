import SwiftUI

struct AuthView: View {
    @State private var isSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Logo and Title
                VStack(spacing: 16) {
                    Text("Capture")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(CaptureTheme.Typography.titleGradient())
                    
                    Text("Build habits with authentic moments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Auth Forms
                if isSignUp {
                    SignUpView()
                } else {
                    SignInView()
                }
                
                // Toggle Auth Mode
                Button(action: {
                    withAnimation { isSignUp.toggle() }
                }) {
                    HStack(spacing: 6) {
                        Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                            .foregroundColor(.secondary)
                        Text(isSignUp ? "Sign In" : "Sign Up")
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.bottom, 30)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .background(CaptureTheme.Palette.background)
        }
    }
}

struct SignInView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 16) {
            ThemedTextField(title: "Email", placeholder: "Enter your email", text: $email, keyboard: .emailAddress)
            ThemedSecureField(title: "Password", placeholder: "Enter your password", text: $password)
            
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task { await authManager.signIn(email: email, password: password) }
            }) {
                if authManager.isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                else { Text("Sign In").fontWeight(.semibold) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
        }
    }
}

struct SignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    
    var body: some View {
        VStack(spacing: 16) {
            ThemedTextField(title: "Username", placeholder: "Enter your username", text: $username)
            ThemedTextField(title: "Email", placeholder: "Enter your email", text: $email, keyboard: .emailAddress)
            ThemedSecureField(title: "Password", placeholder: "Enter your password", text: $password)
            
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                Task { await authManager.signUp(email: email, password: password, username: username) }
            }) {
                if authManager.isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                else { Text("Sign Up").fontWeight(.semibold) }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(10)
            .disabled(authManager.isLoading || email.isEmpty || password.isEmpty || username.isEmpty)
        }
    }
}

private struct ThemedTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .keyboardType(keyboard)
                .padding(12)
                .background(CaptureTheme.Palette.accent)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10).stroke(CaptureTheme.Palette.border, lineWidth: 1)
                )
                .onSubmit {
                    hideKeyboard()
                }
        }
    }
}

private struct ThemedSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            SecureField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .padding(12)
                .background(CaptureTheme.Palette.accent)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10).stroke(CaptureTheme.Palette.border, lineWidth: 1)
                )
                .onSubmit {
                    hideKeyboard()
                }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}

private func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}