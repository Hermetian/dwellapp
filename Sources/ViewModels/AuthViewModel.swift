import SwiftUI
import Models
import Combine
import Services

@MainActor
public class AuthViewModel: ObservableObject {
    @Published public var currentUser: User?
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var isAuthenticated = false
    @Published public var showError = false
    
    private var authService: AuthService!
    private var cancellables = Set<AnyCancellable>()
    
    public init(authService: AuthService? = nil) {
        if let authService = authService {
            self.authService = authService
        } else {
            self.authService = AuthService()
        }
        
        // Subscribe to auth state changes
        self.authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
            .store(in: &cancellables)
            
        // Subscribe to error changes to automatically show error alert
        $error
            .receive(on: DispatchQueue.main)
            .map { $0 != nil }
            .assign(to: &$showError)
    }
    
    public func validatePassword(_ password: String) -> Bool {
        // Password must be at least 8 characters long and contain at least one number
        return password.count >= 8 && password.contains { $0.isNumber }
    }
    
    public func signIn(email: String, password: String) async throws {
        guard !isLoading else { return }
        guard !email.isEmpty && !password.isEmpty else {
            self.error = AuthError.signInError("Email and password are required")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await authService.signIn(email: email, password: password)
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
    }
    
    public func signUp(email: String, password: String, name: String) async throws {
        guard !isLoading else { return }
        guard !email.isEmpty && !password.isEmpty && !name.isEmpty else {
            self.error = AuthError.signUpError("All fields are required")
            return
        }
        guard validatePassword(password) else {
            self.error = AuthError.signUpError("Password must be at least 8 characters long and contain at least one number")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await authService.signUp(email: email, password: password, name: name)
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
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
            self.error = AuthError.resetPasswordError("Email is required")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            try await authService.resetPassword(email: email)
            isLoading = false
        } catch {
            isLoading = false
            self.error = error
            throw error
        }
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
    
    public func clearError() {
        error = nil
    }
} 