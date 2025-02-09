import SwiftUI
import PhotosUI
import AVKit
import Core
import ViewModels
import Firebase

struct PropertyFormView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @Binding var property: Property
    @Binding var selectedVideos: [VideoItem]
    let mode: FormMode
    
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var previewState = PreviewState()
    @State private var showLinkVideoSheet = false
    @State private var showDeleteAlert = false
    
    let amenitiesList = ["Parking", "Pool", "Gym", "Elevator", "Security", "Furnished", "Pets Allowed", "Laundry"]
    
    enum FormMode {
        case create
        case edit
    }
    
    struct PreviewState {
        var isShowing = false
        var url: URL? = nil
        var player: AVPlayer? = nil
    }
    
    var pricingHint: String {
        switch property.type {
        case PropertyTypes.vacationRental.rawValue:
            return "per night"
        case PropertyTypes.roomRent.rawValue, PropertyTypes.propertyRent.rawValue:
            return "per month"
        case PropertyTypes.condoTownhouseBuy.rawValue, PropertyTypes.houseBuy.rawValue:
            return "purchase price"
        default:
            return "price"
        }
    }
    
    var isFormValid: Bool {
        !property.title.isEmpty && property.price > 0
    }
    
    var body: some View {
        Form {
            PropertyBasicInfoSection(property: $property, pricingHint: pricingHint)
            PropertySpecificationsSection(property: $property)
            PropertyVideosSection(
                selectedVideos: $selectedVideos,
                mode: mode,
                selectedVideo: $selectedVideo,
                showLinkVideoSheet: $showLinkVideoSheet,
                previewState: $previewState
            )
            PropertyAmenitiesSection(property: $property, amenitiesList: amenitiesList)
            
            if mode == .edit {
                Section {
                    Toggle("Available", isOn: Binding(
                        get: { property.isAvailable },
                        set: { newValue in
                            Task {
                                do {
                                    // Update backend first
                                    try await appViewModel.propertyViewModel.updateProperty(
                                        id: property.id ?? "",
                                        data: ["isAvailable": newValue]
                                    )
                                    // Only update UI if backend update succeeds
                                    var updated = property
                                    updated.isAvailable = newValue
                                    property = updated
                                } catch {
                                    alertMessage = error.localizedDescription
                                    showAlert = true
                                }
                            }
                        }
                    ))
                    .tint(property.isAvailable ? .green : .gray)
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete Property", systemImage: "trash")
                    }
                }
            }
        }
        .onChange(of: selectedVideo) { _ in
            Task {
                if let video = selectedVideo,
                   let data = try? await video.loadTransferable(type: Data.self),
                   let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fileName = "\(UUID().uuidString).mov"
                    let fileURL = directory.appendingPathComponent(fileName)
                    try? data.write(to: fileURL)
                    
                    let originalFileName = video.itemIdentifier?.components(separatedBy: "/").last ?? ""
                    let nameWithoutExtension = originalFileName.components(separatedBy: ".").first ?? "Untitled Video"
                    
                    await MainActor.run {
                        selectedVideos.append(VideoItem(
                            url: fileURL,
                            title: nameWithoutExtension,
                            description: ""
                        ))
                        selectedVideo = nil
                    }
                }
            }
        }
        .sheet(isPresented: $previewState.isShowing) {
            VideoPreviewView(previewState: $previewState)
        }
        .sheet(isPresented: $showLinkVideoSheet) {
            LinkVideoView(
                property: $property,
                selectedVideos: $selectedVideos
            )
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .alert("Delete Property", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        try await appViewModel.propertyViewModel.deleteProperty(property)
                        dismiss()
                    } catch {
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this property? This action cannot be undone.")
        }
    }
}

struct VideoPreviewView: View {
    @Binding var previewState: PropertyFormView.PreviewState
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemBackground)
                        .edgesIgnoringSafeArea(.all)
                    
                    if let player = previewState.player {
                        ZStack {
                            Color(.systemBackground)
                            VideoPlayer(player: player)
                                .background(Color(.systemBackground))
                        }
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(width: geometry.size.width)
                        .frame(maxHeight: .infinity)
                        .onAppear {
                            player.play()
                        }
                        .onDisappear {
                            player.pause()
                            previewState.player = nil
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        previewState.player?.pause()
                        previewState.player = nil
                        previewState.isShowing = false
                    }
                }
            }
        }
    }
}

struct PropertyBasicInfoSection: View {
    @Binding var property: Property
    let pricingHint: String
    
