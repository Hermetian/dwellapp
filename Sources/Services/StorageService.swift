import Foundation
import FirebaseStorage
import AVFoundation
import UIKit

@MainActor
class StorageService: ObservableObject {
    private let storage = Storage.storage()
    
    func uploadVideo(videoURL: URL) async throws -> (videoUrl: String, thumbnailUrl: String?) {
        let videoData = try Data(contentsOf: videoURL)
        let videoFileName = UUID().uuidString + ".mp4"
        let videoRef = storage.reference().child("videos/\(videoFileName)")
        
        // Upload video
        _ = try await videoRef.putDataAsync(videoData, metadata: nil)
        let videoDownloadURL = try await videoRef.downloadURL()
        
        // Generate and upload thumbnail
        let thumbnailURL = try await generateAndUploadThumbnail(from: videoURL, videoFileName: videoFileName)
        
        return (videoDownloadURL.absoluteString, thumbnailURL)
    }
    
    private func generateAndUploadThumbnail(from videoURL: URL, videoFileName: String) async throws -> String? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        // Generate thumbnail at 0 seconds
        let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
        let thumbnail = UIImage(cgImage: cgImage)
        
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        
        // Upload thumbnail
        let thumbnailFileName = UUID().uuidString + ".jpg"
        let thumbnailRef = storage.reference().child("thumbnails/\(thumbnailFileName)")
        
        _ = try await thumbnailRef.putDataAsync(thumbnailData, metadata: nil)
        let thumbnailURL = try await thumbnailRef.downloadURL()
        
        return thumbnailURL.absoluteString
    }
    
    func uploadProfileImage(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "StorageService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let fileName = UUID().uuidString + ".jpg"
        let imageRef = storage.reference().child("profile_images/\(fileName)")
        
        _ = try await imageRef.putDataAsync(imageData, metadata: nil)
        let downloadURL = try await imageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func deleteFile(at url: String) async throws {
        let ref = storage.reference(forURL: url)
        try await ref.delete()
    }
    
    func getFileMetadata(at url: String) async throws -> [String: Any] {
        let ref = storage.reference(forURL: url)
        let metadata = try await ref.getMetadata()
        
        return [
            "size": metadata.size,
            "contentType": metadata.contentType ?? "",
            "createdAt": metadata.timeCreated ?? Date(),
            "updatedAt": metadata.updated ?? Date(),
            "name": metadata.name
        ]
    }
} 