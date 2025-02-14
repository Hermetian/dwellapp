import SwiftUI
import Core
import ViewModels
import FirebaseFirestore
import AVKit

public struct ManageVideosView: View {
    @StateObject private var viewModel: VideoViewModel
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var videoToDelete: Video?
    @State private var showDeleteConfirmation = false
    @State private var showEditVideo = false
    @State private var showStoryboardEditor = false
    @State private var selectedVideo: Video?
    @State private var properties: [Property] = []
    
    public init() {
        _viewModel = StateObject(wrappedValue: VideoViewModel(
            databaseService: DatabaseService(),
            storageService: StorageService(),
            videoService: VideoService()
        ))
    }
    
    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.videos.isEmpty {
                    ProgressView("Loading videos...")
                } else {
                    videosList
                }
            }
            .navigationTitle("Manage Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showStoryboardEditor = true
                    } label: {
                        Label("New Remix", systemImage: "plus.rectangle.on.rectangle")
                    }
                }
            }
            .task {
                // Initial load of videos and properties
                let currentUserId = appViewModel.authViewModel.currentUser?.id
                try? await viewModel.loadVideos(userId: currentUserId)
                await loadProperties()
            }
            .sheet(isPresented: $showEditVideo) {
                if let video = selectedVideo {
                    VideoMetadataEditorView(video: video) {
                        Task {
                            let currentUserId = appViewModel.authViewModel.currentUser?.id
                            try? await viewModel.loadVideos(userId: currentUserId)
                        }
                    }
                }
            }
            .onChange(of: showEditVideo) { isVisible in
                NotificationCenter.default.post(
                    name: .mainFeedOverlayVisibilityChanged,
                    object: nil,
                    userInfo: ["isVisible": isVisible]
                )
            }
            .sheet(isPresented: $showStoryboardEditor) {
                if let video = selectedVideo {
                    VideoStoryboardEditor(initialVideo: video) {
                        Task {
                            let currentUserId = appViewModel.authViewModel.currentUser?.id
                            try? await viewModel.loadVideos(userId: currentUserId)
                        }
                    }
                } else {
                    VideoStoryboardEditor(initialVideo: nil) {
                        Task {
                            let currentUserId = appViewModel.authViewModel.currentUser?.id
                            try? await viewModel.loadVideos(userId: currentUserId)
                        }
                    }
                }
            }
            .onChange(of: showStoryboardEditor) { isVisible in
                NotificationCenter.default.post(
                    name: .mainFeedOverlayVisibilityChanged,
                    object: nil,
                    userInfo: ["isVisible": isVisible]
                )
            }
        }
    }
    
    private var videosList: some View {
        List {
            ForEach(viewModel.videos) { video in
                VideoRowView(
                    video: video,
                    onEdit: {
                        selectedVideo = video
                        showEditVideo = true
                    },
                    onRemix: {
                        selectedVideo = video
                        showStoryboardEditor = true
                    },
                    onDelete: {
                        videoToDelete = video
                        showDeleteConfirmation = true
                    }
                )
                .onAppear {
                    if video.id == viewModel.videos.last?.id && !viewModel.isLoading && viewModel.hasMoreVideos {
                        Task {
                            let currentUserId = appViewModel.authViewModel.currentUser?.id
                            try? await viewModel.loadVideos(userId: currentUserId)
                        }
                    }
                }
            }
            
            if viewModel.isLoading && !viewModel.videos.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .confirmationDialog(
            "Delete Video",
            isPresented: $showDeleteConfirmation,
            presenting: videoToDelete
        ) { video in
            Button("Delete", role: .destructive) {
                Task {
                    try? await viewModel.deleteVideo(video)
                }
            }
        } message: { video in
            Text("Are you sure you want to delete '\(video.title)'?")
        }
    }
    
    private func loadProperties() async {
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("properties").getDocuments()
            properties = try snapshot.documents.map { try $0.data(as: Property.self) }
        } catch {
            print("Error loading properties: \(error)")
        }
    }
}

// Separate view for video row to improve performance
private struct VideoRowView: View {
    let video: Video
    let onEdit: () -> Void
    let onRemix: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(video.title)
                .font(.headline)
            Text(video.description)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Property information
            if let propertyId = video.propertyId {
                Text("Property ID: \(propertyId)")
                    .font(.caption)
                    .foregroundColor(.blue)
            } else {
                Text("Unattached")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            Text("Uploaded: \(video.uploadDate.formatted())")
                .font(.caption)
                .foregroundColor(.gray)
            
            // Action buttons
            HStack {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                
                Button {
                    onRemix()
                } label: {
                    Label("Remix", systemImage: "scissors")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
    }
} 