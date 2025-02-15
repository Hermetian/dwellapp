import Core
import Foundation
import Combine

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public var authViewModel: AuthViewModel
    @Published public var propertyViewModel: PropertyViewModel
    @Published public var filterViewModel: FilterViewModel
    @Published public var profileViewModel: ProfileViewModel
    @Published public var videoViewModel: VideoViewModel
    @Published public var messagingViewModel: MessagingViewModel
    @Published public var aiEditorService: AIAssistedEditorService?
    
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        let databaseService = DatabaseService()
        let storageService = StorageService()
        let videoService = VideoService()
        
        self.authViewModel = AuthViewModel()
        self.propertyViewModel = PropertyViewModel(databaseService: databaseService, storageService: storageService, videoService: videoService)
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
        
        // Load user's data when authenticated
        Task {
            await loadUserData()
        }
        
        // Subscribe to auth state changes
        authViewModel.$currentUser
            .sink { [weak self] user in
                guard let self = self else { return }
                Task { @MainActor in
                    if user != nil {
                        await self.loadUserData()
                    } else {
                        // Clear user data when logged out
                        self.propertyViewModel.favoriteProperties = []
                        self.videoViewModel.likedVideos = []
                        self.messagingViewModel.conversations = []
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadUserData() async {
        if let userId = authViewModel.currentUser?.id {
            // Load favorited properties
            propertyViewModel.loadFavorites(for: userId)
            
            // Load liked videos
            do {
                try await videoViewModel.loadLikedVideos(for: userId)
            } catch {
                print("Error loading liked videos: \(error)")
            }
            
            // Load chat channels
            messagingViewModel.loadConversations(for: userId)
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
}