import Core
import Foundation
import AVFoundation
import Combine

@MainActor
public final class VideoViewModel: ObservableObject {
    @Published public var videos: [PropertyVideo] = []
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var currentPage = 0
    @Published public var hasMoreVideos = true
    
    private var databaseService: DatabaseService
    private var storageService: StorageService
    private var videoService: VideoService
    private var cancellables = Set<AnyCancellable>()
    private var lastVideoId: String?
    private let pageSize = 10
    
    public nonisolated init(databaseService: DatabaseService,
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
    
    public func loadVideos() async throws {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let newVideos = try await withCheckedThrowingContinuation { continuation in
                databaseService.getVideosStream(limit: pageSize, lastVideoId: lastVideoId)
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
        } catch {
            self.error = error
            throw error
        }
    }
    
    public func uploadVideo(url: URL, propertyId: String, title: String, description: String) async throws -> String {
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
            let video = PropertyVideo(
                propertyId: propertyId,
                title: title,
                description: description,
                videoUrl: videoUrl.absoluteString,
                thumbnailUrl: thumbnailUrl.absoluteString,
                uploadDate: Date()
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
    
    public func deleteVideo(_ video: PropertyVideo) async throws {
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
    
    public func updateVideo(_ video: PropertyVideo, title: String, description: String) async throws {
        guard !isLoading else { throw NSError(domain: "VideoViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        defer {
            isLoading = false
        }
        
        do {
            var updatedVideo = video
            updatedVideo.title = title
            updatedVideo.description = description
            
            try await databaseService.updateVideo(updatedVideo)
            
            // Update in local array
            if let index = videos.firstIndex(where: { $0.id == video.id }) {
                videos[index] = updatedVideo
            }
        } catch {
            self.error = error
            throw error
        }
    }
} 