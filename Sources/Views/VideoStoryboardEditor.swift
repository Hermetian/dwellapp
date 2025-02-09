import PhotosUI
import SwiftUI
import AVKit
import Core
import ViewModels

private enum ClipEditingMode: String, CaseIterable, Identifiable {
    case filter = "Filter"
    case trim = "Trim"
    var id: Self { self }
}

private struct SingleFilterControl: View {
    let title: String
    let value: Float
    let range: ClosedRange<Float>
    let defaultValue: Float
    let onChange: (Float) -> Void
    
    var body: some View {
        FilterControl(
            title: title,
            value: Binding(
                get: { value },
                set: { onChange($0) }
            ),
            range: range,
            defaultValue: defaultValue
        ) { _ in }
    }
}

private struct ClipFilterControls: View {
    let clip: VideoService.VideoClip
    let index: Int
    let onFilterUpdate: (VideoService.VideoFilter, Int) -> Void
    
    private func getCurrentFilterValue(_ filter: VideoService.VideoFilter?) -> (type: FilterType, value: Float) {
        switch filter {
        case .brightness(let value): return (.brightness, value)
        case .contrast(let value): return (.contrast, value)
        case .saturation(let value): return (.saturation, value)
        case .vibrance(let value): return (.vibrance, value)
        case .temperature(let value): return (.temperature, value)
        case .none: return (.brightness, 0)
        }
    }
    
    private enum FilterType {
        case brightness, contrast, saturation, vibrance, temperature
        
        var defaultValue: Float {
            switch self {
            case .brightness, .vibrance: return 0
            case .contrast, .saturation: return 1
            case .temperature: return 6500
            }
        }
        
        var range: ClosedRange<Float> {
            switch self {
            case .brightness, .vibrance: return -1...1
            case .contrast, .saturation: return 0...2
            case .temperature: return 3000...9000
            }
        }
        
        func makeFilter(_ value: Float) -> VideoService.VideoFilter {
            switch self {
            case .brightness: return .brightness(value)
            case .contrast: return .contrast(value)
            case .saturation: return .saturation(value)
            case .vibrance: return .vibrance(value)
            case .temperature: return .temperature(value)
            }
        }
    }
    
    var body: some View {
        let currentFilter = getCurrentFilterValue(clip.filter)
        
        VStack {
            SingleFilterControl(
                title: "Brightness",
                value: currentFilter.type == .brightness ? currentFilter.value : FilterType.brightness.defaultValue,
                range: FilterType.brightness.range,
                defaultValue: FilterType.brightness.defaultValue
            ) { onFilterUpdate(.brightness($0), index) }
            
            SingleFilterControl(
                title: "Contrast",
                value: currentFilter.type == .contrast ? currentFilter.value : FilterType.contrast.defaultValue,
                range: FilterType.contrast.range,
                defaultValue: FilterType.contrast.defaultValue
            ) { onFilterUpdate(.contrast($0), index) }
            
            SingleFilterControl(
                title: "Saturation",
                value: currentFilter.type == .saturation ? currentFilter.value : FilterType.saturation.defaultValue,
                range: FilterType.saturation.range,
                defaultValue: FilterType.saturation.defaultValue
            ) { onFilterUpdate(.saturation($0), index) }
            
            SingleFilterControl(
                title: "Vibrance",
                value: currentFilter.type == .vibrance ? currentFilter.value : FilterType.vibrance.defaultValue,
                range: FilterType.vibrance.range,
                defaultValue: FilterType.vibrance.defaultValue
            ) { onFilterUpdate(.vibrance($0), index) }
            
            SingleFilterControl(
                title: "Temperature",
                value: currentFilter.type == .temperature ? currentFilter.value : FilterType.temperature.defaultValue,
                range: FilterType.temperature.range,
                defaultValue: FilterType.temperature.defaultValue
            ) { onFilterUpdate(.temperature($0), index) }
        }
    }
}

private struct VideoPreviewSection: View {
    let currentPlayer: AVPlayer?
    let stitchedPlayer: AVPlayer?
    let isProcessing: Bool
    
