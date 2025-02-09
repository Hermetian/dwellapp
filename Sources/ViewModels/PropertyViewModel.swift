import Core
import SwiftUI
import Combine
import AVFoundation
import FirebaseFirestore

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class PropertyViewModel: ObservableObject {
    @Published public var properties: [Property] = []
    @Published public var favoriteProperties: [Property] = []
    @Published public var selectedProperty: Property?
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var currentPage = 0
    @Published public var hasMoreProperties = true
    @Published public var currentUserId: String?
    @Published public var property: Property?
    
    // Draft property state
    @Published public var draftTitle = ""
    @Published public var draftDescription = ""
    @Published public var draftPrice = ""
    @Published public var draftAddress = ""
    @Published public var draftBedrooms = 1
    @Published public var draftBathrooms = 1
    @Published public var draftSquareFootage = ""
    @Published public var draftAvailableDate = Date()
    @Published public var draftSelectedVideos: [VideoItem] = []
    @Published public var draftSelectedAmenities: Set<String> = []
    @Published public var draftPropertyType = "Property (Rent)"
    
    private var databaseService: DatabaseService!
    private var storageService: StorageService!
    private var videoService: VideoService!
    private var cancellables = Set<AnyCancellable>()
    var lastPropertyId: String?
    private let pageSize = 10
    
    public init(databaseService: DatabaseService? = nil,
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
        Task {
            try? await loadProperties()
        }
    }
    
    public func loadProperties() async throws {
        guard !isLoading else { throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            let newProperties = try await withCheckedThrowingContinuation { continuation in
                databaseService.getPropertiesStream(limit: pageSize, lastPropertyId: lastPropertyId)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { properties in
                            continuation.resume(returning: properties)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            if newProperties.isEmpty {
                hasMoreProperties = false
            } else {
                properties.append(contentsOf: newProperties)
                lastPropertyId = newProperties.last?.id
            }
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
        
        isLoading = false
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
            // Delete videos and thumbnails
            for videoId in property.videoIds {
                try await videoService.deleteVideo(id: videoId)
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
    
    public func resetProperties() async throws {
        properties = []
        lastPropertyId = nil
        hasMoreProperties = true
        try await loadProperties()
    }

    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    public func createProperty(title: String,
                             description: String,
                             price: Double,
                             location: String,
                             videoURL: URL,
                             bedrooms: Int,
                             bathrooms: Int,
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
            _ = try await storageService.uploadData(try Data(contentsOf: compressedVideoURL), path: "videos/\(UUID().uuidString).mp4")
            
            // Generate and upload thumbnail
            let thumbnailImage = try await videoService.generateThumbnail(from: videoURL)
            let thumbnailUrl = try await storageService.uploadData(thumbnailImage.jpegData(compressionQuality: 0.7)!, path: "thumbnails/\(UUID().uuidString).jpg")
            
            // Create property
            let property = Property(
                managerId: managerId,
                title: title,
                description: description,
                price: price,
                address: location,
                videoIds: [],  // Will be updated after video creation
                thumbnailUrl: thumbnailUrl.absoluteString,
                bedrooms: bedrooms,
                bathrooms: Double(bathrooms),
                squareFootage: squareFootage,
                availableFrom: availableFrom,
                amenities: amenities,
                type: "rental",
                userId: managerId
            )
            
            // Save to database
            let propertyId = try await databaseService.createProperty(property)
            
            // Create video entry and link it to the property
            let video = try await videoService.uploadVideo(
                url: videoURL,
                title: title,
                description: description,
                videoType: .property,
                propertyId: propertyId,
                userId: managerId
            )
            
            if let videoId = video.id {
                try await addVideoToProperty(propertyId: propertyId, videoId: videoId)
            }
            
            // Refresh properties
            try await loadProperties()
            
            isLoading = false
            return propertyId
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    #endif
    
    public func createProperty(_ property: Property) async throws -> String {
        guard !isLoading else { throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let propertyId = try await databaseService.createProperty(property)
            try await loadProperties()
            return propertyId
        } catch {
            self.error = error
            throw error
        }
    }
    
    public func updateProperty(id: String, data: [String: Any]) async throws {
        guard !isLoading else { throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            try await databaseService.updateProperty(id: id, data: data)
            try await loadProperties()
        } catch {
            self.error = error
            throw error
        }
    }
    
    public func addVideoToProperty(propertyId: String, videoId: String) async throws {
        try await updateProperty(id: propertyId, data: [
            "videoIds": FieldValue.arrayUnion([videoId])
        ])
    }
    
    public func removeVideoFromProperty(propertyId: String, videoId: String) async throws {
        try await updateProperty(id: propertyId, data: [
            "videoIds": FieldValue.arrayRemove([videoId])
        ])
    }
    
    public func loadProperty(id: String) async {
        isLoading = true
        error = nil
        
        do {
            property = try await databaseService.getProperty(id: id)
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    public func clearDraft() {
        draftTitle = ""
        draftDescription = ""
        draftPrice = ""
        draftAddress = ""
        draftBedrooms = 1
        draftBathrooms = 1
        draftSquareFootage = ""
        draftAvailableDate = Date()
        draftSelectedVideos = []
        draftSelectedAmenities = []
        draftPropertyType = "Property (Rent)"
    }
} 