import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private let authStatePublisher = PassthroughSubject<FirebaseAuth.User?, Never>()
    
    init() {
        setupAuthStateHandler()
    }
    
    private func setupAuthStateHandler() {
        // Set up the auth state listener
        authStateHandler = auth.addStateDidChangeListener { [weak self] _, user in
            self?.authStatePublisher.send(user)
        }
        
        // Subscribe to auth state changes
        authStatePublisher
            .receive(on: DispatchQueue.main)
            .flatMap { [weak self] (firebaseUser: FirebaseAuth.User?) -> AnyPublisher<User?, Never> in
                guard let self = self, let firebaseUser = firebaseUser else {
                    return Just<User?>(nil).eraseToAnyPublisher()
                }
                return self.fetchUser(withId: firebaseUser.uid)
            }
            .assign(to: \AuthService.currentUser, on: self)
            .store(in: &cancellables)
    }
    
    deinit {
        // Remove the auth state listener when the service is deallocated
        if let handler = authStateHandler {
            auth.removeStateDidChangeListener(handler)
        }
    }
    
    private func fetchUser(withId uid: String) -> AnyPublisher<User?, Never> {
        Future { [weak self] promise in
            self?.db.collection("users").document(uid).getDocument { snapshot, error in
                if let error = error {
                    print("Error fetching user: \(error.localizedDescription)")
                    promise(.success(nil))
                    return
                }
                
                guard let data = snapshot?.data(),
                      let user = try? Firestore.Decoder().decode(User.self, from: data) else {
                    promise(.success(nil))
                    return
                }
                
                promise(.success(user))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func signIn(email: String, password: String) async throws {
        try await auth.signIn(withEmail: email, password: password)
    }
    
    func signUp(email: String, password: String, name: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        let user = User(id: result.user.uid,
                       email: email,
                       name: name)
        try await createUserDocument(user)
    }
    
    private func createUserDocument(_ user: User) async throws {
        guard let userId = user.id else { return }
        try await db.collection("users").document(userId).setData(from: user)
    }
    
    func signOut() throws {
        try auth.signOut()
    }
    
    func resetPassword(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
    }
    
    func updatePassword(newPassword: String) async throws {
        try await auth.currentUser?.updatePassword(to: newPassword)
    }
    
    func deleteAccount() async throws {
        guard let user = auth.currentUser else { return }
        try await db.collection("users").document(user.uid).delete()
        try await user.delete()
    }
} 