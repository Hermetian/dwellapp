import SwiftUI
import AVKit
import Core

private struct ClipFilterControls: View {
    let clip: VideoService.VideoClip
    let index: Int
    let onFilterUpdate: (VideoService.VideoFilter, Int) -> Void
    
    var body: some View {
        VStack {
            FilterControl(
                title: "Brightness",
                value: Binding(
                    get: {
                        if case .brightness(let value) = clip.filter {
                            return value
                        }
                        return 0
                    },
                    set: { newValue in
                        onFilterUpdate(.brightness(newValue), index)
                    }
                ),
                range: -1...1,
                defaultValue: 0
            ) { _ in }
            
            FilterControl(
                title: "Contrast",
                value: Binding(
                    get: {
                        if case .contrast(let value) = clip.filter {
                            return value
                        }
                        return 1
                    },
                    set: { newValue in
                        onFilterUpdate(.contrast(newValue), index)
                    }
                ),
                range: 0...2,
                defaultValue: 1
            ) { _ in }
            
            FilterControl(
                title: "Saturation",
                value: Binding(
                    get: {
                        if case .saturation(let value) = clip.filter {
                            return value
                        }
                        return 1
                    },
                    set: { newValue in
                        onFilterUpdate(.saturation(newValue), index)
                    }
                ),
                range: 0...2,
                defaultValue: 1
            ) { _ in }
            
            FilterControl(
                title: "Vibrance",
                value: Binding(
                    get: {
                        if case .vibrance(let value) = clip.filter {
                            return value
                        }
                        return 0
                    },
                    set: { newValue in
                        onFilterUpdate(.vibrance(newValue), index)
                    }
                ),
                range: -1...1,
                defaultValue: 0
            ) { _ in }
            
            FilterControl(
                title: "Temperature",
                value: Binding(
                    get: {
                        if case .temperature(let value) = clip.filter {
                            return value
                        }
                        return 6500
                    },
                    set: { newValue in
                        onFilterUpdate(.temperature(newValue), index)
                    }
                ),
                range: 3000...9000,
                defaultValue: 6500
            ) { _ in }
        }
    }
}

public struct VideoStoryboardEditor: View {
    @StateObject private var viewModel: VideoStoryboardEditorViewModel
    @Environment(\.dismiss) private var dismiss
    
    public init(initialVideo: Video?, onSave: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: VideoStoryboardEditorViewModel(clips: [], initialVideo: initialVideo, onSave: onSave))
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Video preview
                if let player = viewModel.player {
                    VideoPlayer(player: player)
                        .frame(height: 250)
                        .cornerRadius(12)
                        .overlay(
                            Group {
                                if viewModel.isProcessing {
                                    Color.black.opacity(0.5)
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
                        )
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 250)
                        .cornerRadius(12)
                        .overlay(
                            Label("No clips added", systemImage: "film")
                                .foregroundColor(.gray)
                        )
                }
                
                // Timeline
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.clips.indices, id: \.self) { index in
                            ClipThumbnail(clip: viewModel.clips[index], isSelected: viewModel.selectedClipIndex == index)
                                .frame(width: 120, height: 80)
                                .onTapGesture {
                                    viewModel.selectedClipIndex = index
                                    viewModel.previewClip(at: index)
                                }
                        }
                        
