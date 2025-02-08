import Core
import SwiftUI
import ViewModels
import AVKit
import Combine
import FirebaseFirestore

@MainActor
public struct FeedView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var videoFeedVM = VideoFeedViewModel()
    @State private var showPropertyDetails = false
    @State private var selectedProperty: Property?
    @State private var showFilters = false
    @State private var cancellables = Set<AnyCancellable>()
    
    public var body: some View {
        GeometryReader { geometry in
            TabView(selection: $videoFeedVM.currentIndex) {
                ForEach(Array(videoFeedVM.videos.enumerated()), id: \.element.id) { index, video in
                    VideoPlayerCard(
                        video: video,
                        onPropertyTap: { property in
                            selectedProperty = property
                            showPropertyDetails = true
                        }
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(
                        width: geometry.size.height,
                        height: geometry.size.width
                    )
                    .onAppear {
                        videoFeedVM.onVideoAppear(at: index)
                    }
                    .tag(index)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .rotationEffect(.degrees(90))
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showPropertyDetails) {
            if let property = selectedProperty {
                PropertyDetailView(property: property)
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(showOnlyPropertyVideos: $videoFeedVM.showOnlyPropertyVideos)
        }
        .onAppear {
            setupFilterSubscription()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
    
    private func setupFilterSubscription() {
        // Only setup property filters if we're showing property videos
        videoFeedVM.$showOnlyPropertyVideos
            .combineLatest(appViewModel.$propertyViewModel)
            .sink { showOnlyProperty, propertyVM in
                if showOnlyProperty {
                    let filteredIds = propertyVM.properties
                        .filter { property in
                            let typeFilter = appViewModel.filterViewModel.selectedPropertyTypes.contains(property.type)
            let priceFilter = appViewModel.filterViewModel.isPriceInRange(property.price, for: property.type)
            let bedroomFilter = appViewModel.filterViewModel.matchesBedroomFilter(property.bedrooms)
            let bathroomFilter = appViewModel.filterViewModel.matchesBathroomFilter(property.bathrooms)
            let amenitiesFilter = appViewModel.filterViewModel.matchesAmenitiesFilter(property.amenities)
            
                            return typeFilter && priceFilter && bedroomFilter && bathroomFilter && amenitiesFilter
                        }
                        .map { $0.id ?? "" }
                    
                    videoFeedVM.updatePropertyFilter(Set(filteredIds))
                } else {
                    videoFeedVM.updatePropertyFilter([])
                }
            }
            .store(in: &cancellables)
    }
}

private struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var showOnlyPropertyVideos: Bool
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section("Video Type") {
                    Toggle("Show Only Property Videos", isOn: $showOnlyPropertyVideos)
                }
                
                if showOnlyPropertyVideos {
                    Section("Property Filters") {
                        FilterView()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct VideoPlayerCard: View {
    let video: Video
    let onPropertyTap: (Property) -> Void
    
    @StateObject private var playerVM = VideoPlayerViewModel()
    @State private var property: Property?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let player = playerVM.player {
                VideoPlayer(player: player)
                    .disabled(true)
            }
            
            // Video controls and info overlay
            VStack {
                Spacer()
                
                HStack(alignment: .bottom) {
                    // Video info
                VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(.headline)
                        
                        if video.videoType == .property, let property = property {
                            HStack {
                                Text(formatPrice(property.price, type: property.type))
                                    .font(.subheadline)
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "bed.double.fill")
                            Text("\(property.bedrooms)")
                            Image(systemName: "drop.fill")
                            Text(String(format: "%.1f", property.bathrooms))
                        }
                                .font(.caption)
                            }
                        }
                        
                        Text(video.description)
                        .font(.subheadline)
                        
                        if video.videoType == .property, let property = property {
                            Button {
                                onPropertyTap(property)
                            } label: {
                                HStack {
                                    Image(systemName: "house.fill")
                                    Text("View Property")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 20) {
                        Button {
                            // Like functionality
                        } label: {
                            VStack {
                                Image(systemName: "heart.fill")
                                    .font(.title)
                                Text("Like")
                                    .font(.caption)
                            }
                        }
                        
                        Button {
                            // Share functionality
                        } label: {
                            VStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title)
                                Text("Share")
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.trailing)
                }
                .padding(.bottom, 30)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            
            if isLoading {
                ProgressView()
            }
        }
        .onAppear {
            loadVideo()
            if video.videoType == .property {
                loadProperty()
            }
        }
        .onDisappear {
            playerVM.pause()
        }
    }
    
    private func loadVideo() {
        Task {
            isLoading = true
            if let url = URL(string: video.videoUrl) {
                await playerVM.setVideo(url: url)
                isLoading = false
            }
        }
    }
    
    private func loadProperty() {
        guard let propertyId = video.propertyId else { return }
        
        Task {
            do {
                let db = Firestore.firestore()
                let docRef = db.collection("properties").document(propertyId)
                property = try await docRef.getDocument(as: Property.self)
            } catch {
                print("Error loading property: \(error)")
            }
        }
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