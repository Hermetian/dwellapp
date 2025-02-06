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
            print("🔥 Firebase Auth State Changed - User: \(user?.uid ?? "nil")")
            if let user = user {
                Task { [weak self] in
                    do {
                        try await self?.fetchUser(userId: user.uid)
                        print("✅ Successfully fetched user data for: \(user.uid)")
                    } catch {
                        print("❌ Error fetching user: \(error)")
                        if let self = self {
                            self.currentUser = nil
                        }
                    }
                }
            } else {
                print("👤 User signed out or no user")
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
        print("🔑 Attempting sign in for email: \(email)")
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            print("✅ Successfully signed in user: \(result.user.uid)")
            try await fetchUser(userId: result.user.uid)
        } catch let error as NSError {
            print("❌ Sign in error: \(error)")
            if error.domain == AuthErrorDomain {
                switch error.code {
                case AuthErrorCode.wrongPassword.rawValue:
                    throw AuthError.signInError("Incorrect password")
                case AuthErrorCode.userNotFound.rawValue:
                    throw AuthError.signInError("No account found with this email")
                case AuthErrorCode.invalidEmail.rawValue:
                    throw AuthError.signInError("Please enter a valid email address")
                case AuthErrorCode.userDisabled.rawValue:
                    throw AuthError.signInError("This account has been disabled")
                case AuthErrorCode.invalidCredential.rawValue:
                    // Try to sign out first to clear any stale auth state
                    try? auth.signOut()
                    throw AuthError.signInError("Invalid credentials. Please try signing in again.")
                default:
                    throw AuthError.signInError("Failed to sign in: \(error.localizedDescription)")
                }
            } else {
                throw AuthError.signInError("An unexpected error occurred: \(error.localizedDescription)")
            }
        }
    }
    
    public func signUp(email: String, password: String, name: String) async throws {
        print("📝 Starting sign up process for email: \(email)")
        do {
            print("🔐 Creating Firebase user account...")
            let result = try await auth.createUser(withEmail: email, password: password)
            print("✅ Firebase user created with ID: \(result.user.uid)")
            
            let user = User(id: result.user.uid,
                          email: email,
                          name: name,
                          favoriteListings: [],
                          createdAt: Date(),
                          updatedAt: Date())
            
            print("💾 Creating user document in Firestore...")
            do {
                try db.collection("users").document(result.user.uid).setData(from: user)
                print("✅ User document created in Firestore")
                
                print("🔄 Fetching user data...")
                try await fetchUser(userId: result.user.uid)
                print("✅ Sign up process completed successfully")
            } catch {
                // If Firestore document creation fails, delete the auth user to maintain consistency
                print("❌ Failed to create user document in Firestore")
                try? await result.user.delete()
                throw AuthError.signUpError("Failed to complete signup. Please try again.")
            }
        } catch let error as NSError {
            print("❌ Sign up error: \(error)")
            print("❌ Error domain: \(error.domain)")
            print("❌ Error code: \(error.code)")
            print("❌ Error user info: \(error.userInfo)")
            
            if error.domain == AuthErrorDomain {
                switch error.code {
                case AuthErrorCode.emailAlreadyInUse.rawValue:
                    throw AuthError.signUpError("This email is already registered")
                case AuthErrorCode.invalidEmail.rawValue:
                    throw AuthError.signUpError("Please enter a valid email address")
                case AuthErrorCode.weakPassword.rawValue:
                    throw AuthError.signUpError("Please choose a stronger password")
                case AuthErrorCode.networkError.rawValue:
                    throw AuthError.signUpError("Network error. Please check your internet connection and try again.")
                default:
                    throw AuthError.signUpError("Failed to create account: \(error.localizedDescription)")
                }
            } else if error.domain == FirestoreErrorDomain {
                throw AuthError.signUpError("Failed to save user data. Please try again.")
            } else {
                throw AuthError.signUpError("An unexpected error occurred: \(error.localizedDescription)")
            }
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
        } catch let error as NSError {
            print("Password reset error: \(error)")
            if error.domain == AuthErrorDomain {
                switch error.code {
                case AuthErrorCode.userNotFound.rawValue:
                    throw AuthError.resetPasswordError("No account found with this email")
                case AuthErrorCode.invalidEmail.rawValue:
                    throw AuthError.resetPasswordError("Please enter a valid email address")
                default:
                    throw AuthError.resetPasswordError("Failed to send reset email: \(error.localizedDescription)")
                }
            } else {
                throw AuthError.resetPasswordError("An unexpected error occurred: \(error.localizedDescription)")
            }
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
    
    public func sendSignInLink(toEmail email: String) async throws {
        let actionCodeSettings = ActionCodeSettings()
        // Use the full Dynamic Links URL pattern
        actionCodeSettings.url = URL(string: "https://dwell.page.link/email-signin")
        actionCodeSettings.handleCodeInApp = true
        actionCodeSettings.setIOSBundleID("com.gauntletai.dwell")
        actionCodeSettings.dynamicLinkDomain = "dwell.page.link"
        
        do {
            print("🔗 Attempting to send sign-in link to \(email)")
            print("📱 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
            print("🌐 Redirect URL: \(actionCodeSettings.url?.absoluteString ?? "unknown")")
            print("🔗 Dynamic Link Domain: \(actionCodeSettings.dynamicLinkDomain ?? "unknown")")
            
            try await Auth.auth().sendSignInLink(toEmail: email,
                                               actionCodeSettings: actionCodeSettings)
            print("✅ Successfully sent sign-in link")
            // Save the email locally
            UserDefaults.standard.set(email, forKey: "emailForSignIn")
        } catch let error as NSError {
            print("❌ Detailed error: \(error)")
            print("❌ Error domain: \(error.domain)")
            print("❌ Error code: \(error.code)")
            print("❌ Error user info: \(error.userInfo)")
            throw AuthError.signInError("Failed to send sign in link: \(error.localizedDescription)")
        }
    }
    
    public func signInWithEmailLink(email: String, link: String) async throws {
        guard Auth.auth().isSignIn(withEmailLink: link) else {
            throw AuthError.signInError("Invalid sign in link")
        }
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, link: link)
            // Create a new user document if this is a new user
            if result.additionalUserInfo?.isNewUser == true {
                let user = User(id: result.user.uid,
                              email: email,
                              name: email.components(separatedBy: "@").first ?? "User",
                              favoriteListings: [],
                              createdAt: Date(),
                              updatedAt: Date())
                try db.collection("users").document(result.user.uid).setData(from: user)
            }
            try await fetchUser(userId: result.user.uid)
        } catch {
            throw AuthError.signInError("Failed to sign in with email link: \(error.localizedDescription)")
        }
    }
    
    // For existing users to link email authentication to their account
    public func linkWithEmailLink(email: String, link: String) async throws {
        guard let user = auth.currentUser else {
            throw AuthError.userNotFound
        }
        
        guard Auth.auth().isSignIn(withEmailLink: link) else {
            throw AuthError.signInError("Invalid sign in link")
        }
        
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, link: link)
            _ = try await user.link(with: credential)
        } catch {
            throw AuthError.signInError("Failed to link email authentication: \(error.localizedDescription)")
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