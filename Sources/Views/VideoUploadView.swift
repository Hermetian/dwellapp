import SwiftUI
import PhotosUI
import AVKit
import Core
import FirebaseFirestore
import FirebaseStorage
import ViewModels

@MainActor
public struct VideoUploadView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = VideoUploadViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var title = ""
    @State private var description = ""
    @State private var videoType: VideoType = .property
    @State private var propertyId: String = ""
    @State private var showPropertySelection = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showVideoEditor = false
    
    private let videoService: VideoService
    private let userId: String
    private let initialVideoURL: URL?
    private let onFinish: (() -> Void)?
    
    public init(videoService: VideoService, userId: String, initialVideoURL: URL? = nil, onFinish: (() -> Void)? = nil) {
        self.videoService = videoService
        self.userId = userId
        self.initialVideoURL = initialVideoURL
        self.onFinish = onFinish
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    if let videoURL = viewModel.videoURL {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .frame(height: 200)
                        
                        Button {
                            showVideoEditor = true
                        } label: {
                            Label("Edit Video", systemImage: "wand.and.stars")
                                .foregroundColor(.blue)
                        }
                    } else {
                        PhotosPicker(selection: $selectedItem,
                                   matching: .videos) {
                            VStack {
                                Image(systemName: "video.badge.plus")
                                    .font(.largeTitle)
                                Text("Select Video")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Section {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    Picker("Video Type", selection: $videoType) {
                        ForEach(VideoType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized)
                                .tag(type)
                        }
                    }
                    
                    if videoType == .property {
                        Button("Select Property") {
                            showPropertySelection = true
                        }
                        if !propertyId.isEmpty {
                            Text("Property Selected: \(propertyId)")
                                .font(.caption)
                        }
                    }
                }
                
                Section {
                    Button(action: uploadVideo) {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Upload Video")
                        }
                    }
                    .disabled(isLoading || viewModel.videoURL == nil || title.isEmpty)
                }
            }
            .navigationTitle("Upload Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedItem) { newValue in
                if let newValue {
                    Task {
                        await viewModel.loadVideo(from: newValue)
                    }
                }
            }
            .onAppear {
                if let url = initialVideoURL {
                    viewModel.videoURL = url
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showVideoEditor) {
                if let videoURL = viewModel.videoURL {
                    VideoEditorView(videoURL: videoURL) { editedURL in
                        viewModel.videoURL = editedURL
                    }
                }
            }
            .sheet(isPresented: $showPropertySelection) {
                PropertyPickerView(selectedPropertyId: $propertyId)
            }
        }
    }
    
    private func uploadVideo() {
        guard let videoURL = viewModel.videoURL else { return }
        
        isLoading = true
        Task {
            do {
                if let aiEditorService = appViewModel.aiEditorService {
                    let suggestions = try? await aiEditorService.getContentSuggestions(for: videoURL, property: nil)
                    if let suggestions = suggestions {
                        if title.isEmpty {
                            title = suggestions.title
                        }
                        if description.isEmpty {
                            description = suggestions.description
                        }
                    }
                }
                
                _ = try await videoService.uploadVideo(
                    url: videoURL,
                    title: title,
                    description: description,
                    videoType: videoType,
                    propertyId: videoType == .property ? propertyId : nil,
                    userId: userId
                )
                await MainActor.run {
                    if let finish = onFinish {
                        finish()
                    }
                    dismiss()
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isLoading = false
        }
    }
}

@MainActor
class VideoUploadViewModel: ObservableObject {
    @Published var videoURL: URL?
    
    func loadVideo(from item: PhotosPickerItem) async {
        do {
            guard let videoData = try await item.loadTransferable(type: Data.self) else { return }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try videoData.write(to: tempURL)
            videoURL = tempURL
        } catch {
            print("Error loading video: \(error)")
        }
    }
}

private struct PropertyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @Binding var selectedPropertyId: String
    @State private var isLoading = true
    @State private var showEditSheet = false
    @State private var editingVideos: [VideoItem] = []
    @State private var showError = false
    @State private var errorMessage = ""
    
    private func initializeNewProperty() {
        let currentUserId = appViewModel.authViewModel.currentUser?.id ?? ""
        appViewModel.propertyViewModel.draftTitle = ""
        appViewModel.propertyViewModel.draftDescription = ""
        appViewModel.propertyViewModel.draftPrice = ""
        appViewModel.propertyViewModel.draftAddress = ""
        appViewModel.propertyViewModel.draftBedrooms = 1
        appViewModel.propertyViewModel.draftBathrooms = 1
        appViewModel.propertyViewModel.draftSquareFootage = ""
        appViewModel.propertyViewModel.draftAvailableDate = Date()
        appViewModel.propertyViewModel.draftSelectedVideos = []
        appViewModel.propertyViewModel.draftSelectedAmenities = []
        appViewModel.propertyViewModel.draftPropertyType = PropertyTypes.propertyRent.rawValue
        appViewModel.propertyViewModel.currentUserId = currentUserId
    }
    
    private var filteredProperties: [Property] {
        if let userId = appViewModel.authViewModel.currentUser?.id {
            return appViewModel.propertyViewModel.sortedProperties(forUser: userId)
        }
        return []
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    List {
                        Button {
                            initializeNewProperty()
                            showEditSheet = true
                        } label: {
                            Label("Create New Property", systemImage: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        
                        ForEach(filteredProperties) { property in
                            Button {
                                selectedPropertyId = property.id ?? ""
                                dismiss()
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(property.title)
                                        .font(.headline)
                                    Text(property.address)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                do {
                    try await appViewModel.propertyViewModel.loadProperties()
                    isLoading = false
                } catch {
                    print("Error loading properties: \(error)")
                    isLoading = false
                }
            }
            .sheet(isPresented: $showEditSheet) {
                NavigationView {
                    UploadPropertyView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    showEditSheet = false
                                }
                            }
                        }
                        .onDisappear {
                            // Check if a property was created and select it
                            if let newPropertyId = appViewModel.propertyViewModel.property?.id {
                                selectedPropertyId = newPropertyId
                                dismiss()
                            }
                        }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}