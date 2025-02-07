import Core
import SwiftUI
import ViewModels
import AVKit

public struct FeedView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var currentIndex = 0
    @State private var showPropertyDetails = false
    @State private var selectedProperty: Property?
    
    public var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(Array(filteredProperties.enumerated()), id: \.element.uniqueIdentifier) { index, property in
                    VideoPlayerCard(property: property, geometry: geometry)
                        .tag(index)
                        .onTapGesture {
                            selectedProperty = property
                            showPropertyDetails = true
                        }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPropertyDetails) {
            if let property = selectedProperty {
                PropertyDetailView(property: property)
            }
        }
        .task {
            do {
                try await appViewModel.propertyViewModel.loadProperties()
            } catch {
                print("Error loading properties: \(error)")
            }
        }
    }
    
    private var filteredProperties: [Property] {
        appViewModel.propertyViewModel.properties.filter { property in
            // Apply filters based on user preferences
            let priceFilter = appViewModel.filterViewModel.isPriceInRange(property.price, for: property.type)
            let typeFilter = appViewModel.filterViewModel.selectedPropertyTypes.contains(property.type)
            let bedroomFilter = appViewModel.filterViewModel.matchesBedroomFilter(property.bedrooms)
            let bathroomFilter = appViewModel.filterViewModel.matchesBathroomFilter(property.bathrooms)
            let amenitiesFilter = appViewModel.filterViewModel.matchesAmenitiesFilter(property.amenities)
            
            return priceFilter && typeFilter && bedroomFilter && bathroomFilter && amenitiesFilter
        }
    }
}

struct VideoPlayerCard: View {
    let property: Property
    let geometry: GeometryProxy
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear {
                        player.play()
                        isPlaying = true
                    }
                    .onDisappear {
                        player.pause()
                        isPlaying = false
                    }
            }
            
            VStack(alignment: .leading) {
                Spacer()
                
                // Property info overlay
                VStack(alignment: .leading, spacing: 8) {
                    Text(property.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(property.type)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(formatPrice(property.price, type: property.type))
                            .font(.headline)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "bed.double.fill")
                            Text("\(property.bedrooms)")
                            Image(systemName: "drop.fill")
                            Text(String(format: "%.1f", property.bathrooms))
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
        }
        .onAppear {
            setupPlayer()
        }
    }
    
    private func setupPlayer() {
        guard let url = URL(string: property.videoUrl) else { return }
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        self.player = player
    }
    
    private func formatPrice(_ price: Double, type: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        
        let formattedPrice = formatter.string(from: NSNumber(value: price)) ?? "$0"
        
        switch type {
        case "Vacation Rental":
            return "\(formattedPrice)/night"
        case "Room (Rent)", "Property (Rent)":
            return "\(formattedPrice)/month"
        default:
            return formattedPrice
        }
    }
}

#Preview {
    NavigationView {
        FeedView()
            .environmentObject(AppViewModel())
    }
} 