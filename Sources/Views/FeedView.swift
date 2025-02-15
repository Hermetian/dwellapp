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
    @State private var showFilters = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var selectedProperty: Property?
    
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
                    ScrollView(.vertical) {
                        TabView(selection: $videoFeedVM.currentIndex) {
                            ForEach(Array(videoFeedVM.videos.enumerated()), id: \ .element.id) { index, video in
                                VideoPlayerCard(
                                    video: video,
                                    cardIndex: index,
                                    activeIndex: $videoFeedVM.currentIndex,
                                    viewPropertyDisabled: (selectedProperty != nil),
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
                                            } catch {
                                                print("Error loading property: \(error)")
                                            }
                                        }
                                    }
                                )
                                .id(video.id ?? UUID().uuidString)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .onAppear {
                                    if index == videoFeedVM.currentIndex {
                                        videoFeedVM.onVideoAppear(at: index)
                                    }
                                    print("Video appeared: \(video.title) (type: \(video.videoType), userId: \(video.userId))")
                                }
                                .onChange(of: videoFeedVM.currentIndex) { newIndex in
                                    if index == newIndex {
                                        videoFeedVM.onVideoAppear(at: index)
                                    }
                                }
                                .tag(index)
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    }
                    .scrollDisabled(true)
                    .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                        videoFeedVM.currentIndex = videoFeedVM.currentIndex
                    }
                }
            }
        }
        .sheet(item: $selectedProperty) { property in
            PropertyDetailView(property: property)
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(showOnlyPropertyVideos: $videoFeedVM.showOnlyPropertyVideos)
        }
        .onAppear {
            setupFilterSubscription()
        }
        .onChange(of: showFilters) { isVisible in
            NotificationCenter.default.post(
                name: .mainFeedOverlayVisibilityChanged,
                object: nil,
                userInfo: ["isVisible": isVisible]
            )
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

    // New properties for active index tracking
    let cardIndex: Int
    @Binding var activeIndex: Int
    
    // Store whether this is a property video at initialization
    private let isPropertyVideo: Bool
    private let initialPropertyId: String
    let viewPropertyDisabled: Bool
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var playerVM = VideoPlayerViewModel()
    @EnvironmentObject private var chatViewModel: ChatViewModel
    @State private var isLoading = true
    @State private var showChatAlert = false
    @AppStorage("hasSeenChatTip") private var hasSeenChatTip = false
    @State private var showChatTip = false

    init(video: Video, cardIndex: Int, activeIndex: Binding<Int>, viewPropertyDisabled: Bool, onPropertyTap: @escaping () -> Void) {
        self.onPropertyTap = onPropertyTap
        self.cardIndex = cardIndex
        self._activeIndex = activeIndex
        _currentVideo = State(initialValue: video)
        self.isPropertyVideo = video.videoType == .property
        self.initialPropertyId = video.propertyId ?? ""
        self.viewPropertyDisabled = viewPropertyDisabled
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
                    ZStack {
                        VideoPlayer(player: player)
                            .disabled(true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Video Controls Overlay
                        VStack {
                            Spacer()
                            
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(height: 4)
                                    
                                    // Progress track
                                    Rectangle()
                                        .fill(Color.white)
                                        .frame(width: geometry.size.width * (playerVM.currentTime / max(playerVM.duration, 1)), height: 4)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let percentage = value.location.x / geometry.size.width
                                            let time = max(0, min(playerVM.duration * percentage, playerVM.duration))
                                            try? playerVM.seek(to: time)
                                        }
                                )
                            }
                            .frame(height: 30)
                            .padding(.horizontal)
                            
                            // Control buttons
                            HStack(spacing: 40) {
                                // Skip backward
                                Button {
                                    try? playerVM.seek(to: max(0, playerVM.currentTime - 10))
                                } label: {
                                    Image(systemName: "gobackward.10")
                                        .font(.system(size: 35))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                // Play/Pause
                                Button {
                                    if playerVM.isPlaying {
                                        playerVM.pause()
                                    } else {
                                        playerVM.play()
                                    }
                                } label: {
                                    Image(systemName: playerVM.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                
                                // Skip forward
                                Button {
                                    try? playerVM.seek(to: min(playerVM.duration, playerVM.currentTime + 10))
                                } label: {
                                    Image(systemName: "goforward.10")
                                        .font(.system(size: 35))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 20)
                            
                            // Time labels
                            HStack {
                                Text(formatTime(playerVM.currentTime))
                                Spacer()
                                Text(formatTime(playerVM.duration))
                            }
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 100)  // Add padding to avoid overlap with other controls
                    }
                }
                
                // Controls overlay
                VStack {
                    Spacer()
                    
                    HStack(alignment: .bottom, spacing: 20) {
                        // Left side - Video info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(currentVideo.title)
                                .font(.headline)
                            
                            if isPropertyVideo && !initialPropertyId.isEmpty {
                                Text(currentVideo.description)
                                    .font(.subheadline)
                                
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
                                .disabled(viewPropertyDisabled)
                            }
                        }
                        .padding()
                        .frame(width: geometry.size.width * 0.8, alignment: .leading)
                        
                        // Right side - Action buttons
                        VStack(spacing: 20) {
                            if isPropertyVideo && !initialPropertyId.isEmpty && currentVideo.userId != Auth.auth().currentUser?.uid {
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
            if isLoading {
                loadVideo()
            }
            playerVM.setOverlayVisible(false)
        }
        .onChange(of: showChatAlert) { newValue in
            playerVM.setOverlayVisible(newValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mainFeedOverlayVisibilityChanged)) { notification in
            if let isVisible = notification.userInfo?["isVisible"] as? Bool {
                playerVM.setOverlayVisible(isVisible)
            }
        }
        .onChange(of: activeIndex) { newValue in
            if newValue != cardIndex {
                playerVM.pause()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                playerVM.pause()
            } else {
                if activeIndex == cardIndex {
                    playerVM.play()
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
                if playerVM.isPlaying {
                    playerVM.play()
                }
                isLoading = false
            }
        }
    }
    
    private func formatTime(_ timeInSeconds: TimeInterval) -> String {
        let minutes = Int(timeInSeconds) / 60
        let seconds = Int(timeInSeconds) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationView {
        FeedView()
            .environmentObject(AppViewModel())
    }
}

// Add extension for the notification name
extension Notification.Name {
    static let mainFeedOverlayVisibilityChanged = Notification.Name("mainFeedOverlayVisibilityChanged")
} 