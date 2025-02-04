import Foundation
import UIKit
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var myProperties: [Property] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var authService: AuthService!
    private var databaseService: DatabaseService!
    private var storageService: StorageService!
    private var cancellables = Set<AnyCancellable>()
    
    nonisolated init(authService: AuthService? = nil,
                    databaseService: DatabaseService? = nil,
                    storageService: StorageService? = nil) {
        if let authService = authService {
            self.authService = authService
        }
        if let databaseService = databaseService {
            self.databaseService = databaseService
        }
        if let storageService = storageService {
            self.storageService = storageService
        }
        Task { @MainActor in
            if self.authService == nil {
                self.authService = await AuthService()
            }
            if self.databaseService == nil {
                self.databaseService = await DatabaseService()
            }
            if self.storageService == nil {
                self.storageService = await StorageService()
            }
            await self.setup()
        }
    }
    
    private func setup() {
        // Observe auth state changes
        authService.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.user = user
                if let userId = user?.id {
                    self?.loadMyProperties(userId: userId)
                }
            }
            .store(in: &cancellables)
    }
    
    func loadMyProperties(userId: String) {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        databaseService.getPropertiesStream(limit: 0)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] properties in
                self?.myProperties = properties.filter { $0.managerId == userId }
            }
            .store(in: &cancellables)
    }
    
    func updateProfile(name: String? = nil, profileImage: UIImage? = nil) async {
        guard !isLoading, let userId = user?.id else { return }
        isLoading = true
        error = nil
        
        do {
            var updateData: [String: Any] = [:]
            
            if let name = name {
                updateData["name"] = name
            }
            
            if let image = profileImage {
                let imageUrl = try await storageService.uploadProfileImage(image)
                updateData["profileImageUrl"] = imageUrl
            }
            
            try await databaseService.updateProperty(id: userId, data: updateData)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func updatePassword(newPassword: String) async {
        guard !isLoading else { return }
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
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            // Delete profile image if exists
            if let imageUrl = user?.profileImageUrl {
                try await storageService.deleteFile(at: imageUrl)
            }
            
            // Delete all user's properties
            for property in myProperties {
                try await storageService.deleteFile(at: property.videoUrl)
                if let thumbnailUrl = property.thumbnailUrl {
                    try await storageService.deleteFile(at: thumbnailUrl)
                }
                if let id = property.id {
                    try await databaseService.deleteProperty(id: id)
                }
            }
            
            // Delete user account
            try await authService.deleteAccount()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func signOut() {
        do {
            try authService.signOut()
        } catch {
            self.error = error
        }
    }
} 