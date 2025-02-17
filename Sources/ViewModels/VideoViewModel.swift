import Core
import Foundation
import AVFoundation
import Combine
import FirebaseFirestore
import FirebaseCrashlytics
import os

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
    @Published public var likedVideos: [Video] = []
    
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
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.dwell.app", category: "VideoViewModel.AI")
        logger.info("Starting AI processing for video: \(video.id ?? "unknown")")
        
        guard let videoId = video.id else {
            let error = NSError(domain: "VideoViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video ID available"])
            logger.error("Failed: \(error.localizedDescription)")
            Crashlytics.crashlytics().record(error: error)
            throw error
        }
        
        guard let url = URL(string: video.videoUrl) else {
            let error = NSError(domain: "VideoViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
            logger.error("Failed: \(error.localizedDescription), URL: \(video.videoUrl)")
            Crashlytics.crashlytics().record(error: error)
            throw error
        }
        
        logger.info("Processing video URL: \(url.absoluteString)")
        aiProcessingVideoId = videoId
        
        defer {
            aiProcessingVideoId = nil
        }
        
        do {
            logger.info("Initializing AIAssistedEditorService")
            let aiService = try AIAssistedEditorService(videoService: videoService)
            
            logger.info("Starting video content analysis")
            let analysis = try await aiService.analyzeVideoContent(videoURL: url)
            logger.info("Video analysis completed. Transcript available: \(analysis.transcript != nil)")
            
            // Generate title and description based on analysis
            var title = "Property Tour"
            var description = ""
            var amenities: [String] = []
            
            if let transcript = analysis.transcript {
                logger.info("Processing transcript of length: \(transcript.count)")
                // Use transcript to identify key features
                let features = try await aiService.extractKeyFeatures(from: transcript)
                logger.info("Features extracted - Title: \(features.title), Amenities count: \(features.amenities.count)")
                title = features.title
                description = features.description
                amenities = features.amenities
            } else {
                logger.warning("No transcript available for feature extraction")
            }
            
            logger.info("Saving AI processing results")
            aiProcessedResults[videoId] = (title: title, description: description, amenities: amenities)
            logger.info("AI processing completed successfully")
        } catch {
            logger.error("AI processing failed: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                logger.error("Error details - Domain: \(nsError.domain), Code: \(nsError.code)")
                if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                    logger.error("Underlying error: \(underlyingError)")
                }
            }
            Crashlytics.crashlytics().record(error: error)
            throw error
        }
    }
    
    public func toggleVideoLike(videoId: String, userId: String) async throws {
        guard !isLoading else { throw NSError(domain: "VideoViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            let isLiked = likedVideos.contains { $0.id == videoId }
            
            try await databaseService.updateVideo(id: videoId, data: [
                "likeCount": FieldValue.increment(Int64(isLiked ? -1 : 1)),
                "likedBy": isLiked ? FieldValue.arrayRemove([userId]) : FieldValue.arrayUnion([userId])
            ])
            
            // Update local state
            if isLiked {
                likedVideos.removeAll { $0.id == videoId }
            } else if let video = videos.first(where: { $0.id == videoId }) {
                likedVideos.append(video)
            }
            
            // Update the video in the videos array
            if let index = videos.firstIndex(where: { $0.id == videoId }) {
                var updatedVideo = videos[index]
                updatedVideo.likeCount = (updatedVideo.likeCount ?? 0) + (isLiked ? -1 : 1)
                if isLiked {
                    updatedVideo.likedBy?.removeAll { $0 == userId }
                } else {
                    if updatedVideo.likedBy == nil {
                        updatedVideo.likedBy = []
                    }
                    updatedVideo.likedBy?.append(userId)
                }
                videos[index] = updatedVideo
            }
        } catch {
            self.error = error
            throw error
        }
        
        isLoading = false
    }
    
    // Add method to load liked videos for a user
    public func loadLikedVideos(for userId: String) async throws {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        
        do {
            let querySnapshot = try await db.collection("videos")
                .whereField("likedBy", arrayContains: userId)
                .getDocuments()
            
            likedVideos = try querySnapshot.documents.map { try $0.data(as: Video.self) }
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