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
    // Nonisolated wrapper to hold player resources
    private class PlayerResources {
        var player: AVPlayer?
        var timeObserver: Any?
        var itemObserver: NSKeyValueObservation?
        
        init(player: AVPlayer? = nil, timeObserver: Any? = nil, itemObserver: NSKeyValueObservation? = nil) {
            self.player = player
            self.timeObserver = timeObserver
            self.itemObserver = itemObserver
        }
        
        func cleanup() {
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            itemObserver?.invalidate()
            player?.pause()
            player = nil
            timeObserver = nil
            itemObserver = nil
        }
    }
    
    @Published public var isPlaying = false
    @Published public var duration: TimeInterval = 0
    @Published public var currentTime: TimeInterval = 0
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var isMuted = false
    @Published public var isOverlayVisible = false
    private var wasPlayingBeforeOverlay = false  // Track previous playing state
    
    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @Published public var thumbnailImage: UIImage?
    #endif
    
    // Hold all player resources in a nonisolated wrapper
    private let resources = PlayerResources()
    private var videoService: VideoService?
    private var cancellables = Set<AnyCancellable>()
    
    // Public access to player
    public var player: AVPlayer? {
        resources.player
    }
    
    public init() {}
    
    deinit {
        resources.cleanup()
        cancellables.removeAll()
    }
    
    private func cleanup() async {
        resources.cleanup()
        objectWillChange.send()  // Notify observers of player change
    }
    
    private func setPlayer(_ player: AVPlayer?) {
        resources.player = player
        objectWillChange.send()  // Notify observers of player change
    }
    
    public func setVideo(url: URL) async {
        await cleanup()
        
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        // Configure player
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        
        // Get video duration
        if let duration = try? await asset.load(.duration) {
            self.duration = duration.seconds
        }
        
        // Add periodic time observer
        resources.timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = time.seconds
                self?.handleTimeUpdate(for: player)
            }
        }
        
        // Observe player item status
        resources.itemObserver = player.currentItem?.observe(\.status, options: [.new, .old]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                self?.handleStatusChange(for: item)
            }
        }
        
        setPlayer(player)
        if !isOverlayVisible {
            player.play()
            isPlaying = true
        }
    }
    
    public func play() {
        guard !isOverlayVisible else { return }  // Don't play if overlay is visible
        resources.player?.play()
        isPlaying = true
    }
    
    public func pause() {
        resources.player?.pause()
        isPlaying = false
    }
    
    public func setOverlayVisible(_ visible: Bool) {
        isOverlayVisible = visible
        if visible {
            wasPlayingBeforeOverlay = isPlaying  // Save the state
            pause()
        } else if wasPlayingBeforeOverlay {  // Only resume if it was playing before
            play()
            wasPlayingBeforeOverlay = false  // Reset the state
        }
    }
    
    private func handleTimeUpdate(for player: AVPlayer) {
        guard let duration = player.currentItem?.duration else { return }
        let currentTime = player.currentTime()
        
        if currentTime >= duration {
            // Video finished, loop it
            player.seek(to: .zero)
            if !isOverlayVisible {  // Only play if no overlay is visible
                player.play()
            }
        }
    }
    
    private func handleStatusChange(for item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            if !isOverlayVisible {  // Only play if no overlay is visible
                resources.player?.play()
                isPlaying = true
            }
        case .failed:
            print("Failed to load video: \(String(describing: item.error))")
            isPlaying = false
        case .unknown:
            break
        @unknown default:
            break
        }
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
            resources.player = AVPlayer(playerItem: playerItem)
            
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
        resources.timeObserver = resources.player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = time.seconds
            }
        }
    }
    
    private func setupPlayerObservers() {
        resources.player?.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.isPlaying = status == .playing
                }
            }
            .store(in: &cancellables)
    }
    
    public func seek(to time: TimeInterval) throws {
        guard let player = resources.player else {
            throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not initialized"])
        }
        
        let targetTime = max(0, min(time, duration))
        let cmTime = CMTime(seconds: targetTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // Pause during seek to prevent visual glitches
        let wasPlaying = isPlaying
        player.pause()
        
        player.seek(to: cmTime) { [weak self] finished in
            guard let self = self else { return }
            if finished && wasPlaying && !self.isOverlayVisible {
                player.play()
                self.isPlaying = true
            }
        }
    }
    
    public func toggleMute() throws {
        guard let player = resources.player else {
            throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not initialized"])
        }
        isMuted.toggle()
        player.isMuted = isMuted
    }
} 