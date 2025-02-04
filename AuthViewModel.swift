import Foundation
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var error: Error?
    @Published var isLoading = false
    
    private let authService: AuthService
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthService = AuthService()) {
        self.authService = authService
        
        // Observe auth state changes
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
            .store(in: &cancellables)
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        error = nil
        
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func signUp(email: String, password: String, name: String) async {
        isLoading = true
        error = nil
        
        do {
            try await authService.signUp(email: email, password: password, name: name)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func signOut() {
        error = nil
        
        do {
            try authService.signOut()
        } catch {
            self.error = error
        }
    }
    
    func resetPassword(email: String) async {
        isLoading = true
        error = nil
        
        do {
            try await authService.resetPassword(email: email)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func updatePassword(newPassword: String) async {
        isLoading = true
        error = nil
        
        do {
            try await authService.updatePassword(newPassword: newPassword)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func deleteAccount() async {
        isLoading = true
        error = nil
        
        do {
            try await authService.deleteAccount()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
} 