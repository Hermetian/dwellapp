import SwiftUI
import PhotosUI
import AVKit

struct UploadPropertyView: View {
    @StateObject private var propertyViewModel = PropertyViewModel()
    @StateObject private var authViewModel = AuthViewModel()
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
    
    let amenitiesList = ["Parking", "Pool", "Gym", "Elevator", "Security", "Furnished", "Pets Allowed", "Laundry"]
    
    var isFormValid: Bool {
        !title.isEmpty && !description.isEmpty && !price.isEmpty &&
        !address.isEmpty && !squareFootage.isEmpty && selectedVideoURL != nil
    }
    
    var body: some View {
        Form {
            Section(header: Text("Basic Information")) {
                TextField("Title", text: $title)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Price per month", text: $price)
                    .keyboardType(.decimalPad)
                TextField("Address", text: $address)
            }
            
            Section(header: Text("Specifications")) {
                Stepper("Bedrooms: \(bedrooms)", value: $bedrooms, in: 1...10)
                Stepper("Bathrooms: \(bathrooms)", value: $bathrooms, in: 1...10)
                TextField("Square Footage", text: $squareFootage)
                    .keyboardType(.numberPad)
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
        .navigationBarItems(
            leading: Button("Cancel") {
                dismiss()
            },
            trailing: Button("Post") {
                uploadProperty()
            }
            .disabled(!isFormValid)
        )
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
            if let videoURL = selectedVideoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .ignoresSafeArea()
            }
        }
        .alert("Upload Status", isPresented: $showAlert) {
            Button("OK") {
                if !alertMessage.contains("Error") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func uploadProperty() {
        guard let userId = authViewModel.currentUser?.id,
              let videoURL = selectedVideoURL else { return }
        
        // Convert amenities Set to Dictionary
        let amenitiesDict = Dictionary(uniqueKeysWithValues: 
            selectedAmenities.map { ($0, true) }
        )
        
        Task {
            do {
                await propertyViewModel.uploadProperty(
                    title: title,
                    description: description,
                    price: Double(price) ?? 0,
                    address: address,
                    videoURL: videoURL,
                    bedrooms: bedrooms,
                    bathrooms: bathrooms,
                    squareFootage: Double(squareFootage) ?? 0,
                    availableFrom: availableDate,
                    managerId: userId,
                    amenities: amenitiesDict
                )
                alertMessage = "Property listed successfully!"
            } catch {
                alertMessage = "Error: \(error.localizedDescription)"
            }
            showAlert = true
        }
    }
}

#Preview {
    NavigationView {
        UploadPropertyView()
    }
}