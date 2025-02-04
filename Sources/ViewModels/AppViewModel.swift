import SwiftUI
import Services

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var authViewModel: AuthViewModel
    @Published public var propertyViewModel: PropertyViewModel
    @Published public var profileViewModel: ProfileViewModel
    
    public init() {
        let authService = AuthService()
        let databaseService = DatabaseService()
        let storageService = StorageService()
        
        self.authViewModel = AuthViewModel(authService: authService)
        self.propertyViewModel = PropertyViewModel(databaseService: databaseService, storageService: storageService)
        self.profileViewModel = ProfileViewModel(authService: authService, databaseService: databaseService, storageService: storageService)
    }
} 