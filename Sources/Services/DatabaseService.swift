import Models
import FirebaseFirestore
import FirebaseFirestoreSwift
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
    
    func getProperty(id: String) async throws -> Property {
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
    
    public func createOrGetConversation(propertyId: String, tenantId: String, managerId: String) async throws -> String {
        let query = db.collection("conversations")
            .whereField("propertyId", isEqualTo: propertyId)
            .whereField("tenantId", isEqualTo: tenantId)
            .whereField("managerId", isEqualTo: managerId)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        if let existingDoc = snapshot.documents.first {
            return existingDoc.documentID
        }
        
        let conversation = Conversation(propertyId: propertyId,
                                     tenantId: tenantId,
                                     managerId: managerId)
        
        let docRef = db.collection("conversations").document()
        try docRef.setData(from: conversation)
        return docRef.documentID
    }
    
    public func sendMessage(_ message: Message) async throws {
        let batch = db.batch()
        
        let messageRef = db.collection("messages").document()
        try batch.setData(from: message, forDocument: messageRef)
        
        let conversationRef = db.collection("conversations").document(message.conversationId)
        batch.updateData([
            "lastMessageContent": message.content,
            "lastMessageAt": message.timestamp,
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
    
    public func markConversationAsRead(conversationId: String) async throws {
        let ref = db.collection("conversations").document(conversationId)
        let data = ["hasUnreadMessages": false] as [String: Any]
        try await ref.updateData(data)
    }
} 