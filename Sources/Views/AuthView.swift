import SwiftUI
import Services
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
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo and Title
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                
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
                        Button("Forgot Password?") {
                            showForgotPassword = true
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