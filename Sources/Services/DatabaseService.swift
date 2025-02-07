import FirebaseFirestore
import Combine

@MainActor
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
        let docRef = db.collection("properties").document(id)
        let snapshot = try await docRef.getDocument()
        
        guard let property = try? snapshot.data(as: Property.self) else {
            throw NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Property not found"])
        }
        
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
    public func createOrGetConversation(propertyId: String, tenantId: String, managerId: String) async throws -> String {
        // Check if conversation already exists
        let querySnapshot = try await db.collection("conversations")
            .whereField("propertyId", isEqualTo: propertyId)
            .whereField("participants", arrayContainsAny: [tenantId, managerId])
            .getDocuments()
        
        if let existingDoc = querySnapshot.documents.first {
            return existingDoc.documentID
        }
        
        // Create new conversation
        let conversation = Conversation.create(propertyId: propertyId, tenantId: tenantId, managerId: managerId)
        let docRef = db.collection("conversations").document(conversation.id)
        try docRef.setData(from: conversation)
        return conversation.id
    }
    
    @MainActor
    public func sendMessage(_ message: Message) async throws {
        let batch = db.batch()
        
        // Add message
        let messageRef = db.collection("messages").document(message.id)
        try batch.setData(from: message, forDocument: messageRef)
        
        // Update conversation
        let conversationRef = db.collection("conversations").document(message.conversationId)
        batch.updateData([
            "lastMessage": message.text,
            "lastMessageTimestamp": message.timestamp,
            "hasUnreadMessages": true
        ], forDocument: conversationRef)
        
        try await batch.commit()
    }
    
    public func getMessagesStream(conversationId: String) -> AnyPublisher<[Message], Error> {
        Future { [weak self] promise in
            guard let self = self else { return }
            
            let listener = self.db.collection("messages")
                .whereField("conversationId", isEqualTo: conversationId)
                .order(by: "timestamp", descending: true)
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
                        let messages = try documents.map { try $0.data(as: Message.self) }
                        promise(.success(messages))
                    } catch {
                        promise(.failure(error))
                    }
                }
            
            self.store(listener: listener, for: "messages-\(conversationId)")
        }
        .eraseToAnyPublisher()
    }
    
    public func getConversationsStream(userId: String) -> AnyPublisher<[Conversation], Error> {
        Future { [weak self] promise in
            guard let self = self else { return }
            
            let listener = self.db.collection("conversations")
                .whereFilter(Filter.orFilter([
                    Filter.whereField("tenantId", isEqualTo: userId),
                    Filter.whereField("managerId", isEqualTo: userId)
                ]))
                .order(by: "lastMessageAt", descending: true)
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
                        let conversations = try documents.map { try $0.data(as: Conversation.self) }
                        promise(.success(conversations))
                    } catch {
                        promise(.failure(error))
                    }
                }
            
            self.store(listener: listener, for: "conversations-\(userId)")
        }
        .eraseToAnyPublisher()
    }
    
    @MainActor
    public func markConversationAsRead(conversationId: String) async throws {
        let ref = db.collection("conversations").document(conversationId)
        // Create a Sendable dictionary
        let updateData: [String: Any] = ["hasUnreadMessages": false]
        @Sendable func updateFirestore() async throws {
            try await ref.updateData(updateData)
        }
        try await updateFirestore()
    }
    
    // MARK: - Video Methods
    
    public func getVideosStream(limit: Int = 10, lastVideoId: String? = nil) -> AnyPublisher<[PropertyVideo], Error> {
        var query = db.collection("videos")
            .order(by: "uploadDate", descending: true)
            .limit(to: limit)
        
        if let lastId = lastVideoId {
            return Future { [weak self] promise in
                guard let self = self else { return }
                
                Task {
                    do {
                        let lastDoc = try await self.db.collection("videos").document(lastId).getDocument()
                        query = query.start(afterDocument: lastDoc)
                        
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
                                let videos = try documents.map { try $0.data(as: PropertyVideo.self) }
                                promise(.success(videos))
                            } catch {
                                promise(.failure(error))
                            }
                        }
                        
                        self.store(listener: listener, for: "videos-\(lastId)")
                    } catch {
                        promise(.failure(error))
                    }
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
                    let videos = try documents.map { try $0.data(as: PropertyVideo.self) }
                    promise(.success(videos))
                } catch {
                    promise(.failure(error))
                }
            }
            
            self.store(listener: listener, for: "videos-all")
        }
        .eraseToAnyPublisher()
    }
    
    public func getPropertyVideos(propertyId: String) -> AnyPublisher<[PropertyVideo], Error> {
        Future { [weak self] promise in
            guard let self = self else { return }
            
            let listener = self.db.collection("videos")
                .whereField("propertyId", isEqualTo: propertyId)
                .order(by: "uploadDate", descending: true)
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
                        let videos = try documents.map { try $0.data(as: PropertyVideo.self) }
                        promise(.success(videos))
                    } catch {
                        promise(.failure(error))
                    }
                }
            
            self.store(listener: listener, for: "property-videos-\(propertyId)")
        }
        .eraseToAnyPublisher()
    }
    
    public func createVideo(_ video: PropertyVideo) async throws -> String {
        let docRef = try await db.collection("videos").addDocument(from: video)
        return docRef.documentID
    }
    
    public func updateVideo(_ video: PropertyVideo) async throws {
        guard let id = video.id else { throw NSError(domain: "DatabaseService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video ID not found"]) }
        try await db.collection("videos").document(id).setData(from: video, merge: true)
    }
    
    public func deleteVideo(id: String) async throws {
        try await db.collection("videos").document(id).delete()
    }
} 