                        // Add clip button
                        Button {
                            viewModel.showClipPicker = true
                        } label: {
                            VStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title)
                                Text("Add Clip")
                                    .font(.caption)
                            }
                            .frame(width: 120, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Clip controls
                if let selectedIndex = viewModel.selectedClipIndex {
                    VStack(spacing: 12) {
                        HStack {
                            Button {
                                viewModel.moveClip(from: selectedIndex, offset: -1)
                            } label: {
                                Image(systemName: "arrow.left")
                            }
                            .disabled(selectedIndex == 0)
                            
                            Spacer()
                            
                            Button {
                                viewModel.removeClip(at: selectedIndex)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
                            Button {
                                viewModel.moveClip(from: selectedIndex, offset: 1)
                            } label: {
                                Image(systemName: "arrow.right")
                            }
                            .disabled(selectedIndex == viewModel.clips.count - 1)
                        }
                        .padding(.horizontal)
                        
                        // Filter controls
                        ClipFilterControls(
                            clip: viewModel.clips[selectedIndex],
                            index: selectedIndex,
                            onFilterUpdate: { filter, index in
                                viewModel.updateFilter(filter, forClipAt: index)
                            }
                        )
                    }
                }
            }
            .padding()
            .navigationTitle("Create Remix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await viewModel.saveRemix()
                        }
                    }
                    .disabled(viewModel.clips.isEmpty || viewModel.isProcessing)
                }
            }
            .task {
                await viewModel.loadInitialClip()
            }
            .sheet(isPresented: $viewModel.showClipPicker) {
                VideoPickerView { url in
                    Task {
                        await viewModel.addClip(from: url)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

private struct ClipThumbnail: View {
    let clip: VideoService.VideoClip
    let isSelected: Bool
    
    var body: some View {
        AsyncImage(url: clip.sourceURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Color.gray
        }
        .frame(width: 120, height: 80)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
    }
}

@MainActor
class VideoStoryboardEditorViewModel: ObservableObject {
    @Published var clips: [VideoService.VideoClip]
    @Published var selectedClipIndex: Int?
    @Published var isProcessing = false
    @Published var showClipPicker = false
    @Published var currentTime: CMTime = .zero
    @Published var player: AVPlayer?
    @Published var showError = false
    @Published var errorMessage = ""
    
    let initialVideo: Video?
    let onSave: () -> Void
    
    let videoService = VideoService()
    
    init(clips: [VideoService.VideoClip], initialVideo: Video? = nil, onSave: @escaping () -> Void) {
        self.clips = clips
        self.initialVideo = initialVideo
        self.onSave = onSave
    }
    
    func loadInitialClip() async {
        if let initialVideo = initialVideo, let url = URL(string: initialVideo.videoUrl) {
            do {
                let duration = try await videoService.getVideoDuration(url: url)
                let clip = try await videoService.createClip(from: url, startTime: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
                self.clips.append(clip)
                self.selectedClipIndex = 0
                self.previewClip(at: 0)
            } catch {
                self.errorMessage = error.localizedDescription
                self.showError = true
            }
        }
    }
    
    func updateFilter(_ filter: VideoService.VideoFilter, forClipAt index: Int) {
        guard index >= 0 && index < clips.count else { return }
        clips[index].filter = filter
    }
    
    func previewClip(at index: Int) {
        guard index < clips.count else { return }
        let clip = clips[index]
        player = AVPlayer(url: clip.sourceURL)
        player?.seek(to: clip.startTime)
        player?.play()
    }
    
    func moveClip(from index: Int, offset: Int) {
        guard index + offset >= 0 && index + offset < clips.count else { return }
        clips.swapAt(index, index + offset)
        selectedClipIndex = index + offset
    }
    
    func removeClip(at index: Int) {
        clips.remove(at: index)
        if clips.isEmpty {
            selectedClipIndex = nil
            player = nil
        } else {
            selectedClipIndex = min(index, clips.count - 1)
            previewClip(at: selectedClipIndex ?? 0)
        }
    }
    
    func addClip(from url: URL) async {
        do {
            let duration = try await videoService.getVideoDuration(url: url)
            let clip = try await videoService.createClip(from: url, startTime: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
            self.clips.append(clip)
            self.selectedClipIndex = clips.count - 1
            self.previewClip(at: selectedClipIndex ?? 0)
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    func saveRemix() async {
        guard !clips.isEmpty else { return }
        isProcessing = true
        do {
            _ = try await videoService.stitchClips(clips)
            onSave()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
} 