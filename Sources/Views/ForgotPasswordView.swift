import SwiftUI
import ViewModels

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Reset Password")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .padding(.horizontal)
                
                Button {
                    Task {
                        do {
                            try await appViewModel.authViewModel.resetPassword(email: email)
                            alertMessage = "Password reset email sent. Please check your inbox and follow the instructions to reset your password."
                            showAlert = true
                        } catch {
                            alertMessage = error.localizedDescription
                            showAlert = true
                        }
                    }
                } label: {
                    if appViewModel.authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Send Reset Link")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .disabled(email.isEmpty || appViewModel.authViewModel.isLoading)
                
                Spacer()
            }
            .padding(.top, 50)
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertMessage.contains("sent") ? "Success" : "Error"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        if alertMessage.contains("sent") {
                            dismiss()
                        }
                    }
                )
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AppViewModel())
} 