import SwiftUI
import Core
import ViewModels

struct LinkVideoView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding var property: Property
    @Binding var selectedVideos: [VideoItem]
    
    @State private var showUnlinkAlert = false
    @State private var selectedVideo: Video?
    @State private var linkedPropertyTitle = ""
    
    var body: some View {
        NavigationView {
            List {
                ForEach(appViewModel.videoViewModel.videos.sorted(by: { $0.uploadDate > $1.uploadDate })) { video in
                    Button {
                        if video.propertyId != nil {
                            selectedVideo = video
                            // Fetch the property title for the alert
                            if let propertyId = video.propertyId {
                                Task {
                                    await appViewModel.propertyViewModel.loadProperty(id: propertyId)
                                    if let property = appViewModel.propertyViewModel.property {
                                        linkedPropertyTitle = property.title
                                        showUnlinkAlert = true
                                    }
                                }
                            }
                        } else {
                            linkVideo(video)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(video.title)
                                    .foregroundColor(video.propertyId != nil ? .red : .primary)
                                Text(video.description)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(video.uploadDate.formatted())
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            if video.propertyId != nil {
                                Image(systemName: "link")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Video Already Linked", isPresented: $showUnlinkAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Unlink & Relink", role: .destructive) {
                if let video = selectedVideo {
                    unlinkAndRelink(video)
                }
            }
        } message: {
            Text("This video is currently linked to '\(linkedPropertyTitle)'. Would you like to remove it from that property and link it here?")
        }
    }
    
    private func linkVideo(_ video: Video) {
        Task {
            do {
                try await appViewModel.propertyViewModel.addVideoToProperty(
                    propertyId: property.id ?? "",
                    videoId: video.id ?? ""
                )
                
                // Add to selectedVideos
                if let url = URL(string: video.videoUrl) {
                    await MainActor.run {
                        selectedVideos.append(VideoItem(
                            url: url,
                            title: video.title,
                            description: video.description
                        ))
                    }
                }
                
                dismiss()
            } catch {
                print("Error linking video: \(error)")
            }
        }
    }
    
    private func unlinkAndRelink(_ video: Video) {
        guard let videoId = video.id,
              let oldPropertyId = video.propertyId else { return }
        
        Task {
            do {
                // Remove from old property
                try await appViewModel.propertyViewModel.removeVideoFromProperty(
                    propertyId: oldPropertyId,
                    videoId: videoId
                )
                
                // Add to new property
                try await appViewModel.propertyViewModel.addVideoToProperty(
                    propertyId: property.id ?? "",
                    videoId: videoId
                )
                
                // Add to selectedVideos
                if let url = URL(string: video.videoUrl) {
                    await MainActor.run {
                        selectedVideos.append(VideoItem(
                            url: url,
                            title: video.title,
                            description: video.description
                        ))
                    }
                }
                
                dismiss()
            } catch {
                print("Error unlinking and relinking video: \(error)")
            }
        }
    }
}

#Preview {
    LinkVideoView(property: .constant(Property.preview), selectedVideos: .constant([]))
        .environmentObject(AppViewModel())
} 