import SwiftUI
import PhotosUI
import AVKit
import Core
import ViewModels

struct UploadPropertyView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedVideo: PhotosPickerItem?
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var previewState = PreviewState()
    @State private var refreshID = UUID()
    
    let amenitiesList = ["Parking", "Pool", "Gym", "Elevator", "Security", "Furnished", "Pets Allowed", "Laundry"]
    let propertyTypes = [
        "Vacation Rental",
        "Room (Rent)",
        "Property (Rent)",
        "Condo/Townhouse (Buy)",
        "House (Buy)"
    ]
    
    var pricingHint: String {
        switch appViewModel.propertyViewModel.draftPropertyType {
        case "Vacation Rental":
            return "per night"
        case "Room (Rent)", "Property (Rent)":
            return "per month"
        default:
            return "price"
        }
    }
    
    var isFormValid: Bool {
        !appViewModel.propertyViewModel.draftTitle.isEmpty && 
        !appViewModel.propertyViewModel.draftDescription.isEmpty && 
        !appViewModel.propertyViewModel.draftPrice.isEmpty &&
        !appViewModel.propertyViewModel.draftAddress.isEmpty && 
        !appViewModel.propertyViewModel.draftSquareFootage.isEmpty && 
        !appViewModel.propertyViewModel.draftSelectedVideos.isEmpty
    }
    
    // Add a separate preview state
    struct PreviewState {
        var isShowing = false
        var url: URL? = nil
        var player: AVPlayer? = nil
    }
    
    var body: some View {
        VStack {
        Form {
            Section(header: Text("Basic Information")) {
                    TextField("Title", text: $appViewModel.propertyViewModel.draftTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                    TextField("Description", text: $appViewModel.propertyViewModel.draftDescription, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                    
                    Picker("Property Type", selection: $appViewModel.propertyViewModel.draftPropertyType) {
                        ForEach(propertyTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    HStack {
                        TextField("Price", text: $appViewModel.propertyViewModel.draftPrice)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                        Text(pricingHint)
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    
                    TextField("Address", text: $appViewModel.propertyViewModel.draftAddress)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
            }
            
            Section(header: Text("Specifications")) {
                    Stepper("Bedrooms: \(appViewModel.propertyViewModel.draftBedrooms)", value: $appViewModel.propertyViewModel.draftBedrooms, in: 1...10)
                    Stepper("Bathrooms: \(appViewModel.propertyViewModel.draftBathrooms)", value: $appViewModel.propertyViewModel.draftBathrooms, in: 1...10)
                    TextField("Square Footage", text: $appViewModel.propertyViewModel.draftSquareFootage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                    DatePicker("Available From", selection: $appViewModel.propertyViewModel.draftAvailableDate, displayedComponents: .date)
            }
            
                Section(header: Text("Videos")) {
                PhotosPicker(selection: $selectedVideo, matching: .videos) {
                        Label("Add Video", systemImage: "video.badge.plus")
                    }
                    
                    ForEach(appViewModel.propertyViewModel.draftSelectedVideos, id: \.id) { video in
                        VStack(alignment: .leading, spacing: 8) {
                            // Title field - explicitly interactive
                            TextField("Video Title", text: Binding(
                                get: { video.title.isEmpty ? "" : video.title },
                                set: { newValue in
                                    if let index = appViewModel.propertyViewModel.draftSelectedVideos.firstIndex(where: { $0.id == video.id }) {
                                        appViewModel.propertyViewModel.draftSelectedVideos[index].title = newValue
                                    }
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 4)
                            
                            // Description field - explicitly interactive
                            TextField("Video Description", text: Binding(
                                get: { video.description.isEmpty ? "" : video.description },
                                set: { newValue in
                                    if let index = appViewModel.propertyViewModel.draftSelectedVideos.firstIndex(where: { $0.id == video.id }) {
                                        appViewModel.propertyViewModel.draftSelectedVideos[index].description = newValue
                                    }
                                }
                            ))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 4)
                            
                            // Action buttons in their own container
                            HStack(spacing: 20) {
                                Button {
                                    print("Preview button pressed for video: \(video.title)")
                                    previewState.url = video.url
                                    previewState.player = AVPlayer(url: video.url)
                                    previewState.isShowing = true
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
                                
                                Button {
                                    print("Delete button pressed for video: \(video.title)")
                                    withAnimation(.easeInOut) {
                                        appViewModel.propertyViewModel.draftSelectedVideos.removeAll { $0.id == video.id }
                                        refreshID = UUID()
                                    }
                                } label: {
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
                        .contentShape(Rectangle())
                        .transition(.opacity.combined(with: .scale))
                        .id(refreshID)
                    }
                }
                
                if !appViewModel.propertyViewModel.draftSelectedVideos.isEmpty {
                    Section {
                        Text("\(appViewModel.propertyViewModel.draftSelectedVideos.count) video\(appViewModel.propertyViewModel.draftSelectedVideos.count == 1 ? "" : "s") selected")
                            .foregroundColor(.gray)
                }
            }
            
            Section(header: Text("Amenities")) {
                ForEach(amenitiesList, id: \.self) { amenity in
                    Toggle(amenity, isOn: Binding(
                            get: { appViewModel.propertyViewModel.draftSelectedAmenities.contains(amenity) },
                        set: { isSelected in
                            if isSelected {
                                    appViewModel.propertyViewModel.draftSelectedAmenities.insert(amenity)
                            } else {
                                    appViewModel.propertyViewModel.draftSelectedAmenities.remove(amenity)
                                }
                            }
                        ))
                    }
                }
            }
            
            // Post button at the bottom
            Button(action: {
                uploadProperty()
            }) {
                Text("Post Property")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isFormValid)
            .padding()
        }
        .navigationTitle("List Property")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
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
                    
                    // Extract the original filename without extension
                    let originalFileName = video.itemIdentifier?.components(separatedBy: "/").last ?? ""
                    let nameWithoutExtension = originalFileName.components(separatedBy: ".").first ?? "Untitled Video"
                    
                    // Add new video to the list with the original filename as title
                    await MainActor.run {
                        appViewModel.propertyViewModel.draftSelectedVideos.append(VideoItem(
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
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") {
                if !alertMessage.contains("Error") {
                    appViewModel.propertyViewModel.clearDraft()
                    dismiss()
                }
            }
        }
    }
    
    private func uploadProperty() {
        guard let userId = appViewModel.authViewModel.currentUser?.id else { return }
        
        // Create property without videos first
        let property = Property(
            managerId: userId,
            title: appViewModel.propertyViewModel.draftTitle,
            description: appViewModel.propertyViewModel.draftDescription,
            price: Double(appViewModel.propertyViewModel.draftPrice) ?? 0,
            address: appViewModel.propertyViewModel.draftAddress,
            videoIds: [], // Will be updated after video uploads
            bedrooms: appViewModel.propertyViewModel.draftBedrooms,
            bathrooms: Double(appViewModel.propertyViewModel.draftBathrooms),
            squareFootage: Double(appViewModel.propertyViewModel.draftSquareFootage) ?? 0,
            availableFrom: appViewModel.propertyViewModel.draftAvailableDate,
            type: appViewModel.propertyViewModel.draftPropertyType,
            userId: userId
        )
        
        Task {
            do {
                // Create property first
                let propertyId = try await appViewModel.propertyViewModel.createProperty(property)
                
                // Upload all videos
                var videoIds: [String] = []
                for video in appViewModel.propertyViewModel.draftSelectedVideos {
                    let videoId = try await appViewModel.videoViewModel.uploadVideo(
                        url: video.url,
                        propertyId: propertyId,
                        title: video.title,
                        description: video.description,
                        userId: userId
                    )
                    videoIds.append(videoId)
                }
                
                // Update property with video IDs
                if !videoIds.isEmpty {
                    try await appViewModel.propertyViewModel.updateProperty(
                        id: propertyId,
                        data: ["videoIds": videoIds]
                    )
                }
                
                alertMessage = "Property listed successfully!"
                showAlert = true
            } catch {
                alertMessage = "Error: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

#Preview {
    NavigationView {
        UploadPropertyView()
            .environmentObject(AppViewModel())
    }
}