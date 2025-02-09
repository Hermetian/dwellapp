import SwiftUI
import PhotosUI
import AVKit

public struct VideoPickerView: View {
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    public init(onSelect: @escaping (URL) -> Void) {
        self.onSelect = onSelect
    }
    
    public var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading video...")
                } else {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .videos,
                        photoLibrary: .shared()
                    ) {
                        VStack(spacing: 12) {
                            Image(systemName: "video.badge.plus")
                                .font(.system(size: 48))
                                .foregroundColor(.blue)
                            
                            Text("Select Video")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .padding()
            .navigationTitle("Choose Video")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .onChange(of: selectedItem) { newItem in
                guard let item = newItem else { return }
                Task {
                    isLoading = true
                    do {
                        guard let transferable = try await item.loadTransferable(type: VideoTransferable.self) else {
                            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video"])
                        }
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathExtension("mp4")
                        try transferable.data.write(to: tempURL)
                        await MainActor.run {
                            onSelect(tempURL)
                            dismiss()
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                    isLoading = false
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

private struct VideoTransferable: Transferable {
    let data: Data
    let filename: String
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .movie) { data in
            VideoTransferable(data: data, filename: UUID().uuidString)
        }
    }
} 