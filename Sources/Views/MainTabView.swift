import SwiftUI
import ViewModels
import Core
import FirebaseFirestore
import AVKit
import FirebaseStorage

public struct MainTabView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var selectedTab = 0
    @State private var showFilters = false
    @State private var showRadialMenu = false
    @State private var showNewVideo = false
    @State private var showNewProperty = false
    @State private var showManageVideos = false
    @State private var showManageProperties = false
    @State private var openedByHold = false
    @GestureState private var dragLocation: CGPoint?
    @State private var isHolding = false
    @StateObject private var videoService = VideoService()
    
    private var menuItems: [RadialMenuItem] {
        [
            RadialMenuItem(title: "New Video", icon: "video.badge.plus") {
                showNewVideo = true
                showRadialMenu = false
            },
            RadialMenuItem(title: "New Property", icon: "plus.square.fill") {
                showNewProperty = true
                showRadialMenu = false
            },
            RadialMenuItem(title: "Manage Videos", icon: "video.square") {
                showManageVideos = true
                showRadialMenu = false
            },
            RadialMenuItem(title: "Manage Properties", icon: "building.2") {
                showManageProperties = true
                showRadialMenu = false
            }
        ]
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            TabView(selection: $selectedTab) {
                NavigationStack {
                    FeedView()
                }
                .tag(0)
                
                NavigationStack {
                    MessagingView()
                }
                .tag(1)
                
                NavigationStack {
                    ProfileView()
                }
                .tag(2)
            }
            
            // Custom Tab Bar
            VStack(spacing: 0) {
                // Radial Menu Overlay
                if showRadialMenu {
                    Color.black
                        .opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showRadialMenu = false
                        }
                    
                    RadialMenu(
                        items: menuItems,
                        isPressed: $showRadialMenu,
                        openedByHold: openedByHold,
                        dragLocation: dragLocation
                    )
                        .frame(height: 220)
                        .offset(y: -40)
                }
                
                HStack(spacing: 0) {
                    // Feed Tab (Larger)
                    Button {
                        selectedTab = 0
                    } label: {
                        HStack {
                            Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                                .font(.title3)
                            Text("Feed")
                        }
                        .padding(.horizontal)
                        .frame(height: 44)
                        .background(selectedTab == 0 ? Color.blue.opacity(0.1) : Color.clear)
                        .cornerRadius(22)
                    }
                    .foregroundColor(selectedTab == 0 ? .blue : .primary)
                    .frame(width: UIScreen.main.bounds.width * 0.45)
                    
                    // Upload & Manage (Center)
                    VStack(spacing: 2) {
                        Image(systemName: "signpost.right.fill")
                            .font(.title3)
                        Text("List")
                            .font(.caption)
                    }
                    .foregroundColor(showRadialMenu ? .blue : .primary)
                    .frame(width: 60)
                    .frame(width: UIScreen.main.bounds.width * 0.25)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        openedByHold = false
                        showRadialMenu.toggle()
                    }
                    .gesture(
                        SequenceGesture(
                            LongPressGesture(minimumDuration: 0.3)
                                .onEnded { _ in
                                    openedByHold = true
                                    isHolding = true
                                    showRadialMenu = true
                                },
                            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                .updating($dragLocation) { value, state, _ in
                                    if isHolding {
                                        state = value.location
                                    }
                                }
                                .onEnded { value in
                                    if isHolding {
                                        isHolding = false
                                    }
                                }
                        )
                    )
                    
                    // Messages Tab (Icon only)
                    Button {
                        selectedTab = 1
                    } label: {
                        Image(systemName: selectedTab == 1 ? "message.fill" : "message")
                            .font(.title3)
                    }
                    .foregroundColor(selectedTab == 1 ? .blue : .primary)
                    .frame(width: UIScreen.main.bounds.width * 0.15)
                    
                    // Profile Tab (Icon only)
                    Button {
                        selectedTab = 2
                    } label: {
                        Image(systemName: selectedTab == 2 ? "person.fill" : "person")
                            .font(.title3)
                    }
                    .foregroundColor(selectedTab == 2 ? .blue : .primary)
                    .frame(width: UIScreen.main.bounds.width * 0.15)
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .background(
                    Rectangle()
                        .fill(.thinMaterial)
                        .ignoresSafeArea()
                )
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterView()
        }
        .sheet(isPresented: $showNewVideo) {
            NavigationStack {
                VideoUploadView(
                    videoService: videoService,
                    userId: appViewModel.authViewModel.currentUser?.id ?? ""
                )
            }
        }
        .sheet(isPresented: $showNewProperty) {
            UploadPropertyView()
        }
        .sheet(isPresented: $showManageVideos) {
            ManageVideosView()
        }
        .sheet(isPresented: $showManageProperties) {
            ManagePropertiesView()
        }
    }
    
    public init() {}
}

