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
            // Simple one-time fetch of properties
            let fetchedProperties = try await databaseService.getProperties()
            properties = fetchedProperties
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
    
    // Consolidated property-level favorite toggling. All UI actions (from PropertyCard, PropertyDetailView, or even video-level controls) should call this method.
    public func toggleFavorite(propertyId: String, userId: String) async throws {
        // CHECKLIST ITEM 2: Ensure valid propertyId
        guard !propertyId.isEmpty else {
            throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Property ID is missing. Cannot toggle favorite."])
        }
        guard !isLoading else { throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            // Get the current state from the database
            let isFavorite = try await databaseService.isPropertyFavorited(userId: userId, propertyId: propertyId)
            let newFavoriteState = !isFavorite
            
            try await databaseService.togglePropertyFavorite(
                userId: userId,
                propertyId: propertyId,
                isFavorite: newFavoriteState
            )
            
            // If the property was just favorited (not unfavorited), create/update conversation
            if newFavoriteState {
                // Get the property to access its managerId
                if let property = properties.first(where: { $0.id == propertyId }) {
                    // Only create a conversation if the user is not liking their own property
                    if property.managerId != userId {
                        // Create or get conversation directly through DatabaseService
                        let channelId = try await databaseService.createOrGetConversation(
                            propertyId: propertyId,
                            tenantId: userId,
                            managerId: property.managerId,
                            videoId: property.videoIds.first
                        )
                        
                        // Create a message expressing interest in the property
                        let action = property.type.lowercased().contains("rent") ? "renting" : "buying"
                        let message = ChatMessage(
                            id: UUID().uuidString,
                            channelId: channelId,
                            senderId: userId,
                            text: "Hello, I'm interested in \(action) your \(property.title)"
                        )
                        
                        // Send message directly through DatabaseService
                        try await databaseService.sendMessage(message)
                    }
                }
            }
            
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
            
            // Update the property in our local array instead of reloading everything
            if let index = properties.firstIndex(where: { $0.id == id }) {
                var updatedProperty = properties[index]
                for (key, value) in data {
                    switch key {
                    case "isAvailable":
                        if let boolValue = value as? Bool {
                            updatedProperty.isAvailable = boolValue
                        }
                    // Add other cases as needed
                    default: break
                    }
                }
                properties[index] = updatedProperty
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    public func addVideoToProperty(propertyId: String, videoId: String) async throws {
        try await updateProperty(id: propertyId, data: [
            "videoIds": FieldValue.arrayUnion([videoId])
        ])
        try await databaseService.updateVideo(id: videoId, data: [
            "videoType": Core.VideoType.property.rawValue,
            "propertyId": propertyId
        ])
    }
    
    public func removeVideoFromProperty(propertyId: String, videoId: String) async throws {
        try await updateProperty(id: propertyId, data: [
            "videoIds": FieldValue.arrayRemove([videoId])
        ])
        try await databaseService.updateVideo(id: videoId, data: [
            "videoType": Core.VideoType.forFun.rawValue,
            "propertyId": NSNull()  // This will set the field to nil in Firestore
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
    
    public func createPropertyWithVideos(_ property: Property, videos: [VideoItem], userId: String) async throws -> String {
        print("🚀 Starting createPropertyWithVideos")
        print("📝 Property details - Title: \(property.title), Type: \(property.type)")
        print("🎥 Number of videos to upload: \(videos.count)")
        
        guard !isLoading else {
            print("❌ Error: Operation already in progress")
            throw NSError(domain: "PropertyViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"])
        }
        
        print("✅ Loading check passed")
        isLoading = true
        error = nil
        
        defer {
            print("🔄 Resetting isLoading state")
            isLoading = false
        }
        
        do {
            print("📦 Creating property in database...")
            let propertyId = try await databaseService.createProperty(property)
            print("✅ Property created with ID: \(propertyId)")
            
            // Upload all videos
            var videoIds: [String] = []
            for (index, video) in videos.enumerated() {
                print("🎬 Uploading video \(index + 1)/\(videos.count)")
                print("📹 Video details - Title: \(video.title), URL: \(video.url)")
                
                do {
                    let uploadedVideo = try await videoService.uploadVideo(
                        url: video.url,
                        title: video.title,
                        description: video.description,
                        videoType: .property,
                        propertyId: propertyId,
                        userId: userId
                    )
                    
                    print("🎥 Video uploaded, returned object: \(String(describing: uploadedVideo))")
                    if let videoId = uploadedVideo.id {
                        print("✅ Got video ID: \(videoId)")
                        videoIds.append(videoId)
                    } else {
                        print("⚠️ Warning: Uploaded video has no ID")
                    }
                } catch {
                    print("❌ Error uploading video: \(error.localizedDescription)")
                    throw error
                }
            }
            
            print("📊 Total video IDs collected: \(videoIds.count)")
            
            // Update property with video IDs if we have any
            if !videoIds.isEmpty {
                print("🔄 Updating property with video IDs...")
                try await databaseService.updateProperty(id: propertyId, data: ["videoIds": videoIds])
                print("✅ Property updated with video IDs")
            } else {
                print("ℹ️ No videos to link to property")
            }
            
            print("🎉 Operation completed successfully")
            return propertyId
        } catch {
            print("❌ Error in createPropertyWithVideos: \(error.localizedDescription)")
            print("📝 Error details: \(String(describing: error))")
            self.error = error
            throw error
        }
    }
    
    public func sortedAmenities(for property: Property) -> [String] {
        guard let amenities = property.amenities else { return [] }
        return amenities.keys.sorted().filter { amenities[$0] ?? false }
    }
    
    public func sortedProperties(forUser userId: String) -> [Property] {
        return properties.filter { $0.userId == userId }
                         .sorted { $0.title < $1.title }
    }
    
    deinit {
        cancellables.removeAll()
    }
} 