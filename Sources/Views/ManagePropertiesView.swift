import SwiftUI
import Core
import ViewModels

struct ManagePropertiesView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var propertyToDelete: Property?
    @State private var editingVideos: [VideoItem] = []
    @State private var editingProperty: Property?
    @State private var isLoading = false
    
    private var emptyProperty: Property {
        Property(
            managerId: appViewModel.authViewModel.currentUser?.id ?? "",
            title: "",
            description: "",
            price: 0,
            address: "",
            videoIds: [],
            bedrooms: 1,
            bathrooms: 1,
            squareFootage: 0,
            availableFrom: Date(),
            type: PropertyTypes.propertyRent.rawValue,
            userId: appViewModel.authViewModel.currentUser?.id ?? ""
        )
    }
    
    var body: some View {
        List {
            ForEach(appViewModel.propertyViewModel.properties) { property in
                PropertyRowView(
                    property: property,
                    onEdit: {
                        editingProperty = property
                        loadVideos(for: property)
                    },
                    onDelete: {
                        propertyToDelete = property
                        showDeleteAlert = true
                    },
                    onToggleAvailability: {
                        toggleAvailability(for: property)
                    }
                )
            }
        }
        .navigationTitle("Manage Properties")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingProperty = emptyProperty
                    editingVideos = []
                    showEditSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditSheet, onDismiss: {
            // Clear editing state when sheet is dismissed
            editingProperty = nil
            editingVideos = []
        }) {
            if let propertyIndex = editingProperty.flatMap({ property in
                appViewModel.propertyViewModel.properties.firstIndex(where: { $0.id == property.id })
            }) {
                NavigationView {
                    PropertyEditSheet(
                        property: Binding(
                            get: { appViewModel.propertyViewModel.properties[propertyIndex] },
                            set: { newValue in
                                appViewModel.propertyViewModel.properties[propertyIndex] = newValue
                            }
                        ),
                        editingVideos: $editingVideos
                    )
                }
            } else if let property = editingProperty {
                // New property
                NavigationView {
                    PropertyEditSheet(
                        property: Binding(
                            get: { property },
                            set: { editingProperty = $0 }
                        ),
                        editingVideos: $editingVideos
                    )
                }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .alert("Delete Property", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let property = propertyToDelete {
                    showEditSheet = false  // Trigger sheet dismissal first
                    
                    Task {
                        do {
                            try await appViewModel.propertyViewModel.deleteProperty(property)
                            await MainActor.run {
                                // Update UI state after successful deletion
                                appViewModel.propertyViewModel.properties.removeAll { $0.id == property.id }
                                editingProperty = nil
                                editingVideos = []
                                propertyToDelete = nil
                            }
                        } catch {
                            print("Error deleting property: \(error)")
                        }
                    }
                }
            }
        } message: {
            if let property = propertyToDelete {
                Text("Are you sure you want to delete '\(property.title)'? This action cannot be undone.")
            }
        }
    }
    
    private func loadVideos(for property: Property) {
        Task {
            isLoading = true
            editingVideos = []
            do {
                let currentUserId = appViewModel.authViewModel.currentUser?.id
                let videos = try await appViewModel.videoViewModel.getPropertyVideos(
                    propertyId: property.id ?? "",
                    userId: currentUserId
                )
                editingVideos = videos.compactMap { video in
                    guard let url = URL(string: video.videoUrl) else { return nil }
                    return VideoItem(
                        url: url,
                        title: video.title,
                        description: video.description
                    )
                }
                await MainActor.run {
                    showEditSheet = true
                    isLoading = false
                }
            } catch {
                print("Error loading videos: \(error)")
                await MainActor.run {
                    showEditSheet = true
                    isLoading = false
                }
            }
        }
    }
    
    private func toggleAvailability(for property: Property) {
        Task {
            var updated = property
            updated.isAvailable = !property.isAvailable
            try? await appViewModel.propertyViewModel.updateProperty(
                id: property.id ?? "",
                data: ["isAvailable": updated.isAvailable]
            )
            if let index = appViewModel.propertyViewModel.properties.firstIndex(where: { $0.id == property.id }) {
                appViewModel.propertyViewModel.properties[index] = updated
            }
        }
    }
}

#Preview {
    NavigationView {
        ManagePropertiesView()
            .environmentObject(AppViewModel())
    }
} 