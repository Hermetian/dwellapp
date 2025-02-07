import Core
import SwiftUI
import AVKit
import Combine

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
    
    private var videoService: VideoService?
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    public nonisolated init(videoService: VideoService? = nil) {
        self.videoService = videoService
        Task { @MainActor in
            await self.setup()
        }
    }
    
    @MainActor
    private func setup() async {
        if videoService == nil {
            videoService = VideoService()
        }
    }
    
    public nonisolated func cleanup() {
        Task { @MainActor in
            await self._cleanup()
        }
    }
    
    @MainActor
    private func _cleanup() async {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.pause()
        player = nil
        cancellables.removeAll()
    }
    
    public func setupPlayer(with url: URL) async throws {
        guard !isLoading else { throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation in progress"]) }
        guard let videoService = videoService else { throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "VideoService not initialized"]) }
        
        isLoading = true
        error = nil
        
        do {
            // Get video duration
            duration = try await videoService.getVideoDuration(url: url)
            
            #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            // Generate thumbnail
            thumbnailImage = try await videoService.generateThumbnail(from: url)
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
    
    deinit {
        cleanup()
    }
} 