    var body: some View {
            VStack(spacing: 16) {
            // Current clip preview
            Group {
                if let player = currentPlayer {
                    VideoPlayer(player: player)
                        .overlay(processingOverlay)
                } else {
                    emptyPreview
                }
            }
                        .frame(height: 250)
                        .cornerRadius(12)
                        .overlay(
                Text("Selected Clip")
                    .font(.caption)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
                    .padding(8),
                alignment: .topLeading
            )
            
            // Stitched preview
                            Group {
                if let player = stitchedPlayer {
                    VideoPlayer(player: player)
                        .overlay(processingOverlay)
                } else {
                    emptyPreview
                }
            }
            .frame(height: 250)
            .cornerRadius(12)
            .overlay(
                Text("Final Video")
                    .font(.caption)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
                    .padding(8),
                alignment: .topLeading
            )
        }
    }
    
    @ViewBuilder
    private var processingOverlay: some View {
                                if isProcessing {
            ZStack {
                                    Color.black.opacity(0.5)
                                    ProgressView()
                                        .tint(.white)
                                }
                            }
    }
    
    private var emptyPreview: some View {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                Label("No video", systemImage: "film")
                                .foregroundColor(.gray)
                        )
                }
}

private struct TimelineSection: View {
    let clips: [VideoService.VideoClip]
    let selectedClipIndex: Int?
    let onClipSelected: (Int) -> Void
    let onAddExisting: () -> Void
    let onUploadNew: () -> Void
    
    var body: some View {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(clips.indices, id: \.self) { index in
                    ClipThumbnail(
                        clip: clips[index],
                        isSelected: selectedClipIndex == index
                    )
                                .frame(width: 120, height: 80)
                                .onTapGesture {
                        onClipSelected(index)
                    }
                }
                
                AddClipButton(
                    title: "Upload Video",
                    systemImage: "square.and.arrow.up",
                    onTap: onUploadNew
                )
                
                AddClipButton(
                    title: "My Videos",
                    systemImage: "film",
                    onTap: onAddExisting
                )
            }
            .padding()
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

private struct AddClipButton: View {
    let title: String
    let systemImage: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
                            VStack {
                Image(systemName: systemImage)
                                    .font(.title)
                Text(title)
                                    .font(.caption)
                            }
                            .frame(width: 120, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
}

private struct ClipControlsSection: View {
    let selectedIndex: Int
    let clips: [VideoService.VideoClip]
    let originalDuration: TimeInterval
    @Binding var trimStart: TimeInterval
    @Binding var trimEnd: TimeInterval
    let onTrimStartChange: (TimeInterval) -> Void
    let onTrimEndChange: (TimeInterval) -> Void
    let onMoveClip: (Int) -> Void
    let onRemoveClip: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Trim Clip")
                .font(.headline)
            
            // Single slider with two handles
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    // Selected range
                    Rectangle()
                        .fill(Color.blue)
                        .frame(
                            width: CGFloat((trimEnd - trimStart) / originalDuration) * geometry.size.width,
                            height: 4
                        )
                        .offset(x: CGFloat(trimStart / originalDuration) * geometry.size.width)
                    
                    // Start handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)
                        .offset(x: CGFloat(trimStart / originalDuration) * geometry.size.width - 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = value.location.x / geometry.size.width
                                    let newTrimStart = max(0, min(trimEnd - 1, newPosition * originalDuration))
                                    onTrimStartChange(newTrimStart)
                                }
                        )
                    
                    // End handle
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(radius: 2)
                        .offset(x: CGFloat(trimEnd / originalDuration) * geometry.size.width - 10)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newPosition = value.location.x / geometry.size.width
                                    let newTrimEnd = min(originalDuration, max(trimStart + 1, newPosition * originalDuration))
                                    onTrimEndChange(newTrimEnd)
                                }
                        )
                }
            }
            .frame(height: 20)
            .padding(.horizontal, 10)
            
            // Time indicators
            HStack {
                Text(formatTime(trimStart))
                Spacer()
                Text(formatTime(trimEnd))
            }
            .font(.caption)
            .foregroundColor(.gray)
            
            ClipActionButtons(
                selectedIndex: selectedIndex,
                clipsCount: clips.count,
                onMoveClip: onMoveClip,
                onRemoveClip: onRemoveClip
            )
        }
        .padding()
        .background(Color(.systemBackground))
                .cornerRadius(12)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private struct ClipActionButtons: View {
    let selectedIndex: Int
    let clipsCount: Int
    let onMoveClip: (Int) -> Void
    let onRemoveClip: () -> Void
    
    var body: some View {
                        HStack {
            Button(action: { onMoveClip(-1) }) {
                                Image(systemName: "arrow.left")
                            }
                            .disabled(selectedIndex == 0)
                            
                            Spacer()
                            
            Button(action: onRemoveClip) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            
                            Spacer()
                            
            Button(action: { onMoveClip(1) }) {
                                Image(systemName: "arrow.right")
                            }
            .disabled(selectedIndex == clipsCount - 1)
        }
    }
}

