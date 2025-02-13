import Core
import SwiftUI
import ViewModels
import AVKit
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
public struct FeedView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var videoFeedVM = VideoFeedViewModel()
    @State private var showPropertyDetails = false
    @State private var selectedProperty: Property?
    @State private var showFilters = false
    @State private var cancellables = Set<AnyCancellable>()
    
    public var body: some View {
        Group {
            if videoFeedVM.isLoading {
                ProgressView("Loading videos...")
            } else if videoFeedVM.videos.isEmpty {
                VStack(spacing: 16) {
                    Text("No videos found")
                        .font(.headline)
                    if videoFeedVM.showOnlyPropertyVideos {
                        Text("Try disabling property-only filter")
                            .foregroundColor(.secondary)
                    }
                    if let error = videoFeedVM.error {
                        Text("Error: \(error.localizedDescription)")
                            .foregroundColor(.red)
                    }
                }
            } else {
                GeometryReader { geometry in
                    TabView(selection: $videoFeedVM.currentIndex) {
                        ForEach(Array(videoFeedVM.videos.enumerated()), id: \.element.id) { index, video in
                            VideoPlayerCard(
                                video: video,
                                onPropertyTap: {
                                    guard let propertyId = video.propertyId, !propertyId.isEmpty else {
                                        print("No propertyId for video \(video.id ?? "")")
                                        return
                                    }
                                    Task {
                                        do {
                                            let db = Firestore.firestore()
                                            let docRef = db.collection("properties").document(propertyId)
                                            let prop = try await docRef.getDocument(as: Property.self)
                                            selectedProperty = prop
                                            showPropertyDetails = true
                                        } catch {
                                            print("Error loading property: \(error)")
                                        }
                                    }
                                }
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onAppear {
                                videoFeedVM.onVideoAppear(at: index)
                                print("Video appeared: \(video.title) (type: \(video.videoType), userId: \(video.userId))")
                            }
                            .tag(index)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
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
            List {
                Section {
                    Toggle("Show Only Property Videos", isOn: $showOnlyPropertyVideos)
                }
                
                if showOnlyPropertyVideos {
                    Section(header: Text("Property Types")) {
                        ForEach(FilterViewModel.propertyTypes, id: \.self) { type in
                            Toggle(type, isOn: Binding(
                                get: { appViewModel.filterViewModel.selectedPropertyTypes.contains(type) },
                                set: { isSelected in
                                    if isSelected {
                                        appViewModel.filterViewModel.selectedPropertyTypes.insert(type)
                                    } else {
                                        appViewModel.filterViewModel.selectedPropertyTypes.remove(type)
                                    }
                                    appViewModel.filterViewModel.saveFilters()
                                }
                            ))
                        }
                    }
                    
                    if !appViewModel.filterViewModel.selectedPropertyTypes.isEmpty {
                        Section(header: Text("Bedrooms")) {
                            Picker("Bedrooms", selection: Binding(
                                get: { appViewModel.filterViewModel.selectedBedrooms },
                                set: { newValue in
                                    appViewModel.filterViewModel.selectedBedrooms = newValue
                                    appViewModel.filterViewModel.saveFilters()
                                }
                            )) {
                                ForEach(FilterViewModel.bedroomOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        Section(header: Text("Bathrooms")) {
                            Picker("Bathrooms", selection: Binding(
                                get: { appViewModel.filterViewModel.selectedBathrooms },
                                set: { newValue in
                                    appViewModel.filterViewModel.selectedBathrooms = newValue
                                    appViewModel.filterViewModel.saveFilters()
                                }
                            )) {
                                ForEach(FilterViewModel.bathroomOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        if appViewModel.filterViewModel.selectedPropertyTypes.contains("Vacation Rental") {
                            Section(header: Text("Price per Night")) {
                                PriceRangeSlider(
                                    value: Binding(
                                        get: { appViewModel.filterViewModel.vacationRentalPriceRange },
                                        set: { range in
                                            appViewModel.filterViewModel.vacationRentalPriceRange = range
                                            appViewModel.filterViewModel.saveFilters()
                                        }
                                    ),
                                    range: 0...1000,
                                    step: 50
                                )
                            }
                        }
                        
                        if !appViewModel.filterViewModel.selectedPropertyTypes.isDisjoint(with: ["Room (Rent)", "Property (Rent)"]) {
                            Section(header: Text("Price per Month")) {
                                PriceRangeSlider(
                                    value: Binding(
                                        get: { appViewModel.filterViewModel.rentalPriceRange },
                                        set: { range in
                                            appViewModel.filterViewModel.rentalPriceRange = range
                                            appViewModel.filterViewModel.saveFilters()
                                        }
                                    ),
                                    range: 0...10000,
                                    step: 100
                                )
                            }
                        }
                        
                        if !appViewModel.filterViewModel.selectedPropertyTypes.isDisjoint(with: ["Condo/Townhouse (Buy)", "House (Buy)"]) {
                            Section(header: Text("Purchase Price")) {
                                PriceRangeSlider(
                                    value: Binding(
                                        get: { appViewModel.filterViewModel.purchasePriceRange },
                                        set: { range in
                                            appViewModel.filterViewModel.purchasePriceRange = range
                                            appViewModel.filterViewModel.saveFilters()
                                        }
                                    ),
                                    range: 0...2000000,
                                    step: 50000
                                )
                            }
                        }
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
    @State private var currentVideo: Video
    let onPropertyTap: () -> Void
    
    @StateObject private var playerVM = VideoPlayerViewModel()
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @State private var property: Property?
    @State private var isLoading = true
    @State private var showPreview = false
    @State private var previewPlayer: AVPlayer?
    @State private var showChatAlert = false
    @AppStorage("hasSeenChatTip") private var hasSeenChatTip = false
    @State private var showChatTip = false
    
    init(video: Video, onPropertyTap: @escaping () -> Void) {
        self.onPropertyTap = onPropertyTap
        _currentVideo = State(initialValue: video)
    }
    
    private func refreshVideo() {
        guard let videoId = currentVideo.id, !videoId.isEmpty else { return }
        Task {
            do {
                let db = Firestore.firestore()
                let docRef = db.collection("videos").document(videoId)
                let updatedVideo = try await docRef.getDocument(as: Video.self)
                currentVideo = updatedVideo
            } catch {
                print("Error refreshing video: \(error)")
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background layer
                Color.black
                
                // Video player
                if let player = playerVM.player {
                    VideoPlayer(player: player)
                        .disabled(true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // Controls overlay
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 20) {
                        // Left side - Video info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(currentVideo.title)
                                .font(.headline)
                            
                            if currentVideo.videoType == .property,
                               let propertyId = currentVideo.propertyId,
                               !propertyId.isEmpty {
                                if let prop = property {
                                    HStack {
                                        Text(formatPrice(prop.price, type: prop.type))
                                            .font(.subheadline)
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Image(systemName: "bed.double.fill")
                                            Text("\(prop.bedrooms)")
                                            Image(systemName: "drop.fill")
                                            Text(String(format: "%.1f", prop.bathrooms))
                                        }
                                        .font(.caption)
                                    }
                                    Text(currentVideo.description)
                                        .font(.subheadline)
                                }
                                
                                Button {
                                    onPropertyTap()
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
                        .frame(maxWidth: .infinity * 0.8, alignment: .leading)
                        
                        // Right side - Action buttons
                        VStack(spacing: 20) {
                            Button {
                                print("Preview button pressed for video: \(currentVideo.title)")
                                showPreview = true
                            } label: {
                                VStack {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title)
                                    Text("Preview")
                                        .font(.caption)
                                }
                                .frame(width: 60, height: 60)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                            }
                            
                            if currentVideo.videoType == .property,
                               let propertyId = currentVideo.propertyId,
                               !propertyId.isEmpty,
                               currentVideo.userId != Auth.auth().currentUser?.uid {
                                Button {
                                    showChatAlert = true
                                    hasSeenChatTip = true
                                    showChatTip = false
                                } label: {
                                    VStack {
                                        Image(systemName: "message.fill")
                                            .font(.title)
                                        Text("Chat")
                                            .font(.caption)
                                    }
                                    .frame(width: 60, height: 60)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(8)
                                }
                                .overlay {
                                    if !hasSeenChatTip && showChatTip {
                                        VStack {
                                            Text("👋 Tap here to chat about this property!")
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(8)
                                                .background(Color.blue)
                                                .cornerRadius(8)
                                        }
                                        .offset(x: -120, y: 0)
                                    }
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
                                .frame(width: 60, height: 60)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.trailing, 20)
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
        }
        .onAppear {
            refreshVideo()
            loadVideo()
            if currentVideo.videoType == .property {
                loadProperty()
            }
        }
        .onDisappear {
            playerVM.pause()
            previewPlayer?.pause()
            previewPlayer = nil
        }
        .sheet(isPresented: $showPreview) {
            NavigationView {
                Group {
                    if let url = URL(string: currentVideo.videoUrl) {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                            .onAppear {
                                previewPlayer = AVPlayer(url: url)
                                previewPlayer?.play()
                            }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            previewPlayer?.pause()
                            previewPlayer = nil
                            showPreview = false
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showChatAlert) {
            Alert(
                title: Text("Start Chat"),
                message: Text("Would you like to start a conversation about this property?"),
                primaryButton: .default(Text("Yes")) {
                    Task {
                        await chatViewModel.createChannel(forVideo: currentVideo)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func loadVideo() {
        Task {
            isLoading = true
            if let url = URL(string: currentVideo.videoUrl) {
                await playerVM.setVideo(url: url)
                isLoading = false
            }
        }
    }
    
    private func loadProperty() {
        guard let propertyId = currentVideo.propertyId, !propertyId.isEmpty else { 
            property = nil
            return 
        }
        
        Task {
            do {
                let db = Firestore.firestore()
                let docRef = db.collection("properties").document(propertyId)
                property = try await docRef.getDocument(as: Property.self)
            } catch {
                print("Error loading property: \(error)")
                property = nil
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