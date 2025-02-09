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
    let player: AVPlayer?
    let isProcessing: Bool
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(height: 250)
                    .cornerRadius(12)
                    .overlay(processingOverlay)
            } else {
                emptyPreview
            }
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
            .frame(height: 250)
            .cornerRadius(12)
            .overlay(
                Label("No clips added", systemImage: "film")
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
    let originalDuration: Double
    @Binding var trimStart: Double
    @Binding var trimEnd: Double
    let onTrimStartChange: (Double) -> Void
    let onTrimEndChange: (Double) -> Void
    let onMoveClip: (Int) -> Void
    let onRemoveClip: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ClipTrimControls(
                totalDuration: originalDuration,
                clipStart: $trimStart,
                clipEnd: $trimEnd
            )
            .onChange(of: trimStart, perform: onTrimStartChange)
            .onChange(of: trimEnd, perform: onTrimEndChange)

            ClipActionButtons(
                selectedIndex: selectedIndex,
                clipsCount: clips.count,
                onMoveLeft: { onMoveClip(-1) },
                onMoveRight: { onMoveClip(1) },
                onRemove: onRemoveClip
            )
            .padding(.horizontal)
        }
    }
}

private struct ClipActionButtons: View {
    let selectedIndex: Int
    let clipsCount: Int
    let onMoveLeft: () -> Void
    let onMoveRight: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onMoveLeft) {
                Image(systemName: "arrow.left")
            }
            .disabled(selectedIndex == 0)
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            Button(action: onMoveRight) {
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
            VStack(spacing: 16) {
                VideoPreviewSection(
                    player: viewModel.player,
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
            .padding()
            .navigationTitle("Create Clip")
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
                            await viewModel.saveClip()
                        }
                    }
                    .disabled(viewModel.clips.isEmpty || viewModel.isProcessing)
                }
            }
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
                            let tempURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString)
                                .appendingPathExtension("mov")
                            try videoData.write(to: tempURL)
                            await viewModel.addClip(from: tempURL)
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                            viewModel.showError = true
                        }
                    }
                }
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
    
    func loadInitialClip() async {
        if let initialVideo = initialVideo, let url = URL(string: initialVideo.videoUrl) {
            do {
                let rawDuration = try await videoService.getVideoDuration(url: url)
                let duration = max(rawDuration, 0.1)
                let clip = try await videoService.createClip(from: url, startTime: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
                self.clips.append(clip)
                self.originalDuration = duration
                self.selectClip(0)
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
            let rawDuration = try await videoService.getVideoDuration(url: url)
            let duration = max(rawDuration, 0.1)
            let clip = try await videoService.createClip(from: url, startTime: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
            self.clips.append(clip)
            self.selectClip(clips.count - 1)
        } catch {
            self.errorMessage = error.localizedDescription
            self.showError = true
        }
    }
    
    func saveClip() async {
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
    
    func selectClip(_ index: Int) {
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
        trimStart = newValue
        let clip = clips[idx]
        clips[idx] = VideoService.VideoClip(
            sourceURL: clip.sourceURL,
            startTime: CMTime(seconds: newValue, preferredTimescale: 600),
            duration: CMTime(seconds: trimEnd - newValue, preferredTimescale: 600),
            filter: clip.filter
        )
    }
    
    func updateTrimEnd(_ newValue: Double) {
        guard let idx = selectedClipIndex else { return }
        trimEnd = newValue
        let clip = clips[idx]
        clips[idx] = VideoService.VideoClip(
            sourceURL: clip.sourceURL,
            startTime: clip.startTime,
            duration: CMTime(seconds: newValue - trimStart, preferredTimescale: 600),
            filter: clip.filter
        )
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