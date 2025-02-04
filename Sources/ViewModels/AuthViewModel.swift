import SwiftUI
import Models
import Combine
import Services

@MainActor
public class AuthViewModel: ObservableObject {
    @Published public var currentUser: User?
    @Published public var isLoading = false
    @Published public var error: Error?
    
    public var isAuthenticated: Bool {
        currentUser != nil
    }
    
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
            }
            .store(in: &cancellables)
    }
    
    public func signIn(email: String, password: String) async throws {
        isLoading = true
        error = nil
        
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, name: String) async throws {
        isLoading = true
        error = nil
        
        do {
            try await authService.signUp(email: email, password: password, name: name)
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    public func signOut() async throws {
        isLoading = true
        error = nil
        
        do {
            try await authService.signOut()
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    func resetPassword(email: String) async throws {
        isLoading = true
        error = nil
        
        do {
            try await authService.resetPassword(email: email)
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    func updatePassword(newPassword: String) async throws {
        isLoading = true
        error = nil
        
        do {
            try await authService.updatePassword(newPassword: newPassword)
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    func deleteAccount() async throws {
        isLoading = true
        error = nil
        
        do {
            try await authService.deleteAccount()
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
} 