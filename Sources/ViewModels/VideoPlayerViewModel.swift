import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
class VideoPlayerViewModel: ObservableObject {
    @Published var isPlaying = false
    @Published var duration: TimeInterval = 0
    @Published var currentTime: TimeInterval = 0
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isMuted = false
    @Published var thumbnailImage: UIImage?
    
    private var videoService: VideoService!
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    
    nonisolated init(videoService: VideoService? = nil) {
        if let videoService = videoService {
            self.videoService = videoService
        }
        Task { @MainActor in
            if self.videoService == nil {
                self.videoService = await VideoService()
            }
            await self.setup()
        }
    }
    
    private func setup() {
        // Setup code here
    }
    
    nonisolated func cleanup() {
        Task { @MainActor in
            await self._cleanup()
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
    
    func setupPlayer(with url: URL) async {
        isLoading = true
        error = nil
        
        do {
            // Get video duration
            duration = try await videoService.getVideoDuration(url: url)
            
            // Generate thumbnail
            thumbnailImage = try await videoService.generateThumbnail(from: url)
            
            // Setup player
            let asset = AVAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
            
            // Setup time observer
            setupTimeObserver()
            
            // Setup player observers
            setupPlayerObservers()
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
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
    
    func play() {
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime)
    }
    
    func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }
    
    // Video processing functions
    
    func trimVideo(at url: URL, startTime: TimeInterval, endTime: TimeInterval) async throws -> URL {
        let startCMTime = CMTime(seconds: startTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let endCMTime = CMTime(seconds: endTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        return try await videoService.trimVideo(url: url, startTime: startCMTime, endTime: endCMTime)
    }
    
    func compressVideo(at url: URL) async throws -> URL {
        return try await videoService.compressVideo(url: url)
    }
    
    func extractFrame(from url: URL, at time: TimeInterval) async throws -> UIImage {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        return try await videoService.extractFrame(from: url, at: cmTime)
    }
    
    func getVideoMetadata(for url: URL) async throws -> [String: Any] {
        return try await videoService.getVideoMetadata(url: url)
    }
    
    deinit {
        cleanup()
    }
} 