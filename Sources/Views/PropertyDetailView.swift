import Core
import SwiftUI
import AVKit
import ViewModels
import FirebaseFirestore

public struct PropertyDetailView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var messagingViewModel = MessagingViewModel()
    let property: Property
    @State private var showingVideo = false
    @State private var selectedVideoId: String?
    @State private var showingContact = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var videos: [Video] = []
    @State private var previewPlayer: AVPlayer?
    
    private var isFavorited: Bool {
        appViewModel.propertyViewModel.favoriteProperties.contains { $0.id == property.id }
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Property Images/Video
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: property.thumbnailUrl ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Color.gray
                    }
                    .frame(height: 250)
                    .clipped()
                    
                    if !property.videoIds.isEmpty {
                        Button {
                            selectedVideoId = property.videoIds.first
                            showingVideo = true
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding(8)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    // Title and Price
                    HStack {
                        Text(property.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Text("$\(Int(property.price))/month")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    // Address
                    Text(property.address)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Property Details
                    HStack(spacing: 20) {
                        DetailItem(icon: "bed.double.fill", value: "\(property.bedrooms)")
                        DetailItem(icon: "shower.fill", value: String(format: "%.1f", property.bathrooms))
                        DetailItem(icon: "square.fill", value: "\(Int(property.squareFootage)) sqft")
                    }
                    
                    // Description
                    Text("Description")
                        .font(.headline)
                    Text(property.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // Amenities
                    if let amenities = property.amenities, !amenities.isEmpty {
                        Text("Amenities")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(appViewModel.propertyViewModel.sortedAmenities(for: property), id: \ .self) { amenity in
                                AmenityView(name: amenity)
                            }
                        }
                    }
                    
                    // Action Buttons
                    HStack {
                        Button {
                            if let propertyId = property.id, !propertyId.isEmpty {
                                Task {
                                    do {
                                        try await appViewModel.propertyViewModel.toggleFavorite(
                                            propertyId: propertyId,
                                            userId: appViewModel.authViewModel.currentUser?.id ?? ""
                                        )
                                    } catch {
                                        errorMessage = error.localizedDescription
                                        showError = true
                                    }
                                }
                            } else {
                                errorMessage = "Property not saved. Cannot favorite."
                                showError = true
                            }
                        } label: {
                            Image(systemName: isFavorited ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(isFavorited ? .red : .gray)
                        }
                        .buttonStyle(.bordered)
                        .disabled(property.id?.isEmpty ?? true)
                        
                        Spacer()
                        
                        Button {
                            // Check that the currentUser id and property id are valid
                            guard let userId = appViewModel.authViewModel.currentUser?.id,
                                  let propertyId = property.id, !propertyId.isEmpty else {
                                errorMessage = "Property not saved. Cannot contact manager."
                                showError = true
                                return
                            }
                            
                            // Check if trying to message oneself
                            if userId == property.managerId {
                                errorMessage = "Despite everything, it's still you (can't message oneself)"
                                showError = true
                                return
                            }
                            
                            showingContact = true
                        } label: {
                            Text("Contact Manager")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingVideo) {
            NavigationView {
                GeometryReader { geometry in
                    ZStack {
                        Color(.systemBackground)
                            .edgesIgnoringSafeArea(.all)
                        
                        if let videoId = selectedVideoId,
                           let video = videos.first(where: { video in video.id == videoId }),
                           let videoURL = URL(string: video.videoUrl) {
                            ZStack {
                                VideoPlayer(player: previewPlayer ?? AVPlayer(url: videoURL))
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .edgesIgnoringSafeArea(.all)
                                    .onAppear {
                                        if previewPlayer == nil {
                                            previewPlayer = AVPlayer(url: videoURL)
                                        }
                                        previewPlayer?.play()
                                    }
                                    .onDisappear {
                                        previewPlayer?.pause()
                                        previewPlayer = nil
                                    }
                                
                                // Add like button overlay
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button {
                                            if let propertyId = property.id, !propertyId.isEmpty {
                                                Task {
                                                    do {
                                                        try await appViewModel.propertyViewModel.toggleFavorite(
                                                            propertyId: propertyId,
                                                            userId: appViewModel.authViewModel.currentUser?.id ?? ""
                                                        )
                                                    } catch {
                                                        errorMessage = error.localizedDescription
                                                        showError = true
                                                    }
                                                }
                                            } else {
                                                errorMessage = "Property not saved. Cannot favorite."
                                                showError = true
                                            }
                                        } label: {
                                            Image(systemName: isFavorited ? "heart.fill" : "heart")
                                                .font(.system(size: 30))
                                                .foregroundColor(isFavorited ? .red : .white)
                                                .padding(20)
                                                .background(.ultraThinMaterial)
                                                .clipShape(Circle())
                                        }
                                        .padding(.trailing, 20)
                                        .padding(.bottom, 20)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            previewPlayer?.pause()
                            previewPlayer = nil
                            showingVideo = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingContact) {
            NavigationView {
                MessagingView(
                    propertyId: property.id ?? "",
                    managerId: property.managerId,
                    videoId: selectedVideoId
                )
                .environmentObject(appViewModel)
            }
        }
        .task {
            // Load videos when view appears
            if !property.videoIds.isEmpty {
                do {
                    let db = Firestore.firestore()
                    let snapshot = try await db.collection("videos")
                        .whereField(FieldPath.documentID(), in: property.videoIds)
                        .getDocuments()
                    videos = try snapshot.documents.map { try $0.data(as: Video.self) }
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct DetailItem: View {
    let icon: String
    let value: String
    
    public var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(value)
                .font(.subheadline)
        }
    }
}

struct AmenityView: View {
    let name: String
    
    public var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(name)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        PropertyDetailView(property: Property(
            id: "sample-property-id",
            managerId: "123",
            title: "Sample Property",
            description: "A beautiful property",
            price: 2000,
            address: "123 Main St",
            videoIds: [],
            bedrooms: 2,
            bathrooms: 2,
            squareFootage: 1000,
            availableFrom: Date(),
            type: "Apartment",
            userId: "123"
        ))
        .environmentObject(AppViewModel())
    }
} 