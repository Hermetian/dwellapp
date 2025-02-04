import Foundation
import AVFoundation
import UIKit

@MainActor
class VideoService: ObservableObject {
    func getVideoDuration(url: URL) async throws -> TimeInterval {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        return duration.seconds
    }
    
    func getVideoDimensions(url: URL) async throws -> CGSize {
        let asset = AVAsset(url: url)
        let track = try await asset.loadTracks(withMediaType: .video).first
        let size = try await track?.load(.naturalSize) ?? .zero
        return size
    }
    
    func trimVideo(url: URL, startTime: CMTime, endTime: CMTime) async throws -> URL {
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
        
        // Export
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality)
        export?.outputURL = tempURL
        export?.outputFileType = .mp4
        export?.timeRange = timeRange
        
        await export?.export()
        
        guard export?.status == .completed else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to export video"])
        }
        
        return tempURL
    }
    
    func generateThumbnail(from url: URL, at time: CMTime = .zero) async throws -> UIImage {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
    
    func compressVideo(url: URL, quality: String = AVAssetExportPresetMediumQuality) async throws -> URL {
        let asset = AVAsset(url: url)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        let export = AVAssetExportSession(asset: asset, presetName: quality)
        export?.outputURL = tempURL
        export?.outputFileType = .mp4
        
        await export?.export()
        
        guard export?.status == .completed else {
            throw NSError(domain: "VideoService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to compress video"])
        }
        
        return tempURL
    }
    
    func extractFrame(from url: URL, at time: CMTime) async throws -> UIImage {
        return try await generateThumbnail(from: url, at: time)
    }
    
    func getVideoMetadata(url: URL) async throws -> [String: Any] {
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
            "fileSize": try await url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        ]
    }
    
    func cleanupTempFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        try? FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "mp4" || $0.pathExtension == "jpg" }
            .forEach { try? FileManager.default.removeItem(at: $0) }
    }
} 