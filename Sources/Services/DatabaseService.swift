import FirebaseFirestore
import Combine

public class DatabaseService: ObservableObject {
    private let db = Firestore.firestore()
    private var listeners: [String: ListenerRegistration] = [:]
    
    public init() {}
    
    deinit {
        // Synchronously remove listeners in deinit to avoid capture issues
        listeners.values.forEach { $0.remove() }
        listeners.removeAll()
    }
    
    private func store(listener: ListenerRegistration, for key: String) {
        listeners[key]?.remove()
        listeners[key] = listener
    }
    
    // Helper method to remove a specific listener
    public func removeListener(for key: String) {
        if let listener = listeners[key] {
            listener.remove()
            listeners.removeValue(forKey: key)
        }
    }
    
    // Helper method for type-safe dictionary updates
    private func updateData<T: Sendable>(_ data: [String: T], at ref: DocumentReference) async throws {
        try await ref.updateData(data as [String: Any])
    }
    
    // MARK: - Properties Collection
    
    public func createProperty(_ property: Property) async throws -> String {
        let docRef = db.collection("properties").document()
        try docRef.setData(from: property)
        return docRef.documentID
    }
    
    public func getProperty(id: String) async throws -> Property {
        // Added guard to ensure id is not empty
        guard !id.isEmpty else {
            throw NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Property id cannot be empty"])
        }
        let docRef = db.collection("properties").document(id)
        let snapshot = try await docRef.getDocument()
        
        // Decode property and attach the document id
        var property = try snapshot.data(as: Property.self)
        property.id = snapshot.documentID
        return property
    }
    
