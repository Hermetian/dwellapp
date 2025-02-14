import Foundation
import FirebaseFirestore
import Combine
import Core

@MainActor
public class VideoFeedViewModel: ObservableObject {
    @Published public var videos: [Core.Video] = []
    @Published public var currentIndex: Int = 0
    @Published public var isLoading = false
    @Published public var error: Error?
    @Published public var showOnlyPropertyVideos = false
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private var cancellables = Set<AnyCancellable>()
    private let pageSize = 5
    private var propertyIds: Set<String> = []
    
    public init() {
        loadInitialVideos()
    }
    
    public func updatePropertyFilter(_ propertyIds: Set<String>) {
        self.propertyIds = propertyIds
        loadInitialVideos()
    }
    
    public func toggleVideoTypeFilter(showOnlyPropertyVideos: Bool) {
        self.showOnlyPropertyVideos = showOnlyPropertyVideos
        loadInitialVideos()
    }
    
    public func loadInitialVideos() {
        Task {
            isLoading = true
            do {
                var query = db.collection("videos")
                    .order(by: "serverTimestamp", descending: true)
                
                if showOnlyPropertyVideos {
                    if !propertyIds.isEmpty {
                        // Show filtered property videos
                        query = query
                            .whereField("videoType", isEqualTo: Core.VideoType.property.rawValue)
                            .whereField("propertyId", in: Array(propertyIds))
                    } else {
                        // Show all property videos
                        query = query.whereField("videoType", isEqualTo: Core.VideoType.property.rawValue)
                    }
                }
                // When not in property-only mode, show all videos without any type filtering
                
                query = query.limit(to: pageSize)
                let querySnapshot = try await query.getDocuments()
                
                videos = try querySnapshot.documents.map { try $0.data(as: Core.Video.self) }
                lastDocument = querySnapshot.documents.last
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    public func loadMoreVideos() {
        guard !isLoading, let last = lastDocument else { return }
        
        Task {
            isLoading = true
            do {
                var query = db.collection("videos")
                    .order(by: "serverTimestamp", descending: true)
                
                if showOnlyPropertyVideos {
                    if !propertyIds.isEmpty {
                        // Show filtered property videos
                        query = query
                            .whereField("videoType", isEqualTo: Core.VideoType.property.rawValue)
                            .whereField("propertyId", in: Array(propertyIds))
                    } else {
                        // Show all property videos
                        query = query.whereField("videoType", isEqualTo: Core.VideoType.property.rawValue)
                    }
                }
                // When not in property-only mode, show all videos without any type filtering
                
                query = query.limit(to: pageSize)
                    .start(afterDocument: last)
                
                let querySnapshot = try await query.getDocuments()
                
                let newVideos = try querySnapshot.documents.map { try $0.data(as: Core.Video.self) }
                videos.append(contentsOf: newVideos)
                lastDocument = querySnapshot.documents.last
                isLoading = false
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    public func onVideoAppear(at index: Int) {
        if index == videos.count - 2 {
            loadMoreVideos()
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
} 