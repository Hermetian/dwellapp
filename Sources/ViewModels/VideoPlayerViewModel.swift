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
        
        // Add periodic time observer
        resources.timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
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
        player.play()
    }
    
    public func play() {
        resources.player?.play()
    }
    
    public func pause() {
        resources.player?.pause()
    }
    
    public func togglePlayback() {
        if resources.player?.timeControlStatus == .playing {
            pause()
        } else {
            play()
        }
    }
    
    private func handleTimeUpdate(for player: AVPlayer) {
        guard let duration = player.currentItem?.duration else { return }
        let currentTime = player.currentTime()
        
        if currentTime >= duration {
            // Video finished, loop it
            player.seek(to: .zero)
            player.play()
        }
    }
    
    private func handleStatusChange(for item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            resources.player?.play()
        case .failed:
            print("Failed to load video: \(String(describing: item.error))")
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
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime)
    }
    
    public func toggleMute() throws {
        guard let player = resources.player else {
            throw NSError(domain: "VideoPlayerViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Player not initialized"])
        }
        isMuted.toggle()
        player.isMuted = isMuted
    }
} 