    public func getPropertiesStream(limit: Int = 10, lastPropertyId: String? = nil) -> AnyPublisher<[Property], Error> {
        var query = db.collection("properties")
            .order(by: "createdAt", descending: true)
        
        if limit > 0 {
            query = query.limit(to: limit)
        }
        
        if let lastId = lastPropertyId {
            let docRef = db.collection("properties").document(lastId)
            return Future { [weak self] promise in
                guard let self = self else { return }
                
                docRef.getDocument { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    guard let snapshot = snapshot else {
                        promise(.failure(NSError(domain: "", code: -1)))
                        return
                    }
                    
                    let finalQuery = query.start(afterDocument: snapshot)
                    let listener = finalQuery.addSnapshotListener { querySnapshot, error in
                        if let error = error {
                            promise(.failure(error))
                            return
                        }
                        guard let documents = querySnapshot?.documents else {
                            promise(.success([]))
                            return
                        }
                        do {
                            let properties = try documents.map { try $0.data(as: Property.self) }
                            promise(.success(properties))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                    self.store(listener: listener, for: "properties-\(lastId)")
                }
            }
            .eraseToAnyPublisher()
        }
        
        return Future { [weak self] promise in
            guard let self = self else { return }
            
            let listener = query.addSnapshotListener { querySnapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                guard let documents = querySnapshot?.documents else {
                    promise(.success([]))
                    return
                }
                do {
                    let properties = try documents.map { try $0.data(as: Property.self) }
                    promise(.success(properties))
                } catch {
                    promise(.failure(error))
                }
            }
            self.store(listener: listener, for: "properties-all")
        }
        .eraseToAnyPublisher()
    }
    
    public func updateProperty(id: String, data: [String: Any]) async throws {
        try await db.collection("properties").document(id).updateData(data)
    }
    
    public func deleteProperty(id: String) async throws {
        try await db.collection("properties").document(id).delete()
    }
    
    public func incrementPropertyViewCount(id: String) async throws {
        let ref = db.collection("properties").document(id)
        let data = ["viewCount": FieldValue.increment(Int64(1))] as [String: Any]
        try await ref.updateData(data)
    }
    
    // MARK: - Favorites
    
    @MainActor
    public func togglePropertyFavorite(userId: String, propertyId: String, isFavorite: Bool) async throws {
        let batch = db.batch()
        
        let userRef = db.collection("users").document(userId)
        let propertyRef = db.collection("properties").document(propertyId)
        
        if isFavorite {
            batch.updateData([
                "favoriteListings": FieldValue.arrayUnion([propertyId])
            ], forDocument: userRef)
            
            batch.updateData([
                "favoriteCount": FieldValue.increment(Int64(1))
            ], forDocument: propertyRef)
        } else {
            batch.updateData([
                "favoriteListings": FieldValue.arrayRemove([propertyId])
            ], forDocument: userRef)
            
            batch.updateData([
                "favoriteCount": FieldValue.increment(Int64(-1))
            ], forDocument: propertyRef)
        }
        
        try await batch.commit()
    }
    
    @MainActor
    public func getUserFavorites(userId: String) -> AnyPublisher<[Property], Error> {
        Future { [weak self] promise in
            guard let self = self else { return }
            
            let listener = self.db.collection("users").document(userId)
                .addSnapshotListener { documentSnapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    guard let document = documentSnapshot else {
                        promise(.success([]))
                        return
                    }
                    
                    do {
                        let user = try document.data(as: User.self)
                        let favoriteIds = user.favoriteListings
                        
                        if favoriteIds.isEmpty {
                            promise(.success([]))
                            return
                        }
                        
                        self.db.collection("properties")
                            .whereField(FieldPath.documentID(), in: favoriteIds)
                            .getDocuments { querySnapshot, error in
                                if let error = error {
                                    promise(.failure(error))
                                    return
                                }
                                
                                guard let documents = querySnapshot?.documents else {
                                    promise(.success([]))
                                    return
                                }
                                
                                do {
                                    let properties = try documents.map { try $0.data(as: Property.self) }
                                    promise(.success(properties))
                                } catch {
                                    promise(.failure(error))
                                }
                            }
                    } catch {
                        promise(.failure(error))
                    }
                }
            
            self.store(listener: listener, for: "favorites-\(userId)")
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Messages
    
    @MainActor
    public func createOrGetConversation(propertyId: String, tenantId: String, managerId: String, videoId: String? = nil) async throws -> String {
        print("🔄 DatabaseService: Checking for existing channel - videoId: \(videoId ?? ""), buyerId: \(tenantId)")
        
        // Check if chat channel already exists
        let querySnapshot = try await db.collection("chatChannels")
            .whereField("propertyId", isEqualTo: propertyId)
            .whereField("buyerId", isEqualTo: tenantId)
            .whereField("sellerId", isEqualTo: managerId)
            .getDocuments()
        
        if let existingDoc = querySnapshot.documents.first {
            print("ℹ️ DatabaseService: Channel already exists")
            return existingDoc.documentID
        }
        
        print("🆕 DatabaseService: Creating new channel")
        
        // Get property info to create chat title
        let property = try await getProperty(id: propertyId)
        let chatTitle: String
        if let videoId = videoId,
           let video = try? await getVideo(id: videoId) {
            chatTitle = "\(property.title): \(video.title)"
        } else {
            chatTitle = property.title
        }
        
        // Create new chat channel using ChatChannel model
        var channel = ChatChannel(
            buyerId: tenantId,
            sellerId: managerId,
            propertyId: propertyId,
            videoId: videoId ?? "",
            chatTitle: chatTitle,
            lastMessage: nil,
            lastMessageTimestamp: nil,
            serverTimestamp: Timestamp(date: Date()),
            lastSenderId: nil,
            isRead: true
        )
        let channelId = channel.id ?? UUID().uuidString
        channel.id = channelId
        let docRef = db.collection("chatChannels").document(channelId)
        print("📝 DatabaseService: Setting data for channel \(channelId)")
        try docRef.setData(from: channel)
        print("✅ DatabaseService: Channel created")
        return channelId
    }
    
    @MainActor
    public func sendMessage(_ message: ChatMessage) async throws {
        print("📤 DatabaseService: Sending message in channel \(message.channelId)")
        
        let messageRef = db.collection("chatMessages").document(message.id ?? UUID().uuidString)
        let messageId = message.id ?? UUID().uuidString
        
        let batch = db.batch()
        
        // Prepare message data with server timestamp for message.timestamp
        var messageData: [String: Any] = [
            "id": messageId,
            "channelId": message.channelId,
            "senderId": message.senderId,
            "text": message.text
        ]
        if let attachmentUrl = message.attachmentUrl {
            messageData["attachmentUrl"] = attachmentUrl
        }
        if let attachmentType = message.attachmentType {
            messageData["attachmentType"] = attachmentType
        }
        messageData["timestamp"] = FieldValue.serverTimestamp()
        
        batch.setData(messageData, forDocument: messageRef)
        
        // Update chat channel with server timestamp for lastMessageTimestamp
        let channelRef = db.collection("chatChannels").document(message.channelId)
        batch.updateData([
            "lastMessage": message.text,
            "lastMessageTimestamp": FieldValue.serverTimestamp(),
            "lastSenderId": message.senderId,
            "isRead": false
        ], forDocument: channelRef)
        
        try await batch.commit()
        print("✅ DatabaseService: Message sent and channel updated")
    }
    
    @MainActor
    public func getMessagesStream(channelId: String) -> AnyPublisher<[ChatMessage], Error> {
        let subject = PassthroughSubject<[ChatMessage], Error>()

        let listener = self.db.collection("chatMessages")
            .whereField("channelId", isEqualTo: channelId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    subject.send(completion: .failure(error))
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    subject.send([])
                    return
                }

                do {
                    let messages = try documents.map { try $0.data(as: ChatMessage.self) }
                    subject.send(messages)
                } catch {
                    subject.send(completion: .failure(error))
                }
            }

        self.store(listener: listener, for: "messages-\(channelId)")
        return subject.eraseToAnyPublisher()
    }
    
    @MainActor
    public func getConversationsStream(userId: String) -> AnyPublisher<[ChatChannel], Error> {
        Future { [weak self] promise in
            guard let self = self else { return }
            
            let listener = self.db.collection("chatChannels")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("buyerId", isEqualTo: userId),
                    Filter.whereField("sellerId", isEqualTo: userId)
                ]))
                .order(by: "serverTimestamp", descending: true)
                .addSnapshotListener { querySnapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    guard let documents = querySnapshot?.documents else {
                        promise(.success([]))
                        return
                    }
                    
                    do {
                        let channels = try documents.map { try $0.data(as: ChatChannel.self) }
                        promise(.success(channels))
                    } catch {
                        promise(.failure(error))
                    }
                }
            
            self.store(listener: listener, for: "conversations-\(userId)")
        }
        .eraseToAnyPublisher()
    }
    
