import Core
import SwiftUI
import AVKit
import ViewModels

public struct PropertyDetailView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var messagingViewModel = MessagingViewModel()
    let property: Property
    @State private var showingVideo = false
    @State private var showingContact = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                    
                    if !property.videoUrl.isEmpty {
                        Button {
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
                    if let amenities = property.amenities {
                        Text("Amenities")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(Array(amenities.keys.sorted().enumerated()), id: \.element) { index, amenity in
                                if amenities[amenity] ?? false {
                                    AmenityView(name: amenity)
                                }
                            }
                        }
                    }
                    
                    // Action Buttons
                    HStack {
                        Button {
                            Task {
                                do {
                                    try await appViewModel.propertyViewModel.toggleFavorite(propertyId: property.id ?? "", userId: appViewModel.authViewModel.currentUser?.id ?? "")
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
                        } label: {
                            Image(systemName: isFavorited ? "heart.fill" : "heart")
                                .foregroundColor(isFavorited ? .red : .gray)
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Button {
                            Task {
                                do {
                                    guard let userId = appViewModel.authViewModel.currentUser?.id else { return }
                                    let conversationId = try await messagingViewModel.createOrGetConversation(
                                        propertyId: property.id ?? "",
                                        tenantId: userId,
                                        managerId: property.managerId
                                    )
                                    if !conversationId.isEmpty {
                                        showingContact = true
                                    }
                                } catch {
                                    errorMessage = error.localizedDescription
                                    showError = true
                                }
                            }
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
            if !property.videoUrl.isEmpty, let videoURL = URL(string: property.videoUrl) {
                #if os(iOS)
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                #else
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(minHeight: 400)
                #endif
            }
        }
        .sheet(isPresented: $showingContact) {
            MessagingView()
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
            managerId: "123",
            title: "Sample Property",
            description: "A beautiful property",
            price: 2000,
            address: "123 Main St",
            videoUrl: "",
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