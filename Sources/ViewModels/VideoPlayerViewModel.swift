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
        var orientationObserver: NSObjectProtocol?
        
        init(player: AVPlayer? = nil, timeObserver: Any? = nil, itemObserver: NSKeyValueObservation? = nil, orientationObserver: NSObjectProtocol? = nil) {
            self.player = player
            self.timeObserver = timeObserver
            self.itemObserver = itemObserver
            self.orientationObserver = orientationObserver
        }
        
        func cleanup() {
            if let timeObserver = timeObserver {
                player?.removeTimeObserver(timeObserver)
            }
            itemObserver?.invalidate()
            if let orientationObserver = orientationObserver {
                NotificationCenter.default.removeObserver(orientationObserver)
            }
            player?.pause()
            player = nil
            timeObserver = nil
            itemObserver = nil
            orientationObserver = nil
        }
    }
    
    @Published public var isPlaying = false
    @Published public var duration: TimeInterval = 0
    @Published public var currentTime: TimeInterval = 0
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var isMuted = false
    @Published public var isOverlayVisible = false
    private var wasPlayingBeforeOverlay = false
    private var wasPlayingBeforeBackground = false
    
    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @Published public var thumbnailImage: UIImage?
    #endif
    
    private let resources = PlayerResources()
    private var videoService: VideoService?
    private var cancellables = Set<AnyCancellable>()
    
    public var player: AVPlayer? {
        resources.player
    }
    
    public init() {
        setupBackgroundNotifications()
    }
    
    deinit {
        resources.cleanup()
        cancellables.removeAll()
    }
    
    private func setupBackgroundNotifications() {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleBackgroundTransition(active: false)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleBackgroundTransition(active: true)
            }
            .store(in: &cancellables)
        #endif
    }
    
    private func handleBackgroundTransition(active: Bool) {
        if active {
            if wasPlayingBeforeBackground && !isOverlayVisible {
                play()
            }
        } else {
            wasPlayingBeforeBackground = isPlaying
            pause()
        }
    }
    
    private func cleanup() async {
        resources.cleanup()
        objectWillChange.send()
    }
    
    private func setPlayer(_ player: AVPlayer?) {
        resources.player = player
        objectWillChange.send()
        
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        // Setup orientation change handling
        if let player = player {
            resources.orientationObserver = NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self, weak player] _ in
                guard let self = self, let player = player else { return }
                
                // Store current time and playing state
                let currentTime = player.currentTime()
                let wasPlaying = self.isPlaying
                
                // Pause briefly during rotation
                player.pause()
                
                // Resume playback after a short delay to allow rotation to complete
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    await player.seek(to: currentTime)
                    if wasPlaying && !self.isOverlayVisible {
                        player.play()
                        self.isPlaying = true
                    }
                }
            }
        }
        #endif
    }
    
    public func setVideo(url: URL) async {
        await cleanup()
        
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: playerItem)
        
        player.automaticallyWaitsToMinimizeStalling = true
        player.volume = 1.0
        
        if let duration = try? await asset.load(.duration) {
            self.duration = duration.seconds
        }
        
        resources.timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = time.seconds
                self?.handleTimeUpdate(for: player)
            }
        }
        
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
    
    public func releasePlayer() {
        Task {
            await cleanup()
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