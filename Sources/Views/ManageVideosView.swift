import SwiftUI
import Core
import ViewModels
import FirebaseFirestore
import AVKit

public struct ManageVideosView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @Environment(\.dismiss) private var dismiss
    @StateObject private var videoService = VideoService()
    @State private var videoToDelete: Video?
    @State private var showDeleteConfirmation = false
    @State private var showEditVideo = false
    @State private var showStoryboardEditor = false
    @State private var selectedVideo: Video?
    @State private var properties: [Property] = []
    
    public var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.videos) { video in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(.headline)
                        Text(video.description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        // Property information
                        if let propertyId = video.propertyId {
                            if let property = properties.first(where: { $0.id == propertyId }) {
                                Text("Property: \(property.title)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Property: Loading...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
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
                                selectedVideo = video
                                showEditVideo = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless)
                            
                            Button {
                                selectedVideo = video
                                showStoryboardEditor = true
                            } label: {
                                Label("Remix", systemImage: "scissors")
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.borderless)
                            
                            Spacer()
                            
                            Button {
                                videoToDelete = video
                                showDeleteConfirmation = true
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
            .confirmationDialog(
                "Delete Video",
                isPresented: $showDeleteConfirmation,
                presenting: videoToDelete
            ) { video in
                Button("Delete", role: .destructive) {
                    Task {
                        if let id = video.id {
                            try? await videoService.deleteVideo(id: id)
                            viewModel.loadInitialVideos()
                        }
                    }
                }
            } message: { video in
                Text("Are you sure you want to delete '\(video.title)'?")
            }
            .task {
                // Load properties for displaying property titles
                do {
                    let db = Firestore.firestore()
                    let snapshot = try await db.collection("properties").getDocuments()
                    properties = try snapshot.documents.map { try $0.data(as: Property.self) }
                } catch {
                    print("Error loading properties: \(error)")
                }
            }
            .sheet(isPresented: $showEditVideo) {
                if let video = selectedVideo {
                    VideoMetadataEditorView(video: video) {
                        Task {
                            viewModel.loadInitialVideos()
                        }
                    }
                }
            }
            .sheet(isPresented: $showStoryboardEditor) {
                VideoStoryboardEditor(initialVideo: selectedVideo) {
                    Task {
                        viewModel.loadInitialVideos()
                    }
                }
            }
        }
    }
} 