import SwiftUI
import AVFoundation
import Combine
import Services

#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public class VideoPlayerViewModel: ObservableObject {
    @Published public var isPlaying = false
    @Published public var duration: TimeInterval = 0
    @Published public var currentTime: TimeInterval = 0
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var isMuted = false
    
    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @Published public var thumbnailImage: UIImage?
    #endif
    
    private var videoService: VideoService!
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    public nonisolated init(videoService: VideoService? = nil) {
        if let videoService = videoService {
            self.videoService = videoService
        }
        Task { @MainActor in
            if self.videoService == nil {
                self.videoService = VideoService()
            }
            self.setup()
        }
    }
    
    private func setup() {
        // Setup code here
    }
    
    public nonisolated func cleanup() {
        Task { @MainActor in
            self._cleanup()
        }
    }
    
    private func _cleanup() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
        player = nil
        cancellables.removeAll()
    }
    
    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private func generateThumbnail(from url: URL) async throws -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
    #else
    private func generateThumbnail(from url: URL) async throws -> Any? {
        throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Thumbnail generation not available on this platform"])
    }
    #endif
    
    public func setupPlayer(with url: URL) async throws {
        guard !isLoading else { throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            // Get video duration
            duration = try await videoService.getVideoDuration(url: url)
            
            #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            // Generate thumbnail
            thumbnailImage = try await generateThumbnail(from: url)
            #endif
            
            // Setup player
            let asset = AVAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
            
            // Setup time observer
            setupTimeObserver()
            
            // Setup player observers
            setupPlayerObservers()
            
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
            }
        }
    }
    
    private func setupPlayerObservers() {
        player?.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isPlaying = status == .playing
            }
            .store(in: &cancellables)
    }
    
    public func play() throws {
        guard let player = player else {
            throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not initialized"])
        }
        player.play()
    }
    
    public func pause() throws {
        guard let player = player else {
            throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not initialized"])
        }
        player.pause()
    }
    
    public func togglePlayback() throws {
        if isPlaying {
            try pause()
        } else {
            try play()
        }
    }
    
    public func seek(to time: TimeInterval) throws {
        guard let player = player else {
            throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not initialized"])
        }
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime)
    }
    
    public func toggleMute() throws {
        guard let player = player else {
            throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not initialized"])
        }
        isMuted.toggle()
        player.isMuted = isMuted
    }
    
    // Video processing functions
    
    public func trimVideo(at url: URL, startTime: TimeInterval, endTime: TimeInterval) async throws -> URL {
        guard !isLoading else { throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            let startCMTime = CMTime(seconds: startTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            let endCMTime = CMTime(seconds: endTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            let result = try await videoService.trimVideo(url: url, startTime: startCMTime, endTime: endCMTime)
            isLoading = false
            return result
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    public func compressVideo(at url: URL) async throws -> URL {
        guard !isLoading else { throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            let result = try await videoService.compressVideo(url: url)
            isLoading = false
            return result
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    public func extractFrame(from url: URL, at time: TimeInterval) async throws -> UIImage {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        let cgImage = try imageGenerator.copyCGImage(at: cmTime, actualTime: nil)
        return UIImage(cgImage: cgImage)
    }
    #else
    public func extractFrame(from url: URL, at time: TimeInterval) async throws -> Any {
        throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Frame extraction not available on this platform"])
    }
    #endif
    
    public func getVideoMetadata(for url: URL) async throws -> [String: Any] {
        guard !isLoading else { throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        isLoading = true
        error = nil
        
        do {
            let result = try await videoService.getVideoMetadata(url: url)
            isLoading = false
            return result
        } catch {
            self.error = error
            isLoading = false
            throw error
        }
    }
    
    deinit {
        cleanup()
    }
} 