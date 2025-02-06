import Core
import SwiftUI
import Combine

@MainActor
public class AuthViewModel: ObservableObject {
    @Published public var currentUser: User?
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
            handleError(AuthError.signInError("Email and password are required"))
            return
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
                objectWillChange.send()  // Force UI update
                print("✅ isAuthenticated set to true")
            }
        } catch {
            handleError(error)
            throw error
        }
        
        isLoading = false
    }
    
    public func signUp(email: String, password: String, name: String) async throws {
        guard !isLoading else { return }
        guard !email.isEmpty && !password.isEmpty && !name.isEmpty else {
            handleError(AuthError.signUpError("All fields are required"))
            return
        }
        
        guard validatePassword(password) else {
            handleError(AuthError.signUpError("Password must be at least 8 characters and contain at least one number"))
            return
        }
        
        isLoading = true
        clearError()
        
        do {
            try await authService.signUp(email: email, password: password, name: name)
        } catch {
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