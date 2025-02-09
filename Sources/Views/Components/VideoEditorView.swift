import SwiftUI
import AVKit
import Core

public struct VideoEditorView: View {
    let videoURL: URL
    let onSave: (URL) -> Void
    
    @StateObject private var videoService = VideoService()
    @Environment(\.dismiss) private var dismiss
    
    public init(videoURL: URL, onSave: @escaping (URL) -> Void) {
        self.videoURL = videoURL
        self.onSave = onSave
    }
    
    public var body: some View {
        VideoFilterEditorView(videoURL: videoURL, onSave: onSave)
    }
}

// Internal implementation
fileprivate struct VideoFilterEditorView: View {
    let videoURL: URL
    let onSave: (URL) -> Void
    
    @StateObject private var videoService = VideoService()
    @State private var player: AVPlayer?
    @State private var isProcessing = false
    @State private var currentFilter: VideoService.VideoFilter?
    @State private var brightness: Float = 0
    @State private var contrast: Float = 1
    @State private var saturation: Float = 1
    @State private var vibrance: Float = 0
    @State private var temperature: Float = 6500
    @State private var previewURL: URL
    @Environment(\.dismiss) private var dismiss
    
    init(videoURL: URL, onSave: @escaping (URL) -> Void) {
        self.videoURL = videoURL
        self.onSave = onSave
        _previewURL = State(initialValue: videoURL)
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Video preview
                VideoPlayer(player: player)
                    .frame(height: 250)
                    .cornerRadius(12)
                    .overlay(
                        Group {
                            if isProcessing {
                                Color.black.opacity(0.5)
                                ProgressView()
                                    .tint(.white)
                            }
                        }
                    )
                
                // Editing controls
                ScrollView {
                    VStack(spacing: 20) {
                        FilterControl(
                            title: "Brightness",
                            value: $brightness,
                            range: -1...1,
                            defaultValue: 0
                        ) { value in
                            applyFilter(.brightness(value))
                        }
                        
                        FilterControl(
                            title: "Contrast",
                            value: $contrast,
                            range: 0...2,
                            defaultValue: 1
                        ) { value in
                            applyFilter(.contrast(value))
                        }
                        
                        FilterControl(
                            title: "Saturation",
                            value: $saturation,
                            range: 0...2,
                            defaultValue: 1
                        ) { value in
                            applyFilter(.saturation(value))
                        }
                        
                        FilterControl(
                            title: "Vibrance",
                            value: $vibrance,
                            range: -1...1,
                            defaultValue: 0
                        ) { value in
                            applyFilter(.vibrance(value))
                        }
                        
                        FilterControl(
                            title: "Temperature",
                            value: $temperature,
                            range: 3000...9000,
                            defaultValue: 6500
                        ) { value in
                            applyFilter(.temperature(value))
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Edit Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(previewURL)
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
            .onAppear {
                player = AVPlayer(url: videoURL)
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }
    
    private func applyFilter(_ filter: VideoService.VideoFilter) {
        guard !isProcessing else { return }
        
        isProcessing = true
        currentFilter = filter
        
        Task {
            do {
                let filteredURL = try await videoService.applyFilter(to: videoURL, filter: filter)
                await MainActor.run {
                    previewURL = filteredURL
                    player = AVPlayer(url: filteredURL)
                    player?.play()
                    isProcessing = false
                }
            } catch {
                print("Error applying filter: \(error)")
                isProcessing = false
            }
        }
    }
} 