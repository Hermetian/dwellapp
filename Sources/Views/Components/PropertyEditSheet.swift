import SwiftUI
import Core
import ViewModels

struct PropertyEditSheet: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @Binding var property: Property
    @Binding var editingVideos: [VideoItem]
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(property: Binding<Property>, editingVideos: Binding<[VideoItem]>) {
        self._property = property
        self._editingVideos = editingVideos
    }
    
    var body: some View {
        NavigationView {
            PropertyFormView(
                property: $property,
                selectedVideos: $editingVideos,
                mode: property.id == nil ? .create : .edit
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            do {
                                if property.id == nil {
                                    // Create new property
                                    _ = try await appViewModel.propertyViewModel.createPropertyWithVideos(
                                        property,
                                        videos: editingVideos,
                                        userId: appViewModel.authViewModel.currentUser?.id ?? ""
                                    )
                                } else {
                                    // Update existing property
                                    try await appViewModel.propertyViewModel.updateProperty(
                                        id: property.id ?? "",
                                        data: property.dictionary
                                    )
                                    
                                    // Update videos if needed
                                    for (index, videoId) in property.videoIds.enumerated() {
                                        if index < editingVideos.count {
                                            let videoItem = editingVideos[index]
                                            try await appViewModel.videoViewModel.updateVideo(
                                                videoId,
                                                title: videoItem.title,
                                                description: videoItem.description
                                            )
                                        }
                                    }
                                }
                                
                                dismiss()
                            } catch {
                                alertMessage = error.localizedDescription
                                showAlert = true
                            }
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
} 