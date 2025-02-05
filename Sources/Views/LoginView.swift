import SwiftUI
import ViewModels

struct LoginView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var email = ""
    @State private var password = ""
    @State private var showForgotPassword = false
    @State private var showSignUp = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [.blue.opacity(0.7), .purple.opacity(0.7)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Logo and Title
                        VStack(spacing: 8) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            
                            Text("DwellApp")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Find your perfect home")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 60)
                        
                        // Login Form
                        VStack(spacing: 16) {
                            // Email field
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                #if os(iOS)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                #endif
                            
                            // Password field
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                #if os(iOS)
                                .textContentType(.password)
                                #endif
                            
                            // Forgot password button
                            Button {
                                showForgotPassword = true
                            } label: {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            
                            // Login button
                            Button {
                                Task {
                                    do {
                                        try await authViewModel.signIn(email: email, password: password)
                                    } catch {
                                        alertMessage = error.localizedDescription
                                        showAlert = true
                                    }
                                }
                            } label: {
                                if authViewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Sign In")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(authViewModel.isLoading)
                            
                            // Sign up button
                            Button {
                                showSignUp = true
                            } label: {
                                Text("Don't have an account? Sign Up")
                                    .font(.footnote)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

#Preview {
    LoginView()
} 