import Core
import SwiftUI
import Combine

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public class ProfileViewModel: ObservableObject {
    @Published public var user: User?
    @Published public var myProperties: [Property] = []
    @Published public var isLoading = false
    @Published public var error: Error?
    
    private var authService: AuthService!
    private var databaseService: DatabaseService!
    private var storageService: StorageService!
    private var cancellables = Set<AnyCancellable>()
    
    public nonisolated init(authService: AuthService? = nil,
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
                self.authService = AuthService()
            }
            if self.databaseService == nil {
                self.databaseService = DatabaseService()
            }
            if self.storageService == nil {
                self.storageService = StorageService()
            }
            self.setup()
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
    
    public func loadMyProperties(userId: String) {
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
    
    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    public func updateProfile(name: String? = nil, profileImage: UIImage? = nil) async throws {
        guard !isLoading else { throw NSError(domain: "ProfileViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        guard let userId = user?.id else { throw NSError(domain: "ProfileViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "User ID not found"]) }
        
        isLoading = true
        error = nil
        
        do {
            var updateData: [String: Any] = [:]
            
            if let name = name {
                updateData["name"] = name
            }
            
            if let profileImage = profileImage {
                let imageUrl = try await storageService.uploadProfileImage(profileImage)
                updateData["profileImageUrl"] = imageUrl
            }
            
            try await databaseService.updateProperty(id: userId, data: updateData)
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    #endif
    
    public func updatePassword(newPassword: String) async throws {
        guard !isLoading else { throw NSError(domain: "ProfileViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            try await authService.updatePassword(newPassword: newPassword)
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    public func deleteAccount() async throws {
        guard !isLoading else { throw NSError(domain: "ProfileViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            // Delete user's properties
            for property in myProperties {
                // Delete property images from storage
                if let imageUrl = property.imageUrl {
                    try? await storageService.deleteFile(at: imageUrl)
                }
                if let id = property.id {
                    try await databaseService.deleteProperty(id: id)
                }
            }
            
            // Delete user account
            try await authService.deleteAccount()
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    public func signOut() async throws {
        guard !isLoading else { throw NSError(domain: "ProfileViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            try await authService.signOut()
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    deinit {
        cancellables.removeAll()
    }
} 