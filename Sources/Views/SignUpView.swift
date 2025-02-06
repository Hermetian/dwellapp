import SwiftUI
import ViewModels
import Core
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
    }
}

struct SignUpView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showTerms = false
    @State private var acceptedTerms = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    
    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        password == confirmPassword &&
        password.count >= 8 &&
        acceptedTerms
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Join DwellApp to find your perfect home")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Sign Up Form
                VStack(spacing: 16) {
                    // Name field
                    TextField("Full Name", text: $name)
                        .textFieldStyle(RoundedTextFieldStyle())
                        #if os(iOS)
                        .textContentType(.name)
                        #endif
                    
                    // Email field
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedTextFieldStyle())
                            #if os(iOS)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            #endif
                            .onChange(of: email) { _ in
                                emailError = nil
                            }
                        
                        if let error = emailError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedTextFieldStyle())
                            #if os(iOS)
                            .textContentType(.newPassword)
                            #endif
                            .onChange(of: password) { _ in
                                passwordError = nil
                            }
                        
                        if let error = passwordError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.vertical, 2)
                        }
                        
                        Text("Password Requirements:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        
                        PasswordRequirementView(
                            text: "At least 8 characters",
                            isMet: password.count >= 8
                        )
                        PasswordRequirementView(
                            text: "Contains at least one number (0-9)",
                            isMet: password.contains { $0.isNumber }
                        )
                    }
                    
                    // Confirm Password field
                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(RoundedTextFieldStyle())
                            #if os(iOS)
                            .textContentType(.newPassword)
                            #endif
                            
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Terms and Conditions
                    Toggle(isOn: $acceptedTerms) {
                        Button(action: { showTerms = true }) {
                            Text("I accept the Terms and Conditions")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Sign up button
                    Button {
                        Task {
                            do {
                                // Clear previous errors
                                emailError = nil
                                passwordError = nil
                                alertMessage = ""
                                showAlert = false
                                
                                print("📱 SignUpView: Starting signup process")
                                try await appViewModel.authViewModel.signUp(
                                    email: email,
                                    password: password,
                                    name: name
                                )
                                
                                print("📱 SignUpView: Signup successful, dismissing view")
                                dismiss()
                            } catch {
                                print("📱 SignUpView: Signup failed with error: \(error.localizedDescription)")
                                handleSignupError(error)
                            }
                        }
                    } label: {
                        if appViewModel.authViewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Creating Account...")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text("Create Account")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isFormValid || appViewModel.authViewModel.isLoading)
                    
                    // Back to login button
                    Button {
                        dismiss()
                    } label: {
                        Text("Already have an account? Sign In")
                            .font(.footnote)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .sheet(isPresented: $showTerms) {
            TermsView()
        }
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button("Cancel") {
                    dismiss()
                }
            }
            #endif
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func handleSignupError(_ error: Error) {
        if let authError = error as? Core.AuthError {
            switch authError {
            case .signUpError(let message):
                if message.contains("email") {
                    emailError = message
                } else if message.contains("password") || message.contains("Password") {
                    passwordError = message
                } else {
                    alertMessage = message
                    showAlert = true
                }
            default:
                alertMessage = error.localizedDescription
                showAlert = true
            }
        } else {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

struct PasswordRequirementView: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isMet ? .green : .gray)
            
            Text(text)
                .font(.caption)
                .foregroundColor(isMet ? .primary : .secondary)
        }
    }
}

struct TermsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Terms and Conditions")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("By using DwellApp, you agree to these terms...")
                        .font(.body)
                    
                    // Add your terms and conditions text here
                }
                .padding()
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

#Preview {
    NavigationView {
        SignUpView()
            .environmentObject(AppViewModel())
    }
} 