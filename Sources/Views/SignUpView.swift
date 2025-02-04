import SwiftUI

struct SignUpView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showTerms = false
    @State private var acceptedTerms = false
    
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
                        .textContentType(.name)
                    
                    // Email field
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    // Password field
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.newPassword)
                    
                    // Confirm Password field
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .textContentType(.newPassword)
                    
                    // Password requirements
                    if !password.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            PasswordRequirementView(
                                text: "At least 8 characters",
                                isMet: password.count >= 8
                            )
                            PasswordRequirementView(
                                text: "Passwords match",
                                isMet: !confirmPassword.isEmpty && password == confirmPassword
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Terms and conditions
                    HStack {
                        Toggle("", isOn: $acceptedTerms)
                            .labelsHidden()
                        
                        Button {
                            showTerms = true
                        } label: {
                            Text("I accept the Terms and Conditions")
                                .font(.footnote)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Sign up button
                    Button {
                        Task {
                            await authViewModel.signUp(
                                email: email,
                                password: password,
                                name: name
                            )
                        }
                    } label: {
                        if authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Create Account")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isFormValid || authViewModel.isLoading)
                    
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
        .alert("Error", isPresented: .constant(authViewModel.error != nil)) {
            Button("OK") {
                authViewModel.error = nil
            }
        } message: {
            Text(authViewModel.error?.localizedDescription ?? "")
        }
        .sheet(isPresented: $showTerms) {
            TermsView()
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
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

#Preview {
    SignUpView()
} 