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
    @Published public var aiEditorService: AIAssistedEditorService?
    
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
        
        // Initialize AI Editor Service
        do {
            self.aiEditorService = try AIAssistedEditorService(videoService: videoService)
        } catch {
            print("Failed to initialize AIAssistedEditorService: \(error)")
            self.aiEditorService = nil
        }
    }
}