    @MainActor
    public func markChannelAsRead(channelId: String, forUserId currentUserId: String) async throws {
        let ref = db.collection("chatChannels").document(channelId)
        let snapshot = try await ref.getDocument()
        guard let channel = try? snapshot.data(as: ChatChannel.self),
              channel.lastSenderId != currentUserId else {
            return // Don't mark as read if the last message was sent by the current user
        }
        
        try await ref.updateData(["isRead": true])
    }
    
    // MARK: - Video Methods
    
    public func getVideosStream(limit: Int = 10, lastVideoId: String? = nil, userId: String? = nil) -> AnyPublisher<[Video], Error> {
        var query = db.collection("videos")
            .order(by: "uploadDate", descending: true)
            .limit(to: limit)
        
        if let userId = userId {
            query = query.whereField("userId", isEqualTo: userId)
        }
        
        if let lastId = lastVideoId {
            return Future { [weak self] promise in
                guard let self = self else { return }
                
                let docRef = self.db.collection("videos").document(lastId)
                docRef.getDocument { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        promise(.failure(NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Document not found"])))
                        return
                    }
                    
                    let listener = query.start(afterDocument: snapshot).addSnapshotListener { querySnapshot, error in
                        if let error = error {
                            promise(.failure(error))
                            return
                        }
                        
                        guard let documents = querySnapshot?.documents else {
                            promise(.success([]))
                            return
                        }
                        
                        do {
                            let videos = try documents.map { try $0.data(as: Video.self) }
                            promise(.success(videos))
                        } catch {
                            promise(.failure(error))
                        }
                    }
                    
                    self.store(listener: listener, for: "videos-\(lastId)")
                }
            }
            .eraseToAnyPublisher()
        }
        
        return Future { [weak self] promise in
            guard let self = self else { return }
            
            let listener = query.addSnapshotListener { querySnapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    promise(.success([]))
                    return
                }
                
                do {
                    let videos = try documents.map { try $0.data(as: Video.self) }
                    promise(.success(videos))
                } catch {
                    promise(.failure(error))
                }
            }
            
            self.store(listener: listener, for: "videos-all")
        }
        .eraseToAnyPublisher()
    }
    
    public func getPropertyVideos(propertyId: String, userId: String? = nil) -> AnyPublisher<[Video], Error> {
        Future { [weak self] promise in
            guard let self = self else { return }
            
            var query = self.db.collection("videos")
                .whereField("propertyId", isEqualTo: propertyId)
                .order(by: "uploadDate", descending: true)
            
            if let userId = userId {
                query = query.whereField("userId", isEqualTo: userId)
            }
            
            let listener = query.addSnapshotListener { querySnapshot, error in
                if let error = error {
                    promise(.failure(error))
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    promise(.success([]))
                    return
                }
                
                do {
                    let videos = try documents.map { try $0.data(as: Video.self) }
                    promise(.success(videos))
                } catch {
                    promise(.failure(error))
                }
            }
            
            self.store(listener: listener, for: "property-videos-\(propertyId)")
        }
        .eraseToAnyPublisher()
    }
    
    public func createVideo(_ video: Video) async throws -> String {
        let docRef = try db.collection("videos").addDocument(from: video)
        return docRef.documentID
    }
    
    public func updateVideo(_ video: Video) async throws {
        guard let id = video.id else { throw NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video ID not found"]) }
        try db.collection("videos").document(id).setData(from: video, merge: true)
    }
    
    // Updates a video document with a targeted update using a dictionary of fields.
    // This method is recommended for actions such as toggling likes,
    // where only specific fields ('likeCount' and 'likedBy') need to be updated.
    public func updateVideo(id: String, data: [String: Any]) async throws {
        try await db.collection("videos").document(id).updateData(data)
    }
    
    public func deleteVideo(id: String) async throws {
        try await db.collection("videos").document(id).delete()
    }
    
    public func getVideo(id: String) async throws -> Video {
        let snapshot = try await db.collection("videos").document(id).getDocument()
        guard let data = snapshot.data(), snapshot.exists else {
            throw NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video not found"])
        }
        
        var video = try Firestore.Decoder().decode(Video.self, from: data)
        video.id = snapshot.documentID
        return video
    }
    
    // One-time fetch of properties
    public func getProperties() async throws -> [Property] {
        let query = db.collection("properties")
            .order(by: "createdAt", descending: true)
        
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map { document in
            var property = try document.data(as: Property.self)
            property.id = document.documentID
            return property
        }
    }
} 