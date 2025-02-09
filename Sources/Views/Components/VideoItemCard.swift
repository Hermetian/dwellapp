import SwiftUI
import AVKit
import Core

struct VideoItemCard: View {
    @Binding var videoItem: VideoItem
    let onPreview: (VideoItem) -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Video Title", text: $videoItem.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 4)
            
            TextField("Video Description", text: $videoItem.description)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 4)
            
            HStack(spacing: 20) {
                Button {
                    onPreview(videoItem)
                } label: {
                    HStack {
                        Image(systemName: "play.circle")
                        Text("Preview")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
        .background(Color.clear)
    }
} 