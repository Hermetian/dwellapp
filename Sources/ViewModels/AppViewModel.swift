import Core
import Foundation

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var authViewModel: AuthViewModel
    @Published public var propertyViewModel: PropertyViewModel
    @Published public var profileViewModel: ProfileViewModel
    
    public init() {
        let databaseService = DatabaseService()
        let storageService = StorageService()
        
        self.authViewModel = AuthViewModel()
        self.propertyViewModel = PropertyViewModel(databaseService: databaseService, storageService: storageService)
        self.profileViewModel = ProfileViewModel(authService: AuthService(), databaseService: databaseService, storageService: storageService)
    }
} 