import Foundation
import Combine
import AVFoundation

@MainActor
class PropertyViewModel: ObservableObject {
    @Published var properties: [Property] = []
    @Published var favoriteProperties: [Property] = []
    @Published var selectedProperty: Property?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var currentPage = 0
    @Published var hasMoreProperties = true
    @Published var currentUserId: String?
    
    private var databaseService: DatabaseService!
    private var storageService: StorageService!
    private var videoService: VideoService!
    private var cancellables = Set<AnyCancellable>()
    var lastPropertyId: String?
    private let pageSize = 10
    
    nonisolated init(databaseService: DatabaseService? = nil,
                    storageService: StorageService? = nil,
                    videoService: VideoService? = nil) {
        if let databaseService = databaseService {
            self.databaseService = databaseService
        }
        if let storageService = storageService {
            self.storageService = storageService
        }
        if let videoService = videoService {
            self.videoService = videoService
        }
        Task { @MainActor in
            if self.databaseService == nil {
                self.databaseService = await DatabaseService()
            }
            if self.storageService == nil {
                self.storageService = await StorageService()
            }
            if self.videoService == nil {
                self.videoService = await VideoService()
            }
            await self.setup()
        }
    }
    
    private func setup() {
        // Initial setup if needed
        loadProperties()
    }
    
    func loadProperties() {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        databaseService.getPropertiesStream(limit: pageSize, lastPropertyId: lastPropertyId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] newProperties in
                guard let self = self else { return }
                if newProperties.isEmpty {
                    self.hasMoreProperties = false
                } else {
                    self.properties.append(contentsOf: newProperties)
                    self.lastPropertyId = newProperties.last?.id
                }
            }
            .store(in: &cancellables)
    }
    
    func loadFavorites(for userId: String) {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        databaseService.getUserFavorites(userId: userId)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] properties in
                self?.favoriteProperties = properties
            }
            .store(in: &cancellables)
    }
    
    func toggleFavorite(propertyId: String, userId: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let isFavorite = favoriteProperties.contains { $0.id == propertyId }
            try await databaseService.togglePropertyFavorite(
                userId: userId,
                propertyId: propertyId,
                isFavorite: !isFavorite
            )
            // Refresh favorites
            loadFavorites(for: userId)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func incrementViewCount(for propertyId: String) async {
        do {
            try await databaseService.incrementPropertyViewCount(id: propertyId)
        } catch {
            self.error = error
        }
    }
    
    func uploadProperty(title: String,
                       description: String,
                       price: Double,
                       address: String,
                       videoURL: URL,
                       bedrooms: Int,
                       bathrooms: Int,
                       squareFootage: Double,
                       availableFrom: Date,
                       managerId: String,
                       amenities: [String: Bool]?) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            // Upload video and get URLs
            let (videoUrl, thumbnailUrl) = try await storageService.uploadVideo(videoURL: videoURL)
            
            // Create property
            let property = Property(
                managerId: managerId,
                title: title,
                description: description,
                price: price,
                address: address,
                videoUrl: videoUrl,
                thumbnailUrl: thumbnailUrl,
                bedrooms: bedrooms,
                bathrooms: bathrooms,
                squareFootage: squareFootage,
                availableFrom: availableFrom,
                amenities: amenities
            )
            
            // Save to database
            let _ = try await databaseService.createProperty(property)
            
            // Refresh properties
            loadProperties()
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func deleteProperty(_ property: Property) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            // Delete video and thumbnail
            try await storageService.deleteFile(at: property.videoUrl)
            if let thumbnailUrl = property.thumbnailUrl {
                try await storageService.deleteFile(at: thumbnailUrl)
            }
            
            // Delete from database
            if let id = property.id {
                try await databaseService.deleteProperty(id: id)
            }
            
            // Remove from local arrays
            properties.removeAll { $0.id == property.id }
            favoriteProperties.removeAll { $0.id == property.id }
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    func resetProperties() {
        properties = []
        lastPropertyId = nil
        hasMoreProperties = true
        loadProperties()
    }
} 