//import SwiftUI
//
//struct AuthView: View {
//    @EnvironmentObject var authManager: AuthManager
//    @State private var isSignUp = false
//    @State private var email = ""
//    @State private var password = ""
//    @State private var name = ""
//    @State private var confirmPassword = ""
//    
//    var body: some View {
//        NavigationView {
//            VStack(spacing: 32) {
//                // Header
//                VStack(spacing: 16) {
//                    Text("Capture")
//                        .font(.system(size: 48, weight: .bold))
//                        .foregroundColor(.primary)
//                    
//                    Text("Track your habits, capture your progress")
//                        .font(.system(size: 18))
//                        .foregroundColor(.secondary)
//                        .multilineTextAlignment(.center)
//                }
//                
//                // Auth Form
//                VStack(spacing: 20) {
//                    // Toggle between Sign In and Sign Up
//                    Picker("Auth Mode", selection: $isSignUp) {
//                        Text("Sign In").tag(false)
//                        Text("Sign Up").tag(true)
//                    }
//                    .pickerStyle(SegmentedPickerStyle())
//                    .padding(.horizontal)
//                    
//                    VStack(spacing: 16) {
//                        if isSignUp {
//                            TextField("Name", text: $name)
//                                .textFieldStyle(RoundedBorderTextFieldStyle())
//                                .autocapitalization(.words)
//                        }
//                        
//                        TextField("Email", text: $email)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//                            .keyboardType(.emailAddress)
//                            .autocapitalization(.none)
//                        
//                        SecureField("Password", text: $password)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//                        
//                        if isSignUp {
//                            SecureField("Confirm Password", text: $confirmPassword)
//                                .textFieldStyle(RoundedBorderTextFieldStyle())
//                        }
//                    }
//                    .padding(.horizontal)
//                    
//                    // Action Button
//                    Button(action: performAuth) {
//                        HStack {
//                            if authManager.isLoading {
//                                ProgressView()
//                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
//                                    .scaleEffect(0.8)
//                            }
//                            
//                            Text(isSignUp ? "Sign Up" : "Sign In")
//                                .font(.system(size: 16, weight: .semibold))
//                        }
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.accentColor)
//                        .foregroundColor(.white)
//                        .cornerRadius(12)
//                    }
//                    .disabled(authManager.isLoading || !isFormValid)
//                    .opacity(isFormValid ? 1.0 : 0.6)
//                    .padding(.horizontal)
//                    
//                    // Error Message
//                    if let errorMessage = authManager.errorMessage {
//                        Text(errorMessage)
//                            .font(.system(size: 14))
//                            .foregroundColor(.red)
//                            .multilineTextAlignment(.center)
//                            .padding(.horizontal)
//                    }
//                }
//                
//                Spacer()
//                
//                // Footer
//                VStack(spacing: 8) {
//                    Text("By continuing, you agree to our")
//                        .font(.system(size: 12))
//                        .foregroundColor(.secondary)
//                    
//                    HStack(spacing: 4) {
//                        Button("Terms of Service") {
//                            // Handle terms of service
//                        }
//                        .font(.system(size: 12))
//                        .foregroundColor(.accentColor)
//                        
//                        Text("and")
//                            .font(.system(size: 12))
//                            .foregroundColor(.secondary)
//                        
//                        Button("Privacy Policy") {
//                            // Handle privacy policy
//                        }
//                        .font(.system(size: 12))
//                        .foregroundColor(.accentColor)
//                    }
//                }
//            }
//            .padding()
//            .navigationBarHidden(true)
//        }
//    }
//    
//    private var isFormValid: Bool {
//        if isSignUp {
//            return !email.isEmpty && !password.isEmpty && !name.isEmpty && password == confirmPassword && password.count >= 6
//        } else {
//            return !email.isEmpty && !password.isEmpty
//        }
//    }
//    
//    private func performAuth() {
//        if isSignUp {
//            Task {
//                await authManager.signUp(email: email, password: password, name: name)
//            }
//        } else {
//            Task {
//                await authManager.signIn(email: email, password: password)
//            }
//        }
//    }
//}
//
//#Preview {
//    AuthView()
//        .environmentObject(AuthManager.shared)
//}