    let propertyTypes = [
        PropertyTypes.vacationRental.rawValue,
        PropertyTypes.roomRent.rawValue,
        PropertyTypes.propertyRent.rawValue,
        PropertyTypes.condoTownhouseBuy.rawValue,
        PropertyTypes.houseBuy.rawValue
    ]
    
    var body: some View {
        Section(header: Text("Basic Information")) {
            TextField("Title", text: $property.title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
            
            TextField("Description", text: $property.description, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
            
            Picker("Property Type", selection: $property.type) {
                ForEach(propertyTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            
            HStack {
                TextField("Price", value: $property.price, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text(pricingHint)
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            
            TextField("Address", text: $property.address)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
        }
    }
}

struct PropertySpecificationsSection: View {
    @Binding var property: Property
    
    var body: some View {
        Section(header: Text("Specifications")) {
            Stepper("Bedrooms: \(property.bedrooms)", value: $property.bedrooms, in: 1...10)
            
            Stepper("Bathrooms: \(Int(property.bathrooms))", value: Binding(
                get: { Int(property.bathrooms) },
                set: { property.bathrooms = Double($0) }
            ), in: 1...10)
            
            TextField("Square Footage", value: $property.squareFootage, format: .number)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
            
            DatePicker("Available From", selection: $property.availableFrom, displayedComponents: .date)
        }
    }
}

struct PropertyVideosSection: View {
    @Binding var selectedVideos: [VideoItem]
    let mode: PropertyFormView.FormMode
    @Binding var selectedVideo: PhotosPickerItem?
    @Binding var showLinkVideoSheet: Bool
    @Binding var previewState: PropertyFormView.PreviewState
    
    private func makeVideoCard(at index: Int) -> VideoItemCard {
        VideoItemCard(
            videoItem: $selectedVideos[index],
            onPreview: { (video: VideoItem) in
                previewState.url = video.url
                previewState.player = AVPlayer(url: video.url)
                previewState.isShowing = true
            },
            onDelete: {
                withAnimation(.easeInOut) {
                    var videos = selectedVideos
                    videos.remove(at: index)
                    selectedVideos = videos
                }
            }
        )
    }
    
    var body: some View {
        Section(header: Text("Videos")) {
            if mode == .create {
                PhotosPicker(selection: $selectedVideo, matching: .videos) {
                    Label("Add Video", systemImage: "video.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                .padding(.vertical, 4)
            } else {
                Group {
                    PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        Label("Add New Video", systemImage: "video.badge.plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    .padding(.bottom, 8)
                }
                
                Group {
                    Button {
                        showLinkVideoSheet = true
                    } label: {
                        Label("Link Existing Video", systemImage: "link")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            
            let indices: Range<Int> = selectedVideos.indices
            ForEach(indices, id: \.self) { index in
                makeVideoCard(at: index)
            }
            
            if !selectedVideos.isEmpty {
                Text("\(selectedVideos.count) video\(selectedVideos.count == 1 ? "" : "s") selected")
                    .foregroundColor(.gray)
            }
        }
    }
}

struct PropertyAmenitiesSection: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Binding var property: Property
    let amenitiesList: [String]
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    private func amenityBinding(for amenity: String) -> Binding<Bool> {
        Binding(
            get: {
                let currentAmenities = property.amenities ?? [:]
                return currentAmenities[amenity] ?? false
            },
            set: { isSelected in
                Task {
                    do {
                        // Create updated property for UI
                        var updated = property
                        var updatedAmenities = updated.amenities ?? [:]
                        updatedAmenities[amenity] = isSelected
                        updated.amenities = updatedAmenities
                        
                        // Update backend first
                        if let id = property.id {
                            try await appViewModel.propertyViewModel.updateProperty(
                                id: id,
                                data: ["amenities": updatedAmenities]
                            )
                            // Only update UI if backend update succeeds
                            property = updated
                        } else {
                            // If no ID (new property), just update UI
                            property = updated
                        }
                    } catch {
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            }
        )
    }
    
    var body: some View {
        Section(header: Text("Amenities")) {
            ForEach(amenitiesList, id: \.self) { amenity in
                Toggle(amenity, isOn: amenityBinding(for: amenity))
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
}

struct PropertyFormViewPreviewWrapper: View {
    @State var property: Property = Property.preview
    @State var selectedVideos: [VideoItem] = []
    var body: some View {
        // Use edit mode to test toggles
        PropertyFormView(property: $property, selectedVideos: $selectedVideos, mode: .edit)
            .environmentObject(AppViewModel())
    }
}

#Preview {
    PropertyFormViewPreviewWrapper()
} 