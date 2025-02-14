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
    
    public func getVideos(propertyId: String? = nil, limit: Int = 10, lastVideoId: String? = nil, userId: String? = nil) async throws -> [Video] {
        var query = db.collection("videos")
            .order(by: "serverTimestamp", descending: true)
        
        if let propertyId = propertyId {
            query = query.whereField("propertyId", isEqualTo: propertyId)
        }
        
        if let userId = userId {
            query = query.whereField("userId", isEqualTo: userId)
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
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetMediumQuality) else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.timeRange = timeRange
        
        return try await withUnsafeThrowingContinuation { continuation in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(throwing: export.error ?? NSError(domain: "VideoService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to export video: \(String(describing: export.error))"]))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "VideoService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
                default:
                    continuation.resume(throwing: NSError(domain: "VideoService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected export status: \(export.status)"]))
                }
            }
        }
    }
    
    private func createExportSession(for composition: AVComposition, videoComposition: AVVideoComposition? = nil) async throws -> AVAssetExportSession {
        print("🎬 Creating export session...")
        
        // Try to create export session with medium quality first (more compatible)
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetMediumQuality
        ) else {
            throw NSError(domain: "VideoService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).mp4")
        print("📍 Output URL: \(outputURL.path)")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        if let videoComposition = videoComposition {
            // Create a new composition with fixed settings
            let newComposition = AVMutableVideoComposition()
            newComposition.renderSize = CGSize(width: 1280, height: 720)
            newComposition.frameDuration = CMTime(value: 1, timescale: 30)
            
            // Create a single instruction for the entire duration
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: composition.duration)
            
            // Create layer instruction for the video track
            if let videoTrack = try? composition.tracks(withMediaType: .video).first {
                let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
                
                // Calculate scale to fit 1280x720
                let trackSize = try await videoTrack.load(.naturalSize)
                let scaleX = 1280.0 / trackSize.width
                let scaleY = 720.0 / trackSize.height
                let scale = min(scaleX, scaleY)
                
                // Center the video
                let scaledWidth = trackSize.width * scale
                let scaledHeight = trackSize.height * scale
                let tx = (1280 - scaledWidth) / 2
                let ty = (720 - scaledHeight) / 2
                
                // Apply transform
                let transform = CGAffineTransform(scaleX: scale, y: scale)
                    .concatenating(CGAffineTransform(translationX: tx, y: ty))
                
                layerInstruction.setTransform(transform, at: .zero)
                instruction.layerInstructions = [layerInstruction]
            }
            
            newComposition.instructions = [instruction]
            print("🎬 Output size: 1280x720")
            print("⏱️ Frame duration: \(newComposition.frameDuration.seconds) seconds (\(1.0/newComposition.frameDuration.seconds) fps)")
            print("📝 Number of instructions: \(newComposition.instructions.count)")
            
            exportSession.videoComposition = newComposition
        }
        
        return exportSession
    }
    
    @MainActor
    private func export(using session: AVAssetExportSession) async throws -> URL {
        print("📤 Starting export...")
        print("🎬 Using preset: \(session.presetName)")
        if let fileType = session.outputFileType {
            print("📼 Output file type: \(fileType.rawValue)")
        }
        
        if let videoComposition = session.videoComposition {
            let size = videoComposition.renderSize
            let fps = 1.0 / videoComposition.frameDuration.seconds
            print("🎥 Video composition: \(Int(size.width))x\(Int(size.height)) @ \(Int(fps)) fps")
        }
        
        return try await withUnsafeThrowingContinuation { continuation in
            session.exportAsynchronously {
                switch session.status {
                case .completed:
                    print("✅ Export completed successfully")
                    if let outputURL = session.outputURL {
                        print("📁 Output saved to: \(outputURL.path)")
                        continuation.resume(returning: outputURL)
                    } else {
                        print("❌ Export completed but no output URL")
                        continuation.resume(throwing: NSError(domain: "VideoService", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Export completed but no output URL"]))
                    }
                case .failed:
                    print("❌ Export failed: \(String(describing: session.error))")
                    if let error = session.error {
                        print("💥 Error details: \(error.localizedDescription)")
                    }
                    continuation.resume(throwing: session.error ?? NSError(domain: "VideoService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Export failed with unknown error"]))
                case .cancelled:
                    print("⚠️ Export cancelled")
                    continuation.resume(throwing: NSError(domain: "VideoService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
                default:
                    print("❓ Unexpected export status: \(session.status.rawValue)")
                    continuation.resume(throwing: NSError(domain: "VideoService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected export status"]))
                }
            }
        }
    }
    
    public func trimVideo(url: URL, startTime: CMTime, endTime: CMTime) async throws -> URL {
        let asset = AVAsset(url: url)
        let composition = AVMutableComposition()
        
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition track"])
        }
        
        let timeRange = CMTimeRange(start: startTime, end: endTime)
        let assetTrack = try await asset.loadTracks(withMediaType: .video).first!
        
        try compositionTrack.insertTimeRange(
            timeRange,
            of: assetTrack,
            at: .zero
        )
        
        // Export the composition
        let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        )!
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(domain: "VideoService", code: -1)
        }
        
        return outputURL
    }
    
    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    public func generateThumbnail(from url: URL) async throws -> UIImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
    
    public func extractFrame(from url: URL, at time: CMTime) async throws -> UIImage {
        return try await generateThumbnail(from: url)
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
        
        return try await withUnsafeThrowingContinuation { continuation in
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    continuation.resume(returning: tempURL)
                case .failed:
                    continuation.resume(throwing: export.error ?? NSError(domain: "VideoService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to compress video: \(String(describing: export.error))"]))
                case .cancelled:
                    continuation.resume(throwing: NSError(domain: "VideoService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
                default:
                    continuation.resume(throwing: NSError(domain: "VideoService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unexpected export status: \(export.status)"]))
                }
            }
        }
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
    
    public func applyFilter(to url: URL, filter: VideoFilter) async throws -> URL {
        let asset = AVAsset(url: url)
        let composition = AVMutableVideoComposition(asset: asset) { request in
            let source = request.sourceImage.clampedToExtent()
            var output = source  // Initialize output with source image
            
            switch filter {
            case .brightness(let value):
                output = source.applyingFilter("CIColorControls", parameters: ["inputBrightness": value])
            case .contrast(let value):
                output = source.applyingFilter("CIColorControls", parameters: ["inputContrast": 1.0 + value])
            case .saturation(let value):
                output = source.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.0 + value])
            case .vibrance(let value):
                if let filter = CIFilter(name: "CIVibrance") {
                    filter.setValue(source, forKey: kCIInputImageKey)
                    filter.setValue(CGFloat(value), forKey: kCIInputAmountKey)
                    if let filtered = filter.outputImage {
                        output = filtered
                    }
                }
            case .temperature(let value):
                if let filter = CIFilter(name: "CITemperatureAndTint") {
                    filter.setValue(source, forKey: kCIInputImageKey)
                    filter.setValue(CIVector(x: CGFloat(6500), y: 0), forKey: "inputNeutral")
                    filter.setValue(CIVector(x: CGFloat(value), y: 0), forKey: "inputTargetNeutral")
                    if let filtered = filter.outputImage {
                        output = filtered
                    }
                }
            }
            
            request.finish(with: output, context: nil)
        }
        
        let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        )!
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = composition
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(domain: "VideoService", code: -1)
        }
        
        return outputURL
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
    
    private func validateVideoTrack(_ track: AVAssetTrack) async throws -> CGSize {
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        
        print("🔍 Track validation:")
        print("  • Natural size: \(size)")
        print("  • Preferred transform: \(transform)")
        
        // Get the actual dimensions after applying the transform
        let rect = CGRect(origin: .zero, size: size).applying(transform)
        print("  • Computed rect: \(rect)")
        let finalSize = CGSize(width: abs(rect.width), height: abs(rect.height))
        print("  • Final size after abs(): \(finalSize)")
        
        // Validate dimensions
        guard finalSize.width > 0, finalSize.width.isFinite,
              finalSize.height > 0, finalSize.height.isFinite else {
            print("❌ Invalid dimensions detected:")
            print("  • Width: \(finalSize.width) (valid: \(finalSize.width > 0 && finalSize.width.isFinite))")
            print("  • Height: \(finalSize.height) (valid: \(finalSize.height > 0 && finalSize.height.isFinite))")
            throw NSError(domain: "VideoService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid video dimensions"])
        }
        
        return finalSize
    }
    
    public func createClip(from url: URL, startTime: CMTime, duration: CMTime) async throws -> VideoClip {
        // Download the asset if needed to obtain a local file URL
        let localURL = try await downloadRemoteAssetIfNeeded(url: url)
        print("🎥 Creating clip from local URL: \(localURL)")
        
        let asset = AVAsset(url: localURL)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw NSError(domain: "VideoService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }
        
        // Validate time ranges if necessary (existing validations)...
        print("⏱️ Valid time range: start=\(startTime.seconds), duration=\(duration.seconds)")
        
        return VideoClip(sourceURL: localURL, startTime: startTime, duration: duration)
    }
    
    public func stitchClips(_ clips: [VideoClip]) async throws -> URL {
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create composition track"])
        }
        
        var currentTime = CMTime.zero
        var instructions: [AVMutableVideoCompositionInstruction] = []
        
        // First pass: validate all clips and determine output dimensions
        var outputSize: CGSize?
        for clip in clips {
            let asset = AVAsset(url: clip.sourceURL)
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
                throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No video track found in clip"])
            }
            
            let trackSize = try await validateVideoTrack(videoTrack)
            if outputSize == nil {
                outputSize = trackSize
            }
        }
        
        guard let finalOutputSize = outputSize else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not determine output dimensions"])
        }
        
        // Second pass: compose video with normalized timelines
        for clip in clips {
            let asset = AVAsset(url: clip.sourceURL)
            guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else { continue }
            
            // Create a timeRange that starts from zero relative to the source
            let normalizedTimeRange = CMTimeRange(
                start: .zero,
                duration: clip.duration
            )
            
            // Insert the clip starting from the current composition time
            try await compositionTrack.insertTimeRange(
                normalizedTimeRange,
                of: videoTrack,
                at: currentTime
            )
            
            // Create a composition instruction for this segment
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: currentTime, duration: clip.duration)
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
            
            // Calculate and apply the transform for this clip
            let transform = try await adjustedTransform(for: videoTrack, targetSize: finalOutputSize)
            layerInstruction.setTransform(transform, at: currentTime)
            
            instruction.layerInstructions = [layerInstruction]
            instructions.append(instruction)
            
            // Try to add audio if available
            if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
               let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
               ) {
                try compositionAudioTrack.insertTimeRange(
                    normalizedTimeRange,
                    of: audioTrack,
                    at: currentTime
                )
            }
            
            currentTime = CMTimeAdd(currentTime, clip.duration)
        }
        
        // Create and configure video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = instructions
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = finalOutputSize
        
        // Create export session
        let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        )!
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw exportSession.error ?? NSError(domain: "VideoService", code: -1)
        }
        
        return outputURL
    }
    
    public func renderClip(_ clip: VideoClip) async throws -> URL {
        print("🎥 Starting to render clip from URL: \(clip.sourceURL)")
        print("🎬 Source video type: \(try await getVideoFileType(clip.sourceURL))")
        
        let asset = AVAsset(url: clip.sourceURL)
        let composition = AVMutableComposition()
        
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first,
              let compositionVideoTrack = composition.addMutableTrack(
                withMediaType: .video,
                preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw NSError(domain: "VideoService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create video track"])
        }
        
        print("📐 Original video dimensions: \(try await videoTrack.load(.naturalSize))")
        print("🎯 Time range - start: \(clip.startTime.seconds), duration: \(clip.duration.seconds)")
        
        let timeRange = CMTimeRange(start: clip.startTime, duration: clip.duration)
        try compositionVideoTrack.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        
        if let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionAudioTrack.insertTimeRange(timeRange, of: audioTrack, at: .zero)
            print("🔊 Audio track added")
        }
        
        var videoComposition: AVMutableVideoComposition?
        if let filter = clip.filter {
            print("🎨 Applying filter: \(String(describing: filter))")
            let context = self.ciContext
            videoComposition = AVMutableVideoComposition(asset: composition) { request in
                var outputImage = request.sourceImage
                
                switch filter {
                case .brightness(let value):
                    if let filter = CIFilter(name: "CIColorControls") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CGFloat(value), forKey: kCIInputBrightnessKey)
                        if let filtered = filter.outputImage {
                            outputImage = filtered
                        }
                    }
                    
                case .contrast(let value):
                    if let filter = CIFilter(name: "CIColorControls") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CGFloat(value), forKey: kCIInputContrastKey)
                        if let filtered = filter.outputImage {
                            outputImage = filtered
                        }
                    }
                    
                case .saturation(let value):
                    if let filter = CIFilter(name: "CIColorControls") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CGFloat(value), forKey: kCIInputSaturationKey)
                        if let filtered = filter.outputImage {
                            outputImage = filtered
                        }
                    }
                    
                case .vibrance(let value):
                    if let filter = CIFilter(name: "CIVibrance") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CGFloat(value), forKey: kCIInputAmountKey)
                        if let filtered = filter.outputImage {
                            outputImage = filtered
                        }
                    }
                    
                case .temperature(let value):
                    if let filter = CIFilter(name: "CITemperatureAndTint") {
                        filter.setValue(outputImage, forKey: kCIInputImageKey)
                        filter.setValue(CIVector(x: CGFloat(6500), y: 0), forKey: "inputNeutral")
                        filter.setValue(CIVector(x: CGFloat(value), y: 0), forKey: "inputTargetNeutral")
                        if let filtered = filter.outputImage {
                            outputImage = filtered
                        }
                    }
                }
                
                request.finish(with: outputImage, context: context)
            }
            
            videoComposition?.renderSize = try await compositionVideoTrack.load(.naturalSize)
            videoComposition?.frameDuration = CMTime(value: 1, timescale: 30)
        }
        
        print("📦 Creating export session...")
        let exportSession = try await createExportSession(for: composition, videoComposition: videoComposition)
        print("🎬 Export session preset: \(exportSession.presetName)")
        print("📼 Output file type: \(exportSession.outputFileType?.rawValue ?? "unknown")")
        
        return try await export(using: exportSession)
    }
    
    private func getVideoFileType(_ url: URL) async throws -> String {
        let asset = AVAsset(url: url)
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = videoTracks.first else {
            return "no video track"
        }
        return try await getVideoCodecType(track)
    }
    
    func getVideoCodecType(_ track: AVAssetTrack) async throws -> String {
        guard let formatDescriptions = try? await track.load(.formatDescriptions),
              let formatDescription = formatDescriptions.first else {
            return "no format description"
        }
        
        let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
        return String(format: "%c%c%c%c",
            (mediaSubType >> 24) & 0xff,
            (mediaSubType >> 16) & 0xff,
            (mediaSubType >> 8) & 0xff,
            mediaSubType & 0xff)
    }
    
    // MARK: - Video Format Handling
    
    private struct VideoFormat {
        let codec: String
        let dimensions: CGSize
        let frameRate: Float
        
        // Make initializer internal to the struct
        fileprivate init(codec: String, dimensions: CGSize, frameRate: Float) {
            self.codec = codec
            // Always force dimensions to 1280x720
            self.dimensions = CGSize(width: 1280, height: 720)
            self.frameRate = frameRate
        }
        
        static func load(from track: AVAssetTrack) async throws -> VideoFormat {
            let formatDescriptions = try await track.load(.formatDescriptions)
            guard let formatDescription = formatDescriptions.first else {
                throw NSError(domain: "VideoFormat", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "No format description"])
            }
            
            let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
            let codec = String(format: "%c%c%c%c",
                               (mediaSubType >> 24) & 0xff,
                               (mediaSubType >> 16) & 0xff,
                               (mediaSubType >> 8) & 0xff,
                               mediaSubType & 0xff)
            
            let naturalSize = try await track.load(.naturalSize)
            guard naturalSize.width > 0, naturalSize.width.isFinite,
                  naturalSize.height > 0, naturalSize.height.isFinite else {
                throw NSError(domain: "VideoFormat", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Invalid natural size"])
            }
            
            let transform = (try? await track.load(.preferredTransform)) ?? .identity
            let rect = CGRect(origin: .zero, size: naturalSize).applying(transform)
            let dimensions = CGSize(width: abs(rect.width), height: abs(rect.height))
            let frameRate = (try? await track.load(.nominalFrameRate)) ?? 30.0
            
            return VideoFormat(codec: codec, dimensions: dimensions, frameRate: frameRate)
        }
        
        var description: String {
            "\(codec) \(Int(dimensions.width))x\(Int(dimensions.height))@\(Int(frameRate))fps"
        }
    }
    
    private func logVideoDetails(_ asset: AVAsset) async {
        print("📹 Checking video details...")
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else {
                print("❌ Could not get video details: no video track")
                return
            }
            
            if let format = try? await VideoFormat.load(from: track) {
                print("📹 Details: \(format.description)")
            } else {
                print("❌ Could not get video details: format loading failed")
            }
        } catch {
            print("❌ Could not get video details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Functions
    
    private func adjustedTransform(for videoTrack: AVAssetTrack, targetSize: CGSize) async throws -> CGAffineTransform {
        let trackSize = try await videoTrack.load(.naturalSize)
        let originalTransform = try await videoTrack.load(.preferredTransform)
        
        print("🔄 Transform calculation:")
        print("  • Track size: \(trackSize)")
        print("  • Original transform: \(originalTransform)")
        
        // First apply the original transform to get the correct orientation
        let videoRect = CGRect(origin: .zero, size: trackSize).applying(originalTransform)
        print("  • Video rect after transform: \(videoRect)")
        
        let videoWidth = abs(videoRect.width)
        let videoHeight = abs(videoRect.height)
        print("  • Original dimensions - width: \(videoWidth), height: \(videoHeight)")
        
        // Calculate scale to fit within 1280x720 while maintaining aspect ratio
        let scaleWidth = 1280.0 / videoWidth
        let scaleHeight = 720.0 / videoHeight
        let scale = min(scaleWidth, scaleHeight)
        
        let scaledWidth = videoWidth * scale
        let scaledHeight = videoHeight * scale
        print("  • Scale factor: \(scale)")
        print("  • Scaled dimensions - width: \(scaledWidth), height: \(scaledHeight)")
        
        // Center the scaled video
        let tx = (1280 - scaledWidth) / 2.0
        let ty = (720 - scaledHeight) / 2.0
        print("  • Center translation - x: \(tx), y: \(ty)")
        
        // Create final transform: original transform -> scale -> center
        let finalTransform = originalTransform
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: tx, y: ty))
        
        print("  • Final transform: \(finalTransform)")
        return finalTransform
    }
    
    private func downloadRemoteAssetIfNeeded(url: URL) async throws -> URL {
        // If the URL is already a file URL, return it
        if url.isFileURL {
            return url
        }
        
        print("Downloading remote asset: \(url)")
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Determine file extension or default to mp4
        let fileExtension = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        
        try data.write(to: tempURL)
        print("Downloaded asset to: \(tempURL)")
        return tempURL
    }
}