public struct VideoStoryboardEditor: View {
    @StateObject private var viewModel: VideoStoryboardEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showExistingVideos: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var selectedItem: PhotosPickerItem?
    
    public init(initialVideo: Video?, onSave: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: VideoStoryboardEditorViewModel(clips: [], initialVideo: initialVideo, onSave: onSave))
    }
    
    public var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(spacing: 16) {
                        VideoPreviewSection(
                            currentPlayer: viewModel.player,
                            stitchedPlayer: viewModel.stitchedPlayer,
                            isProcessing: viewModel.isProcessing
                        )
                        TimelineSection(
                            clips: viewModel.clips,
                            selectedClipIndex: viewModel.selectedClipIndex,
                            onClipSelected: viewModel.selectClip,
                            onAddExisting: { showExistingVideos = true },
                            onUploadNew: { showPhotoPicker = true }
                        )
                        if let selectedIndex = viewModel.selectedClipIndex {
                            ClipControlsSection(
                                selectedIndex: selectedIndex,
                                clips: viewModel.clips,
                                originalDuration: viewModel.originalDuration,
                                trimStart: viewModel.trimStartBinding,
                                trimEnd: viewModel.trimEndBinding,
                                onTrimStartChange: viewModel.updateTrimStart,
                                onTrimEndChange: viewModel.updateTrimEnd,
                                onMoveClip: { offset in
                                    viewModel.moveClip(from: selectedIndex, offset: offset)
                                },
                                onRemoveClip: {
                                    viewModel.removeClip(at: selectedIndex)
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                Button {
                    Task {
                        try? await viewModel.prepareForSave()
                    }
                } label: {
                    if viewModel.isProcessing {
                        HStack {
                            ProgressView()
                                .tint(.white)
                            Text("Processing...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.5))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    } else {
                        Text("Save")
                            .frame(maxWidth: .infinity)
            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(viewModel.clips.isEmpty || viewModel.isProcessing)
                .padding(.horizontal)
            }
            .navigationTitle("Create Clip")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showExistingVideos) {
                ExistingVideosView { video in
                    if let videoUrl = URL(string: video.videoUrl) {
                        Task {
                            await viewModel.addClip(from: videoUrl)
                        }
                    }
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedItem,
                matching: .videos
            )
            .onChange(of: selectedItem) { item in
                if let item {
                    Task {
                        do {
                            guard let videoData = try await item.loadTransferable(type: Data.self) else { return }
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                            try videoData.write(to: tempURL)
                            await viewModel.addClip(from: tempURL)
                    } catch {
                            viewModel.errorMessage = error.localizedDescription
                            viewModel.showError = true
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showUploadSheet) {
                if let url = viewModel.stitchedURL {
                    VideoUploadView(
                        videoService: viewModel.videoService,
                        userId: "dummyUser",
                        initialVideoURL: url
                    ) {
                        viewModel.finalizeUpload()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
        .task {
            // Load initial clip if provided
            do {
                try await viewModel.loadInitialClip()
        } catch {
                // Handle error appropriately
                viewModel.errorMessage = error.localizedDescription
                viewModel.showError = true
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
    @Published var originalDuration: Double = 0
    @Published private(set) var trimStart: Double = 0
    @Published private(set) var trimEnd: Double = 0
    @Published var finalTitle: String = ""
    @Published var finalDescription: String = ""
    @Published var isFinalVideo: Bool = false
    @Published var stitchedPlayer: AVPlayer?
    @Published var showUploadSheet = false
    @Published var stitchedURL: URL?
    
    let initialVideo: Video?
    let onSave: () -> Void
    
    let videoService = VideoService()
    
    init(clips: [VideoService.VideoClip], initialVideo: Video? = nil, onSave: @escaping () -> Void) {
        self.clips = clips
        self.initialVideo = initialVideo
        self.onSave = onSave
    }
    
    var trimStartBinding: Binding<Double> {
        Binding(
            get: { self.trimStart },
            set: { self.updateTrimStart($0) }
        )
    }
    
    var trimEndBinding: Binding<Double> {
        Binding(
            get: { self.trimEnd },
            set: { self.updateTrimEnd($0) }
        )
    }
    
    func loadInitialClip() async throws {
        if let initialVideo = initialVideo, let url = URL(string: initialVideo.videoUrl) {
            let rawDuration = try await videoService.getVideoDuration(url: url)
            let duration = max(rawDuration, 0.1)
            let clip = try await videoService.createClip(from: url, startTime: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
            self.clips.append(clip)
            self.originalDuration = duration
            self.selectClip(0)
            try await updateStitchedPreview()
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
            let rawDuration = try await videoService.getVideoDuration(url: url)
            let duration = max(rawDuration, 0.1)
            let clip = try await videoService.createClip(from: url, startTime: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
            self.clips.append(clip)
            self.selectClip(clips.count - 1)
            try await updateStitchedPreview()
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    func saveClip() async {
        guard !clips.isEmpty else { return }
        isProcessing = true
        do {
            // Stitch the clips and get the final video URL
            let stitchedURL = try await videoService.stitchClips(clips)
            
            // Use user-provided metadata for the video
            let titleToUpload = finalTitle.isEmpty ? "Stitched Video \(Int(Date().timeIntervalSince1970))" : finalTitle
            let descriptionToUpload = finalDescription.isEmpty ? "Video created from storyboard editor." : finalDescription
            
            // Upload the stitched video to the database
            let uploadedVideo = try await videoService.uploadVideo(
                url: stitchedURL,
                title: titleToUpload,
                description: descriptionToUpload,
                videoType: .property,
                propertyId: nil,
                userId: "dummyUser"
            )
            
            // Configure the AVPlayer to preview the saved video using its download URL
            guard let savedURL = URL(string: uploadedVideo.videoUrl) else {
                throw NSError(domain: "VideoStoryboardEditorViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL from upload"])
            }
            let playerItem = AVPlayerItem(url: savedURL)
            player = AVPlayer(playerItem: playerItem)
            player?.actionAtItemEnd = .none
            
            // Add observer to loop the video indefinitely
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { _ in
                Task { @MainActor in
                    self.player?.seek(to: .zero)
                    self.player?.play()
                }
            }
            
            // Start playback immediately
            player?.play()
            
            // Call onSave callback
            onSave()
            self.selectedClipIndex = nil
            self.isFinalVideo = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        isProcessing = false
    }
    
    func selectClip(_ index: Int) {
        if isFinalVideo { return }
        selectedClipIndex = index
        if index < clips.count {
            let clip = clips[index]
            let duration = max(clip.duration.seconds, 0.1)
            trimStart = clip.startTime.seconds
            trimEnd = clip.startTime.seconds + duration
            originalDuration = duration
            previewClip(at: index)
        }
    }
    
    func updateTrimStart(_ newValue: Double) {
        guard let idx = selectedClipIndex else { return }
        Task {
            do {
                await MainActor.run {
                    self.isProcessing = true
                    player?.pause()
                    trimStart = newValue
                }
                let clip = clips[idx]
                let newClip = VideoService.VideoClip(
                    sourceURL: clip.sourceURL,
                    startTime: CMTime(seconds: newValue, preferredTimescale: 600),
                    duration: CMTime(seconds: trimEnd - newValue, preferredTimescale: 600),
                    filter: clip.filter
                )
                await MainActor.run {
                    clips[idx] = newClip
                    previewClip(at: idx)
                }
                try await updateStitchedPreview()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update trim: \(error.localizedDescription)"
                    self.showError = true
                    self.isProcessing = false
                }
            }
        }
    }
    
    func updateTrimEnd(_ newValue: Double) {
        guard let idx = selectedClipIndex else { return }
        Task {
            do {
                await MainActor.run {
                    self.isProcessing = true
                    player?.pause()
                    trimEnd = newValue
                }
                let clip = clips[idx]
                let newClip = VideoService.VideoClip(
                    sourceURL: clip.sourceURL,
                    startTime: clip.startTime,
                    duration: CMTime(seconds: newValue - trimStart, preferredTimescale: 600),
                    filter: clip.filter
                )
                await MainActor.run {
                    clips[idx] = newClip
                    previewClip(at: idx)
                }
                try await updateStitchedPreview()
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update trim: \(error.localizedDescription)"
                    self.showError = true
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func updateStitchedPreview() async throws {
        guard !clips.isEmpty else {
            await MainActor.run {
                stitchedPlayer?.pause()
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
                stitchedPlayer = nil
            }
            return
        }
        
        // If only one clip exists, use its URL directly instead of stitching
        if clips.count == 1 {
            let singleURL = clips[0].sourceURL
            await MainActor.run {
                let playerItem = AVPlayerItem(url: singleURL)
                let queuePlayer = AVQueuePlayer(playerItem: playerItem)
                _ = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
                self.stitchedPlayer = queuePlayer
                queuePlayer.play()
                isProcessing = false
            }
            return
        }
        
        // First pause the stitched player, ignoring errors if it's not playing
        if let player = await MainActor.run(body: { stitchedPlayer }) {
            do {
                try await player.pause()
            } catch {
                // Log or ignore specific pause errors like 'Operation stopped'
                print("Ignore pause error: \(error.localizedDescription)")
            }
        }
        
        // Then update UI state
        await MainActor.run {
            isProcessing = true
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
            stitchedPlayer = nil
        }
        
        do {
            let url = try await videoService.stitchClips(clips)
            
            // Create asset and verify it has video tracks
            let asset = AVAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard !tracks.isEmpty else {
                throw NSError(domain: "VideoStoryboardEditor", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Generated video has no video tracks"])
            }
            
            // Create a queue player for better looping support
            await MainActor.run {
                let playerItem = AVPlayerItem(url: url)
                let queuePlayer = AVQueuePlayer(playerItem: playerItem)
                
                // Set up looping using AVPlayerLooper
                _ = AVPlayerLooper(player: queuePlayer, templateItem: playerItem)
                
                self.stitchedPlayer = queuePlayer
                queuePlayer.play()
                isProcessing = false
            }
        } catch {
            try await MainActor.run {
                isProcessing = false
                throw error  // Re-throw to be caught by caller
            }
        }
    }
    
    func prepareForSave() async {
        guard !clips.isEmpty else { return }
        
        isProcessing = true
        do {
            // First stop any existing preview playback and clean up
            try await MainActor.run {
                stitchedPlayer?.pause()
                NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
                stitchedPlayer = nil
            }
            
            // Generate the final video
            let url = try await videoService.stitchClips(clips)
            
            // Verify the video is valid and has the expected content
            let asset = AVAsset(url: url)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard !tracks.isEmpty else {
                throw NSError(domain: "VideoStoryboardEditor", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Generated video has no video tracks"])
            }
            
            // Verify the duration is as expected
            let duration = try await asset.load(.duration)
            guard duration.seconds > 0 else {
                throw NSError(domain: "VideoStoryboardEditor", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Generated video has zero duration"])
            }
            
            try await MainActor.run {
                self.stitchedURL = url
                self.showUploadSheet = true
                self.isProcessing = false
            }
        } catch {
            try await MainActor.run {
                self.errorMessage = "Failed to prepare video: \(error.localizedDescription)"
                self.showError = true
                self.isProcessing = false
            }
        }
    }
    
    func finalizeUpload() {
        onSave()
        showUploadSheet = false
        stitchedURL = nil
    }
}

// MARK: - ExistingVideosView
public struct ExistingVideosView: View {
    let onSelect: (Video) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: VideoViewModel
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    public init(onSelect: @escaping (Video) -> Void) {
        self.onSelect = onSelect
        // Initialize VideoViewModel with required services
        _viewModel = StateObject(wrappedValue: VideoViewModel(
            databaseService: DatabaseService(),
            storageService: StorageService(),
            videoService: VideoService()
        ))
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading videos...")
                } else if viewModel.videos.isEmpty {
                    VStack {
                        Image(systemName: "video.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No Videos")
                            .font(.headline)
                        Text("You haven't uploaded any videos yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.videos) { video in
                            Button {
                                onSelect(video)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(video.title)
                                        .font(.headline)
                                    Text(video.description)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Text("Uploaded: \(video.uploadDate.formatted())")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Your Videos")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                isLoading = true
                do {
                    try await viewModel.loadVideos()
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
                isLoading = false
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
} 
