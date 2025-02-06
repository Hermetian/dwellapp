import Core
import SwiftUI
import ViewModels

public struct AuthView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showForgotPassword = false
    @State private var showEmailLinkSignIn = false
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo and Title
                VStack(spacing: 12) {
                    Image("Logo", bundle: .main)
                        .interpolation(.high)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    
                    Text("DwellApp")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Find your perfect home")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 40)
                
                Text(isSignUp ? "Create Account" : "Welcome Back")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Form Fields
                VStack(spacing: 15) {
                    if isSignUp {
                        TextField("Name", text: $name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            #if os(iOS)
                            .textContentType(.name)
                            #endif
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        #endif
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        #if os(iOS)
                        .textContentType(isSignUp ? .newPassword : .password)
                        #endif
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: handleSubmit) {
                        if appViewModel.authViewModel.isLoading {
                            ProgressView()
                        } else {
                            Text(isSignUp ? "Sign Up" : "Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .disabled(!isFormValid || appViewModel.authViewModel.isLoading)
                    
                    Button(action: { isSignUp.toggle() }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                            .foregroundColor(.blue)
                    }
                    
                    if !isSignUp {
                        HStack {
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Button("Sign in with Email Link") {
                                showEmailLinkSignIn = true
                            }
                        }
                        .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .sheet(isPresented: $showEmailLinkSignIn) {
            EmailLinkSignInView(authViewModel: appViewModel.authViewModel)
        }
    }
    
    private var isFormValid: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !name.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func handleSubmit() {
        Task {
            do {
                if isSignUp {
                    try await appViewModel.authViewModel.signUp(email: email, password: password, name: name)
                } else {
                    try await appViewModel.authViewModel.signIn(email: email, password: password)
                }
            } catch {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    public init() {}
}

#Preview {
    AuthView()
        .environmentObject(AppViewModel())
} 