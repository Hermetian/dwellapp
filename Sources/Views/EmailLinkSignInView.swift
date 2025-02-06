import SwiftUI
import ViewModels

public struct EmailLinkSignInView: View {
    @StateObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var showAlert = false
    @Environment(\.dismiss) private var dismiss
    
    public init(authViewModel: AuthViewModel) {
        _authViewModel = StateObject(wrappedValue: authViewModel)
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Sign in with Email Link")
                .font(.title)
                .fontWeight(.bold)
            
            Text("We'll send you an email with a sign-in link")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disabled(authViewModel.isLoading)
            
            Button(action: sendSignInLink) {
                if authViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Send Sign-in Link")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || authViewModel.isLoading)
            
            if authViewModel.showError {
                Text(authViewModel.error?.localizedDescription ?? "An error occurred")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .alert("Check Your Email", isPresented: $authViewModel.isEmailLinkSent) {
            Button("OK") { dismiss() }
        } message: {
            Text("We've sent a sign-in link to \(email). Please check your email to continue.")
        }
        .onAppear {
            // Listen for email link sign-in completion
            NotificationCenter.default.addObserver(
                forName: Notification.Name("HandleEmailSignInLink"),
                object: nil,
                queue: .main
            ) { notification in
                handleEmailSignInLink(notification)
            }
        }
    }
    
    private func sendSignInLink() {
        Task {
            do {
                try await authViewModel.sendSignInLink(email: email)
            } catch {
                // Error is already handled by the view model
            }
        }
    }
    
    private func handleEmailSignInLink(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let email = userInfo["email"] as? String,
              let link = userInfo["link"] as? String else {
            return
        }
        
        Task {
            do {
                try await authViewModel.signInWithEmailLink(email: email, link: link)
                dismiss()
            } catch {
                // Error is already handled by the view model
            }
        }
    }
}

#Preview {
    EmailLinkSignInView(authViewModel: AuthViewModel())
} 