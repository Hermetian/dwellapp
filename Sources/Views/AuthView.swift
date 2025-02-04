import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var isSignUp = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showForgotPassword = false
    
    var body: some View {
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
                            .autocapitalization(.words)
                    }
                    
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Sign In/Up Button
                Button(action: {
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
                }) {
                    if appViewModel.authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .background(Color.blue)
                .cornerRadius(10)
                .padding(.horizontal)
                .disabled(appViewModel.authViewModel.isLoading)
                
                // Toggle Sign In/Up
                Button(action: {
                    isSignUp.toggle()
                    email = ""
                    password = ""
                    name = ""
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
                
                // Forgot Password
                if !isSignUp {
                    Button("Forgot Password?") {
                        showForgotPassword = true
                    }
                    .foregroundColor(.gray)
                }
            }
            .padding()
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $showForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AppViewModel())
} 