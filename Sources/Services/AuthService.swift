import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
public class AuthService: ObservableObject {
    @Published public var currentUser: User?
    private var handle: AuthStateDidChangeListenerHandle?
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    public init() {
        setupAuthStateHandler()
    }
    
    deinit {
        if let handle = handle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    private func setupAuthStateHandler() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                Task { [weak self] in
                    do {
                        try await self?.fetchUser(userId: user.uid)
                    } catch {
                        print("Error fetching user: \(error)")
                        if let self = self {
                            self.currentUser = nil
                        }
                    }
                }
            } else {
                self?.currentUser = nil
            }
        }
    }
    
    private func fetchUser(userId: String) async throws {
        let document = try await db.collection("users").document(userId).getDocument()
        let user = try document.data(as: User.self)
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    public func signIn(email: String, password: String) async throws {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            try await fetchUser(userId: result.user.uid)
        } catch {
            throw AuthError.signInError(error.localizedDescription)
        }
    }
    
    public func signUp(email: String, password: String, name: String) async throws {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            let user = User(id: result.user.uid,
                                 email: email,
                                 name: name)
            
            try db.collection("users").document(result.user.uid).setData(from: user)
            try await fetchUser(userId: result.user.uid)
        } catch {
            throw AuthError.signUpError(error.localizedDescription)
        }
    }
    
    public func signOut() async throws {
        do {
            try auth.signOut()
            currentUser = nil as User?
        } catch {
            throw AuthError.signOutError(error.localizedDescription)
        }
    }
    
    public func resetPassword(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch {
            throw AuthError.resetPasswordError(error.localizedDescription)
        }
    }
    
    public func updatePassword(newPassword: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }
        
        do {
            try await user.updatePassword(to: newPassword)
        } catch {
            throw AuthError.updatePasswordError(error.localizedDescription)
        }
    }
    
    public func deleteAccount() async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }
        
        do {
            let userId = user.uid
            try await db.collection("users").document(userId).delete()
            try await user.delete()
            currentUser = nil as User?
        } catch {
            throw AuthError.deleteAccountError(error.localizedDescription)
        }
    }
}

public enum AuthError: LocalizedError {
    case signInError(String)
    case signUpError(String)
    case signOutError(String)
    case resetPasswordError(String)
    case updatePasswordError(String)
    case deleteAccountError(String)
    case userNotFound
    
    public var errorDescription: String? {
        switch self {
        case .signInError(let message):
            return "Sign in failed: \(message)"
        case .signUpError(let message):
            return "Sign up failed: \(message)"
        case .signOutError(let message):
            return "Sign out failed: \(message)"
        case .resetPasswordError(let message):
            return "Password reset failed: \(message)"
        case .updatePasswordError(let message):
            return "Password update failed: \(message)"
        case .deleteAccountError(let message):
            return "Account deletion failed: \(message)"
        case .userNotFound:
            return "User not found"
        }
    }
} 