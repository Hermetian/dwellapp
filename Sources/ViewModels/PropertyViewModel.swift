import SwiftUI
import Models
import Combine
import AVFoundation
import Services

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public class PropertyViewModel: ObservableObject {
    @Published public var properties: [Property] = []
    @Published public var favoriteProperties: [Property] = []
    @Published public var selectedProperty: Property?
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var currentPage = 0
    @Published public var hasMoreProperties = true
    @Published public var currentUserId: String?
    
    private var databaseService: DatabaseService!
    private var storageService: StorageService!
    private var videoService: VideoService!
    private var cancellables = Set<AnyCancellable>()
    var lastPropertyId: String?
    private let pageSize = 10
    
    public nonisolated init(databaseService: DatabaseService? = nil,
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
                self.databaseService = DatabaseService()
            }
            if self.storageService == nil {
                self.storageService = StorageService()
            }
            if self.videoService == nil {
                self.videoService = VideoService()
            }
            self.setup()
        }
    }
    
    private func setup() {
        // Initial setup if needed
        loadProperties()
    }
    
    public func loadProperties() {
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
    
    public func loadFavorites(for userId: String) {
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
    
    public func toggleFavorite(propertyId: String, userId: String) async throws {
        guard !isLoading else { throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
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
            throw error
        }
        
        isLoading = false
    }
    
    public func incrementViewCount(for propertyId: String) async throws {
        guard !isLoading else { throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            try await databaseService.incrementPropertyViewCount(id: propertyId)
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    public func deleteProperty(_ property: Property) async throws {
        guard !isLoading else { throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
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
            throw error
        }
        
        isLoading = false
    }
    
    public func resetProperties() {
        properties = []
        lastPropertyId = nil
        hasMoreProperties = true
        loadProperties()
    }

    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    public func createProperty(title: String,
                             description: String,
                             price: Double,
                             location: String,
                             videoURL: URL,
                             bedrooms: Int = 0,
                             bathrooms: Int = 0,
                             squareFootage: Double = 0,
                             availableFrom: Date = Date(),
                             amenities: [String: Bool]? = nil) async throws -> String {
        guard !isLoading else { throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        guard let managerId = currentUserId else { throw NSError(domain: "PropertyViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "User ID not found"]) }
        
        isLoading = true
        error = nil
        
        do {
            // Process and upload video
            let compressedVideoURL = try await videoService.compressVideo(url: videoURL)
            let videoUrl = try await storageService.uploadData(data: try Data(contentsOf: compressedVideoURL), path: "videos/\(UUID().uuidString).mp4")
            
            // Generate and upload thumbnail
            let thumbnailImage = try await videoService.generateThumbnail(from: videoURL)
            let thumbnailUrl = try await storageService.uploadData(data: thumbnailImage.jpegData(compressionQuality: 0.7)!, path: "thumbnails/\(UUID().uuidString).jpg")
            
            // Create property
            let property = Property(
                managerId: managerId,
                title: title,
                description: description,
                price: price,
                address: location,
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
            
            isLoading = false
            return property.id ?? ""
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    #endif
} 