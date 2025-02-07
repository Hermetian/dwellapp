import Core
import Foundation

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var authViewModel: AuthViewModel
    @Published public var propertyViewModel: PropertyViewModel
    @Published public var filterViewModel: FilterViewModel
    @Published public var profileViewModel: ProfileViewModel
    @Published public var videoViewModel: VideoViewModel
    @Published public var messagingViewModel: MessagingViewModel
    
    public init() {
        let databaseService = DatabaseService()
        let storageService = StorageService()
        let videoService = VideoService()
        
        self.authViewModel = AuthViewModel()
        self.propertyViewModel = PropertyViewModel(databaseService: databaseService, storageService: storageService)
        self.filterViewModel = FilterViewModel()
        self.profileViewModel = ProfileViewModel(authService: AuthService(), databaseService: databaseService, storageService: storageService)
        self.videoViewModel = VideoViewModel(databaseService: databaseService, storageService: storageService, videoService: videoService)
        self.messagingViewModel = MessagingViewModel()
    }
} 