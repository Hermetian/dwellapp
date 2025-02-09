@preconcurrency import CoreImage
import AVFoundation
import FirebaseFirestore
import FirebaseStorage
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Added extension to mark AVAssetExportSession as @unchecked Sendable to resolve concurrency warnings
extension AVAssetExportSession: @unchecked @retroactive Sendable {}

public class VideoService: ObservableObject {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let ciContext = CIContext()
    
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
    
    public func getVideoDuration(url: URL) async throws -> Double {
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
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously {
                Task { @MainActor in
                continuation.resume()
                }
            }
        }
        
        if export.status != .completed {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to export video: \(String(describing: export.error))"])
        }
    }
    
    private func createExportSession(for composition: AVComposition, videoComposition: AVVideoComposition? = nil) throws -> AVAssetExportSession {
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        if let videoComposition = videoComposition {
            exportSession.videoComposition = videoComposition
        }
        
        return exportSession
    }
    
    @MainActor
    private func export(using session: AVAssetExportSession) async throws -> URL {
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<URL, Error>) in
            session.exportAsynchronously {
                Task { @MainActor in
                    if session.status == .completed, let outputURL = session.outputURL {
                        continuation.resume(returning: outputURL)
                    } else {
                        continuation.resume(throwing: session.error ?? NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export failed"]))
                    }
                }
            }
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
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            export.exportAsynchronously {
                Task { @MainActor in
                continuation.resume()
                }
            }
        }
        
        if export.status != .completed {
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
    
    public func applyFilter(to videoURL: URL, filter: VideoFilter) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        let composition = AVMutableComposition()
        let videoTrack = try await asset.loadTracks(withMediaType: .video).first
        let audioTrack = try await asset.loadTracks(withMediaType: .audio).first
        
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition video track"])
        }
        
        let timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
        let sourceVideoTrack = videoTrack!
        try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)
        
        if let audioTrack = audioTrack,
           let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }
        
        let context = self.ciContext
        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            var outputImage = request.sourceImage
            
            switch filter {
            case .brightness(let value):
                if let filter = CIFilter(name: "CIColorControls") {
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    filter.setValue(CGFloat(value), forKey: kCIInputBrightnessKey)
                    if let output = filter.outputImage {
                        outputImage = output
                    }
                }
                
            case .contrast(let value):
                if let filter = CIFilter(name: "CIColorControls") {
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    filter.setValue(CGFloat(value), forKey: kCIInputContrastKey)
                    if let output = filter.outputImage {
                        outputImage = output
                    }
                }
                
            case .saturation(let value):
                if let filter = CIFilter(name: "CIColorControls") {
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    filter.setValue(CGFloat(value), forKey: kCIInputSaturationKey)
                    if let output = filter.outputImage {
                        outputImage = output
                    }
                }
                
            case .vibrance(let value):
                if let filter = CIFilter(name: "CIVibrance") {
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    filter.setValue(CGFloat(value), forKey: kCIInputAmountKey)
                    if let output = filter.outputImage {
                        outputImage = output
                    }
                }
                
            case .temperature(let value):
                if let filter = CIFilter(name: "CITemperatureAndTint") {
                    filter.setValue(outputImage, forKey: kCIInputImageKey)
                    filter.setValue(CIVector(x: CGFloat(6500), y: 0), forKey: "inputNeutral")
                    filter.setValue(CIVector(x: CGFloat(value), y: 0), forKey: "inputTargetNeutral")
                    if let output = filter.outputImage {
                        outputImage = output
                    }
                }
            }
            
            request.finish(with: outputImage, context: context)
        }
        
        videoComposition.renderSize = try await compositionVideoTrack.load(.naturalSize)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let exportSession = try self.createExportSession(for: composition, videoComposition: videoComposition)
        return try await self.export(using: exportSession)
    }
    
    public enum VideoFilter: Sendable {
        case brightness(Float)
        case contrast(Float)
        case saturation(Float)
        case vibrance(Float)
        case temperature(Float)
    }
    
    public struct VideoClip: Identifiable, Sendable {
        public let id: UUID
        public let sourceURL: URL
        public let startTime: CMTime
        public let duration: CMTime
        public var filter: VideoFilter?
        
        public init(sourceURL: URL, startTime: CMTime = .zero, duration: CMTime, filter: VideoFilter? = nil) {
            self.id = UUID()
            self.sourceURL = sourceURL
            self.startTime = startTime
            self.duration = duration
            self.filter = filter
        }
    }
    
    public func createClip(from url: URL, startTime: CMTime, duration: CMTime) async throws -> VideoClip {
        // Validate time ranges
        let asset = AVAsset(url: url)
        let assetDuration = try await asset.load(.duration)
        
        guard startTime >= .zero,
              duration > .zero,
              startTime + duration <= assetDuration else {
            throw NSError(domain: "VideoService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid time range for clip"])
        }
        
        return VideoClip(sourceURL: url, startTime: startTime, duration: duration)
    }
    
    public func renderClip(_ clip: VideoClip) async throws -> URL {
        let asset = AVAsset(url: clip.sourceURL)
        let composition = AVMutableComposition()
        
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw NSError(domain: "VideoService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }
        
        let timeRange = CMTimeRange(start: clip.startTime, duration: clip.duration)
        try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        
        if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        }
        
        var videoComposition: AVMutableVideoComposition?
        if let filter = clip.filter {
            let context = self.ciContext
            videoComposition = AVMutableVideoComposition(asset: composition) { request in
                var outputImage = request.sourceImage
                
                switch filter {
                case .brightness(let value):
                    if let filter = CIFilter(name: "CIColorControls") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CGFloat(value), forKey: kCIInputBrightnessKey)
                        if let output = filter.outputImage {
                            outputImage = output
                        }
                    }
                    
                case .contrast(let value):
                    if let filter = CIFilter(name: "CIColorControls") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CGFloat(value), forKey: kCIInputContrastKey)
                        if let output = filter.outputImage {
                            outputImage = output
                        }
                    }
                    
                case .saturation(let value):
                    if let filter = CIFilter(name: "CIColorControls") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CGFloat(value), forKey: kCIInputSaturationKey)
                        if let output = filter.outputImage {
                            outputImage = output
                        }
                    }
                    
                case .vibrance(let value):
                    if let filter = CIFilter(name: "CIVibrance") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CGFloat(value), forKey: kCIInputAmountKey)
                        if let output = filter.outputImage {
                            outputImage = output
                        }
                    }
                    
                case .temperature(let value):
                    if let filter = CIFilter(name: "CITemperatureAndTint") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CIVector(x: CGFloat(6500), y: 0), forKey: "inputNeutral")
                        filter.setValue(CIVector(x: CGFloat(value), y: 0), forKey: "inputTargetNeutral")
                        if let output = filter.outputImage {
                            outputImage = output
                        }
                    }
                }
                
                request.finish(with: outputImage, context: context)
            }
            
            videoComposition?.renderSize = try await compositionVideoTrack.load(.naturalSize)
            videoComposition?.frameDuration = CMTime(value: 1, timescale: 30)
        }
        
        let exportSession = try self.createExportSession(for: composition, videoComposition: videoComposition)
        return try await self.export(using: exportSession)
    }
    
    public func stitchClips(_ clips: [VideoClip]) async throws -> URL {
        guard !clips.isEmpty else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No clips provided"])
        }
        
        let composition = AVMutableComposition()
        var currentTime = CMTime.zero
        
        // Create tracks with specific parameters
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition tracks"])
        }
        
        // First pass: validate all clips and collect video properties
        var naturalSize: CGSize = .zero
        for (index, clip) in clips.enumerated() {
            let asset = AVAsset(url: clip.sourceURL)
            
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw NSError(domain: "VideoService", code: -1, 
                            userInfo: [NSLocalizedDescriptionKey: "No video track found in clip \(index)"])
            }
            
            let trackSize = try await videoTrack.load(.naturalSize)
            if naturalSize == .zero {
                naturalSize = trackSize
            }
            
            // Validate time range
            let assetDuration = try await asset.load(.duration)
            if clip.startTime + clip.duration > assetDuration {
                throw NSError(domain: "VideoService", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid time range for clip \(index)"])
            }
        }
        
        // Second pass: add tracks to composition
        for clip in clips {
            let asset = AVAsset(url: clip.sourceURL)
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }
            
            let timeRange = CMTimeRange(start: clip.startTime, duration: clip.duration)
            
            // Scale and position video to match first clip's dimensions
            let trackSize = try await videoTrack.load(.naturalSize)
            let transform = try await videoTrack.load(.preferredTransform)
            
            let scaleX = naturalSize.width / trackSize.width
            let scaleY = naturalSize.height / trackSize.height
            let scale = min(scaleX, scaleY)
            
            let scaledTransform = CGAffineTransform(scaleX: scale, y: scale)
                .concatenating(transform)
            
            try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: currentTime)
            compositionVideoTrack.preferredTransform = scaledTransform
            
            if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: currentTime)
            }
            
            currentTime = currentTime + clip.duration
        }
        
        let context = self.ciContext
        let videoComposition = AVMutableVideoComposition(asset: composition) { request in
            var outputImage = request.sourceImage
            
            var accumulatedTime = CMTime.zero
            for clip in clips {
                let clipEndTime = accumulatedTime + clip.duration
                if request.compositionTime >= accumulatedTime && request.compositionTime < clipEndTime,
                   let filter = clip.filter {
                    switch filter {
                    case .brightness(let value):
                        if let filter = CIFilter(name: "CIColorControls") {
                            filter.setValue(outputImage, forKey: kCIInputImageKey)
                            filter.setValue(CGFloat(value), forKey: kCIInputBrightnessKey)
                            if let output = filter.outputImage {
                                outputImage = output
                            }
                        }
                        
                    case .contrast(let value):
                        if let filter = CIFilter(name: "CIColorControls") {
                            filter.setValue(outputImage, forKey: kCIInputImageKey)
                            filter.setValue(CGFloat(value), forKey: kCIInputContrastKey)
                            if let output = filter.outputImage {
                                outputImage = output
                            }
                        }
                        
                    case .saturation(let value):
                        if let filter = CIFilter(name: "CIColorControls") {
                            filter.setValue(outputImage, forKey: kCIInputImageKey)
                            filter.setValue(CGFloat(value), forKey: kCIInputSaturationKey)
                            if let output = filter.outputImage {
                                outputImage = output
                            }
                        }
                        
                    case .vibrance(let value):
                        if let filter = CIFilter(name: "CIVibrance") {
                            filter.setValue(outputImage, forKey: kCIInputImageKey)
                            filter.setValue(CGFloat(value), forKey: kCIInputAmountKey)
                            if let output = filter.outputImage {
                                outputImage = output
                            }
                        }
                        
                    case .temperature(let value):
                        if let filter = CIFilter(name: "CITemperatureAndTint") {
                            filter.setValue(outputImage, forKey: kCIInputImageKey)
                            filter.setValue(CIVector(x: CGFloat(6500), y: 0), forKey: "inputNeutral")
                            filter.setValue(CIVector(x: CGFloat(value), y: 0), forKey: "inputTargetNeutral")
                            if let output = filter.outputImage {
                                outputImage = output
                            }
                        }
                    }
                    break
                }
                accumulatedTime = clipEndTime
            }
            
            request.finish(with: outputImage, context: context)
        }
        
        videoComposition.renderSize = naturalSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        let exportSession = try self.createExportSession(for: composition, videoComposition: videoComposition)
        return try await self.export(using: exportSession)
    }
} 
