import AVFoundation
import FirebaseFirestore
import FirebaseStorage
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public class VideoService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    public init() {}
    
    public func uploadVideo(
        url: URL,
        title: String,
        description: String,
        videoType: VideoType,
        propertyId: String? = nil,
        userId: String
    ) async throws -> Video {
        // Check file size
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        let maxSize: Int64 = 100 * 1024 * 1024  // 100MB limit
        
        var videoData: Data
        var finalURL = url
        
        if fileSize > maxSize {
            // Compress video if it's too large
            let compressedURL = try await compressVideo(url: url, quality: AVAssetExportPresetMediumQuality)
            finalURL = compressedURL
            videoData = try Data(contentsOf: compressedURL)
        } else {
            videoData = try Data(contentsOf: url)
        }
        
        // Set metadata
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        let videoRef = storage.reference().child("videos/\(UUID().uuidString).mp4")
        
        do {
            // Upload video with metadata
            _ = try await videoRef.putDataAsync(videoData, metadata: metadata)
            let videoDownloadURL = try await videoRef.downloadURL()
            
            // Generate and upload thumbnail
            let thumbnailURL = try await generateAndUploadThumbnail(from: finalURL)
            
            // Create video object
            let video = Video(
                videoType: videoType,
                propertyId: propertyId,
                title: title,
                description: description,
                videoUrl: videoDownloadURL.absoluteString,
                thumbnailUrl: thumbnailURL,
                userId: userId
            )
            
            // Save to Firestore
            let docRef = db.collection("videos").document()
            try docRef.setData(from: video)
            
            // Clean up temporary files if we created any
            if finalURL != url {
                try? FileManager.default.removeItem(at: finalURL)
            }
            
            return video
        } catch {
            // Clean up any temporary files on error
            if finalURL != url {
                try? FileManager.default.removeItem(at: finalURL)
            }
            
            // Provide more specific error information
            if let storageError = error as? StorageError {
                switch storageError {
                case .quotaExceeded:
                    throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Storage quota exceeded. Please try a smaller video."])
                case .unauthorized:
                    throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unauthorized to upload video. Please sign in again."])
                default:
                    throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to upload video: \(storageError.localizedDescription)"])
                }
            }
            throw error
        }
    }
    
    public func deleteVideo(id: String) async throws {
        let docRef = db.collection("videos").document(id)
        let video = try await docRef.getDocument(as: Video.self)
        
        // Delete video file
        if let videoUrl = URL(string: video.videoUrl) {
            let videoRef = storage.reference(forURL: videoUrl.absoluteString)
            try await videoRef.delete()
        }
        
        // Delete thumbnail
        if let thumbnailUrl = video.thumbnailUrl, let thumbnailURL = URL(string: thumbnailUrl) {
            let thumbnailRef = storage.reference(forURL: thumbnailURL.absoluteString)
            try await thumbnailRef.delete()
        }
        
        // Delete document
        try await docRef.delete()
    }
    
    public func getVideos(propertyId: String? = nil, limit: Int = 10, lastVideoId: String? = nil) async throws -> [Video] {
        var query = db.collection("videos")
            .order(by: "serverTimestamp", descending: true)
        
        if let propertyId = propertyId {
            query = query.whereField("propertyId", isEqualTo: propertyId)
        }
        
        if let lastId = lastVideoId {
            let lastDoc = try await db.collection("videos").document(lastId).getDocument()
            query = query.start(afterDocument: lastDoc)
        }
        
        query = query.limit(to: limit)
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map { try $0.data(as: Video.self) }
    }
    
    private func generateAndUploadThumbnail(from videoURL: URL) async throws -> String? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Generate thumbnail at 0 seconds
        let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
        
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        let thumbnail = UIImage(cgImage: cgImage)
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        #elseif os(macOS)
        let thumbnail = NSImage(cgImage: cgImage, size: .zero)
        guard let thumbnailData = thumbnail.tiffRepresentation else {
            return nil
        }
        #endif
        
        // Upload thumbnail
        let thumbnailFileName = UUID().uuidString + ".jpg"
        let thumbnailRef = storage.reference().child("thumbnails/\(thumbnailFileName)")
        
        _ = try await thumbnailRef.putDataAsync(thumbnailData, metadata: nil)
        let thumbnailURL = try await thumbnailRef.downloadURL()
        
        return thumbnailURL.absoluteString
    }
    
    public func getVideoDuration(url: URL) async throws -> TimeInterval {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
    
    public func getVideoDimensions(url: URL) async throws -> CGSize {
        let asset = AVAsset(url: url)
        let track = try await asset.loadTracks(withMediaType: .video).first
        let size = try await track?.load(.naturalSize) ?? .zero
        return size
    }
    
    private func exportComposition(_ composition: AVComposition, timeRange: CMTimeRange, to outputURL: URL) async throws {
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.timeRange = timeRange
        
        await withCheckedContinuation { continuation in
            export.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard export.status == .completed else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to export video: \(String(describing: export.error))"])
        }
    }
    
    public func trimVideo(url: URL, startTime: CMTime, endTime: CMTime) async throws -> URL {
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
              let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to setup video composition"])
        }
        
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        try await exportComposition(composition, timeRange: timeRange, to: tempURL)
        return tempURL
    }
    
    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    public func generateThumbnail(from url: URL, at time: CMTime = .zero) async throws -> UIImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
    
    public func extractFrame(from url: URL, at time: CMTime) async throws -> UIImage {
        return try await generateThumbnail(from: url, at: time)
    }
    #endif
    
    public func compressVideo(url: URL, quality: String = AVAssetExportPresetMediumQuality) async throws -> URL {
        let asset = AVAsset(url: url)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        guard let export = AVAssetExportSession(asset: asset, presetName: quality) else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        export.outputURL = tempURL
        export.outputFileType = .mp4
        
        await withCheckedContinuation { continuation in
            export.exportAsynchronously {
                continuation.resume()
            }
        }
        
        guard export.status == .completed else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress video: \(String(describing: export.error))"])
        }
        
        return tempURL
    }
    
    public func getVideoMetadata(url: URL) async throws -> [String: Any] {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        
        guard let videoTrack = tracks.first else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        let size = try await videoTrack.load(.naturalSize)
        
        return [
            "duration": duration.seconds,
            "width": size.width,
            "height": size.height,
            "fileSize": try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        ]
    }
    
    public func cleanupTempFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        try? FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mp4" || $0.pathExtension == "jpg" }
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }
} 