#Preview {
    MainTabView()
        .environmentObject(AppViewModel())
}

struct ManageVideosView: View {
    @StateObject private var viewModel = VideoFeedViewModel()
    @Environment(\.dismiss) private var dismiss
    @StateObject private var videoService = VideoService()
    @State private var videoToDelete: Video?
    @State private var showDeleteConfirmation = false
    @State private var showEditVideo = false
    @State private var selectedVideo: Video?
    @State private var properties: [Property] = []
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.videos) { video in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(.headline)
                        Text(video.description)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        // Property information
                        if let propertyId = video.propertyId {
                            if let property = properties.first(where: { $0.id == propertyId }) {
                                Text("Property: \(property.title)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            } else {
                                Text("Property: Loading...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Text("Unattached")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Text("Uploaded: \(video.uploadDate.formatted())")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        // Action buttons
                        HStack {
                            Button {
                                selectedVideo = video
                                showEditVideo = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.borderless)
                            
                            Spacer()
                            
                            Button {
                                videoToDelete = video
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Manage Videos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete Video",
                isPresented: $showDeleteConfirmation,
                presenting: videoToDelete
            ) { video in
                Button("Delete", role: .destructive) {
                    Task {
                        if let id = video.id {
                            try? await videoService.deleteVideo(id: id)
                            await viewModel.loadInitialVideos()
                        }
                    }
                }
            } message: { video in
                Text("Are you sure you want to delete '\(video.title)'?")
            }
            .task {
                // Load properties for displaying property titles
                do {
                    let db = Firestore.firestore()
                    let snapshot = try await db.collection("properties").getDocuments()
                    properties = try snapshot.documents.map { try $0.data(as: Property.self) }
                } catch {
                    print("Error loading properties: \(error)")
                }
            }
            .sheet(isPresented: $showEditVideo) {
                if let video = selectedVideo {
                    VideoEditView(video: video) {
                        // Reload videos after edit
                        Task {
                            await viewModel.loadInitialVideos()
                        }
                    }
                }
            }
        }
    }
}

struct VideoEditView: View {
    let video: Video
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var isLoading = false
    @State private var showVideoEditor = false
    @StateObject private var videoService = VideoService()
    
    init(video: Video, onSave: @escaping () -> Void) {
        self.video = video
        self.onSave = onSave
        _title = State(initialValue: video.title)
        _description = State(initialValue: video.description)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                }
                
                if let url = URL(string: video.videoUrl) {
                    Section {
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(height: 200)
                        
                        Button {
                            showVideoEditor = true
                        } label: {
                            Label("Edit Video", systemImage: "wand.and.stars")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Edit Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isLoading = true
                            do {
                                let db = Firestore.firestore()
                                if let id = video.id {
                                    try await db.collection("videos").document(id).updateData([
                                        "title": title,
                                        "description": description
                                    ])
                                    onSave()
                                    dismiss()
                                }
                            } catch {
                                print("Error updating video: \(error)")
                            }
                            isLoading = false
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showVideoEditor) {
                if let url = URL(string: video.videoUrl) {
                    VideoEditorView(videoURL: url) { editedURL in
                        Task {
                            isLoading = true
                            do {
                                // Upload the edited video
                                let videoData = try Data(contentsOf: editedURL)
                                let storageRef = Storage.storage().reference().child("videos/\(UUID().uuidString).mp4")
                                let metadata = StorageMetadata()
                                metadata.contentType = "video/mp4"
                                
                                _ = try await storageRef.putDataAsync(videoData, metadata: metadata)
                                let downloadURL = try await storageRef.downloadURL()
                                
                                // Update the video document
                                if let id = video.id {
                                    try await Firestore.firestore().collection("videos").document(id).updateData([
                                        "videoUrl": downloadURL.absoluteString
                                    ])
                                }
                                
                                // Delete the old video file
                                if let oldURL = URL(string: video.videoUrl) {
                                    let oldRef = Storage.storage().reference(forURL: oldURL.absoluteString)
                                    try? await oldRef.delete()
                                }
                                
                                onSave()
                                dismiss()
                            } catch {
                                print("Error saving edited video: \(error)")
                            }
                            isLoading = false
                        }
                    }
                }
            }
        }
    }
}

struct ManagePropertiesView: View {
    var body: some View {
        Text("Manage Properties View")
    }
}