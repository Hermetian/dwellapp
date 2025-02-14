import Core
import Foundation
import AVFoundation
import Combine
import FirebaseFirestore

@MainActor
public final class VideoViewModel: ObservableObject {
    @Published public var videos: [Video] = []
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var currentPage = 0
    @Published public var hasMoreVideos = true
    @Published public var filteredVideos: [Video] = []
    @Published public var aiProcessingVideoId: String?
    @Published public var aiProcessedResults: [String: (title: String, description: String, amenities: [String])] = [:]
    
    public var currentUserId: String? {
        didSet {
            if let userId = currentUserId {
                updateFilteredVideos(userId: userId)
            } else {
                filteredVideos = []
            }
        }
    }
    
    private var databaseService: DatabaseService
    private var storageService: StorageService
    private var videoService: VideoService
    private var cancellables = Set<AnyCancellable>()
    private var lastVideoId: String?
    private let pageSize = 10
    private let db = Firestore.firestore()
    
    public init(databaseService: DatabaseService,
                storageService: StorageService,
                videoService: VideoService) {
        self.databaseService = databaseService
        self.storageService = storageService
        self.videoService = videoService
        Task { @MainActor in
            self.setup()
        }
    }
    
    private func setup() {
        Task {
            try? await loadVideos()
        }
    }
    
    public func loadVideos(userId: String? = nil) async throws {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let newVideos = try await withCheckedThrowingContinuation { continuation in
                databaseService.getVideosStream(limit: pageSize, lastVideoId: lastVideoId, userId: userId)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { videos in
                            continuation.resume(returning: videos)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            if newVideos.isEmpty {
                hasMoreVideos = false
            } else {
                videos.append(contentsOf: newVideos)
                lastVideoId = newVideos.last?.id
            }
            
            if let userId = self.currentUserId {
                updateFilteredVideos(userId: userId)
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    private func updateFilteredVideos(userId: String) {
        self.filteredVideos = videos.filter { $0.userId == userId }
                                 .sorted(by: { $0.uploadDate > $1.uploadDate })
    }
    
    public func uploadVideo(url: URL, propertyId: String, title: String, description: String, userId: String) async throws -> String {
        guard !isLoading else { throw NSError(domain: "VideoViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Process and upload video
            let compressedVideoURL = try await videoService.compressVideo(url: url)
            let videoUrl = try await storageService.uploadData(try Data(contentsOf: compressedVideoURL), path: "videos/\(UUID().uuidString).mp4")
            
            // Generate and upload thumbnail
            let thumbnailImage = try await videoService.generateThumbnail(from: url)
            #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            let thumbnailUrl = try await storageService.uploadData(thumbnailImage.jpegData(compressionQuality: 0.7)!, path: "thumbnails/\(UUID().uuidString).jpg")
            #else
            throw NSError(domain: "VideoViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Thumbnail generation not supported on this platform"])
            #endif
            
            // Create video record
            let video = Video(
                propertyId: propertyId,
                title: title,
                description: description,
                videoUrl: videoUrl.absoluteString,
                thumbnailUrl: thumbnailUrl.absoluteString,
                uploadDate: Date(),
                userId: userId
            )
            
            // Save to database
            let videoId = try await databaseService.createVideo(video)
            
            // Clean up temporary files
            videoService.cleanupTempFiles()
            
            // Refresh videos
            try await loadVideos()
            
            return videoId
        } catch {
            self.error = error
            throw error
        }
    }
    
    public func deleteVideo(_ video: Video) async throws {
        guard !isLoading else { throw NSError(domain: "VideoViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // Delete video and thumbnail files
            try await storageService.deleteFile(at: video.videoUrl)
            if let thumbnailUrl = video.thumbnailUrl {
                try await storageService.deleteFile(at: thumbnailUrl)
            }
            
            // Delete from database
            if let id = video.id {
                try await databaseService.deleteVideo(id: id)
            }
            
            // Remove from local array
            videos.removeAll { $0.id == video.id }
        } catch {
            self.error = error
            throw error
        }
    }
    
    public func updateVideo(_ videoId: String, title: String, description: String) async throws {
        guard !isLoading else { throw NSError(domain: "VideoViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            try await databaseService.updateVideo(id: videoId, data: [
                "title": title,
                "description": description
            ])
            
            // Update in local array if present
            if let index = videos.firstIndex(where: { $0.id == videoId }) {
                var updatedVideo = videos[index]
                updatedVideo.title = title
                updatedVideo.description = description
                videos[index] = updatedVideo
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    public func getVideo(id: String) async throws -> Video {
        try await databaseService.getVideo(id: id)
    }
    
    public func getPropertyVideos(propertyId: String, userId: String? = nil) async throws -> [Video] {
        try await withCheckedThrowingContinuation { continuation in
            databaseService.getPropertyVideos(propertyId: propertyId, userId: userId)
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { videos in
                        continuation.resume(returning: videos)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    public func processVideoWithAI(video: Video) async throws {
        guard let videoId = video.id else {
            print("No video ID available")
            return
        }
        
        guard let url = URL(string: video.videoUrl) else {
            print("Invalid video URL")
            return
        }
        
        aiProcessingVideoId = videoId
        
        let aiService = try AIAssistedEditorService(videoService: videoService)
        let suggestions = try await aiService.getContentSuggestions(for: url, property: nil)
        
        aiProcessedResults[videoId] = suggestions
        aiProcessingVideoId = nil
    }
    
    deinit {
        cancellables.removeAll()
    }
} 