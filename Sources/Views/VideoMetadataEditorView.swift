import SwiftUI
import AVKit
import Core
import FirebaseFirestore
import FirebaseStorage

@MainActor
public struct VideoMetadataEditorView: View {
    let video: Video
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var isLoading = false
    @State private var showVideoEditor = false
    @StateObject private var videoService = VideoService()
    
    public init(video: Video, onSave: @escaping () -> Void) {
        self.video = video
        self.onSave = onSave
        _title = State(initialValue: video.title)
        _description = State(initialValue: video.description)
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }
                
                if let url = URL(string: video.videoUrl) {
                    Section {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(height: 200)
                        
                        Button {
                            showVideoEditor = true
                        } label: {
                            Label("Edit Video", systemImage: "wand.and.stars")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Edit Video")
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
                            isLoading = true
                            do {
                                let db = Firestore.firestore()
                                if let id = video.id {
                                    let updates: [String: String] = [
                                        "title": title,
                                        "description": description
                                    ]
                                    try await db.collection("videos").document(id).updateData(updates)
                                    onSave()
                                    dismiss()
                                }
                            } catch {
                                print("Error updating video: \(error)")
                            }
                            isLoading = false
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showVideoEditor) {
                if let url = URL(string: video.videoUrl) {
                    VideoEditorView(videoURL: url) { editedURL in
                        Task {
                            isLoading = true
                            do {
                                // Upload the edited video
                                let videoData = try Data(contentsOf: editedURL)
                                let storageRef = Storage.storage().reference().child("videos/\(UUID().uuidString).mp4")
                                let metadata = StorageMetadata()
                                metadata.contentType = "video/mp4"
                                
                                _ = try await storageRef.putDataAsync(videoData, metadata: metadata)
                                let downloadURL = try await storageRef.downloadURL()
                                
                                // Update the video document
                                if let id = video.id {
                                    let updates: [String: String] = [
                                        "videoUrl": downloadURL.absoluteString
                                    ]
                                    try await Firestore.firestore().collection("videos").document(id).updateData(updates)
                                }
                                
                                // Delete the old video file
                                if let oldURL = URL(string: video.videoUrl) {
                                    let oldRef = Storage.storage().reference(forURL: oldURL.absoluteString)
                                    try? await oldRef.delete()
                                }
                                
                                onSave()
                                dismiss()
                            } catch {
                                print("Error saving edited video: \(error)")
                            }
                            isLoading = false
                        }
                    }
                }
            }
        }
    }
} 