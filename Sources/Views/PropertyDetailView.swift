import SwiftUI
import Models
import AVKit
import ViewModels

struct PropertyDetailView: View {
    let property: Property
    let userId: String
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    @StateObject private var messagingViewModel = MessagingViewModel()
    @Environment(\.dismiss) private var dismiss
    
    init(property: Property, userId: String) {
        self.property = property
        self.userId = userId
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Video Player
                VideoPlayerView(url: URL(string: property.videoUrl)!)
                    .frame(height: 300)
                
                // Property Details
                VStack(alignment: .leading, spacing: 20) {
                    // Title and Price
                    VStack(alignment: .leading, spacing: 8) {
                        Text(property.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(formatPrice(property.price))
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    
                    // Specifications
                    HStack(spacing: 20) {
                        SpecificationView(
                            icon: "bed.double.fill",
                            value: "\(property.bedrooms)",
                            label: "Beds"
                        )
                        
                        SpecificationView(
                            icon: "shower.fill",
                            value: "\(property.bathrooms)",
                            label: "Baths"
                        )
                        
                        SpecificationView(
                            icon: "square.fill",
                            value: formatArea(property.squareFootage),
                            label: "Sq Ft"
                        )
                    }
                    
                    // Description
                    Text("Description")
                        .font(.headline)
                    
                    Text(property.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // Address
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        Text(property.address)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Available From
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Available From")
                            .font(.headline)
                        
                        Text(formatDate(property.availableFrom))
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Amenities
                    if let amenities = property.amenities {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Amenities")
                                .font(.headline)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(Array(amenities.keys), id: \.self) { key in
                                    if let value = amenities[key] as? Bool, value {
                                        AmenityView(name: key)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button {
                            Task {
                                await appViewModel.propertyViewModel.toggleFavorite(
                                    propertyId: property.id ?? "",
                                    userId: userId
                                )
                            }
                        } label: {
                            Label(
                                appViewModel.propertyViewModel.favoriteProperties.contains { $0.id == property.id } ? "Favorited" : "Add to Favorites",
                                systemImage: appViewModel.propertyViewModel.favoriteProperties.contains { $0.id == property.id } ? "heart.fill" : "heart"
                            )
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            Task {
                                let conversationId = await messagingViewModel.createOrGetConversation(
                                    propertyId: property.id ?? "",
                                    tenantId: userId,
                                    managerId: property.managerId
                                )
                                
                                if let conversationId = conversationId {
                                    // Navigate to chat
                                    // TODO: Implement navigation to chat
                                }
                            }
                        } label: {
                            Label("Contact Manager", systemImage: "message")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(appViewModel.propertyViewModel.error != nil)) {
            Button("OK") {
                appViewModel.propertyViewModel.error = nil
            }
        } message: {
            Text(appViewModel.propertyViewModel.error?.localizedDescription ?? "")
        }
        .onAppear {
            Task {
                await appViewModel.propertyViewModel.incrementViewCount(for: property.id ?? "")
            }
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
    
    private func formatArea(_ area: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: area)) ?? "\(area)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct SpecificationView: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct AmenityView: View {
    let name: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text(name.capitalized)
                .font(.subheadline)
        }
    }
}

struct VideoPlayerView: View {
    let url: URL
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    
    var body: some View {
        ZStack {
            if videoPlayerViewModel.isLoading {
                ProgressView()
            } else if let thumbnailImage = videoPlayerViewModel.thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            
            VideoPlayer(player: AVPlayer(url: url))
                .onAppear {
                    Task {
                        await videoPlayerViewModel.setupPlayer(with: url)
                    }
                }
                .onDisappear {
                    videoPlayerViewModel.cleanup()
                }
        }
    }
}

#Preview {
    PropertyDetailView(
        property: Property(
            managerId: "123",
            title: "Luxury Apartment",
            description: "Beautiful apartment with amazing views",
            price: 500000,
            address: "123 Main St",
            videoUrl: "https://example.com/video.mp4",
            bedrooms: 2,
            bathrooms: 2,
            squareFootage: 1200,
            availableFrom: Date()
        ),
        userId: "456"
    )
} 