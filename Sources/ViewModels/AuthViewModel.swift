import Core
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
public class AuthViewModel: ObservableObject {
    @Published public var currentUser: Core.User?
    @Published public var isAuthenticated = false
    @Published public var error: Error?
    @Published public var isLoading = false
    @Published public var showError = false
    @Published public var isEmailLinkSent = false
    
    private var authService: AuthService!
    private var cancellables = Set<AnyCancellable>()
    
    public nonisolated init() {
        Task { @MainActor in
            self.authService = AuthService()
            setupAuthService()
        }
    }
    
    @MainActor
    private func setupAuthService() {
        // Observe auth state changes
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self = self else { return }
                print("🔐 Auth state change received - User: \(user?.email ?? "nil")")
                self.currentUser = user
                withAnimation {
                    self.isAuthenticated = user != nil
                }
                print("🔐 Auth state updated - isAuthenticated: \(user != nil)")
                objectWillChange.send()  // Force UI update
            }
            .store(in: &cancellables)
    }
    
    private func ensureServiceInitialized() {
        assert(authService != nil, "AuthService not initialized. Ensure all auth operations are performed after initialization.")
    }
    
    public func validatePassword(_ password: String) -> Bool {
        // Password must be at least 8 characters long and contain at least one number
        return password.count >= 8 && password.contains { $0.isNumber }
    }
    
    public func clearError() {
        error = nil
        showError = false
    }
    
    private func handleError(_ error: Error) {
        self.error = error
        self.showError = true
        self.isLoading = false
    }
    
    public func signIn(email: String, password: String) async throws {
        ensureServiceInitialized()
        guard !isLoading else { return }
        guard !email.isEmpty && !password.isEmpty else {
            handleError(AuthError.signInError("Please enter your email and password"))
            throw AuthError.signInError("Please enter your email and password")
        }
        
        isLoading = true
        clearError()
        
        do {
            print("📝 Starting sign in process...")
            try await authService.signIn(email: email, password: password)
            await MainActor.run {
                print("✅ Sign in successful, updating isAuthenticated...")
                withAnimation {
                    self.isAuthenticated = true
                }
                objectWillChange.send()
                print("✅ isAuthenticated set to true")
            }
        } catch let error as NSError {
            print("❌ Sign in error: \(error)")
            isLoading = false
            if error.domain == AuthErrorDomain {
                switch error.code {
                case AuthErrorCode.wrongPassword.rawValue:
                    let error = AuthError.signInError("Incorrect password. Please try again.")
                    handleError(error)
                    throw error
                case AuthErrorCode.userNotFound.rawValue:
                    let error = AuthError.signInError("No account found with this email. Please sign up first.")
                    handleError(error)
                    throw error
                case AuthErrorCode.invalidEmail.rawValue:
                    let error = AuthError.signInError("Please enter a valid email address")
                    handleError(error)
                    throw error
                case AuthErrorCode.userDisabled.rawValue:
                    let error = AuthError.signInError("This account has been disabled")
                    handleError(error)
                    throw error
                case AuthErrorCode.tooManyRequests.rawValue:
                    let error = AuthError.signInError("Too many failed attempts. Please try again later.")
                    handleError(error)
                    throw error
                case AuthErrorCode.networkError.rawValue:
                    let error = AuthError.signInError("Network error. Please check your connection and try again.")
                    handleError(error)
                    throw error
                default:
                    let error = AuthError.signInError("Failed to sign in: \(error.localizedDescription)")
                    handleError(error)
                    throw error
                }
            } else {
                let error = AuthError.signInError("An unexpected error occurred. Please try again.")
                handleError(error)
                throw error
            }
        }
        
        isLoading = false
    }
    
    public func signUp(email: String, password: String, name: String) async throws {
        print("🚀 AuthViewModel: Starting signup process")
        guard !isLoading else {
            print("⚠️ AuthViewModel: Signup already in progress")
            return
        }
        guard !email.isEmpty && !password.isEmpty && !name.isEmpty else {
            print("⚠️ AuthViewModel: Missing required fields")
            let error = AuthError.signUpError("Please fill in all required fields")
            handleError(error)
            throw error
        }
        
        // Check password requirements separately for clearer error messages
        if password.count < 8 {
            print("⚠️ AuthViewModel: Password too short")
            let error = AuthError.signUpError("Password must be at least 8 characters long")
            handleError(error)
            throw error
        }
        
        if !password.contains(where: { $0.isNumber }) {
            print("⚠️ AuthViewModel: Password missing number")
            let error = AuthError.signUpError("Password must contain at least one number")
            handleError(error)
            throw error
        }
        
        print("📝 AuthViewModel: All validation passed, proceeding with signup")
        isLoading = true
        clearError()
        
        do {
            print("🔐 AuthViewModel: Calling AuthService.signUp")
            try await authService.signUp(email: email, password: password, name: name)
            print("✅ AuthViewModel: Signup successful")
        } catch {
            print("❌ AuthViewModel: Signup failed with error: \(error.localizedDescription)")
            isLoading = false
            handleError(error)
            throw error
        }
        
        isLoading = false
    }
    
    public func signOut() async throws {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            try await authService.signOut()
            currentUser = nil
            isAuthenticated = false
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    public func resetPassword(email: String) async throws {
        guard !isLoading else { return }
        guard !email.isEmpty else {
            handleError(AuthError.resetPasswordError("Email is required"))
            return
        }
        
        isLoading = true
        clearError()
        
        do {
            try await authService.resetPassword(email: email)
        } catch {
            handleError(error)
            throw error
        }
        
        isLoading = false
    }
    
    public func updatePassword(newPassword: String) async throws {
        guard !isLoading else { return }
        guard validatePassword(newPassword) else {
            self.error = AuthError.updatePasswordError("Password must be at least 8 characters long and contain at least one number")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await authService.updatePassword(newPassword: newPassword)
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    public func deleteAccount() async throws {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            try await authService.deleteAccount()
            currentUser = nil
            isAuthenticated = false
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    public func sendSignInLink(email: String) async throws {
        guard !isLoading else { return }
        guard !email.isEmpty else {
            handleError(AuthError.signInError("Email is required"))
            return
        }
        
        isLoading = true
        clearError()
        
        do {
            try await authService.sendSignInLink(toEmail: email)
            isEmailLinkSent = true
        } catch {
            handleError(error)
            throw error
        }
        
        isLoading = false
    }
    
    public func signInWithEmailLink(email: String, link: String) async throws {
        guard !isLoading else { return }
        guard !email.isEmpty && !link.isEmpty else {
            handleError(AuthError.signInError("Email and link are required"))
            return
        }
        
        isLoading = true
        clearError()
        
        do {
            try await authService.signInWithEmailLink(email: email, link: link)
        } catch {
            handleError(error)
            throw error
        }
        
        isLoading = false
    }
    
    public func linkWithEmailLink(email: String, link: String) async throws {
        guard !isLoading else { return }
        guard !email.isEmpty && !link.isEmpty else {
            handleError(AuthError.signInError("Email and link are required"))
            return
        }
        
        isLoading = true
        clearError()
        
        do {
            try await authService.linkWithEmailLink(email: email, link: link)
        } catch {
            handleError(error)
            throw error
        }
        
        isLoading = false
    }
} 