import SwiftUI
import PhotosUI
import AVKit
import Core
import FirebaseFirestore
import FirebaseStorage

@MainActor
public struct VideoUploadView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = VideoUploadViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var title = ""
    @State private var description = ""
    @State private var videoType: VideoType = .property
    @State private var propertyId: String = ""
    @State private var showPropertySelection = false
    @State private var isUploading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private let videoService: VideoService
    private let userId: String
    
    public init(videoService: VideoService, userId: String) {
        self.videoService = videoService
        self.userId = userId
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    if let videoURL = viewModel.videoURL {
                        VideoPlayer(player: AVPlayer(url: videoURL))
                            .frame(height: 200)
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
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Upload Video")
                        }
                    }
                    .disabled(isUploading || viewModel.videoURL == nil || title.isEmpty)
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
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            // Add your property selection sheet here
            // .sheet(isPresented: $showPropertySelection) { ... }
        }
    }
    
    private func uploadVideo() {
        guard let videoURL = viewModel.videoURL else { return }
        
        isUploading = true
        Task {
            do {
                let finalPropertyId = videoType == .property ? propertyId : nil
                
                // Show loading state
                withAnimation {
                    isUploading = true
                }
                
                _ = try await videoService.uploadVideo(
                    url: videoURL,
                    title: title,
                    description: description,
                    videoType: videoType,
                    propertyId: finalPropertyId,
                    userId: userId
                )
                
                // Clean up the temporary file
                try? FileManager.default.removeItem(at: videoURL)
                
                dismiss()
            } catch {
                // Handle specific error cases
                if let storageError = error as? StorageError {
                    switch storageError {
                    case .quotaExceeded:
                        errorMessage = "Storage quota exceeded. Please try a smaller video."
                    case .unauthorized:
                        errorMessage = "Please sign in again to upload videos."
                    case .retryLimitExceeded:
                        errorMessage = "Upload failed due to poor network connection. Please try again."
                    default:
                        errorMessage = "Failed to upload video: \(storageError.localizedDescription)"
                    }
                } else {
                    errorMessage = error.localizedDescription
                }
                showError = true
            }
            
            withAnimation {
                isUploading = false
            }
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
    @Binding var selectedProperty: Core.Property?
    @State private var properties: [Core.Property] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    List(properties) { property in
                        Button {
                            selectedProperty = property
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
                await loadProperties()
            }
        }
    }
    
    private func loadProperties() async {
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("properties").getDocuments()
            properties = try snapshot.documents.map { try $0.data(as: Core.Property.self) }
            isLoading = false
        } catch {
            print("Error loading properties: \(error)")
            isLoading = false
        }
    }
} 