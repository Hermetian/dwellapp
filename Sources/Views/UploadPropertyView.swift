import SwiftUI
import PhotosUI
import AVKit
import Models
import ViewModels

struct UploadPropertyView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var price = ""
    @State private var address = ""
    @State private var bedrooms = 1
    @State private var bathrooms = 1
    @State private var squareFootage = ""
    @State private var availableDate = Date()
    @State private var selectedVideo: PhotosPickerItem?
    @State private var selectedVideoURL: URL?
    @State private var showVideoPlayer = false
    @State private var selectedAmenities: Set<String> = []
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var propertyType = "Apartment"
    
    let amenitiesList = ["Parking", "Pool", "Gym", "Elevator", "Security", "Furnished", "Pets Allowed", "Laundry"]
    let propertyTypes = ["Apartment", "House", "Condo", "Townhouse"]
    
    var isFormValid: Bool {
        !title.isEmpty && !description.isEmpty && !price.isEmpty &&
        !address.isEmpty && !squareFootage.isEmpty && selectedVideoURL != nil
    }
    
    var body: some View {
        Form {
            Section(header: Text("Basic Information")) {
                TextField("Title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                TextField("Description", text: $description, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                TextField("Price", text: $price)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                TextField("Address", text: $address)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .textInputAutocapitalization(.words)
                    #endif
                Picker("Property Type", selection: $propertyType) {
                    ForEach(propertyTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
            }
            
            Section(header: Text("Specifications")) {
                Stepper("Bedrooms: \(bedrooms)", value: $bedrooms, in: 1...10)
                Stepper("Bathrooms: \(bathrooms)", value: $bathrooms, in: 1...10)
                TextField("Square Footage", text: $squareFootage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                DatePicker("Available From", selection: $availableDate, displayedComponents: .date)
            }
            
            Section(header: Text("Video")) {
                PhotosPicker(selection: $selectedVideo, matching: .videos) {
                    if selectedVideoURL != nil {
                        Label("Change Video", systemImage: "video.badge.plus")
                    } else {
                        Label("Select Video", systemImage: "video.badge.plus")
                    }
                }
                
                if selectedVideoURL != nil {
                    Button(action: { showVideoPlayer = true }) {
                        Label("Preview Video", systemImage: "play.circle")
                    }
                }
            }
            
            Section(header: Text("Amenities")) {
                ForEach(amenitiesList, id: \.self) { amenity in
                    Toggle(amenity, isOn: Binding(
                        get: { selectedAmenities.contains(amenity) },
                        set: { isSelected in
                            if isSelected {
                                selectedAmenities.insert(amenity)
                            } else {
                                selectedAmenities.remove(amenity)
                            }
                        }
                    ))
                }
            }
        }
        .navigationTitle("List Property")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Post") {
                    uploadProperty()
                }
                .disabled(!isFormValid)
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
                    selectedVideoURL = fileURL
                }
            }
        }
        .sheet(isPresented: $showVideoPlayer) {
            videoPreviewView
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("OK") {
                if !alertMessage.contains("Error") {
                    dismiss()
                }
            }
        }
    }
    
    private func uploadProperty() {
        guard let userId = appViewModel.authViewModel.currentUser?.id else { return }
        
        let property = Property(
            managerId: userId,
            title: title,
            description: description,
            price: Double(price) ?? 0,
            address: address,
            videoUrl: "",  // Will be updated after video upload
            bedrooms: bedrooms,
            bathrooms: Double(bathrooms),
            squareFootage: Double(squareFootage) ?? 0,
            availableFrom: availableDate,
            type: propertyType,
            userId: userId
        )
        
        Task {
            do {
                try await appViewModel.propertyViewModel.createProperty(property)
                alertMessage = "Property listed successfully!"
                showAlert = true
            } catch {
                alertMessage = "Error: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private var videoPreviewView: some View {
        Group {
            if let videoURL = selectedVideoURL {
                #if os(iOS)
                AVPlayerViewController(player: AVPlayer(url: videoURL))
                    .ignoresSafeArea()
                #elseif os(macOS)
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 300)
                #endif
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