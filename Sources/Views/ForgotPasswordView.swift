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
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                Button {
                    Task {
                        do {
                            try await appViewModel.authViewModel.resetPassword(email: email)
                            alertMessage = "Password reset email sent. Please check your inbox."
                            showAlert = true
                        } catch {
                            alertMessage = error.localizedDescription
                            showAlert = true
                        }
                    }
                } label: {
                    Text("Send Reset Link")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(email.isEmpty)
                
                Spacer()
            }
            .padding(.top, 50)
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") {
                if !alertMessage.contains("error") {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(AppViewModel())
} 