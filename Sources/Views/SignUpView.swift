import SwiftUI
import ViewModels

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .textBackgroundColor))
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
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        #if os(iOS)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        #endif
                    
                    // Password field
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedTextFieldStyle())
                        #if os(iOS)
                        .textContentType(.newPassword)
                        #endif
                    
                    // Confirm Password field
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedTextFieldStyle())
                        #if os(iOS)
                        .textContentType(.newPassword)
                        #endif
                    
                    // Password requirements
                    if !password.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            PasswordRequirementView(
                                text: "At least 8 characters",
                                isMet: password.count >= 8
                            )
                            PasswordRequirementView(
                                text: "Contains a number",
                                isMet: password.contains { $0.isNumber }
                            )
                        }
                        .padding(.vertical, 4)
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
                                try await appViewModel.authViewModel.signUp(
                                    email: email,
                                    password: password,
                                    name: name
                                )
                                dismiss()
                            } catch {
                                // Error is handled by the view model
                            }
                        }
                    } label: {
                        if appViewModel.authViewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
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
        .alert("Error", isPresented: $appViewModel.authViewModel.showError) {
            Button("OK") {
                appViewModel.authViewModel.clearError()
            }
        } message: {
            Text(appViewModel.authViewModel.error?.localizedDescription ?? "")
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